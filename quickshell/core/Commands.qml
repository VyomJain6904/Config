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

    // ── Launcher (XDG .desktop) ───────────────────────────────────────
    function launcherHelperCommand(action, args) {
        return scriptCmd("qs-launcher", action, args)
    }

    // ── Control Center (system info / keybinds / actions) ─────────────
    function controlCenterHelperCommand(action, args) {
        return scriptCmd("qs-controlcenter", action, args)
    }

    // ── Lock screen (i3lock) ──────────────────────────────────────────
    function lockHelperCommand() {
        return bashCmd("qs-lock")
    }

    // ── System Health (stub — not yet implemented) ─────────────────────
    function systemHealthHelperCommand(action, args) {
        return ["sh", "-c", "exit 0"]
    }
}
