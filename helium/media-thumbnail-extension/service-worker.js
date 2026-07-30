const ARTWORK_MESSAGE_SOURCE = "quickshell-media-artwork-v3";
const BRIDGE_READY_SOURCE = "quickshell-media-artwork-ready-v1";
const BRIDGE_URL = "http://127.0.0.1:47831/v1/artwork";

async function injectArtworkScripts(tabId) {
  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      files: ["extension-bridge.js"],
      injectImmediately: true
    });
  } catch (_) {
    // Internal browser pages and restricted frames can reject injection.
  }

  try {
    await chrome.scripting.executeScript({
      target: { tabId },
      files: ["media-artwork.js"],
      world: "MAIN",
      injectImmediately: true
    });
  } catch (_) {
    // Internal browser pages and restricted frames can reject injection.
  }
}

async function injectExistingTabs() {
  let tabs = [];
  try {
    tabs = await chrome.tabs.query({ url: ["http://*/*", "https://*/*"] });
  } catch (_) {
    return;
  }

  await Promise.all(
    tabs
      .filter((tab) => Number.isInteger(tab.id))
      .map((tab) => injectArtworkScripts(tab.id))
  );
}

chrome.runtime.onInstalled.addListener(() => {
  void injectExistingTabs();
});

chrome.runtime.onStartup.addListener(() => {
  void injectExistingTabs();
});

chrome.tabs.onUpdated.addListener((tabId, changeInfo) => {
  if (changeInfo.status === "complete") {
    void injectArtworkScripts(tabId);
  }
});

chrome.tabs.onActivated.addListener(({ tabId }) => {
  void injectArtworkScripts(tabId);
});

void injectExistingTabs();

async function forwardArtwork(message) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 6000);
  try {
    const response = await fetch(BRIDGE_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        pageUrl: message.pageUrl || "",
        mediaUrl: message.mediaUrl || "",
        pageKey: message.pageKey || "",
        title: message.title,
        artworkUrl: message.artworkUrl
      }),
      signal: controller.signal
    });
    if (!response.ok) {
      throw new Error(`bridge returned HTTP ${response.status}`);
    }
    return { ok: true };
  } finally {
    clearTimeout(timeout);
  }
}

chrome.runtime.onMessage.addListener((message, _sender, sendResponse) => {
  if (message?.source === BRIDGE_READY_SOURCE) {
    sendResponse({ ok: true, version: message.version || "" });
    return false;
  }

  if (!message || message.source !== ARTWORK_MESSAGE_SOURCE || !message.artworkUrl) {
    sendResponse({ ok: false, error: "invalid artwork message" });
    return false;
  }

  void forwardArtwork({ ...message, title })
    .then((result) => sendResponse(result))
    .catch((error) => {
      console.debug("Quickshell artwork bridge unavailable", error?.message || error);
      sendResponse({ ok: false, error: "bridge unavailable" });
    });
  return true;
});
