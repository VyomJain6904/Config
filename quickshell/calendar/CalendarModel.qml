import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property bool visible: false
    property var events: []
    property var eventsByDate: ({})

    function open() {
        root.visible = true;
        root.refreshEvents();
    }

    function close() {
        root.visible = false;
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function refreshEvents() {
        eventsProcess.running = false;
        eventsProcess.command = Commands.calendarHelperCommand("events");
        eventsProcess.running = true;
    }

    function refreshEventsForMonth(month, year) {
        eventsProcess.running = false;
        eventsProcess.command = Commands.calendarHelperCommand("events", [month.toString(), year.toString()]);
        eventsProcess.running = true;
    }

    Process {
        id: eventsProcess

        command: Commands.calendarHelperCommand("events")
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    root.events = parsed;
                    const byDate = {};
                    for (let i = 0; i < parsed.length; i++) {
                        const ev = parsed[i];
                        if (ev.date) {
                            if (!byDate[ev.date]) {
                                byDate[ev.date] = [];
                            }
                            byDate[ev.date].push(ev);
                        }
                    }
                    root.eventsByDate = byDate;
                } catch (e) {
                    console.warn("Failed to parse calendar events JSON: " + e);
                }
            }
        }
    }
}
