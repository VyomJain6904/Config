pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    AI MODEL USAGE LIST (AiModelList.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Vertical scrolling list of individual language model activity cards. Displays
 * token counters, usage percentages, local execution tags, and quota timers.
 * ─────────────────────────────────────────────────────────────────────────────
 */
ColumnLayout {
    id: root

    // ── External Model Integration & Max Scaling ─────────────────────────────
    required property var aiModel
    required property var platform
    required property int nowSeconds

    readonly property real maximumModelTokens: {
        const models = root.platform.models || [];
        let maximum = 0;
        for (let index = 0; index < models.length; ++index)
            maximum = Math.max(maximum, Number(models[index].activeTokens || 0));
        return maximum;
    }
    spacing: 8

    // =========================================================================
    // 1. FORMATTING & TIME COMPUTATION UTILITIES
    // =========================================================================

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

    function resetScroll() {
        if (modelList.count > 0)
            modelList.positionViewAtBeginning();
    }

    onVisibleChanged: {
        if (visible)
            Qt.callLater(root.resetScroll);
    }

    Connections {
        target: root.aiModel
        function onSelectedPlatformChanged() {
            Qt.callLater(root.resetScroll);
        }
    }

    // =========================================================================
    // 2. HEADER LABEL & EMPTY STATE PLACEHOLDER
    // =========================================================================

    UiText {
        text: root.platform.id === "antigravity" ? "MODEL QUOTAS" : "TOKENS BY MODEL"
        color: Theme.textMuted
        font.pixelSize: Theme.tinyFontSize
        font.bold: true
    }

    Rectangle {
        visible: modelList.count === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        color: Theme.surface
        border.color: Theme.border
        border.width: 1

        UiText {
            anchors.centerIn: parent
            text: "No model activity in this period"
            color: Theme.textMuted
        }
    }

    // =========================================================================
    // 3. MODEL ACTIVITY CARD LIST VIEW
    // =========================================================================

    ListView {
        id: modelList
        visible: count > 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 60
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: root.platform.models || []

        ScrollBar.vertical: ScrollBar {
            id: modelScrollBar
            policy: ScrollBar.AsNeeded
            width: 7

            contentItem: Rectangle {
                implicitWidth: 5
                implicitHeight: 32
                radius: width / 2
                color: modelScrollBar.pressed ? Theme.textStrong : Theme.accentSecondary
                opacity: modelScrollBar.size < 1 ? 0.85 : 0
            }

            background: Rectangle {
                implicitWidth: 7
                color: Theme.surfaceActive
                opacity: modelScrollBar.size < 1 ? 0.55 : 0
            }
        }

        delegate: Rectangle {
            id: modelCard
            required property var modelData
            readonly property var quota: modelData.quota || null
            readonly property bool percentKnown: quota !== null && quota.percentKnown === true
            readonly property bool tokenProgress: quota === null
            readonly property bool progressKnown: percentKnown || tokenProgress
            readonly property real progressFraction: {
                if (percentKnown)
                    return root.percent(quota.remainingPercent) / 100;
                if (tokenProgress && root.maximumModelTokens > 0)
                    return Math.max(0, Number(modelData.activeTokens || 0)) / root.maximumModelTokens;
                return 0;
            }
            readonly property bool progressDanger: percentKnown && root.percent(quota.remainingPercent) < 10
            width: modelList.width - (modelList.contentHeight > modelList.height ? 12 : 0)
            height: quota ? 70 : 58
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            // Animated progress fill background
            Rectangle {
                x: 1
                y: 1
                height: parent.height - 2
                width: Math.max(0, (parent.width - 2) * modelCard.progressFraction)
                visible: modelCard.progressKnown && width > 0
                color: modelCard.progressDanger ? Theme.danger : Theme.borderStrong
                opacity: modelCard.progressDanger ? 0.24 : 1

                Behavior on width {
                    NumberAnimation { duration: Theme.animationNormal }
                }
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 11
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1

                        UiText {
                            text: modelCard.modelData.model
                            color: Theme.textStrong
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        UiText {
                            text: modelCard.quota !== null && (modelCard.quota.label || "").length > 0
                                ? modelCard.quota.label
                                : (modelCard.modelData.provider || "provider") + (modelCard.modelData.kind === "local" ? "  ·  LOCAL" : "")
                            color: modelCard.modelData.kind === "local" ? Theme.success : Theme.textMuted
                            font.pixelSize: Theme.tinyFontSize
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }

                    UiText {
                        visible: modelCard.quota === null
                        text: root.formatTokens(modelCard.modelData.activeTokens)
                        color: Theme.textStrong
                        font.bold: true
                    }

                    UiText {
                        visible: modelCard.quota !== null
                        text: modelCard.percentKnown ? Math.round(root.percent(modelCard.quota.remainingPercent)) + "% left" : "Quota not published"
                        color: modelCard.progressDanger ? Theme.danger : Theme.textStrong
                        font.bold: true
                    }
                }

                UiText {
                    visible: modelCard.quota !== null && Number(modelCard.quota.resetAt || 0) > 0
                    Layout.preferredHeight: visible ? implicitHeight : 0
                    text: visible ? root.resetText(modelCard.quota.resetAt) : ""
                    color: Theme.textMuted
                    font.pixelSize: Theme.tinyFontSize
                }
            }
        }
    }
}
