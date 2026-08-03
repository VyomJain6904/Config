import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    VPN CLIENT ENGINE (VpnModel.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Manages active VPN tunnel connections, configuration file profiles, and target
 * IP routing via `qs-helper vpn-*` commands. Supports clipboard IP copying.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Scope {
    id: root

    // ── Active Tunnel & Profile State Variables ──────────────────────────────
    property bool visible: false
    property bool busy: false
    property string message: ""
    property string vpnIp: ""
    property string targetIp: ""
    property string targetInput: ""
    property string activeProfile: ""
    property var profiles: []
    property bool active: vpnIp !== ""
    property bool connected: active
    property bool targetLocked: connected || busy

    // =========================================================================
    // 1. LIFECYCLE & REFRESH ROUTERS
    // =========================================================================

    function open() {
        root.visible = true;
        root.refreshProfiles();
        root.refresh();
    }

    function close() {
        root.visible = false;
        if (!root.busy) {
            root.message = "";
        }
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function refreshProfiles() {
        if (!profilesProcess.running) {
            profilesProcess.running = true;
        }
    }

    function refresh() {
        if (!statusProcess.running) {
            statusProcess.running = true;
        }
    }

    // =========================================================================
    // 2. PARSING & CONNECTION EXECUTORS
    // =========================================================================

    function parseProfiles(text) {
        const rows = [];
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split("\t");
            if (fields.length < 2) {
                continue;
            }

            rows.push({
                "name": fields[0],
                "path": fields[1],
                "active": fields.length > 2 && fields[2] === "1",
                "logoPath": fields.length > 3 ? fields[3] : ""
            });
        }

        root.profiles = rows;
    }

    function parseStatus(text) {
        const fields = text.trim().split("\t");
        const isConnected = fields.length > 0 && fields[0] === "1";

        root.vpnIp = isConnected && fields.length > 1 ? fields[1] : "";
        root.targetIp = isConnected && fields.length > 2 ? fields[2] : "";
        root.activeProfile = isConnected && fields.length > 3 ? fields[3] : "";

        if (isConnected && root.targetIp.length > 0) {
            root.targetInput = root.targetIp;
        }

        if (!root.busy && isConnected) {
            root.message = "Connected" + (root.activeProfile.length > 0 ? " to " + root.activeProfile : "");
        } else if (!root.busy && root.message.indexOf("Failed") !== 0) {
            root.message = "";
        }
    }

    function connectProfile(profile) {
        if (root.busy || root.connected || !profile || !profile.path || profile.path.length === 0) {
            return;
        }

        root.busy = true;
        root.message = "Connecting " + profile.name + "...";
        actionProcess.command = Commands.vpnHelperCommand("connect", [profile.path, root.targetInput]);
        actionProcess.running = true;
    }

    function disconnect() {
        if (root.busy) {
            return;
        }

        root.busy = true;
        root.message = "Disconnecting VPN...";
        actionProcess.command = Commands.vpnHelperCommand("disconnect");
        actionProcess.running = true;
    }

    function copyToClipboard(text) {
        const value = (text || "").toString().trim();
        if (value.length === 0 || copyProcess.running) {
            return;
        }
        copyProcess.command = Commands.clipboardHelperCommand("copy", [value]);
        copyProcess.running = true;
    }

    // =========================================================================
    // 3. BACKGROUND PROCESSES & TIMERS
    // =========================================================================

    Timer {
        interval: root.visible ? 5000 : 15000
        running: root.visible || root.connected || root.busy
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        id: postActionRefreshTimer

        interval: 1200
        running: false
        repeat: false
        onTriggered: root.refresh()
    }

    Process {
        id: profilesProcess

        command: Commands.vpnHelperCommand("list")
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseProfiles(this.text)
        }
    }

    Process {
        id: statusProcess

        command: Commands.vpnHelperCommand("status")
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parseStatus(this.text)
        }
    }

    Process {
        id: actionProcess

        running: false
        onRunningChanged: {
            if (!running) {
                root.busy = false;
                postActionRefreshTimer.restart();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();
                if (text.length > 0) {
                    root.message = "Failed: " + text;
                    console.warn("VPN action error: " + text);
                }
            }
        }
    }

    Process {
        id: copyProcess

        running: false
    }
}
