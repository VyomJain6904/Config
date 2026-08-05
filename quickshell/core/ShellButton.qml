import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    INTERACTIVE SHELL BUTTON (ShellButton.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Unified interactive action button used across confirmation modals, network
 * toggles, and system controls. Includes automatic hover and selected states.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    // ── Public Interface & Signals ───────────────────────────────────────────
    required property string label          // Display text label
    property bool compact: true             // Uses smaller text sizing if true
    property bool selected: false           // Highlights button when toggled active
    property bool hovered: buttonMouse.containsMouse

    signal activated                        // Emitted upon mouse click

    // ── Dimensions & Dynamic Styling ─────────────────────────────────────────
    implicitWidth: buttonLabel.implicitWidth + 18
    implicitHeight: Theme.buttonHeight
    color: selected ? Theme.buttonFocusBackground : (hovered && enabled ? Theme.buttonHoverBackground : Theme.buttonBackground)
    border.color: selected ? Theme.accent : (hovered && enabled ? Theme.borderStrong : Theme.border)
    border.width: 1
    radius: Theme.radius
    opacity: enabled ? 1 : 0.5

    // ── Centered Label Text ──────────────────────────────────────────────────
    Text {
        id: buttonLabel

        anchors.centerIn: parent
        text: root.label
        color: Theme.text
        font.family: Theme.fontFamily
        font.pixelSize: root.compact ? Theme.smallFontSize : Theme.panelFontSize
        font.bold: true
        elide: Text.ElideRight
    }

    // ── Mouse Interaction Handling ───────────────────────────────────────────
    MouseArea {
        id: buttonMouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
