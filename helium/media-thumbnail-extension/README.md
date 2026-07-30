# Quickshell Media Artwork

This unpacked Chromium/Helium extension sends high-quality page artwork to the
local Quickshell media-artwork bridge. Quickshell displays the cached original
image directly instead of enlarging Chromium's low-resolution MPRIS artwork.

It supports:

- YouTube, including `watch`, `shorts`, `live`, `embed`, and `youtu.be` URLs.
- Twitch and other sites through Open Graph/Twitter image metadata or video posters.
- Pornhub, FPO.xxx, and other sites without site-specific credentials through the
  same generic metadata fallback.

Local media players are handled separately through MPRIS/playerctl, so VLC, mpv,
Spotify, Rhythmbox, and other native players can show their own album artwork
without the browser extension.

## Install in Helium

1. Open `helium://extensions`.
2. Enable **Developer mode**.
3. Choose **Load unpacked**.
4. Select this directory:
   `/home/jain/Study/Config/helium/media-thumbnail-extension`
5. Click **Reload** on the extension once after updating it.

The extension automatically attaches to already-open HTTP/HTTPS tabs as soon
as its service worker starts, and to future tabs. After that one extension
reload, changing videos in YouTube or navigating between media pages does not
require reloading the page.

The Quickshell bridge listens only on `127.0.0.1:47831` and is started by the
Quickshell controls model. The existing MPRIS artwork fallback remains active if
a page does not expose usable artwork. This extension does not store page URLs,
cookies, credentials, or private browsing data.
