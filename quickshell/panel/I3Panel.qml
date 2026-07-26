pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

// qmllint disable uncreatable-type
PanelWindow {
    id: root

    required property var state
    required property var clock
    required property string vpnFontFamily
    required property var calendarModel
    required property var networkModel
    required property var controlsModel
    required property var powerMenuModel
    required property var vpnModel

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

        PillShadow {
            cornerRadius: island.radius
        }

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

                    PanelPill {
                        visible: true
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
                    text: Qt.formatDateTime(root.clock.date, "hh:mm A")
                    color: Theme.textStrong
                    font.bold: true
                }

                MouseArea {
                    id: clockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.networkModel.open();
                        root.calendarModel.open();
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 0

                RowLayout {
                    anchors.fill: parent
                    spacing: Theme.panelGap

                    Item {
                        Layout.fillWidth: true
                    }

                    TrayArea {}

                    PanelPill {
                        visible: root.vpnModel && root.vpnModel.active
                        Layout.preferredWidth: vpnRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.vpnModel.visible
                        hovered: vpnMouse.containsMouse

                        RowLayout {
                            id: vpnRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing + 4

                            IconText {
                                visible: root.vpnModel && root.vpnModel.active
                                text: "" // Custom JetBrainsMono-VPN icon
                                color: "#50fa7b" // Dracula Green
                                font.family: root.vpnFontFamily
                                font.pixelSize: 14
                            }

                            UiText {
                                visible: text.length > 0
                                text: root.vpnModel ? root.vpnModel.vpnIp : ""
                                color: Theme.accentSecondary
                                font.bold: true
                            }

                            Item {
                                visible: root.vpnModel && root.vpnModel.targetIp !== ""
                                Layout.preferredWidth: 6
                            }

                            IconText {
                                visible: root.vpnModel && root.vpnModel.targetIp !== ""
                                text: "" // nf-fa-globe
                                color: Theme.danger
                                font.family: Theme.iconFontFamily
                                font.pixelSize: 14
                            }

                            UiText {
                                visible: text.length > 0
                                text: root.vpnModel ? root.vpnModel.targetIp : ""
                                color: Theme.danger
                                font.bold: true
                            }
                        }

                        MouseArea {
                            id: vpnMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.vpnModel.open()
                        }
                    }

                    PanelPill {
                        visible: true
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
                                text: root.controlsModel.volumePercent.toString() + "%"
                                color: Theme.accentSecondary
                            }
                        }

                        MouseArea {
                            id: controlsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.controlsModel.visible && root.controlsModel.requestedTab === "audio") {
                                    root.controlsModel.close();
                                } else {
                                    root.controlsModel.requestedTab = "audio";
                                    root.controlsModel.open();
                                }
                            }
                            onWheel: wheel => {
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
                        visible: true
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
                            onClicked: {
                                if (root.controlsModel.visible && root.controlsModel.requestedTab === "brightness") {
                                    root.controlsModel.close();
                                } else {
                                    root.controlsModel.requestedTab = "brightness";
                                    root.controlsModel.open();
                                }
                            }
                            onWheel: wheel => {
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
                                    color: root.controlsModel.batteryCharging ? Theme.success : (root.controlsModel.batteryPercent <= 20 ? Theme.danger : Theme.accent)
                                    radius: parent.radius
                                }
                            }

                            UiText {
                                text: root.controlsModel.batteryPercent.toString() + "%"
                                color: Theme.accentSecondary
                            }
                        }

                    }

                    PanelPill {
                        visible: true
                        Layout.preferredWidth: networkRow.implicitWidth + Theme.pillHorizontalPadding * 2
                        Layout.preferredHeight: Theme.pillHeight
                        active: root.networkModel.visible
                        hovered: networkMouse.containsMouse

                        RowLayout {
                            id: networkRow
                            anchors.centerIn: parent
                            spacing: Theme.compactSpacing

                            FallbackIcon {
                                iconName: root.networkModel.statusText.indexOf("offline") >= 0 || root.networkModel.statusText.indexOf("unavailable") >= 0 ? "network-wireless-disconnected" : "network-wireless-signal-excellent"
                                Layout.preferredWidth: 14
                                Layout.preferredHeight: 14
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
                        visible: true
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
