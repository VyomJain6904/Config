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
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) console.warn("i3-msg switch error: " + this.text);
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
                } catch(e) {
                    console.warn("i3-msg get_workspaces parse error: " + e);
                }
            }
        }
    }

    // ── Subscribe to i3 events for updates ────────────────────────────
    Process {
        id: i3SubProcess
        command: ["i3-msg", "-t", "subscribe", "-m", "[ \"workspace\", \"window\" ]"]
        running: true

        stdout: SplitParser {
            onRead: {
                if (!wsFetchProc.running) wsFetchProc.running = true;
                if (!titleProcess.running) titleProcess.running = true;
            }
        }
        
        onRunningChanged: {
            if (!running) {
                Qt.callLater(() => { running = true; })
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
