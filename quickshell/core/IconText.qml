import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    ICON TEXT PRIMITIVE (IconText.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Specializes UiText for rendering single glyph font icons (Nerd Fonts) with
 * centered horizontal alignment and vibrant accent text coloring.
 * ─────────────────────────────────────────────────────────────────────────────
 */
UiText {
    color: Theme.accent
    font.family: Theme.iconFontFamily
    font.pixelSize: Theme.panelFontSize + 1
    horizontalAlignment: Text.AlignHCenter
}
