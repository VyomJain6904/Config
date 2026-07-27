import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property bool visible: false
    property bool loading: false
    property var events: []
    property var eventsByDate: ({})
    property int requestedMonth: new Date().getMonth() + 1
    property int requestedYear: new Date().getFullYear()
    property string requestedKey: requestedYear + "-" + requestedMonth.toString().padStart(2, "0")
    property string displayedKey: ""
    property string freshKey: ""
    property bool cacheQueued: false
    property bool refreshQueued: false

    function open() {
        root.visible = true;
        root.refreshEvents();
    }

    function close() {
        root.visible = false;
    }

    function refreshEvents() {
        const now = new Date();
        root.refreshEventsForMonth(now.getMonth() + 1, now.getFullYear());
    }

    function refreshEventsForMonth(month, year) {
        const normalizedMonth = Math.max(1, Math.min(12, Number(month)));
        const normalizedYear = Number(year);
        const nextKey = normalizedYear + "-" + normalizedMonth.toString().padStart(2, "0");

        root.requestedMonth = normalizedMonth;
        root.requestedYear = normalizedYear;
        if (root.displayedKey !== nextKey) {
            root.applyEvents([], nextKey);
        }
        root.startCacheRead();
        root.startNetworkRefresh();
    }

    function applyEvents(parsed, key) {
        if (key !== root.requestedKey) {
            return;
        }

        const byDate = {};
        for (let i = 0; i < parsed.length; i++) {
            const ev = parsed[i];
            if (!ev.date) {
                continue;
            }
            if (!byDate[ev.date]) {
                byDate[ev.date] = [];
            }
            byDate[ev.date].push(ev);
        }
        root.events = parsed;
        root.eventsByDate = byDate;
        root.displayedKey = key;
    }

    function parseEvents(text, key) {
        const value = text.trim();
        if (value.length === 0 || key !== root.requestedKey) {
            return;
        }

        try {
            const parsed = JSON.parse(value);
            if (!Array.isArray(parsed)) {
                throw new Error("expected an array");
            }
            root.applyEvents(parsed, key);
        } catch (e) {
            console.warn("Failed to parse calendar events JSON: " + e);
        }
    }

    function startCacheRead() {
        if (cacheProcess.running) {
            root.cacheQueued = true;
            return;
        }
        root.cacheQueued = false;
        cacheProcess.requestKey = root.requestedKey;
        cacheProcess.command = Commands.calendarHelperCommand("cached", [
            root.requestedMonth.toString(),
            root.requestedYear.toString()
        ]);
        cacheProcess.running = true;
    }

    function startNetworkRefresh() {
        if (eventsProcess.running) {
            root.refreshQueued = true;
            return;
        }
        root.refreshQueued = false;
        root.loading = true;
        eventsProcess.requestKey = root.requestedKey;
        eventsProcess.command = Commands.calendarHelperCommand("events", [
            root.requestedMonth.toString(),
            root.requestedYear.toString()
        ]);
        eventsProcess.running = true;
    }

    Process {
        id: cacheProcess

        property string requestKey: ""

        running: false

        onRunningChanged: {
            if (!running && root.cacheQueued) {
                root.startCacheRead();
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (root.freshKey !== cacheProcess.requestKey) {
                    root.parseEvents(this.text, cacheProcess.requestKey);
                }
            }
        }
    }

    Process {
        id: eventsProcess

        property string requestKey: ""

        running: false

        onRunningChanged: {
            if (!running) {
                if (eventsProcess.requestKey === root.requestedKey) {
                    root.loading = false;
                }
                if (root.refreshQueued) {
                    root.startNetworkRefresh();
                }
            }
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (eventsProcess.requestKey === root.requestedKey) {
                    root.parseEvents(this.text, eventsProcess.requestKey);
                    root.freshKey = eventsProcess.requestKey;
                }
            }
        }
    }
}
