import QtQuick
import QtQuick.Layouts
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *              NETWORK WIFI ROW (NetworkWifiRow.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Interactive listdelegate representing a discovered wireless access point.
 * Shows signal percentage, security cipher badges, and saved network flags.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    // ── External Binding & Action Signals ────────────────────────────────────
    required property var network
    property bool selected: false
    property bool busy: false
    signal selectedRequested
    signal connectRequested(var network)

    // ── Geometry & State Styling ─────────────────────────────────────────────
    height: 54
    color: root.network.active ? Theme.buttonSelectedBackground : (root.selected ? Theme.buttonFocusBackground : (rowMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground))
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

    // =========================================================================
    // 1. ACCESS POINT ROW LAYOUT & ACTION CHIP
    // =========================================================================
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.rowSpacing
        anchors.rightMargin: Theme.rowSpacing
        spacing: Theme.rowSpacing

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.compactSpacing

            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Text {
                    text: root.network.ssid
                    color: root.network.active ? Theme.accentText : Theme.textStrong
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.panelFontSize
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width - (root.network.secured ? 20 : 0)
                }

                Text {
                    visible: root.network.secured
                    text: "\uf023"
                    color: root.network.active ? Theme.accentText : Theme.textMuted
                    opacity: root.network.active ? 0.8 : 1.0
                    font.family: Theme.iconFontFamily
                    font.pixelSize: 12
                }

                Item {
                    Layout.fillWidth: true
                }
            }

            Text {
                Layout.fillWidth: true
                text: (root.network.security.length > 0 ? root.network.security : "Open") + (root.network.saved ? " • Saved" : "") + " - " + root.network.signal + "% - " + root.network.device
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

        // Interactive Connection Trigger Button
        Rectangle {
            Layout.preferredWidth: actionText.implicitWidth + 18
            Layout.preferredHeight: Theme.chipHeight
            color: actionMouse.containsMouse && !root.busy ? Theme.buttonHoverBackground : Theme.buttonBackground
            border.color: root.network.active ? Theme.border : Theme.accent
            border.width: 1
            radius: Theme.radius
            opacity: root.busy ? 0.5 : 1

            Text {
                id: actionText

                anchors.centerIn: parent
                text: root.network.active ? "Connected" : "Connect"
                color: root.network.active ? Theme.textStrong : Theme.accent
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
