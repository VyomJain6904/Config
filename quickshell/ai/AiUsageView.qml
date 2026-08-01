pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.core

ColumnLayout {
    id: root

    required property var aiModel
    readonly property var platform: root.aiModel.activePlatform
    property int nowSeconds: Math.floor(Date.now() / 1000)
    spacing: Theme.popupSpacing

    function iconFor(platformId) {
        if (platformId === "codex")
            return "file:///usr/share/icons/MacTahoe/apps/scalable/com.openai.ChatGPT-clear.png";
        if (platformId === "opencode")
            return "file:///usr/share/icons/MacTahoe/apps/scalable/opencode-clear.png";
        return "file:///usr/share/icons/MacTahoe/apps/scalable/antigravity-clear.png";
    }

    function formatTokens(value) {
        const tokens = Number(value || 0);
        if (tokens >= 1000000000)
            return (tokens / 1000000000).toFixed(1) + "B";
        if (tokens >= 1000000)
            return (tokens / 1000000).toFixed(1) + "M";
        if (tokens >= 1000)
            return (tokens / 1000).toFixed(1) + "K";
        return Math.round(tokens).toString();
    }

    function percent(value) {
        return Math.max(0, Math.min(100, Number(value || 0)));
    }

    function dailyPercent(tokens) {
        let maximum = 0;
        const days = root.platform.dailyUsage || [];
        for (let index = 0; index < days.length; index++)
            maximum = Math.max(maximum, Number(days[index].tokens || 0));
        if (maximum <= 0)
            return 0;
        return Math.max(2, Number(tokens || 0) * 100 / maximum);
    }

    function resetText(epoch) {
        const seconds = Number(epoch || 0) - root.nowSeconds;
        if (seconds <= 0)
            return epoch ? "Refreshing now" : "Reset time not published";
        const days = Math.floor(seconds / 86400);
        const hours = Math.floor((seconds % 86400) / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        if (days > 0)
            return "Resets in " + days + "d " + hours + "h";
        if (hours > 0)
            return "Resets in " + hours + "h " + minutes + "m";
        return "Resets in " + Math.max(1, minutes) + "m";
    }

    function relativeTime(epoch) {
        const seconds = root.nowSeconds - Number(epoch || 0);
        if (!epoch)
            return "Waiting for data";
        if (seconds < 10)
            return "Updated now";
        if (seconds < 60)
            return "Updated " + seconds + "s ago";
        if (seconds < 3600)
            return "Updated " + Math.floor(seconds / 60) + "m ago";
        return "Updated " + Math.floor(seconds / 3600) + "h ago";
    }

    Timer {
        interval: 30000
        running: root.visible
        repeat: true
        onTriggered: root.nowSeconds = Math.floor(Date.now() / 1000)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.preferredWidth: 46
            Layout.preferredHeight: 46
            color: Theme.surface
            border.color: Theme.borderStrong
            border.width: 1
            radius: Theme.radius

            Image {
                anchors.centerIn: parent
                width: 28
                height: 28
                source: root.iconFor(root.platform.id)
                sourceSize.width: 64
                sourceSize.height: 64
                fillMode: Image.PreserveAspectFit
                smooth: true
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 2

            RowLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 8
                UiText {
                    text: root.platform.name || "AI Usage"
                    color: Theme.textStrong
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.minimumWidth: 0
                }
                Rectangle {
                    implicitWidth: planLabel.implicitWidth + 12
                    implicitHeight: 20
                    color: Theme.surfaceActive
                    border.color: Theme.border
                    border.width: 1
                    UiText {
                        id: planLabel
                        anchors.centerIn: parent
                        text: root.platform.plan || "CONNECTED"
                        color: Theme.textMuted
                        font.pixelSize: Theme.tinyFontSize
                        font.bold: true
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
            }

            UiText {
                text: root.relativeTime(root.platform.updatedAt) + "  ·  " + (root.platform.source || "Local data")
                color: Theme.textMuted
                font.pixelSize: Theme.tinyFontSize
                elide: Text.ElideRight
                Layout.fillWidth: true
                Layout.minimumWidth: 0
            }
        }

        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: root.platform.state === "live" ? Theme.success : (root.platform.state === "unavailable" ? Theme.danger : Theme.accentSecondary)
        }

        ShellButton {
            Layout.minimumWidth: 72
            Layout.preferredWidth: 72
            Layout.maximumWidth: 72
            label: root.aiModel.busy ? "Wait…" : "Refresh"
            enabled: !root.aiModel.busy
            onActivated: root.aiModel.refresh()
        }
    }

    AiPlatformTabs {
        Layout.fillWidth: true
        Layout.minimumHeight: 42
        Layout.preferredHeight: 42
        Layout.maximumHeight: 42
        aiModel: root.aiModel
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Theme.popupSpacing

        Rectangle {
            visible: (root.platform.error || "").length > 0
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? warningText.implicitHeight + 20 : 0
            color: "#1b1414"
            border.color: "#5a3030"
            border.width: 1
            UiText {
                id: warningText
                anchors.fill: parent
                anchors.margins: 10
                text: root.platform.error || ""
                color: "#d99a9a"
                font.pixelSize: Theme.smallFontSize
                wrapMode: Text.Wrap
            }
        }

        ColumnLayout {
            visible: (root.platform.quotaWindows || []).length > 0
            Layout.fillWidth: true
            spacing: 8

            UiText {
                text: "LIVE LIMITS"
                color: Theme.textMuted
                font.pixelSize: Theme.tinyFontSize
                font.bold: true
            }

            Repeater {
                model: root.platform.quotaWindows || []
                delegate: Rectangle {
                    id: quotaCard
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 78
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 6
                        RowLayout {
                            Layout.fillWidth: true
                            UiText {
                                text: quotaCard.modelData.label
                                color: Theme.textStrong
                                font.bold: true
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            UiText {
                                text: Math.round(root.percent(quotaCard.modelData.usedPercent)) + "% used"
                                color: root.percent(quotaCard.modelData.usedPercent) >= 90 ? Theme.danger : Theme.textStrong
                                font.bold: true
                            }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 7
                            color: Theme.surfaceActive
                            Rectangle {
                                height: parent.height
                                width: parent.width * root.percent(quotaCard.modelData.usedPercent) / 100
                                color: root.percent(quotaCard.modelData.usedPercent) >= 90 ? Theme.danger : Theme.accent
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.animationNormal
                                    }
                                }
                            }
                        }
                        UiText {
                            text: root.resetText(quotaCard.modelData.resetAt)
                            color: Theme.textMuted
                            font.pixelSize: Theme.tinyFontSize
                        }
                    }
                }
            }
        }

        ColumnLayout {
            visible: (root.platform.dailyUsage || []).length > 0
            Layout.fillWidth: true
            spacing: 8

            UiText {
                text: "TOKENS BY DAY"
                color: Theme.textMuted
                font.pixelSize: Theme.tinyFontSize
                font.bold: true
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 7 * 32 + 22
                color: Theme.surface
                border.color: Theme.border
                border.width: 1
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5
                    Repeater {
                        model: root.platform.dailyUsage || []
                        delegate: RowLayout {
                            id: dayRow
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.preferredHeight: 27
                            spacing: 10
                            UiText {
                                Layout.preferredWidth: 48
                                text: dayRow.modelData.label
                                color: dayRow.modelData.label === "Today" ? Theme.textStrong : Theme.textMuted
                                font.bold: dayRow.modelData.label === "Today"
                            }
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 7
                                color: Theme.surfaceActive
                                Rectangle {
                                    height: parent.height
                                    width: parent.width * root.dailyPercent(dayRow.modelData.tokens) / 100
                                    color: Theme.accent
                                    Behavior on width {
                                        NumberAnimation {
                                            duration: Theme.animationNormal
                                        }
                                    }
                                }
                            }
                            UiText {
                                Layout.preferredWidth: 66
                                horizontalAlignment: Text.AlignRight
                                text: root.formatTokens(dayRow.modelData.tokens)
                                color: dayRow.modelData.tokens > 0 ? Theme.textStrong : Theme.textMuted
                                font.bold: dayRow.modelData.tokens > 0
                            }
                        }
                    }
                }
            }
        }

        AiModelList {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 100
            aiModel: root.aiModel
            platform: root.platform
            nowSeconds: root.nowSeconds
        }
    }
}
