//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.controlcenter
import qs.calendar
import qs.controls
import qs.health
import qs.network
import qs.notifications
import qs.panel
import qs.power
import qs.state

pragma ComponentBehavior: Bound

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

    SystemHealthModel {
        id: systemHealthModel
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

    NotificationModel {
        id: notificationModel
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
        target: "notifications"

        function clear(): void {
            notificationModel.clear();
        }

        function count(): int {
            return notificationModel.notifications.length;
        }

        function clearHistory(): void {
            notificationModel.clearHistory();
        }

        function closeHistory(): void {
            notificationModel.closeHistory();
        }

        function historyCount(): int {
            return notificationModel.history.length;
        }

        function historyLatestSummary(): string {
            return notificationModel.historyLatestSummary();
        }

        function openHistory(): void {
            notificationModel.openHistory();
        }

        function toggleHistory(): void {
            notificationModel.toggleHistory();
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

        function refresh(): void {
            controlCenterModel.refresh();
        }

        function toggle(): void {
            controlCenterModel.toggle();
        }
    }

    IpcHandler {
        target: "systemhealth"

        function close(): void {
            systemHealthModel.close();
        }

        function open(): void {
            systemHealthModel.openOnScreen(primaryPanel ? primaryPanel.screen : null);
        }

        function refresh(): void {
            systemHealthModel.refresh();
        }

        function toggle(): void {
            if (systemHealthModel.visible) {
                systemHealthModel.close();
            } else {
                systemHealthModel.openOnScreen(primaryPanel ? primaryPanel.screen : null);
            }
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
                rows.push([
                    item.id || "unknown",
                    item.title || "",
                    item.icon || "",
                    item.hasMenu ? "menu" : "no-menu",
                    item.status || ""
                ].join("\t"));
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

            screen:              modelData
            state:               i3State
            clock:               clock
            networkModel:        networkModel
            controlsModel:       controlsModel
            bluetoothModel:      bluetoothModel
            controlCenterModel:  controlCenterModel
            powerMenuModel:      powerMenuModel
            calendarModel:       calendarModel

            Component.onCompleted: {
                // Use the primary screen's panel as the popup anchor
                if (!root.primaryPanel || modelData === Quickshell.screens[0]) {
                    root.primaryPanel = panelInstance
                }
            }
        }
    }

    // ── Global windows (popups) — anchored to primary screen panel ────





    PowerMenuWindow {
        powerMenuModel: powerMenuModel
        panelWindow: root.primaryPanel
    }

    CalendarWindow {
        calendarModel: calendarModel
        panelWindow: root.primaryPanel
    }

    NetworkWindow {
        networkModel: networkModel
        panelWindow: root.primaryPanel
    }

    NotificationPopupWindow {
        notificationModel: notificationModel
        panelWindow: root.primaryPanel
    }

    NotificationHistoryWindow {
        notificationModel: notificationModel
    }

    ControlsWindow {
        controlsModel: controlsModel
        panelWindow: root.primaryPanel
    }

    BluetoothWindow {
        bluetoothModel: bluetoothModel
        panelWindow: root.primaryPanel
    }

    ControlCenterWindow {
        controlCenterModel: controlCenterModel
        panelWindow: root.primaryPanel
        powerMenuModel: powerMenuModel
        healthModel: systemHealthModel
    }

    UtilityDetailWindow {
        controlCenterModel: controlCenterModel
    }

    SystemHealthWindow {
        healthModel: systemHealthModel
        screen: systemHealthModel.targetScreen ? systemHealthModel.targetScreen : (root.primaryPanel ? root.primaryPanel.screen : null)
    }
}
