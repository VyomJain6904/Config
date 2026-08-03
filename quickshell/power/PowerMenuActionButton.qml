import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                POWER MENU ACTION BUTTON (PowerMenuActionButton.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Reusable selection card for power management operations. Supports compact
 * modal sizing and semantic danger highlighting for shutdown actions.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    // ── Configuration & Interaction Properties ───────────────────────────────
    required property var action          // Power action descriptor object
    property bool compact: false          // Enables condensed confirmation padding
    property bool danger: false           // Applies danger accent colors when true
    property bool selected: false         // True when highlighted via keyboard arrows

    signal activated

    // ── Visual Geometry & Styling ────────────────────────────────────────────
    radius: Theme.radius
    color: selected ? Theme.buttonFocusBackground : (actionMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
    border.color: selected ? Theme.accent : (danger ? Theme.danger : Theme.border)
    border.width: 1

    MouseArea {
        id: actionMouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.activated()
    }

    // ── Action Title and Detail Text ─────────────────────────────────────────
    Column {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: root.compact ? 12 : 14
        anchors.rightMargin: root.compact ? 12 : 14
        spacing: root.compact ? Theme.compactSpacing : Theme.listSpacing

        Text {
            width: parent.width
            text: root.action.label
            color: root.selected ? Theme.textStrong : (root.danger ? Theme.textStrong : Theme.text)
            font.family: Theme.fontFamily
            font.pixelSize: root.compact ? Theme.bodyFontSize : Theme.bodyFontSize + 1
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            text: root.action.detail || ""
            color: root.selected ? Theme.text : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            elide: Text.ElideRight
            visible: text.length > 0
        }
    }
}
