pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

PopupWindow {
    id: root

    required property var bluetoothModel
    required property var panelWindow

    readonly property int popupWidth: 360
    readonly property int popupHeight: 560
    readonly property int edgeMargin: Theme.rowSpacing

    visible: bluetoothModel.visible
    implicitWidth: popupWidth
    implicitHeight: popupHeight
    anchor.window: panelWindow
    anchor.rect.x: Math.max(Theme.rowSpacing, panelWindow.width - popupWidth - Theme.rowSpacing)
    anchor.rect.y: 0
    grabFocus: true
    color: Theme.transparent

    onVisibleChanged: if (!visible)
        root.bluetoothModel.close()

    ShellSurface {
        id: content

        Connections {
            target: root._backingWindow
            function onActiveChanged() {
                if (!root._backingWindow.active) {
                    root.bluetoothModel.close();
                }
            }
        }
        anchors.fill: parent
        anchors.bottomMargin: 12
        focus: true

        Keys.onPressed: function (event) {
            if (event.key === Qt.Key_Escape) {
                root.bluetoothModel.close();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            RowLayout {
                Layout.fillWidth: true
                UiText {
                    Layout.fillWidth: true
                    text: root.bluetoothModel.statusText
                    color: Theme.textStrong
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                }
                ShellButton {
                    label: "Scan"
                    onActivated: root.bluetoothModel.refresh(true)
                }
                UiText {
                    text: "x"
                    color: closeMouse.containsMouse ? Theme.accent : Theme.textMuted
                    font.pixelSize: Theme.titleFontSize
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.bluetoothModel.close()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                ShellButton {
                    Layout.fillWidth: true
                    label: "Bluetooth On"
                    onActivated: root.bluetoothModel.action("bluetooth-power", ["on"])
                }
                ShellButton {
                    Layout.fillWidth: true
                    label: "Bluetooth Off"
                    onActivated: root.bluetoothModel.action("bluetooth-power", ["off"])
                }
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.listSpacing
                model: root.bluetoothModel.devices

                delegate: Rectangle {
                    id: deviceRow

                    required property var modelData
                    width: ListView.view.width
                    height: 58
                    radius: Theme.smallRadius
                    color: deviceRow.modelData.connected ? Theme.accent : Theme.surface
                    border.color: deviceRow.modelData.connected ? Theme.accent : Theme.border
                    border.width: deviceRow.modelData.connected ? 1 : Theme.pillBorderWidth

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        UiText {
                            Layout.fillWidth: true
                            text: deviceRow.modelData.name.length > 0 ? deviceRow.modelData.name : deviceRow.modelData.address
                            color: deviceRow.modelData.connected ? Theme.accentText : Theme.textStrong
                            elide: Text.ElideRight
                        }
                        ShellButton {
                            label: deviceRow.modelData.connected ? "Disconnect" : (deviceRow.modelData.paired ? "Connect" : "Pair")
                            onActivated: root.bluetoothModel.action(deviceRow.modelData.connected ? "bluetooth-disconnect" : (deviceRow.modelData.paired ? "bluetooth-connect" : "bluetooth-pair"), [deviceRow.modelData.address])
                        }
                    }
                }
            }
        }
    }
}
