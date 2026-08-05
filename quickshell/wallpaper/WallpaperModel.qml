import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                  WALLPAPER MONITOR STATE ENGINE (WallpaperModel.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * State engine and IPC coordinator for managing desktop wallpaper catalogs,
 * ImageMagick thumbnail rendering, scaling geometries, and i3 persistence.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Scope {
    id: root

    // ── Global Visibility & Catalog State Variables ──────────────────────────
    property bool visible: false
    property bool busy: false
    property var wallpapers: []
    property int wallpaperCount: 0
    property string currentWallpaperPath: ""
    property string currentMode: "fill"
    property string currentColor: "#000000"
    property string computedColor: "#000000"

    // ── Debounce Buffer Variables ────────────────────────────────────────────
    property string pendingPath: ""
    property string pendingMode: ""
    property string pendingColor: ""

    // =========================================================================
    // 1. LIFECYCLE & CATALOG ROUTERS
    // =========================================================================

    onVisibleChanged: {
        if (root.visible && root.wallpapers.length === 0) {
            root.refresh();
        }
    }

    function refresh() {
        root.busy = true;
        listProcess.running = true;
    }

    function open() {
        root.visible = true;
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        root.visible = !root.visible;
    }

    function setWallpaper(path, mode, color) {
        root.pendingPath = path || root.currentWallpaperPath;
        root.pendingMode = mode || root.currentMode;
        root.pendingColor = color || root.currentColor;

        // Instant optimism state update for smooth GUI feedback
        root.currentWallpaperPath = root.pendingPath;
        root.currentMode = root.pendingMode;
        root.currentColor = root.pendingColor;
        root.updateActiveBadges();

        applyTimer.restart();
    }

    function updateMode(mode) {
        root.setWallpaper(root.currentWallpaperPath, mode, root.currentColor);
    }

    function updateColor(colorHex) {
        root.setWallpaper(root.currentWallpaperPath, root.currentMode, colorHex);
    }

    function randomize() {
        randomProcess.command = Commands.wallpaperHelperCommand("random", [root.currentMode, root.currentColor]);
        randomProcess.running = true;
    }

    // Refreshes item active badges in the QML model array
    function updateActiveBadges() {
        if (!root.wallpapers || root.wallpapers.length === 0)
            return;

        let updated = [];
        for (let i = 0; i < root.wallpapers.length; i++) {
            let item = root.wallpapers[i];
            let isActive = (item.path === root.currentWallpaperPath);
            item.active = isActive;
            updated.push(item);
        }
        root.wallpapers = updated;
    }

    function parseList(jsonText) {
        try {
            const data = JSON.parse(jsonText);
            if (data && data.wallpapers) {
                root.wallpapers = data.wallpapers;
                root.wallpaperCount = data.count || data.wallpapers.length;
                if (data.current && data.current.path) {
                    root.currentWallpaperPath = data.current.path;
                    root.currentMode = data.current.mode || "fill";
                    root.currentColor = data.current.color || "#000000";
                    root.computedColor = data.current.computedColor || root.currentColor;
                }
                root.updateActiveBadges();
            }
        } catch (err) {
            console.warn("Error parsing wallpaper catalog:", err);
        }
        root.busy = false;
    }

    function parseCurrent(jsonText) {
        try {
            const data = JSON.parse(jsonText);
            if (data && data.current && data.current.path) {
                root.currentWallpaperPath = data.current.path;
                root.currentMode = data.current.mode || "fill";
                root.currentColor = data.current.color || "#000000";
                root.computedColor = data.current.computedColor || root.currentColor;
                root.updateActiveBadges();
            }
        } catch (err) {
            console.warn("Error parsing wallpaper state:", err);
        }
    }

    // =========================================================================
    // 2. TIMERS & SUBPROCESS EXECUTION ENGINES
    // =========================================================================

    // Execution debouncer prevents disk I/O spam and display redraw loops during rapid tweaking
    Timer {
        id: applyTimer
        interval: 60
        repeat: false
        onTriggered: {
            applyProcess.command = Commands.wallpaperHelperCommand("set", [root.pendingPath, root.pendingMode, root.pendingColor]);
            applyProcess.running = true;
        }
    }

    Process {
        id: listProcess
        command: Commands.wallpaperHelperCommand("list", [])
        running: false

        stdout: SplitParser {
            onRead: data => root.parseList(data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("qs-wallpaper list stderr:", data)
        }
    }

    Process {
        id: applyProcess
        running: false

        stdout: SplitParser {
            onRead: data => root.parseCurrent(data)
        }
    }

    Process {
        id: randomProcess
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.parseCurrent(data);
            }
        }
    }
}
