pragma Singleton
import Quickshell

Singleton {
    // Resolve the scripts directory relative to this file
    readonly property string scriptsPath: Qt.resolvedUrl("../scripts/").toString().replace("file://", "")

    // ── Generic helper ────────────────────────────────────────────────
    function scriptCmd(script, action, extra) {
        const argv  = extra || []
        const path  = scriptsPath + script
        const cmd   = ["python3", path]
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
        return scriptCmd("qs-network", action, args)
    }

    // ── Controls (wpctl / playerctl / bluetoothctl) ───────────────────
    function controlsHelperCommand(action, args) {
        return scriptCmd("qs-controls", action, args)
    }

    // ── VPN (OpenVPN profiles) ───────────────────────────────────────
    function vpnHelperCommand(action, args) {
        return scriptCmd("qs-vpn", action, args)
    }

    // ── Launcher (XDG .desktop) ───────────────────────────────────────
    function launcherHelperCommand(action, args) {
        return scriptCmd("qs-launcher", action, args)
    }

    // ── Calendar (Native Compiled Service & Google Calendar API) ──────
    function calendarHelperCommand(action, args) {
        const argv = args || []
        const cmd = ["/home/jain/.local/bin/qs-calendar-service"]
        if (action !== undefined && action !== null) {
            cmd.push(action)
        }
        return cmd.concat(argv)
    }

    // ── Lock screen (i3lock) ──────────────────────────────────────────
    function lockHelperCommand() {
        return bashCmd("qs-lock")
    }

}
