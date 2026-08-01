import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property bool visible: false
    property var allApps: []
    property var filteredApps: []
    property string query: ""
    property int selectedIndex: 0

    function open() {
        root.query = "";
        root.selectedIndex = 0;
        root.visible = true;
        if (root.allApps.length === 0 || !listProcess.running) {
            listProcess.running = true;
        } else {
            root.updateFilter();
        }
    }

    function close() {
        root.visible = false;
        root.query = "";
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    onQueryChanged: {
        root.selectedIndex = 0;
        root.updateFilter();
    }

    function updateFilter() {
        const trimmed = root.query.trim().toLowerCase();
        if (trimmed.length === 0) {
            root.filteredApps = root.allApps;
            if (root.selectedIndex >= root.filteredApps.length) {
                root.selectedIndex = Math.max(0, root.filteredApps.length - 1);
            }
            return;
        }

        const terms = trimmed.split(/\s+/);
        const matches = [];

        for (let i = 0; i < root.allApps.length; i++) {
            const app = root.allApps[i];
            let allMatched = true;
            for (let j = 0; j < terms.length; j++) {
                if (app.metadata.indexOf(terms[j]) === -1) {
                    allMatched = false;
                    break;
                }
            }
            if (allMatched) {
                matches.push(app);
            }
        }

        root.filteredApps = matches;
        if (root.selectedIndex >= root.filteredApps.length) {
            root.selectedIndex = Math.max(0, root.filteredApps.length - 1);
        }
    }

    function moveSelection(delta) {
        const count = root.filteredApps.length;
        if (count === 0) {
            root.selectedIndex = 0;
            return;
        }
        let next = root.selectedIndex + delta;
        if (next < 0) {
            next = 0;
        } else if (next >= count) {
            next = count - 1;
        }
        root.selectedIndex = next;
    }

    function activateSelected() {
        if (root.filteredApps.length > root.selectedIndex && root.selectedIndex >= 0) {
            root.activate(root.filteredApps[root.selectedIndex]);
        }
    }

    function activate(app) {
        if (!app)
            return;
        launchProcess.command = Commands.launcherHelperCommand("launch", [app.exec, app.terminal]);
        launchProcess.running = true;
        root.close();
    }

    Process {
        id: listProcess
        command: Commands.launcherHelperCommand("list", [])
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.parseApps(this.text)
        }
    }

    Process {
        id: launchProcess
        command: []
    }

    function parseApps(text) {
        const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
        const items = [];

        for (let i = 0; i < lines.length; i++) {
            const fields = lines[i].split("\t");
            if (fields.length < 6)
                continue;

            items.push({
                "name": fields[0],
                "icon": fields[1],
                "exec": fields[2],
                "terminal": fields[3],
                "metadata": fields[4],
                "id": fields[5]
            });
        }

        root.allApps = items;
        root.updateFilter();
    }
}
