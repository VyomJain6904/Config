import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    NATIVE UI TEXT PRIMITIVE (UiText.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Standard text component ensuring consistent JetBrainsMono Nerd Font styling,
 * system panel font sizing, and sharp NativeRendering typography across apps.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Text {
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.panelFontSize
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
