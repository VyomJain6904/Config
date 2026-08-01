pragma Singleton
import Quickshell

Singleton {
    // Resolve helper paths relative to this file
    readonly property string scriptsPath: Qt.resolvedUrl("../scripts/").toString().replace("file://", "")
    readonly property string helperPath: Qt.resolvedUrl("../helpers/bin/qs-helper").toString().replace("file://", "")

    // ── Native Go helper ──────────────────────────────────────────────
    function helperCmd(helper, action, extra) {
        const argv  = extra || []
        const cmd   = [helperPath, helper]
        if (action !== undefined && action !== null) {
            cmd.push(action)
        }
        return cmd.concat(argv)
    }

    function bashCmd(script) {
        return ["bash", scriptsPath + script]
    }

    // ── Network (nmcli) ───────────────────────────────────────────────
    function networkHelperCommand(action, args) {
        return helperCmd("network", action, args)
    }

    // ── Controls (wpctl / playerctl / bluetoothctl) ───────────────────
    function controlsHelperCommand(action, args) {
        return helperCmd("controls", action, args)
    }

    // ── VPN (OpenVPN profiles) ───────────────────────────────────────
    function vpnHelperCommand(action, args) {
        return helperCmd("vpn", action, args)
    }

    function clipboardHelperCommand(action, args) {
        return helperCmd("clipboard", action, args)
    }

    // ── Calendar (Google Calendar API) ────────────────────────────────
    function calendarHelperCommand(action, args) {
        return helperCmd("calendar", action, args)
    }

    // ── AI Usage Tracker ──────────────────────────────────────────────
    function aiHelperCommand(action, args) {
        return helperCmd("ai", action, args)
    }

    // ── Lock screen (i3lock) ──────────────────────────────────────────
    function lockHelperCommand() {
        return bashCmd("qs-lock")
    }

    // ── Launcher (.desktop applications) ──────────────────────────────
    function launcherHelperCommand(action, args) {
        return helperCmd("launcher", action, args)
    }
}
