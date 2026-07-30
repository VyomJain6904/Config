(function () {
  "use strict";

  const SCRIPT_VERSION = "6";
  const CONTROLLER_KEY = "__quickshellMediaArtworkController";
  const ORIGINAL_POST_MESSAGE_KEY = "__quickshellOriginalPostMessage";
  const ARTWORK_MESSAGE_SOURCE = "quickshell-media-artwork-v3";
  const BRIDGE_TOKEN_ATTRIBUTE = "data-quickshell-media-artwork-token";
  const CHECK_INTERVAL_MS = 1500;
  const MIN_LARGE_THUMBNAIL_WIDTH = 640;
  const MIN_LARGE_THUMBNAIL_HEIGHT = 360;
  const YOUTUBE_THUMBNAIL_SIZES = ["maxresdefault", "hq720", "sddefault", "hqdefault", "mqdefault"];
  const PLACEHOLDER_TITLES = new Set([
    "",
    "media",
    "unknown",
    "untitled",
    "no title",
    "a site is playing media"
  ]);

  const previousController = window[CONTROLLER_KEY];
  if (previousController && typeof previousController.stop === "function") {
    previousController.stop();
  }

  let stopped = false;
  let resolveTimer = null;
  let intervalTimer = null;
  let resolving = false;
  let resolvePending = false;
  let resolveGeneration = 0;
  let lastPageKey = "";
  let lastPublishedKey = "";
  let observedLocation = window.location.href;
  const mediaListeners = new Map();

  // Prevent an older main-world resolver from sending v2 messages to an old,
  // invalidated bridge after the extension is reloaded.
  const originalPostMessage = window[ORIGINAL_POST_MESSAGE_KEY] || window.postMessage.bind(window);
  window[ORIGINAL_POST_MESSAGE_KEY] = originalPostMessage;
  window.postMessage = function (message, targetOrigin, transfer) {
    if (message && (message.source === "quickshell-media-artwork-v2" || message.source === "quickshell-media-artwork")) {
      return;
    }
    return originalPostMessage(message, targetOrigin, transfer);
  };

  function cleanTitle(value) {
    return typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
  }

  function usableTitle(value) {
    const title = cleanTitle(value);
    return PLACEHOLDER_TITLES.has(title.toLowerCase()) ? "" : title;
  }

  function absoluteUrl(value) {
    if (!value) {
      return "";
    }
    try {
      return new URL(value, window.location.href).href;
    } catch (_) {
      return "";
    }
  }

  function metadataImage(selectors) {
    for (const selector of selectors) {
      const element = document.querySelector(selector);
      const value = element && element.getAttribute("content");
      const url = absoluteUrl(value);
      if (url) {
        return url;
      }
    }
    return "";
  }

  function youtubeVideoId(url) {
    try {
      const parsed = new URL(url);
      if (parsed.hostname === "youtu.be") {
        return parsed.pathname.slice(1).split("/")[0];
      }
      if (parsed.hostname === "youtube.com" || parsed.hostname.endsWith(".youtube.com")) {
        if (parsed.searchParams.get("v")) {
          return parsed.searchParams.get("v");
        }
        const parts = parsed.pathname.split("/").filter(Boolean);
        if (["shorts", "live", "embed"].includes(parts[0])) {
          return parts[1] || "";
        }
      }
    } catch (_) {
      return "";
    }
    return "";
  }

  function imageDimensions(url) {
    return new Promise((resolve) => {
      const image = new Image();
      const timeout = window.setTimeout(() => {
        image.onload = null;
        image.onerror = null;
        resolve(null);
      }, 2500);
      image.onload = () => {
        window.clearTimeout(timeout);
        resolve({
          width: image.naturalWidth,
          height: image.naturalHeight,
          area: image.naturalWidth * image.naturalHeight
        });
      };
      image.onerror = () => {
        window.clearTimeout(timeout);
        resolve(null);
      };
      image.src = url;
    });
  }

  async function youtubeArtwork(url) {
    const videoId = youtubeVideoId(url);
    if (!videoId) {
      return "";
    }

    const candidates = await Promise.all(YOUTUBE_THUMBNAIL_SIZES.map(async (size, index) => {
      const candidateUrl = `https://i.ytimg.com/vi/${encodeURIComponent(videoId)}/${size}.jpg`;
      const dimensions = await imageDimensions(candidateUrl);
      if (!dimensions || dimensions.width < MIN_LARGE_THUMBNAIL_WIDTH || dimensions.height < MIN_LARGE_THUMBNAIL_HEIGHT) {
        return null;
      }
      return { url: candidateUrl, index, ...dimensions };
    }));

    const validCandidates = candidates.filter(Boolean).sort((left, right) => {
      return right.area - left.area || left.index - right.index;
    });
    return validCandidates.length > 0 ? validCandidates[0].url : "";
  }

  function currentMediaElement() {
    const media = Array.from(document.querySelectorAll("video, audio"));
    const playing = media.find((element) => !element.paused && !element.ended && element.readyState > 0);
    return playing || media.find((element) => element.readyState > 0) || null;
  }

  function mediaElementArtwork(media) {
    return media && media.tagName === "VIDEO" ? absoluteUrl(media.poster) : "";
  }

  function existingArtwork() {
    const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
    const artwork = metadata && metadata.artwork;
    if (!artwork || artwork.length === 0) {
      return "";
    }
    return absoluteUrl(artwork[artwork.length - 1].src);
  }

  function genericArtwork(media) {
    return metadataImage([
      'meta[property="og:image"]',
      'meta[name="twitter:image"]',
      'meta[property="twitter:image"]'
    ]) || mediaElementArtwork(media) || existingArtwork();
  }

  function mediaTitle(media) {
    const metadata = navigator.mediaSession && navigator.mediaSession.metadata;
    const videoTitle = media && (media.getAttribute("aria-label") || media.getAttribute("title"));
    const openGraphTitle = document.querySelector('meta[property="og:title"]');
    const youtubeHeading = document.querySelector("h1.ytd-watch-metadata, h1.title");
    const candidates = [
      metadata && metadata.title,
      videoTitle,
      openGraphTitle && openGraphTitle.getAttribute("content"),
      youtubeHeading && youtubeHeading.textContent,
      document.title
    ];

    for (const candidate of candidates) {
      const title = usableTitle(candidate);
      if (title) {
        return title;
      }
    }

    // Some players expose only the generic Chromium title. Keep those pages
    // eligible for artwork by using a stable, human-readable page identity.
    try {
      const page = new URL(window.location.href);
      const path = decodeURIComponent(page.pathname)
        .split("/")
        .filter(Boolean)
        .pop();
      return cleanTitle(path ? `${page.hostname} — ${path}` : page.hostname);
    } catch (_) {
      return "Web media";
    }
  }

  function mediaUrl(media) {
    return media ? absoluteUrl(media.currentSrc || media.src || "") : "";
  }

  function currentPageKey(media) {
    return `${window.location.href}|${mediaUrl(media)}|${mediaTitle(media)}`;
  }

  function publishArtwork(url, media, pageKey) {
    if (!url) {
      return;
    }

    const title = mediaTitle(media);
    if (!title) {
      return;
    }

    const bridgeToken = document.documentElement && document.documentElement.getAttribute(BRIDGE_TOKEN_ATTRIBUTE);
    if (!bridgeToken) {
      return;
    }

    const publishKey = `${pageKey}|${url}`;
    if (publishKey === lastPublishedKey) {
      return;
    }

    originalPostMessage({
      source: ARTWORK_MESSAGE_SOURCE,
      bridgeToken,
      pageUrl: window.location.href,
      mediaUrl: mediaUrl(media),
      title,
      artworkUrl: url,
      pageKey
    }, "*");
    lastPublishedKey = publishKey;
  }

  function scheduleResolve(delay = 150, navigation = false) {
    if (stopped) {
      return;
    }
    resolvePending = true;
    if (navigation) {
      resolveGeneration += 1;
      lastPageKey = "";
      lastPublishedKey = "";
    }
    if (resolveTimer !== null) {
      window.clearTimeout(resolveTimer);
    }
    resolveTimer = window.setTimeout(() => {
      resolveTimer = null;
      void resolveArtwork();
    }, delay);
  }

  async function resolveArtwork() {
    if (stopped || resolving) {
      return;
    }

    resolving = true;
    resolvePending = false;
    const generation = resolveGeneration;
    const media = currentMediaElement();
    const pageKey = currentPageKey(media);
    if (pageKey !== lastPageKey) {
      lastPageKey = pageKey;
      lastPublishedKey = "";
    }

    try {
      const artwork = (await youtubeArtwork(window.location.href)) || genericArtwork(media);
      const currentMedia = currentMediaElement();
      const currentKey = currentPageKey(currentMedia);
      if (!stopped && generation === resolveGeneration && currentKey === pageKey) {
        publishArtwork(artwork, currentMedia, currentKey);
      } else {
        resolvePending = true;
      }
    } finally {
      resolving = false;
      if (!stopped && (resolvePending || generation !== resolveGeneration || currentPageKey(currentMediaElement()) !== pageKey)) {
        scheduleResolve(100);
      }
    }
  }

  function observeMedia(media) {
    if (!media || mediaListeners.has(media)) {
      return;
    }
    const listener = () => scheduleResolve(100);
    const events = ["play", "pause", "loadedmetadata", "loadeddata", "durationchange", "canplay", "emptied"];
    events.forEach((eventName) => media.addEventListener(eventName, listener, { passive: true }));
    mediaListeners.set(media, { listener, events });
  }

  function scheduleNavigationResolve() {
    observedLocation = window.location.href;
    scheduleResolve(250, true);
  }

  const observer = new MutationObserver(() => {
    document.querySelectorAll("video, audio").forEach(observeMedia);
    scheduleResolve(200);
  });
  observer.observe(document.documentElement || document, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ["src", "poster", "aria-label", "title", "content"]
  });

  const navigationEvents = ["popstate", "hashchange", "yt-navigate-finish", "yt-page-data-updated", "yt-player-updated", "yt-player-state-change"];
  navigationEvents.forEach((eventName) => {
    document.addEventListener(eventName, scheduleNavigationResolve, true);
  });
  window.addEventListener("popstate", scheduleNavigationResolve, { passive: true });
  window.addEventListener("hashchange", scheduleNavigationResolve, { passive: true });

  intervalTimer = window.setInterval(() => {
    if (window.location.href !== observedLocation) {
      scheduleNavigationResolve();
    }
    document.querySelectorAll("video, audio").forEach(observeMedia);
    scheduleResolve(1000);
  }, CHECK_INTERVAL_MS);

  const controller = {
    stop() {
      if (stopped) {
        return;
      }
      stopped = true;
      observer.disconnect();
      if (resolveTimer !== null) {
        window.clearTimeout(resolveTimer);
        resolveTimer = null;
      }
      if (intervalTimer !== null) {
        window.clearInterval(intervalTimer);
        intervalTimer = null;
      }
      navigationEvents.forEach((eventName) => document.removeEventListener(eventName, scheduleNavigationResolve, true));
      window.removeEventListener("popstate", scheduleNavigationResolve);
      window.removeEventListener("hashchange", scheduleNavigationResolve);
      for (const [media, registration] of mediaListeners) {
        registration.events.forEach((eventName) => media.removeEventListener(eventName, registration.listener));
      }
      mediaListeners.clear();
      if (window[CONTROLLER_KEY] === controller) {
        delete window[CONTROLLER_KEY];
      }
    }
  };

  window[CONTROLLER_KEY] = controller;
  window.__quickshellMediaArtworkLoaded = SCRIPT_VERSION;
  document.querySelectorAll("video, audio").forEach(observeMedia);
  scheduleResolve(100);
})();
