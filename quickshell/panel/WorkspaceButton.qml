import QtQuick
import QtQuick.Layouts
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    WORKSPACE SWITCHER BUTTON (WorkspaceButton.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Renders individual workspace numbers on the panel. Features high contrast
 * white text and active slate background highlighting for selected workspaces.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Rectangle {
    id: root

    required property string label
    required property bool selected
    signal clicked

    Layout.preferredWidth: Theme.workspaceButtonSize
    Layout.preferredHeight: Theme.workspaceButtonSize
    radius: Theme.smallRadius
    color: selected ? Theme.surfaceActive : (workspaceMouse.containsMouse ? Theme.surfaceHover : "transparent")

    Text {
        anchors.centerIn: parent
        text: root.label
        color: root.selected ? "#ffffff" : Theme.textMuted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.panelFontSize
        font.bold: root.selected
        verticalAlignment: Text.AlignVCenter
    }

    MouseArea {
        id: workspaceMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
