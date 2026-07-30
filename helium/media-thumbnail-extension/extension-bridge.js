(function () {
  "use strict";

  const BRIDGE_VERSION = "6";
  const CONTROLLER_KEY = "__quickshellMediaArtworkBridgeController";
  const ARTWORK_MESSAGE_SOURCE = "quickshell-media-artwork-v3";
  const BRIDGE_READY_SOURCE = "quickshell-media-artwork-ready-v1";
  const BRIDGE_TOKEN_ATTRIBUTE = "data-quickshell-media-artwork-token";
  const previousController = globalThis[CONTROLLER_KEY];
  if (previousController && typeof previousController.stop === "function") {
    previousController.stop();
  }

  let stopped = false;
  const bridgeToken = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
  if (document.documentElement) {
    document.documentElement.setAttribute(BRIDGE_TOKEN_ATTRIBUTE, bridgeToken);
  }

  function sendArtwork(message) {
    try {
      const result = chrome.runtime.sendMessage({
        source: ARTWORK_MESSAGE_SOURCE,
        pageUrl: message.pageUrl || "",
        mediaUrl: message.mediaUrl || "",
        pageKey: message.pageKey || "",
        title: message.title || "",
        artworkUrl: message.artworkUrl || ""
      });
      if (result && typeof result.catch === "function") {
        result.catch(() => {});
      }
    } catch (_) {
      // The extension may be reloaded while this page remains open.
    }
  }

  function onMessage(event) {
    if (stopped || event.source !== window || !event.data) {
      return;
    }
    if (event.data.source !== ARTWORK_MESSAGE_SOURCE || event.data.bridgeToken !== bridgeToken) {
      return;
    }

    const title = typeof event.data.title === "string" ? event.data.title.trim() : "";
    if (!event.data.artworkUrl) {
      return;
    }

    event.stopImmediatePropagation();
    sendArtwork({
      pageUrl: event.data.pageUrl,
      mediaUrl: event.data.mediaUrl,
      pageKey: event.data.pageKey,
      title,
      artworkUrl: event.data.artworkUrl
    });
  }

  window.addEventListener("message", onMessage, true);

  const controller = {
    stop() {
      if (stopped) {
        return;
      }
      stopped = true;
      window.removeEventListener("message", onMessage, true);
      if (globalThis[CONTROLLER_KEY] === controller) {
        delete globalThis[CONTROLLER_KEY];
      }
    }
  };

  globalThis[CONTROLLER_KEY] = controller;
  globalThis.__quickshellMediaArtworkBridgeLoaded = BRIDGE_VERSION;
  try {
    chrome.runtime.sendMessage({
      source: BRIDGE_READY_SOURCE,
      version: BRIDGE_VERSION,
      pageUrl: window.location.href
    }).catch(() => {});
  } catch (_) {
    // Ignore invalidated extension contexts during reload.
  }
})();
