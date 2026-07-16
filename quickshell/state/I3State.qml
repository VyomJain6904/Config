import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property int    currentWorkspaceNum: 1
    property var    workspaceNames:      []
    property string activeWindowTitle:   "Desktop"
    property var    statusSegments:      []

    // ── Switch to workspace by its number ─────────────────────────────
    function switchWorkspace(num) {
        if (!switchProc.running) {
            switchProc.command = ["i3-msg", "workspace", "number", num.toString()];
            switchProc.running = true;
        }
    }

    Process {
        id: switchProc
        running: false
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
                } catch(e) {}
            }
        }
    }

    Timer {
        id: wsTimer
        interval: 300
        running: true
        repeat: true
        onTriggered: {
            if (!wsFetchProc.running) {
                wsFetchProc.running = true;
            }
        }
    }

    // ── Poll active window title via xdotool ──────────────────────────
    Timer {
        id: titleTimer
        interval: 600
        running: true
        repeat: true
        onTriggered: {
            if (!titleProcess.running) {
                titleProcess.running = true
            }
        }
    }

    Process {
        id: titleProcess
        command: ["xdotool", "getactivewindow", "getwindowname"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim()
                root.activeWindowTitle = (t.length > 0) ? t : "Desktop"
            }
        }
    }

    // ── Init ──────────────────────────────────────────────────────────
    Component.onCompleted: {
        wsFetchProc.running = true;
        titleProcess.running = true;
    }
}
