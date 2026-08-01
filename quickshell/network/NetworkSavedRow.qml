import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.core

Rectangle {
    id: root

    required property var profile
    property bool busy: false
    property bool showPassword: false
    property bool copied: false

    Process {
        id: copyProcess
        command: ["sh", "-c", "printf '%s' \"$1\" | xclip -selection clipboard", "_", root.profile.password]
    }

    Timer {
        id: resetCopyTimer
        interval: 2000
        onTriggered: root.copied = false
    }

    signal connectRequested(string uuid)
    signal disconnectRequested(string device)
    signal forgetRequested(string uuid)
    signal toggleAutoconnectRequested(string uuid, bool enable)

    height: contentColumn.implicitHeight + 24
    color: root.profile.active ? Theme.surfaceHover : Theme.surface
    border.color: root.profile.active ? Theme.accent : Theme.border
    border.width: root.profile.active ? 1 : 0
    radius: Theme.radius
    opacity: root.busy ? 0.6 : 1.0

    ColumnLayout {
        id: contentColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.rowSpacing

            Text {
                Layout.fillWidth: true
                text: root.profile.name
                color: root.profile.active ? Theme.accent : Theme.textStrong
                font.family: Theme.fontFamily
                font.pixelSize: Theme.panelFontSize
                font.bold: root.profile.active
                elide: Text.ElideRight
            }

            Rectangle {
                visible: root.profile.active
                Layout.preferredWidth: activeLabel.implicitWidth + 12
                Layout.preferredHeight: 20
                color: Theme.accent
                radius: 10

                Text {
                    id: activeLabel
                    anchors.centerIn: parent
                    text: "Active"
                    color: Theme.accentText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize - 2
                    font.bold: true
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.showPassword ? "Password: " + (root.profile.password.length > 0 ? root.profile.password : "(No PSK / Open)") : "Password: ••••••••••••"
            color: root.showPassword ? Theme.accent : Theme.textMuted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.smallFontSize
            font.bold: root.showPassword
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            // Show/Hide Password button
            Rectangle {
                Layout.preferredWidth: passText.implicitWidth + 16
                Layout.preferredHeight: Theme.chipHeight
                color: passMouse.containsMouse && !root.busy ? Theme.surfaceActive : Theme.border
                radius: Theme.radius

                Text {
                    id: passText
                    anchors.centerIn: parent
                    text: root.showPassword ? "\uf070" : "\uf06e"
                    color: Theme.textStrong
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 14
                }

                MouseArea {
                    id: passMouse
                    anchors.fill: parent
                    enabled: !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.showPassword = !root.showPassword
                }
            }

            // Auto-connect toggle button
            Rectangle {
                Layout.preferredWidth: autoText.implicitWidth + 16
                Layout.preferredHeight: Theme.chipHeight
                color: autoMouse.containsMouse && !root.busy ? Theme.surfaceActive : Theme.border
                radius: Theme.radius

                Text {
                    id: autoText
                    anchors.centerIn: parent
                    text: root.profile.autoconnect ? "Auto: ON" : "Auto: OFF"
                    color: root.profile.autoconnect ? Theme.success : Theme.textMuted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: root.profile.autoconnect
                }

                MouseArea {
                    id: autoMouse
                    anchors.fill: parent
                    enabled: !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleAutoconnectRequested(root.profile.uuid, !root.profile.autoconnect)
                }
            }

            // Copy password button
            Rectangle {
                visible: root.profile.password.length > 0 && root.profile.password !== "(No PSK / Open)" && root.profile.password !== "--"
                Layout.preferredWidth: copyText.implicitWidth + 16
                Layout.preferredHeight: Theme.chipHeight
                color: copyMouse.containsMouse && !root.busy ? Theme.surfaceActive : Theme.border
                radius: Theme.radius

                Text {
                    id: copyText
                    anchors.centerIn: parent
                    text: root.copied ? "\uf00c" : "\uf0c5"
                    color: root.copied ? Theme.success : Theme.textStrong
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: root.copied
                }

                MouseArea {
                    id: copyMouse
                    anchors.fill: parent
                    enabled: !root.busy && !root.copied
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        copyProcess.running = true;
                        root.copied = true;
                        resetCopyTimer.start();
                    }
                }
            }

            Item { Layout.fillWidth: true }

            // Connect / Disconnect button
            Rectangle {
                Layout.preferredWidth: connText.implicitWidth + 16
                Layout.preferredHeight: Theme.chipHeight
                color: connMouse.containsMouse && !root.busy ? (root.profile.active ? Theme.border : Theme.accent) : (root.profile.active ? Theme.border : Theme.surfaceHover)
                border.color: root.profile.active ? Theme.border : Theme.accent
                border.width: 1
                radius: Theme.radius

                Text {
                    id: connText
                    anchors.centerIn: parent
                    text: root.profile.active ? "Disconnect" : "Connect"
                    color: (!root.profile.active && (connMouse.containsMouse || true)) ? Theme.textStrong : Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: !root.profile.active
                }

                MouseArea {
                    id: connMouse
                    anchors.fill: parent
                    enabled: !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.profile.active) {
                            root.disconnectRequested(root.profile.device);
                        } else {
                            root.connectRequested(root.profile.uuid);
                        }
                    }
                }
            }

            // Forget button
            Rectangle {
                Layout.preferredWidth: forgetText.implicitWidth + 16
                Layout.preferredHeight: Theme.chipHeight
                color: forgetMouse.containsMouse && !root.busy ? Theme.danger : Theme.border
                radius: Theme.radius

                Text {
                    id: forgetText
                    anchors.centerIn: parent
                    text: "Forget"
                    color: forgetMouse.containsMouse ? "#FFFFFF" : Theme.danger
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.smallFontSize
                    font.bold: true
                }

                MouseArea {
                    id: forgetMouse
                    anchors.fill: parent
                    enabled: !root.busy
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.forgetRequested(root.profile.uuid)
                }
            }
        }
    }
}
