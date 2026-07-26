import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property int    currentWorkspaceNum: 1
    property var    workspaceNames:      []
    property var    workspaceAppGrid:   []
    property var    workspaceWindowMap: ({})
    property var    pendingWindowMove:  null
    property bool   windowGridActive:   false
    readonly property var workspaceSlots: ["1", "2", "3", "4", "5", "6", "7", "8"]

    onWindowGridActiveChanged: {
        if (windowGridActive && !treeFetchProc.running) {
            treeFetchProc.running = true;
        }
    }

    function normalizeAppIconName(rawName) {
        if (!rawName || rawName.length === 0) {
            return "";
        }

        const lower = rawName.toLowerCase().trim();
        const aliases = {
            "ghostty": "ghostty",
            "ghosttydrop": "ghostty",
            "com.mitchellh.ghostty": "ghostty",
            "alacritty": "alacritty",
            "alacritty-simple": "alacritty",
            "librewolf": "librewolf",
            "librewolf-default": "librewolf",
            "helium": "helium",
            "obsidian": "obsidian",
            "md.obsidian": "obsidian",
            "thunar": "thunar",
            "filemanager": "thunar",
            "org.gtk.filemanager": "thunar",
            "org.xfce.thunar": "thunar",
            "brave-browser": "brave-browser",
            "brave": "brave-browser",
            "camera": "camera",
            "discord": "discord",
            "com.discordapp.discord": "discord",
            "obs": "obs",
            "obs studio": "obs",
            "com.obsproject.studio": "obs",
            "whatsapp": "whatsapp",
            "com.whatsapp.whatsapp": "whatsapp",
            "telegram": "telegram",
            "telegramdesktop": "telegram",
            "telegram-desktop": "telegram",
            "org.telegram.desktop": "telegram",
            "vlc": "vlc",
            "org.videolan.vlc": "vlc",
            "terminal": "terminal",
            "utilities-terminal": "terminal",
            "vmware": "vmware-workstation",
            "vmware workstation": "vmware-workstation",
            "vmware-workstation": "vmware-workstation",
            "wireshark": "wireshark",
            "sublime": "sublime",
            "sublime_text": "sublime",
            "sublime text": "sublime",
            "com.sublimetext": "sublime",
            "burp": "burp",
            "burpsuite": "burp",
            "burpsuite pro": "burp",
            "burp-startburp": "burp",
            "excalidraw": "excalidraw",
            "pake-excalidraw": "excalidraw",
            "nvidia": "nvidia",
            "antigravity": "antigravity",
            "antigravity ide": "antigravity",
            "localsend": "localsend",
            "torbrowser": "torbrowser",
            "tor browser": "torbrowser"
        };

        return aliases[lower] || lower;
    }

    function extractAppName(node) {
        if (node.app_id && node.app_id.length > 0) {
            return root.normalizeAppIconName(node.app_id);
        }

        if (node.window_properties) {
            if (node.window_properties.class && node.window_properties.class.length > 0) {
                return root.normalizeAppIconName(node.window_properties.class);
            }
            if (node.window_properties.instance && node.window_properties.instance.length > 0) {
                return root.normalizeAppIconName(node.window_properties.instance);
            }
        }

        if (node.name && node.name.length > 0) {
            return root.normalizeAppIconName(node.name);
        }

        return "";
    }

    function shouldShowWorkspaceWindow(node, appName) {
        const title = (node.name || "").toString().toLowerCase().trim();
        if (appName.length === 0) {
            return false;
        }
        if (appName === "quickshell" || title === "quickshell" || title === "quickshell utility") {
            return false;
        }
        return true;
    }

    function parseWorkspaceWindows(tree) {
        const windowMap = {};

        function ensureWorkspace(workspace) {
            if (!windowMap[workspace]) {
                windowMap[workspace] = [];
            }
        }

        function addWorkspaceWindow(workspace, node, appName) {
            if (!workspace || !root.shouldShowWorkspaceWindow(node, appName)) {
                return;
            }

            ensureWorkspace(workspace);

            windowMap[workspace].push({
                conId: node.id ? node.id.toString() : "",
                appKey: appName,
                iconKey: appName,
                title: node.name || appName,
                workspaceNum: parseInt(workspace, 10)
            });
        }

        function visit(node, workspace) {
            let currentWorkspace = workspace;

            if (node.type === "workspace" && typeof node.num === "number" && node.num >= 0) {
                currentWorkspace = node.num.toString();
                ensureWorkspace(currentWorkspace);
            }

            const isWindowLeaf = !!node.window && !!node.id;
            if (currentWorkspace && isWindowLeaf) {
                addWorkspaceWindow(currentWorkspace, node, root.extractAppName(node));
            }

            const tiled = node.nodes || [];
            for (let i = 0; i < tiled.length; i++) {
                visit(tiled[i], currentWorkspace);
            }

            const floating = node.floating_nodes || [];
            for (let i = 0; i < floating.length; i++) {
                visit(floating[i], currentWorkspace);
            }
        }

        visit(tree, "");
        return windowMap;
    }

    function rebuildWorkspaceGrid() {
        const slots = {};
        const ordered = [];

        function includeWorkspace(name) {
            if (!name || slots[name]) {
                return;
            }

            slots[name] = true;
            ordered.push(name);
        }

        for (let i = 0; i < root.workspaceSlots.length; i++) {
            includeWorkspace(root.workspaceSlots[i]);
        }

        for (let j = 0; j < root.workspaceNames.length; j++) {
            includeWorkspace(root.workspaceNames[j]);
        }

        const appKeys = Object.keys(root.workspaceWindowMap);
        for (let k = 0; k < appKeys.length; k++) {
            includeWorkspace(appKeys[k]);
        }

        ordered.sort((a, b) => parseInt(a, 10) - parseInt(b, 10));

        const rows = [];
        for (let index = 0; index < ordered.length; index++) {
            const workspace = ordered[index];
            const windows = root.workspaceWindowMap[workspace] || [];
            const num = parseInt(workspace, 10);

            rows.push({
                num: num,
                label: workspace,
                focused: num === root.currentWorkspaceNum,
                windows: windows,
                empty: windows.length === 0
            });
        }

        root.workspaceAppGrid = rows;
    }

    // ── Switch to workspace by its number ─────────────────────────────
    function switchWorkspace(num) {
        if (!switchProc.running) {
            switchProc.command = ["i3-msg", "workspace", "number", num.toString()];
            switchProc.running = true;
        }
    }

    function refreshWorkspaceState(includeTree) {
        if (!wsFetchProc.running) wsFetchProc.running = true;
        if ((includeTree || root.windowGridActive) && !treeFetchProc.running) treeFetchProc.running = true;
    }

    function runWindowMove(conIdText, workspaceNumText) {
        moveProc.command = ["i3-msg", "[con_id=" + conIdText + "]", "move", "container", "to", "workspace", "number", workspaceNumText];
        moveProc.running = true;
    }

    function moveWindowToWorkspace(conId, num) {
        const conIdText = (conId || "").toString();
        const parsedNum = parseInt(num, 10);
        if (!/^[0-9]+$/.test(conIdText) || isNaN(parsedNum)) {
            return;
        }

        const workspaceNumText = parsedNum.toString();
        if (moveProc.running) {
            root.pendingWindowMove = {
                conId: conIdText,
                workspaceNum: workspaceNumText
            };
            return;
        }

        root.runWindowMove(conIdText, workspaceNumText);
    }

    Process {
        id: switchProc
        running: false
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) console.warn("i3-msg switch error: " + this.text);
            }
        }
    }

    Process {
        id: moveProc
        running: false
        onRunningChanged: {
            if (!running) {
                root.refreshWorkspaceState(true);
                if (root.pendingWindowMove !== null) {
                    const move = root.pendingWindowMove;
                    root.pendingWindowMove = null;
                    Qt.callLater(() => root.runWindowMove(move.conId, move.workspaceNum));
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) console.warn("i3-msg move error: " + this.text);
            }
        }
    }

    // ── Fetch workspaces periodically via i3-msg ─────────────────────
    Process {
        id: wsFetchProc
        command: ["i3-msg", "-t", "get_workspaces"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let wss = JSON.parse(this.text);
                    let nums = [];
                    for(let i=0; i<wss.length; i++) {
                        nums.push(wss[i].num.toString());
                        if (wss[i].focused) {
                            root.currentWorkspaceNum = wss[i].num;
                        }
                    }
                    nums.sort((a,b) => parseInt(a) - parseInt(b));
                    root.workspaceNames = nums;
                    root.rebuildWorkspaceGrid();
                } catch(e) {
                    console.warn("i3-msg get_workspaces parse error: " + e);
                }
            }
        }
    }

    Process {
        id: treeFetchProc
        command: ["i3-msg", "-t", "get_tree"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const tree = JSON.parse(this.text);
                    root.workspaceWindowMap = root.parseWorkspaceWindows(tree);
                    root.rebuildWorkspaceGrid();
                } catch (e) {
                    console.warn("i3-msg get_tree parse error: " + e);
                }
            }
        }
    }

    Timer {
        id: i3SubRestartTimer
        interval: 3000
        repeat: false
        onTriggered: i3SubProcess.running = true
    }

    // ── Subscribe to i3 events for updates ────────────────────────────
    Process {
        id: i3SubProcess
        command: ["i3-msg", "-t", "subscribe", "-m", "[ \"workspace\", \"window\" ]"]
        running: true

        stdout: SplitParser {
            onRead: {
                root.refreshWorkspaceState(false);
            }
        }
        
        onRunningChanged: {
            if (!running) {
                i3SubRestartTimer.restart();
            }
        }
    }

    // ── Init ──────────────────────────────────────────────────────────
    Component.onCompleted: {
        wsFetchProc.running = true;
    }
}
