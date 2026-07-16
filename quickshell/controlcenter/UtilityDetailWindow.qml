import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.core

pragma ComponentBehavior: Bound

FloatingWindow {
    id: root

    required property var controlCenterModel

    visible: controlCenterModel.utilityVisible
    implicitWidth: 680
    implicitHeight: 500
    color: Theme.transparent
    // The prefix keeps this window compatible with preserved user rules that
    // already float the dwm control center by title substring.
    title: "Quickshell Utility"

    function titleForPage() {
        if (controlCenterModel.utilityPage === "keybinds") return "Keybinds";
        return "System Info";
    }

    function rowsForPage() {
        if (controlCenterModel.utilityPage === "keybinds") return controlCenterModel.keybindRows;
        return controlCenterModel.infoRows;
    }

    property string searchQuery: ""

    function filteredRowsForPage() {
        const allRows = rowsForPage();
        if (searchQuery.length === 0) return allRows;
        const q = searchQuery.toLowerCase();
        return allRows.filter(row => {
            const t = root.controlCenterModel.utilityPage === "keybinds" ? row.keys : (row.label || "");
            const d = root.controlCenterModel.utilityPage === "keybinds" ? row.description : (row.detail || row.value || "");
            return t.toLowerCase().indexOf(q) !== -1 || d.toLowerCase().indexOf(q) !== -1;
        });
    }

    ShellSurface {
        anchors.fill: parent
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.controlCenterModel.closeUtility();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            RowLayout {
                Layout.fillWidth: true
                UiText {
                    Layout.fillWidth: true
                    text: root.titleForPage()
                    color: Theme.textStrong
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                }
                ShellButton {
                    label: "Close"
                    onActivated: root.controlCenterModel.closeUtility()
                }
            }

            TextField {
                Layout.fillWidth: true
                placeholderText: "Search keybinds..."
                color: Theme.text
                placeholderTextColor: Theme.placeholder
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                background: Rectangle {
                    color: Theme.surface
                    border.color: Theme.border
                    border.width: 1
                    radius: Theme.radius
                }
                padding: 10
                text: root.searchQuery
                onTextEdited: root.searchQuery = text
                
                // Clear search when window closes
                Connections {
                    target: root.controlCenterModel
                    function onUtilityVisibleChanged() {
                        if (!root.controlCenterModel.utilityVisible) {
                            root.searchQuery = "";
                        }
                    }
                }
            }

            UiText {
                Layout.fillWidth: true
                visible: root.controlCenterModel.message.length > 0
                text: root.controlCenterModel.message
                color: Theme.textMuted
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: Theme.listSpacing
                model: root.filteredRowsForPage()
                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: ControlCenterRow {
                    required property var modelData
                    width: ListView.view.width
                    title: root.controlCenterModel.utilityPage === "keybinds" ? modelData.keys : (modelData.label || "")
                    detail: root.controlCenterModel.utilityPage === "keybinds" ? modelData.description : (modelData.detail || modelData.value || "")
                    status: modelData.status || ""
                    iconName: modelData.icon || ""
                }
            }
        }
    }
}
