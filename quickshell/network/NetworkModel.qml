import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property bool visible: false
    property bool busy: false
    property bool scanning: false
    property bool editorAvailable: false
    property int selectedWifiIndex: -1
    property string statusText: "NET offline"
    property string message: ""
    property string wifiPassword: ""
    property bool hotspotAvailable: false
    property bool hotspotActive: false
    property string hotspotSsid: "Hotspot"
    property string hotspotPassword: ""
    property string hotspotSsidInput: ""
    property string hotspotPasswordInput: ""
    property bool editingHotspot: false
    property string hotspotChannel: ""
    property var hotspotClients: []
    property var connections: []
    property var wifiNetworks: []
    property var savedNetworks: []

    property int passwordAttempts: 0
    property bool connectingWithPassword: false
    property bool testingSpeed: false
    property string speedPing: "-- ms"
    property string speedDownload: "-- Mbps"
    property string speedUpload: "-- Mbps"

    property bool sharingWifi: false
    property string shareSsid: ""
    property string sharePassword: ""
    property string shareQrPath: ""
    property bool showSharePassword: false

    signal passwordFailed(int attempt)

    readonly property var activeConnections: root.connections.filter(function (profile) {
        return profile.active && profile.name !== "lo" && profile.name !== "Quickshell Hotspot" && !profile.name.startsWith("docker") && !profile.name.startsWith("br-") && (profile.type === "802-11-wireless" || profile.type === "wifi" || profile.type === "wireless");
    })

    function open() {
        root.visible = true;
        if (!editorCheckProcess.running) {
            editorCheckProcess.running = true;
        }
        root.refresh(false);
    }

    function close() {
        root.visible = false;
        root.selectedWifiIndex = -1;
        root.message = "";
        root.wifiPassword = "";
        root.editingHotspot = false;
        wifiScanPoller.stop();
        root.scanning = false;
        root.wifiNetworks = [];
        root.speedPing = "-- ms";
        root.speedDownload = "-- Mbps";
        root.speedUpload = "-- Mbps";
        root.sharingWifi = false;
        root.showSharePassword = false;
    }

    onVisibleChanged: {
        if (!root.visible) {
            root.speedPing = "-- ms";
            root.speedDownload = "-- Mbps";
            root.speedUpload = "-- Mbps";
        }
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function shareActiveWifi() {
        root.sharingWifi = false;
        root.showSharePassword = false;
        root.shareSsid = "";
        root.sharePassword = "";
        root.shareQrPath = "";
        wifiShareProcess.running = true;
    }

    function closeShare() {
        root.sharingWifi = false;
        root.showSharePassword = false;
    }

    function copyToClipboard(text) {
        const value = (text || "").toString().trim();
        if (value.length === 0 || copyProcess.running) {
            return;
        }
        copyProcess.command = Commands.clipboardHelperCommand("copy", [value]);
        copyProcess.running = true;
    }

    function refresh(rescanWifi) {
        root.refreshStatus();
        if (!root.visible) {
            return;
        }
        if (!connectionsProcess.running) {
            connectionsProcess.running = true;
        }
        if (!hotspotStatusProcess.running) {
            hotspotStatusProcess.running = true;
        }
        if (!savedNetworksProcess.running) {
            savedNetworksProcess.running = true;
        }
        if (rescanWifi === true || root.wifiNetworks.length > 0) {
            root.refreshWifi(rescanWifi === true);
        }
    }

    function refreshStatus() {
        if (!statusProcess.running) {
            statusProcess.running = true;
        }
    }

    function refreshWifi(rescan) {
        wifiScanProcess.running = false;
        wifiScanProcess.command = Commands.networkHelperCommand("wifi-scan", ["--rescan", "no"]);
        wifiScanProcess.running = true;
        if (rescan && !root.scanning) {
            root.scanning = true;
            wifiRescanProcess.running = true;
            wifiScanPoller.pollCount = 0;
            wifiScanPoller.start();
        }
    }

    function parseConnections(text) {
        const rows = [];
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];

        for (const line of lines) {
            const fields = line.split("\t");

            if (fields.length < 5) {
                continue;
            }

            rows.push({
                "name": fields[0],
                "uuid": fields[1],
                "type": fields[2],
                "active": fields[3] === "yes",
                "device": fields[4],
                "signal": fields.length > 5 ? fields[5] : "0"
            });
        }

        root.connections = rows;
    }

    function parseHotspotStatus(text) {
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
        const clients = [];

        if (lines.length > 0) {
            const fields = lines[0].split("\t");
            root.hotspotAvailable = fields.length > 0 && fields[0] === "1";
            root.hotspotActive = fields.length > 1 && fields[1] === "1";
            root.hotspotSsid = fields.length > 2 && fields[2].length > 0 ? fields[2] : "Hotspot";
            root.hotspotChannel = fields.length > 5 ? fields[5] : "";
            root.hotspotPassword = fields.length > 8 ? fields[8] : "";
        } else {
            root.hotspotAvailable = false;
            root.hotspotActive = false;
            root.hotspotSsid = "Hotspot";
            root.hotspotPassword = "";
            root.hotspotChannel = "";
        }

        for (let i = 1; i < lines.length; i++) {
            const fields = lines[i].split("\t");
            if (fields.length < 4 || fields[0] !== "client") {
                continue;
            }

            clients.push({
                "name": fields[1],
                "ip": fields[2],
                "mac": fields[3]
            });
        }

        root.hotspotClients = clients;
    }

    function parseSavedNetworks(text) {
        const rows = [];
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
        for (const line of lines) {
            const fields = line.split("\t");
            if (fields.length < 6)
                continue;
            rows.push({
                "name": fields[0],
                "uuid": fields[1],
                "active": fields[2] === "yes",
                "device": fields[3] || "wlo1",
                "autoconnect": fields[4] === "yes",
                "password": fields[5] || ""
            });
        }

        let identical = root.savedNetworks && root.savedNetworks.length === rows.length;
        if (identical) {
            for (let i = 0; i < rows.length; i++) {
                if (root.savedNetworks[i].uuid !== rows[i].uuid || root.savedNetworks[i].name !== rows[i].name || root.savedNetworks[i].active !== rows[i].active || root.savedNetworks[i].autoconnect !== rows[i].autoconnect || root.savedNetworks[i].password !== rows[i].password) {
                    identical = false;
                    break;
                }
            }
        }

        if (!identical) {
            root.savedNetworks = rows;
        }
    }

    function parseWifiNetworks(text) {
        const rows = [];
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
        const selectedSsid = root.selectedWifiNetwork() ? root.selectedWifiNetwork().ssid : "";
        const selectedBssid = root.selectedWifiNetwork() ? root.selectedWifiNetwork().bssid : "";

        for (const line of lines) {
            const fields = line.split("\t");

            if (fields.length < 7 || fields[2].length === 0) {
                continue;
            }

            const security = fields[4] === "--" ? "" : fields[4];
            const isSaved = fields.length > 7 ? fields[7] === "yes" : false;

            rows.push({
                "active": fields[0] === "*",
                "bssid": fields[1],
                "ssid": fields[2],
                "signal": fields[3],
                "security": security,
                "channel": fields[5],
                "device": fields[6],
                "saved": isSaved,
                "secured": security.length > 0
            });
        }

        let identical = root.wifiNetworks && root.wifiNetworks.length === rows.length;
        if (identical) {
            for (let i = 0; i < rows.length; i++) {
                const oldSig = parseInt(root.wifiNetworks[i].signal, 10) || 0;
                const newSig = parseInt(rows[i].signal, 10) || 0;
                if (root.wifiNetworks[i].ssid !== rows[i].ssid || root.wifiNetworks[i].active !== rows[i].active || root.wifiNetworks[i].security !== rows[i].security || root.wifiNetworks[i].bssid !== rows[i].bssid || root.wifiNetworks[i].saved !== rows[i].saved || Math.abs(oldSig - newSig) > 5) {
                    identical = false;
                    break;
                }
            }
        }

        if (!identical) {
            root.wifiNetworks = rows;
            root.selectedWifiIndex = -1;

            for (let i = 0; i < rows.length; i++) {
                if (rows[i].ssid === selectedSsid || rows[i].bssid === selectedBssid) {
                    root.selectedWifiIndex = i;
                    break;
                }
            }
        }
    }

    function selectedWifiNetwork() {
        if (root.selectedWifiIndex < 0 || root.selectedWifiIndex >= root.wifiNetworks.length) {
            return null;
        }

        return root.wifiNetworks[root.selectedWifiIndex];
    }

    function selectWifi(index) {
        if (index < 0 || index >= root.wifiNetworks.length) {
            return;
        }

        root.selectedWifiIndex = index;
        root.passwordAttempts = 0;
        root.wifiPassword = "";
        root.message = "";
    }

    function connectWifi(network) {
        if (!network || network.device.length === 0 || network.bssid.length === 0 || network.ssid.length === 0) {
            return;
        }

        if (network.secured && !network.saved && !network.active && root.wifiPassword.length === 0) {
            for (let i = 0; i < root.wifiNetworks.length; i++) {
                if (root.wifiNetworks[i].bssid === network.bssid && root.wifiNetworks[i].device === network.device) {
                    root.selectedWifiIndex = i;
                    break;
                }
            }
            root.message = "Enter the Wi-Fi password for " + network.ssid;
            return;
        }

        const args = [network.device, network.bssid, network.ssid];
        if (network.secured && root.wifiPassword.length > 0) {
            args.push(root.wifiPassword);
            root.connectingWithPassword = true;
        } else {
            root.connectingWithPassword = false;
        }

        root.busy = true;
        root.message = "Connecting " + network.ssid;
        actionProcess.command = Commands.networkHelperCommand("wifi-connect", args);
        actionProcess.running = true;
        realtimeSyncTimer.trigger();
    }

    function connectSelectedWifi() {
        root.connectWifi(root.selectedWifiNetwork());
    }

    function connectSavedNetwork(uuid) {
        if (!uuid || root.busy)
            return;
        root.busy = true;
        root.message = "Connecting saved network...";
        actionProcess.command = ["nmcli", "connection", "up", "uuid", uuid];
        actionProcess.running = true;
        realtimeSyncTimer.trigger();
    }

    function forgetSavedNetwork(uuid) {
        if (!uuid || root.busy)
            return;
        root.busy = true;
        root.message = "Removing saved network...";
        actionProcess.command = ["nmcli", "connection", "delete", "uuid", uuid];
        actionProcess.running = true;
        realtimeSyncTimer.trigger();
    }

    function toggleAutoconnect(uuid, enable) {
        if (!uuid || root.busy)
            return;
        root.busy = true;
        root.message = "Updating auto-connect...";
        actionProcess.command = ["nmcli", "connection", "modify", "uuid", uuid, "connection.autoconnect", enable ? "yes" : "no"];
        actionProcess.running = true;
        realtimeSyncTimer.trigger();
    }

    function toggleHotspot() {
        if (!root.hotspotAvailable || root.busy) {
            return;
        }

        root.busy = true;
        root.message = root.hotspotActive ? "Stopping hotspot " + root.hotspotSsid : "Starting hotspot " + root.hotspotSsid + (root.hotspotChannel.length > 0 ? " on channel " + root.hotspotChannel : "");
        actionProcess.command = Commands.networkHelperCommand(root.hotspotActive ? "hotspot-stop" : "hotspot-start");
        actionProcess.running = true;
    }

    function disconnectDevice(device) {
        if (!device || device.length === 0) {
            return;
        }

        root.busy = true;
        root.message = "Disconnecting " + device;
        actionProcess.command = Commands.networkHelperCommand("disconnect", [device]);
        actionProcess.running = true;
    }

    function openEditor() {
        if (!root.editorAvailable) {
            return;
        }

        if (!editorProcess.running) {
            editorProcess.running = true;
        }
    }

    Timer {
        id: networkRefreshDebouncer
        interval: 150
        running: false
        repeat: false
        onTriggered: {
            if (root.visible) {
                root.refresh(false);
            } else {
                root.refreshStatus();
            }
        }
    }

    Process {
        id: statusProcess

        command: Commands.networkHelperCommand("status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const text = this.text.trim();

                root.statusText = text.length > 0 ? text : "NET offline";
            }
        }
    }

    Process {
        id: connectionsProcess

        command: Commands.networkHelperCommand("connections")
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseConnections(this.text)
        }
    }

    Process {
        id: hotspotStatusProcess

        command: Commands.networkHelperCommand("hotspot-status")
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseHotspotStatus(this.text)
        }
    }

    Process {
        id: actionProcess

        running: false

        onRunningChanged: {
            if (!running) {
                root.busy = false;
                if (root.connectingWithPassword) {
                    root.connectingWithPassword = false;
                    if (exitCode !== 0) {
                        root.passwordAttempts++;
                        root.wifiPassword = "";
                        if (root.passwordAttempts < 3) {
                            root.message = "Incorrect password (" + root.passwordAttempts + "/3 attempts failed)";
                            root.passwordFailed(root.passwordAttempts);
                        } else {
                            root.selectedWifiIndex = -1;
                            root.passwordAttempts = 0;
                            root.message = "Connection failed after 3 incorrect attempts.";
                        }
                    } else {
                        root.selectedWifiIndex = -1;
                        root.passwordAttempts = 0;
                        root.wifiPassword = "";
                        root.message = "";
                    }
                } else {
                    if (exitCode === 0 && root.selectedWifiIndex >= 0) {
                        root.selectedWifiIndex = -1;
                    }
                    root.wifiPassword = "";
                    root.message = "";
                }
                networkRefreshDebouncer.restart();
                realtimeSyncTimer.trigger();
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    console.warn("Network action error: " + this.text);
            }
        }
    }

    Process {
        id: savedNetworksProcess
        command: Commands.networkHelperCommand("wifi-saved")
        running: false
        stdout: StdioCollector {
            onStreamFinished: root.parseSavedNetworks(this.text)
        }
    }

    function runSpeedTest() {
        if (root.testingSpeed)
            return;
        root.testingSpeed = true;
        root.speedPing = "Testing...";
        root.speedDownload = "Testing...";
        root.speedUpload = "Testing...";
        speedTestProcess.running = true;
    }

    Process {
        id: speedTestProcess
        command: Commands.networkHelperCommand("speedtest")
        running: false
        onRunningChanged: {
            if (!running) {
                root.testingSpeed = false;
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split("\t");
                if (parts.length >= 3) {
                    root.speedPing = parts[0];
                    root.speedDownload = parts[1];
                    root.speedUpload = parts[2];
                } else {
                    root.speedPing = "-- ms";
                    root.speedDownload = "-- Mbps";
                    root.speedUpload = "-- Mbps";
                }
            }
        }
    }

    Process {
        id: wifiShareProcess
        command: Commands.networkHelperCommand("wifi-share")
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim());
                    if (data && data.success) {
                        root.shareSsid = data.ssid || "";
                        root.sharePassword = data.password || "";
                        root.shareQrPath = data.qrPath || "";
                        root.sharingWifi = true;
                    } else {
                        console.warn("WiFi share error: " + (data.error || "Unknown"));
                        root.sharingWifi = false;
                    }
                } catch(e) {
                    console.warn("Failed to parse WiFi share output: " + e);
                    root.sharingWifi = false;
                }
            }
        }
    }

    Process {
        id: copyProcess
        running: false
    }

    Timer {
        id: realtimeSyncTimer
        interval: 500
        repeat: true
        property int pollCount: 0
        function trigger() {
            pollCount = 0;
            running = true;
        }
        onTriggered: {
            pollCount++;
            if (!root.visible || pollCount >= 8) {
                running = false;
                return;
            }
            root.refresh(false);
        }
    }

    Process {
        id: wifiScanProcess

        command: Commands.networkHelperCommand("wifi-scan", ["--rescan", "no"])
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.parseWifiNetworks(this.text)
        }
    }

    Process {
        id: wifiRescanProcess
        command: Commands.networkHelperCommand("wifi-rescan")
        running: false
    }

    Timer {
        id: wifiScanPoller
        property int pollCount: 0
        interval: 1500
        repeat: true
        running: false
        onTriggered: {
            pollCount++;
            if (root.visible && !wifiScanProcess.running) {
                wifiScanProcess.running = false;
                wifiScanProcess.command = Commands.networkHelperCommand("wifi-scan", ["--rescan", "no"]);
                wifiScanProcess.running = true;
            }
            if (pollCount >= 4 || !root.visible) {
                wifiScanPoller.stop();
                root.scanning = false;
            }
        }
    }

    Timer {
        id: monitorRestartTimer
        interval: 3000
        repeat: false
        onTriggered: monitorProcess.running = true
    }

    Process {
        id: monitorProcess
        command: Commands.networkHelperCommand("monitor")
        running: true

        stdout: SplitParser {
            onRead: networkRefreshDebouncer.restart()
        }

        onRunningChanged: {
            if (!running) {
                monitorRestartTimer.restart();
            }
        }
    }

    Process {
        id: editorProcess

        command: Commands.networkHelperCommand("editor")
        running: false

        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0)
                    console.warn("Network editor error: " + this.text);
            }
        }
    }

    Process {
        id: editorCheckProcess

        command: ["sh", "-c", "command -v nm-connection-editor >/dev/null 2>&1 && printf yes || printf no"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: root.editorAvailable = this.text.trim() === "yes"
        }
    }

    function startEditingHotspot() {
        root.hotspotSsidInput = root.hotspotSsid;
        root.hotspotPasswordInput = root.hotspotPassword;
        root.editingHotspot = true;
    }

    function cancelEditingHotspot() {
        root.editingHotspot = false;
    }

    function saveHotspotConfig(newSsid, newPassword) {
        if (!newPassword || newPassword.length < 8) {
            root.message = "Hotspot password must be at least 8 characters";
            return;
        }

        root.busy = true;
        root.message = "Saving Hotspot settings...";
        hotspotSaveProcess.command = Commands.networkHelperCommand("hotspot-save", ["--ssid", newSsid, "--password", newPassword]);
        hotspotSaveProcess.running = true;
        root.editingHotspot = false;
    }

    Process {
        id: hotspotSaveProcess

        running: false

        onRunningChanged: {
            if (!running) {
                root.busy = false;
                root.refresh();
            }
        }
    }

    Component.onCompleted: root.refreshStatus()
}
