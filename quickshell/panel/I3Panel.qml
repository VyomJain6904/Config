import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

pragma ComponentBehavior: Bound

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    required property var state
    required property var clock
    required property var calendarModel
    required property var networkModel
    required property var controlsModel
    required property var bluetoothModel
    required property var controlCenterModel
    required property var powerMenuModel

    implicitHeight: Theme.panelHeight
    color: Theme.transparent
    exclusiveZone: Theme.panelHeight
    aboveWindows: true

    anchors {
        bottom: true
        left: true
        right: true
    }

    Rectangle {
        id: island

        anchors.fill: parent
        anchors.leftMargin: Theme.panelEdgeMargin
        anchors.rightMargin: Theme.panelEdgeMargin
        anchors.topMargin: Theme.panelMargin
        anchors.bottomMargin: Theme.panelMargin
        color: Theme.barBackground
        border.color: Theme.border
        border.width: Theme.pillBorderWidth
        radius: Theme.barRadius

        PillShadow { cornerRadius: island.radius }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Theme.panelGap
            anchors.rightMargin: Theme.panelGap
            spacing: Theme.panelGap

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                RowLayout {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width)
                    height: parent.height
                    spacing: Theme.panelGap

                    LogoButton {
                        onActivated: root.controlCenterModel.toggle()
                    }

                    PanelPill {
                        visible: root.controlCenterModel.showWorkspaceWidget
                        Layout.preferredWidth: workspaceRow.implicitWidth + 8
                        Layout.preferredHeight: Theme.pillHeight

                        RowLayout {
                            id: workspaceRow

                            anchors.centerIn: parent
                            spacing: 1

                            Repeater {
                                model: root.state.workspaceNames

                                delegate: WorkspaceButton {
                                    required property int index
                                    required property string modelData

                                    label: modelData
                                    // Compare by workspace NUMBER string, not by 0-based list index
                                    selected: modelData === root.state.currentWorkspaceNum.toString()
                                    onClicked: root.state.switchWorkspace(parseInt(modelData))
                                }
                            }
                        }
                    }
                }
            }

            PanelPill {
                Layout.preferredWidth: clockLabel.implicitWidth + Theme.pillHorizontalPadding * 2
                Layout.preferredHeight: Theme.pillHeight
                active: root.calendarModel.visible
                hovered: clockMouse.containsMouse

                UiText {
                    id: clockLabel

                    anchors.centerIn: parent
                    text: Qt.formatDateTime(root.clock.date, "ddd dd MMM  hh:mm A")
                    color: Theme.textStrong
                    font.bold: true
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.calendarModel.toggle()
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.panelGap

                    Item { Layout.fillWidth: true }

                    Repeater {
                        model: root.state.statusSegments

                        delegate: UiText {
                            required property string modelData
                            text: modelData
                            color: Theme.text
                        }
                    }

                    TrayArea {}

                    PanelPill {
                        visible: root.controlCenterModel.showVolumeWidget
                        Layout.preferredWidth: volumeRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.controlsModel.visible
                        hovered: controlsMouse.containsMouse

                        RowLayout {
                            id: volumeRow

                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing + 2

                            FallbackIcon {
                                iconName: root.controlsModel.volumeMuted ? "audio-volume-muted-panel" : "audio-volume-high-panel"
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }

                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 4
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.border
                                radius: height / 2

                                Rectangle {
                                    width: Math.max(height, Math.round((root.controlsModel.volumePercent / 100) * parent.width))
                                    height: parent.height
                                    color: root.controlsModel.volumeMuted ? Theme.textMuted : Theme.accent
                                    radius: parent.radius
                                }
                            }

                            UiText {
                                text: root.controlsModel.volumeMuted ? "Muted" : root.controlsModel.volumePercent.toString() + "%"
                                color: Theme.accentSecondary
                            }
                        }

                        MouseArea {
                            id: controlsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controlsModel.toggle()
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    root.controlsModel.volumeUp();
                                } else {
                                    root.controlsModel.volumeDown();
                                }
                                wheel.accepted = true;
                            }
                        }
                    }

                    PanelPill {
                        visible: root.controlCenterModel.showVolumeWidget // Using same toggle as volume for now
                        Layout.preferredWidth: brightnessRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.controlsModel.visible
                        hovered: brightnessMouse.containsMouse

                        RowLayout {
                            id: brightnessRow

                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing + 2

                            FallbackIcon {
                                iconName: "display-brightness-symbolic"
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }

                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 4
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.border
                                radius: height / 2

                                Rectangle {
                                    width: Math.max(height, Math.round((root.controlsModel.brightnessPercent / 100) * parent.width))
                                    height: parent.height
                                    color: Theme.accent
                                    radius: parent.radius
                                }
                            }

                            UiText {
                                text: root.controlsModel.brightnessPercent.toString() + "%"
                                color: Theme.accentSecondary
                            }
                        }

                        MouseArea {
                            id: brightnessMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controlsModel.toggle()
                            onWheel: (wheel) => {
                                if (wheel.angleDelta.y > 0) {
                                    root.controlsModel.brightnessUp();
                                } else {
                                    root.controlsModel.brightnessDown();
                                }
                                wheel.accepted = true;
                            }
                        }
                    }

                    PanelPill {
                        visible: true
                        Layout.preferredWidth: batteryRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.controlsModel.visible
                        hovered: batteryMouse.containsMouse

                        RowLayout {
                            id: batteryRow

                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing + 2

                            FallbackIcon {
                                iconName: root.controlsModel.batteryCharging ? "battery-010-charging" : "battery-100"
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }

                            Rectangle {
                                Layout.preferredWidth: 50
                                Layout.preferredHeight: 4
                                Layout.alignment: Qt.AlignVCenter
                                color: Theme.border
                                radius: height / 2

                                Rectangle {
                                    width: Math.max(height, Math.round((root.controlsModel.batteryPercent / 100) * parent.width))
                                    height: parent.height
                                    color: root.controlsModel.batteryPercent <= 20 && !root.controlsModel.batteryCharging ? Theme.error : Theme.accent
                                    radius: parent.radius
                                }
                            }

                            UiText {
                                text: root.controlsModel.batteryPercent.toString() + "%"
                                color: Theme.accentSecondary
                            }
                        }

                        MouseArea {
                            id: batteryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.controlsModel.toggle()
                        }
                    }

                    PanelPill {
                        visible: root.controlCenterModel.showBluetoothWidget
                        Layout.preferredWidth: bluetoothRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.bluetoothModel.visible
                        hovered: bluetoothMouse.containsMouse

                        RowLayout {
                            id: bluetoothRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            FallbackIcon {
                                iconName: "bluetooth-active"
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }
                        }

                        MouseArea {
                            id: bluetoothMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.bluetoothModel.toggle()
                        }
                    }

                    PanelPill {
                        visible: root.controlCenterModel.showNetworkWidget
                        Layout.preferredWidth: networkRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.networkModel.visible
                        hovered: networkMouse.containsMouse

                        RowLayout {
                            id: networkRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            FallbackIcon {
                                iconName: root.networkModel.statusText.indexOf("offline") >= 0
                                    || root.networkModel.statusText.indexOf("unavailable") >= 0
                                    ? "network-wireless-disconnected"
                                    : "network-wireless-signal-excellent"
                                Layout.preferredWidth: 16
                                Layout.preferredHeight: 16
                            }
                        }

                        MouseArea {
                            id: networkMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.networkModel.toggle()
                        }
                    }

                    PanelPill {
                        visible: root.controlCenterModel.showPowerWidget
                        Layout.preferredWidth: Theme.pillHeight
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.powerMenuModel.visible
                        hovered: powerMouse.containsMouse

                        IconText {
                            anchors.centerIn: parent
                            text: "󰐥"
                            color: Theme.accentSecondary
                        }

                        MouseArea {
                            id: powerMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.powerMenuModel.toggle()
                        }
                    }
                }
            }
        }
    }
}
