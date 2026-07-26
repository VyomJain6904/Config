import QtQuick
import qs.core

Rectangle {
    id: root

    required property string label
    property bool compact: true
    property bool selected: false
    property bool hovered: buttonMouse.containsMouse

    signal activated

    implicitWidth: buttonLabel.implicitWidth + 18
    implicitHeight: Theme.buttonHeight
    color: selected ? Theme.surfaceActive : (hovered && enabled ? Theme.surfaceHover : Theme.surface)
    border.color: "transparent"
    border.width: 0
    radius: Theme.radius
    opacity: enabled ? 1 : 0.5

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

    MouseArea {
        id: buttonMouse

        anchors.fill: parent
        enabled: root.enabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
