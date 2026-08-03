import QtQuick
import QtQuick.Layouts
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    SECTION LABEL HEADER (SectionLabel.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Standardized bold title heading used to separate categorized groupings inside
 * modals, menus, and network lists.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Text {
    required property string label

    Layout.fillWidth: true
    text: label
    color: Theme.text
    font.family: Theme.fontFamily
    font.pixelSize: Theme.smallFontSize
    font.bold: true
    elide: Text.ElideRight
}
