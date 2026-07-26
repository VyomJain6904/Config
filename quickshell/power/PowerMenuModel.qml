import Quickshell
import Quickshell.Io
import qs.core

Scope {
    id: root

    property bool visible: false
    property bool confirming: false
    property var pendingAction: null
    property int selectedActionIndex: 0
    property int selectedConfirmIndex: 0

    readonly property var sessionActions: [
        {
            "id": "reboot",
            "label": "Reboot",
            "detail": "Restart this system",
            "command": ["systemctl", "reboot"],
            "confirm": true
        },
        {
            "id": "logout",
            "label": "Log Out",
            "detail": "End the current session",
            "command": ["sh", "-c", "i3-msg exit"],
            "confirm": true
        },
        {
            "id": "lock",
            "label": "Lock",
            "detail": "Secure this session",
            "command": Commands.lockHelperCommand(),
            "confirm": false
        },
        {
            "id": "shutdown",
            "label": "Shutdown",
            "detail": "Power off this system",
            "command": ["systemctl", "poweroff"],
            "confirm": true
        }
    ]

    function open() {
        root.visible = true;
        root.confirming = false;
        root.pendingAction = null;
        root.selectedActionIndex = 0;
        root.selectedConfirmIndex = 0;
    }

    function close() {
        root.visible = false;
        root.confirming = false;
        root.pendingAction = null;
        root.selectedActionIndex = 0;
        root.selectedConfirmIndex = 0;
    }

    function moveSelection(delta) {
        if (root.confirming) {
            root.selectedConfirmIndex = root.selectedConfirmIndex === 0 ? 1 : 0;
            return;
        }

        const count = root.sessionActions.length;
        if (count === 0) {
            root.selectedActionIndex = 0;
            return;
        }

        root.selectedActionIndex = (root.selectedActionIndex + delta + count) % count;
    }

    function activateSelected() {
        if (root.confirming) {
            if (root.selectedConfirmIndex === 0) {
                root.cancelConfirmation();
            } else {
                root.confirmAction();
            }
            return;
        }

        if (root.selectedActionIndex >= 0 && root.selectedActionIndex < root.sessionActions.length) {
            root.requestAction(root.sessionActions[root.selectedActionIndex]);
        }
    }

    function toggle() {
        if (root.visible) {
            root.close();
        } else {
            root.open();
        }
    }

    function requestAction(action) {
        if (!action) {
            return;
        }

        if (action.confirm) {
            root.pendingAction = action;
            root.confirming = true;
            root.selectedConfirmIndex = 0;
            return;
        }

        root.runAction(action);
    }

    function cancelConfirmation() {
        root.confirming = false;
        root.pendingAction = null;
        root.selectedConfirmIndex = 0;
    }

    function confirmAction() {
        if (!root.pendingAction) {
            root.cancelConfirmation();
            return;
        }

        root.runAction(root.pendingAction);
    }

    function runAction(action) {
        if (!action || !action.command || action.command.length === 0) {
            return;
        }

        actionProcess.command = action.command;
        actionProcess.running = true;
        root.close();
    }

    Process {
        id: actionProcess

        running: false
    }
}
