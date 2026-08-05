pragma Singleton
import Quickshell

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    QUICKSHELL HELPER & SCRIPT REGISTRY
 * ─────────────────────────────────────────────────────────────────────────────
 * Central command router for calling external shell scripts and native Go
 * background daemons (qs-helper) across all UI widgets and IPC handlers.
 * ─────────────────────────────────────────────────────────────────────────────
 */
Singleton {
    // ── Relative Helper Paths ────────────────────────────────────────────────
    // Dynamically resolves scripts/ and helpers/bin paths without hardcoded directories
    readonly property string scriptsPath: Qt.resolvedUrl("../scripts/").toString().replace("file://", "")
    readonly property string helperPath: Qt.resolvedUrl("../helpers/bin/qs-helper").toString().replace("file://", "")

    // =========================================================================
    // 1. CORE EXECUTION ROUTERS
    // =========================================================================

    // Constructs argv command array for calling the compiled Go helper binary
    function helperCmd(helper, action, extra) {
        const argv = extra || [];
        const cmd = [helperPath, helper];
        if (action !== undefined && action !== null) {
            cmd.push(action);
        }
        return cmd.concat(argv);
    }

    // Constructs bash execution array for running standalone shell scripts
    function bashCmd(script) {
        return ["bash", scriptsPath + script];
    }

    // =========================================================================
    // 2. DOMAIN-SPECIFIC COMMAND BUILDERS
    // =========================================================================

    // Network manager interface (nmcli wrappers for Wi-Fi and Ethernet profiles)
    function networkHelperCommand(action, args) {
        return helperCmd("network", action, args);
    }

    // Audio & media controls (wpctl volume, playerctl playback, bluetoothctl)
    function controlsHelperCommand(action, args) {
        return helperCmd("controls", action, args);
    }

    // VPN connection routing (OpenVPN connection management)
    function vpnHelperCommand(action, args) {
        return helperCmd("vpn", action, args);
    }

    // Clipboard system interaction (history and buffer utilities)
    function clipboardHelperCommand(action, args) {
        return helperCmd("clipboard", action, args);
    }

    // Calendar data polling (Google Calendar API synchronization)
    function calendarHelperCommand(action, args) {
        return helperCmd("calendar", action, args);
    }

    // AI telemetry & prompt consumption usage tracking
    function aiHelperCommand(action, args) {
        return helperCmd("ai", action, args);
    }

    // Screen locker invocation (delegates to qs-lock bash script)
    function lockHelperCommand() {
        return bashCmd("qs-lock");
    }

    // Desktop application indexing and launcher execution (.desktop items)
    function launcherHelperCommand(action, args) {
        return helperCmd("launcher", action, args);
    }

    // Desktop wallpaper background cataloging and styling (feh wrapper)
    function wallpaperHelperCommand(action, args) {
        return helperCmd("wallpaper", action, args);
    }
}
