import QtQuick
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *              CONTROLS ACTION BUTTON (ControlsActionButton.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Customizable pill button used across utility panels for toggling device
 * states, triggering scans, and running system configurations.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    // ── Button Text & Interactive States ─────────────────────────────────────
    required property string label
    property bool enabled: true
    property bool selected: false
    property string labelFontFamily: Theme.fontFamily
    property int labelPixelSize: Theme.panelFontSize

    signal activated

    // ── Geometry & Visual Feedback ───────────────────────────────────────────
    implicitWidth: buttonLabel.implicitWidth + 18
    implicitHeight: Theme.buttonHeight
    radius: Theme.radius
    color: selected ? Theme.buttonFocusBackground : (controlMouse.containsMouse && root.enabled ? Theme.buttonHoverBackground : Theme.buttonBackground)
    border.color: selected ? Theme.accent : (controlMouse.containsMouse && root.enabled ? Theme.borderStrong : Theme.border)
    border.width: 1
    opacity: root.enabled ? 1 : 0.5

    Text {
        id: buttonLabel

        anchors.centerIn: parent
        text: root.label
        color: Theme.text
        font.family: root.labelFontFamily
        font.pixelSize: root.labelPixelSize
        font.bold: true
        elide: Text.ElideRight
    }

    MouseArea {
        id: controlMouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
