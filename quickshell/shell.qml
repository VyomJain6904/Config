//@ pragma UseQApplication

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.controlcenter
import qs.calendar
import qs.controls
import qs.network
import qs.vpn
import qs.panel
import qs.power
import qs.state

ShellRoot {
    id: root

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    I3State {
        id: i3State
    }

    PowerMenuModel {
        id: powerMenuModel
    }

    CalendarModel {
        id: calendarModel
    }

    NetworkModel {
        id: networkModel
    }

    ControlsModel {
        id: controlsModel
    }

    BluetoothModel {
        id: bluetoothModel
    }

    ControlCenterModel {
        id: controlCenterModel
    }

    VpnModel {
        id: vpnModel
    }

    LazyLoader {
        active: true

        component: Item {
            Component.onCompleted: {
                networkModel.refresh();
                controlsModel.refresh();
            }
        }
    }

    // ── IPC Handlers ──────────────────────────────────────────────────

    IpcHandler {
        target: "power"

        function close(): void {
            powerMenuModel.close();
        }

        function open(): void {
            powerMenuModel.open();
        }

        function toggle(): void {
            powerMenuModel.toggle();
        }
    }

    IpcHandler {
        target: "network"

        function close(): void {
            networkModel.close();
        }

        function open(): void {
            networkModel.open();
        }

        function refresh(): void {
            networkModel.refresh();
        }

        function status(): string {
            return networkModel.statusText;
        }

        function toggle(): void {
            networkModel.toggle();
        }
    }

    IpcHandler {
        target: "controls"

        function close(): void {
            controlsModel.close();
        }

        function bluetoothStatus(): string {
            return controlsModel.bluetoothText;
        }

        function open(): void {
            controlsModel.open();
        }

        function refresh(): void {
            controlsModel.refresh();
        }

        function micStatus(): string {
            return controlsModel.micText;
        }

        function mediaStatus(): string {
            return controlsModel.mediaText;
        }

        function mediaNext(): void {
            controlsModel.mediaNext();
        }

        function mediaPlayPause(): void {
            controlsModel.mediaPlayPause();
        }

        function mediaPrevious(): void {
            controlsModel.mediaPrevious();
        }

        function toggle(): void {
            controlsModel.toggle();
        }

        function volumeDown(): void {
            controlsModel.volumeDown();
        }

        function volumeStatus(): string {
            return controlsModel.volumeDisplayText;
        }

        function volumeSet(percent: int): void {
            controlsModel.volumeSet(percent);
        }

        function volumeToggleMute(): void {
            controlsModel.volumeToggleMute();
        }

        function volumeUp(): void {
            controlsModel.volumeUp();
        }
    }

    IpcHandler {
        target: "controlcenter"

        function close(): void {
            controlCenterModel.close();
        }

        function open(): void {
            controlCenterModel.open();
        }

        function openKeybinds(): void {
            controlCenterModel.openKeybinds();
        }

        function openInfo(): void {
            controlCenterModel.openInfo();
        }

        function refresh(): void {
            controlCenterModel.refresh();
        }

        function toggle(): void {
            controlCenterModel.toggle();
        }
    }

    IpcHandler {
        target: "vpn"

        function close(): void {
            vpnModel.close();
        }

        function open(): void {
            vpnModel.open();
        }

        function refresh(): void {
            vpnModel.refresh();
        }

        function status(): string {
            return vpnModel.active ? vpnModel.vpnIp : "VPN disconnected";
        }

        function toggle(): void {
            vpnModel.toggle();
        }
    }

    IpcHandler {
        target: "tray"

        function count(): int {
            return SystemTray.items.values.length;
        }

        function ids(): string {
            const items = SystemTray.items.values;
            const ids = [];

            for (let i = 0; i < items.length; i++) {
                ids.push(items[i].id || items[i].title || items[i].tooltipTitle || "unknown");
            }

            return ids.join("\n");
        }

        function details(): string {
            const items = SystemTray.items.values;
            const rows = [];

            for (let i = 0; i < items.length; i++) {
                const item = items[i];
                rows.push([item.id || "unknown", item.title || "", item.icon || "", item.hasMenu ? "menu" : "no-menu", item.status || ""].join("\t"));
            }

            return rows.join("\n");
        }
    }

    // ── Primary panel reference (used by popups for anchoring) ────────
    // The first panel in the Variants list acts as the anchor for all popups.
    property var primaryPanel: null

    // ── Multi-monitor panel: one I3Panel per screen ──────────────────
    Variants {
        model: Quickshell.screens

        delegate: I3Panel {
            id: panelInstance
            required property var modelData

            screen: modelData
            state: i3State
            clock: clock
            networkModel: networkModel
            controlsModel: controlsModel
            bluetoothModel: bluetoothModel
            controlCenterModel: controlCenterModel
            powerMenuModel: powerMenuModel
            calendarModel: calendarModel
            vpnModel: vpnModel

            Component.onCompleted: {
                // Use the primary screen's panel as the popup anchor
                if (!root.primaryPanel || modelData === Quickshell.screens[0]) {
                    root.primaryPanel = panelInstance;
                }
            }
        }
    }

    // ── Global windows (popups) — anchored to primary screen panel ────

    PowerMenuWindow {
        powerMenuModel: powerMenuModel
    }

    CalendarWindow {
        calendarModel: calendarModel
        panelWindow: root.primaryPanel
    }

    UtilityWindow {
        networkModel: networkModel
        bluetoothModel: bluetoothModel
        controlsModel: controlsModel
        vpnModel: vpnModel
    }

    ControlCenterWindow {
        controlCenterModel: controlCenterModel
        panelWindow: root.primaryPanel
        powerMenuModel: powerMenuModel
    }

    UtilityDetailWindow {
        controlCenterModel: controlCenterModel
    }
}
