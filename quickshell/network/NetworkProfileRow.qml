import QtQuick
import QtQuick.Layouts
import qs.core

Rectangle {
    id: root

    required property var profile
    signal disconnectRequested(string device)

    height: Theme.confirmButtonHeight
    color: rowMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
    radius: Theme.radius

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
                text: root.profile.name
                color: Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelFontSize
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: (root.profile.type === "802-11-wireless" || root.profile.type === "wifi" || root.profile.type === "wireless" || (root.profile.signal && root.profile.signal !== "0")) ? ("Signal strength: " + (root.profile.signal || "0") + "%") : "Connected"
                color: Theme.textMuted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
                elide: Text.ElideRight
            }
        }

        Rectangle {
            Layout.preferredWidth: actionText.implicitWidth + 18
            Layout.preferredHeight: Theme.chipHeight
            color: actionMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground
            border.color: actionMouse.containsMouse ? Theme.accent : Theme.border
            border.width: 1
            radius: Theme.radius

            Text {
                id: actionText

                anchors.centerIn: parent
                text: "Disconnect"
                color: Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.smallFontSize
            }

            MouseArea {
                id: actionMouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.disconnectRequested(root.profile.device)
            }
        }
    }

    MouseArea {
        id: rowMouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
