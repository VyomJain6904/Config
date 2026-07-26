import QtQuick
import qs.core

Rectangle {
    id: root

    required property var action
    property bool compact: false
    property bool danger: false
    property bool selected: false

    signal activated

    radius: Theme.radius
    color: selected ? Theme.surfaceActive : (actionMouse.containsMouse ? Theme.surfaceHover : Theme.surface)
    border.color: selected ? Theme.accent : (danger ? Theme.danger : Theme.border)
    border.width: 1

    MouseArea {
        id: actionMouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: root.activated()
    }

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
