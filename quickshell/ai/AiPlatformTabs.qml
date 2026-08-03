pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    AI PLATFORM SWITCHER TABS (AiPlatformTabs.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Horizontal button strip for switching the active AI view between Codex,
 * Antigravity, and OpenCode with custom themed brand icons.
 * ─────────────────────────────────────────────────────────────────────────────
 */
RowLayout {
    id: root

    // ── External Controller Binding & Layout Geometry ────────────────────────
    required property var aiModel
    readonly property int fixedHeight: 42
    spacing: Theme.rowSpacing
    implicitHeight: fixedHeight

    // Resolves MacTahoe themed clear icons for AI platforms
    function iconFor(platformId) {
        if (platformId === "codex")
            return "file:///usr/share/icons/MacTahoe/apps/scalable/com.openai.ChatGPT-clear.png";
        if (platformId === "opencode")
            return "file:///usr/share/icons/MacTahoe/apps/scalable/opencode-clear.png";
        return "file:///usr/share/icons/MacTahoe/apps/scalable/antigravity-clear.png";
    }

    // =========================================================================
    // 1. PROVIDER TAB REPEATER
    // =========================================================================
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

            color: root.aiModel.selectedPlatform === tab.modelData.id
                ? Theme.buttonSelectedBackground
                : (tabMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)
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
                    color: root.aiModel.selectedPlatform === tab.modelData.id ? Theme.accentText : Theme.textMuted
                    font.bold: root.aiModel.selectedPlatform === tab.modelData.id
                }
            }

            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.aiModel.selectPlatform(tab.modelData.id)
            }
        }
    }
}
