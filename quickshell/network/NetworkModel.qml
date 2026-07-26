import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property bool visible: false
    property bool busy: false
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

    readonly property var activeConnections: root.connections.filter(function(profile) {
        return profile.active && profile.name !== "lo" && profile.name !== "Quickshell Hotspot" && !profile.name.startsWith("docker");
    })

    function open() {
        root.visible = true;
        root.refresh(true);
    }

    function close() {
        root.visible = false;
        root.selectedWifiIndex = -1;
        root.message = "";
        root.wifiPassword = "";
        root.editingHotspot = false;
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function refresh(rescanWifi) {
        if (!statusProcess.running) {
            statusProcess.running = true;
        }
        if (!connectionsProcess.running) {
            connectionsProcess.running = true;
        }
        if (!hotspotStatusProcess.running) {
            hotspotStatusProcess.running = true;
        }
        root.refreshWifi(rescanWifi === true);
    }

    function refreshWifi(rescan) {
        wifiScanProcess.running = false;
        wifiScanProcess.command = Commands.networkHelperCommand("wifi-scan", rescan ? ["--rescan", "yes"] : ["--rescan", "no"]);
        wifiScanProcess.running = true;
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
                "device": fields[4]
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

    function parseWifiNetworks(text) {
        const rows = [];
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
        const selectedBssid = root.selectedWifiNetwork() ? root.selectedWifiNetwork().bssid : "";

        for (const line of lines) {
            const fields = line.split("\t");

            if (fields.length < 7 || fields[2].length === 0) {
                continue;
            }

            const security = fields[4] === "--" ? "" : fields[4];

            rows.push({
                "active": fields[0] === "*",
                "bssid": fields[1],
                "ssid": fields[2],
                "signal": fields[3],
                "security": security,
                "channel": fields[5],
                "device": fields[6],
                "secured": security.length > 0
            });
        }

        root.wifiNetworks = rows;
        root.selectedWifiIndex = -1;

        for (let i = 0; i < rows.length; i++) {
            if (rows[i].bssid === selectedBssid) {
                root.selectedWifiIndex = i;
                break;
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
        root.wifiPassword = "";
        root.message = "";
    }

    function connectWifi(network) {
        if (!network || network.device.length === 0 || network.bssid.length === 0 || network.ssid.length === 0) {
            return;
        }

        if (network.secured && root.wifiPassword.length === 0) {
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
        if (network.secured) {
            args.push(root.wifiPassword);
        }

        root.busy = true;
        root.message = "Connecting " + network.ssid;
        actionProcess.command = Commands.networkHelperCommand("wifi-connect", args);
        actionProcess.running = true;
    }

    function connectSelectedWifi() {
        root.connectWifi(root.selectedWifiNetwork());
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
        interval: 1000
        running: false
        repeat: false
        onTriggered: root.refresh(false)
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
                root.wifiPassword = "";
                root.message = "";
                networkRefreshDebouncer.restart();
            }
        }
        
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) console.warn("Network action error: " + this.text);
            }
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
                if (this.text.length > 0) console.warn("Network editor error: " + this.text);
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

    Component.onCompleted: editorCheckProcess.running = true
}
