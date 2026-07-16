import QtQuick
import QtQuick.Layouts
import qs.core

Rectangle {
    id: root

    required property var network
    property bool selected: false
    property bool busy: false
    signal selectedRequested
    signal connectRequested(var network)

    height: 54
    color: root.network.active ? Theme.accent : (root.selected ? Theme.surfaceHover : (rowMouse.containsMouse ? Theme.surfaceHover : Theme.surface))
    border.color: root.selected && !root.network.active ? Theme.accent : Theme.border
    border.width: root.selected && !root.network.active ? 1 : 0
    radius: Theme.radius

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onClicked: root.selectedRequested()
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.rowSpacing
        anchors.rightMargin: Theme.rowSpacing
        spacing: Theme.rowSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.compactSpacing

            Text {
                Layout.fillWidth: true
                text: root.network.ssid
                color: root.network.active ? Theme.accentText : Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelFontSize
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (root.network.security.length > 0 ? root.network.security : "Open") + " - " + root.network.signal + "% - " + root.network.device
                color: root.network.active ? Theme.accentText : Theme.textMuted
                opacity: root.network.active ? 0.7 : 1.0
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                elide: Text.ElideRight
            }
        }

        Text {
            Layout.preferredWidth: 54
            text: root.network.active ? "Active" : ""
            color: root.network.active ? Theme.accentText : Theme.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
        }

        Rectangle {
            Layout.preferredWidth: actionText.implicitWidth + 18
            Layout.preferredHeight: Theme.chipHeight
            color: root.network.active ? (actionMouse.containsMouse && !root.busy ? Theme.surfaceHover : Theme.surface) : (actionMouse.containsMouse && !root.busy ? Theme.accent : Theme.border)
            radius: Theme.radius
            opacity: root.busy ? 0.5 : 1

            Text {
                id: actionText

                anchors.centerIn: parent
                text: "Connect"
                color: (!root.network.active && actionMouse.containsMouse && !root.busy) ? Theme.accentText : Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }

            MouseArea {
                id: actionMouse

                anchors.fill: parent
                enabled: !root.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.connectRequested(root.network)
            }
        }
    }
}
