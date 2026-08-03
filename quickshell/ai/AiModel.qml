import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    AI MONITOR STATE ENGINE (AiModel.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * State manager and IPC polling client for tracking AI token quotas, active
 * usage windows, and daily burn rates across Codex, Antigravity, and OpenCode.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Scope {
    id: root

    // ── Global Visibility & Platform State Variables ─────────────────────────
    property bool visible: false
    property bool busy: false
    property string selectedPlatform: "codex"
    property var platformsData: []
    property int generatedAt: 0
    property string lastError: ""
    readonly property var activePlatform: root.platformById(root.selectedPlatform)

    // =========================================================================
    // 1. PLATFORM LOOKUP & SELECTION HELPERS
    // =========================================================================

    // Retrieves structured AI profile metadata by platform identifier
    function platformById(platformId) {
        for (let index = 0; index < root.platformsData.length; index++) {
            if (root.platformsData[index].id === platformId)
                return root.platformsData[index];
        }
        return {
            id: platformId,
            name: platformId === "codex" ? "Codex" : (platformId === "antigravity" ? "Antigravity" : "OpenCode"),
            plan: "LOADING",
            state: "loading",
            source: "",
            updatedAt: 0,
            error: "",
            quotaWindows: [],
            dailyUsage: [],
            models: [],
            summary: {
                activeTokens: 0,
                cacheReadTokens: 0,
                lifetimeTokens: 0,
                peakDailyTokens: 0,
                cost: 0,
                sessions: 0
            }
        };
    }

    function selectPlatform(platformId) {
        root.selectedPlatform = platformId;
    }

    // Cycles between configured AI providers via keyboard shortcut or arrows
    function cyclePlatform(delta) {
        const order = ["codex", "antigravity", "opencode"];
        let index = order.indexOf(root.selectedPlatform);
        index = (index + delta + order.length) % order.length;
        root.selectedPlatform = order[index];
    }

    // =========================================================================
    // 2. LIFECYCLE CONTROLLERS & IPC ROUTERS
    // =========================================================================

    function send(command) {
        if (usageProcess.running) {
            usageProcess.write(command + "\n");
        } else {
            pendingCommand.command = command;
            usageProcess.running = true;
        }
    }

    function open() {
        root.visible = true;
        root.busy = true;
        root.send("open");
    }

    function close() {
        if (root.visible && usageProcess.running) {
            root.send("close");
            stopTimer.restart();
        }
        root.visible = false;
        root.busy = false;
    }

    function toggle() {
        if (root.visible)
            root.close();
        else
            root.open();
    }

    function refresh() {
        root.busy = true;
        refreshTimeout.restart();
        root.send("refresh");
    }

    // Parses raw streaming JSON metrics from the backend helper daemon
    function parseUsage(line) {
        const trimmed = (line || "").trim();
        if (trimmed.length === 0)
            return;
        try {
            const snapshot = JSON.parse(trimmed);
            if (snapshot.schemaVersion !== 2 || !Array.isArray(snapshot.platforms))
                return;
            root.platformsData = snapshot.platforms;
            root.generatedAt = snapshot.generatedAt || 0;
            root.lastError = "";
            root.busy = false;
            refreshTimeout.stop();
        } catch (error) {
            root.lastError = "Invalid usage response";
            console.warn("AI usage stream parse failed:", error);
        }
    }

    QtObject {
        id: pendingCommand

        property string command: ""
    }

    // =========================================================================
    // 3. TIMers & PROCESS RUNNERS
    // =========================================================================

    Timer {
        id: refreshTimeout

        interval: 22000
        repeat: false
        onTriggered: {
            root.busy = false;
            root.lastError = "Refresh timed out";
        }
    }

    Timer {
        id: restartTimer

        interval: 2000
        repeat: false
        onTriggered: {
            if (root.visible) {
                usageProcess.running = true;
            }
        }
    }

    Timer {
        id: stopTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (!root.visible && usageProcess.running) {
                usageProcess.signal(15);
            }
        }
    }

    Process {
        id: usageProcess

        command: Commands.aiHelperCommand("watch")
        running: false
        stdinEnabled: true

        stdout: SplitParser {
            onRead: data => root.parseUsage(data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("AI usage helper:", data)
        }

        onRunningChanged: {
            if (running && pendingCommand.command.length > 0) {
                const command = pendingCommand.command;
                pendingCommand.command = "";
                Qt.callLater(() => usageProcess.write(command + "\n"));
            } else if (!running && root.visible) {
                restartTimer.restart();
            }
        }
    }
}
