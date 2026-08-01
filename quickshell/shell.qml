//@ pragma UseQApplication

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.calendar
import qs.controls
import qs.network
import qs.vpn
import qs.panel
import qs.power
import qs.state
import qs.spotlight
import qs.ai

ShellRoot {
    FontLoader {
        id: vpnFont
        source: "file:///home/jain/.local/share/fonts/JetBrainsMono-VPN.ttf"
    }

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

    VpnModel {
        id: vpnModel
    }

    AiModel {
        id: aiModel
    }

    SpotlightModel {
        id: spotlightModel
    }

    // ── IPC Handlers ──────────────────────────────────────────────────

    IpcHandler {
        target: "menu"

        function close(): void {
            networkModel.close();
            controlsModel.close();
            vpnModel.close();
            calendarModel.close();
            aiModel.close();
        }

        function open(): void {
            networkModel.open();
        }

        function toggle(): void {
            if (networkModel.visible || controlsModel.visible || vpnModel.visible || calendarModel.visible || aiModel.visible) {
                networkModel.close();
                controlsModel.close();
                vpnModel.close();
                calendarModel.close();
                aiModel.close();
            } else {
                networkModel.open();
            }
        }
    }

    IpcHandler {
        target: "spotlight"

        function close(): void {
            spotlightModel.close();
        }

        function open(): void {
            spotlightModel.open();
        }

        function toggle(): void {
            spotlightModel.toggle();
        }
    }

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
        target: "calendar"

        function open(): void {
            calendarModel.open();
        }

        function close(): void {
            calendarModel.close();
        }

        function toggle(): void {
            calendarModel.toggle();
        }
    }

    IpcHandler {
        target: "ai"

        function open(): void {
            aiModel.open();
        }

        function close(): void {
            aiModel.close();
        }

        function toggle(): void {
            aiModel.toggle();
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

    // ── Multi-monitor panel: one I3Panel per screen ──────────────────
    Variants {
        model: Quickshell.screens

        delegate: I3Panel {
            required property var modelData

            screen: modelData
            state: i3State
            clock: clock
            vpnFontFamily: vpnFont.name
            networkModel: networkModel
            controlsModel: controlsModel
            powerMenuModel: powerMenuModel
            calendarModel: calendarModel
            vpnModel: vpnModel
        }
    }

    // ── Global windows ────────────────────────────────────────────────

    PowerMenuWindow {
        powerMenuModel: powerMenuModel
    }

    SpotlightWindow {
        spotlightModel: spotlightModel
    }

    LazyLoader {
        active: networkModel.visible || controlsModel.visible || vpnModel.visible || calendarModel.visible || aiModel.visible

        component: UtilityWindow {
            networkModel: networkModel
            bluetoothModel: bluetoothModel
            controlsModel: controlsModel
            vpnModel: vpnModel
            calendarModel: calendarModel
            aiModel: aiModel
            i3State: i3State
            vpnFontFamily: vpnFont.name
        }
    }
}
