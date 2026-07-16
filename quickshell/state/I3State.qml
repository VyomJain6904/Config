import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.I3

Scope {
    id: root

    // currentWorkspaceNum stores the focused workspace NUMBER (1-based, matches i3 num)
    property int    currentWorkspaceNum: 1
    property var    workspaceNames:      []
    property string activeWindowTitle:   "Desktop"
    property var    statusSegments:      []

    // ── Switch to workspace by its number ─────────────────────────────
    function switchWorkspace(num) {
        I3.dispatch("workspace number " + num.toString())
    }

    // ── Rebuild workspace name list from live I3 workspaces ───────────
    function rebuildWorkspaces() {
        var ws   = I3.workspaces.values
        var nums = []
        for (var i = 0; i < ws.length; i++) {
            nums.push(ws[i].num.toString())
        }
        // Sort numerically
        nums.sort(function(a, b) { return parseInt(a) - parseInt(b) })
        root.workspaceNames = nums
    }

    // ── Connections: focused workspace changes ─────────────────────────
    Connections {
        target: I3

        function onFocusedWorkspaceChanged() {
            root.currentWorkspaceNum = I3.focusedWorkspace
                ? I3.focusedWorkspace.num
                : 1
            // Re-build list in case new workspace was created on focus
            root.rebuildWorkspaces()
        }
    }

    // ── Connections: workspace list additions / removals ──────────────
    Connections {
        target: I3.workspaces

        function onObjectInsertedPost(object, index) {
            root.rebuildWorkspaces()
        }

        function onObjectRemovedPost(object, index) {
            root.rebuildWorkspaces()
        }
    }

    // ── Poll active window title via xdotool ──────────────────────────
    Timer {
        id: titleTimer
        interval: 600
        running:  true
        repeat:   true
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
        root.currentWorkspaceNum = I3.focusedWorkspace ? I3.focusedWorkspace.num : 1
        root.rebuildWorkspaces()
        I3.refreshWorkspaces()
    }
}
