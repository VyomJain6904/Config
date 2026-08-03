import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                    SYSTEM TRAY CONTAINER (TrayArea.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Renders active system tray applet items in a horizontal line while filtering
 * out custom hidden applications (e.g. Flameshot).
 * ─────────────────────────────────────────────────────────────────────────────
 */
RowLayout {
    visible: SystemTray.items.values.length > 0
    spacing: Theme.compactSpacing
    Layout.alignment: Qt.AlignVCenter

    Repeater {
        model: SystemTray.items.values

        delegate: TrayItem {
            required property var modelData

            trayItem: modelData
            // Automatically exclude Flameshot icon to avoid redundant tray clutter
            visible: (modelData.id || "").toLowerCase().indexOf("flameshot") === -1 && (modelData.title || "").toLowerCase().indexOf("flameshot") === -1
        }
    }
}
