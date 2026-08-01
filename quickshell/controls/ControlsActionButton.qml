import QtQuick
import qs.core

Rectangle {
    id: root

    required property string label
    property bool enabled: true
    property bool selected: false
    property string labelFontFamily: Theme.fontFamily
    property int labelPixelSize: Theme.panelFontSize

    signal activated

    implicitWidth: buttonLabel.implicitWidth + 18
    implicitHeight: Theme.buttonHeight
    radius: Theme.radius
    color: selected ? Theme.buttonFocusBackground : (controlMouse.containsMouse && root.enabled ? Theme.buttonHoverBackground : Theme.buttonBackground)
    border.color: selected ? Theme.accent : Theme.border
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
