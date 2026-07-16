import QtQuick
import Quickshell
import qs.core

Scope {
    id: root

    property bool visible: false

    function open() {
        root.visible = true;
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
}
