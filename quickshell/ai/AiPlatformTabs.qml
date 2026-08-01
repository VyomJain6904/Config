pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.core

RowLayout {
    id: root

    required property var aiModel
    readonly property int fixedHeight: 42
    spacing: Theme.rowSpacing
    implicitHeight: fixedHeight

    function iconFor(platformId) {
        if (platformId === "codex")
            return "file:///usr/share/icons/MacTahoe/apps/scalable/com.openai.ChatGPT-clear.png";
        if (platformId === "opencode")
            return "file:///usr/share/icons/MacTahoe/apps/scalable/opencode-clear.png";
        return "file:///usr/share/icons/MacTahoe/apps/scalable/antigravity-clear.png";
    }

    Repeater {
        model: [
            { id: "codex", name: "Codex" },
            { id: "antigravity", name: "Antigravity" },
            { id: "opencode", name: "OpenCode" }
        ]

        delegate: Rectangle {
            id: tab
            required property var modelData
            Layout.fillWidth: true
            Layout.minimumHeight: root.fixedHeight
            Layout.preferredHeight: root.fixedHeight
            Layout.maximumHeight: root.fixedHeight
            color: root.aiModel.selectedPlatform === tab.modelData.id ? Theme.surfaceActive : Theme.surface
            border.color: root.aiModel.selectedPlatform === tab.modelData.id ? Theme.accent : Theme.border
            border.width: 1
            radius: Theme.radius

            Row {
                anchors.centerIn: parent
                spacing: 7

                Image {
                    width: 18
                    height: 18
                    anchors.verticalCenter: parent.verticalCenter
                    source: root.iconFor(tab.modelData.id)
                    sourceSize.width: 32
                    sourceSize.height: 32
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                }

                UiText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.name
                    color: root.aiModel.selectedPlatform === tab.modelData.id ? Theme.textStrong : Theme.textMuted
                    font.bold: root.aiModel.selectedPlatform === tab.modelData.id
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.aiModel.selectPlatform(tab.modelData.id)
            }
        }
    }
}
