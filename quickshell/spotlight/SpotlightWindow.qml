pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import QtQuick.Controls
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                SPOTLIGHT LAUNCHER WINDOW (SpotlightWindow.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Modern floating search overlay with a responsive 4-column application icon
 * grid, intelligent auto-scroll alignment, and keyboard shortcuts.
 * ─────────────────────────────────────────────────────────────────────────────
 */
FloatingWindow {
    id: root

    required property var spotlightModel

    visible: spotlightModel.visible
    implicitWidth: 620
    implicitHeight: 472
    title: "Quickshell Spotlight"
    color: Theme.transparent

    onVisibleChanged: {
        if (visible) {
            searchInput.forceActiveFocus();
        } else {
            root.spotlightModel.close();
        }
    }

    // =========================================================================
    // 1. PRIMARY WINDOW CONTAINER & SEARCH BAR
    // =========================================================================

    Rectangle {
        anchors.fill: parent
        color: "#ee111111"
        border.color: "#1affffff"
        border.width: 1
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Search Input Bar (inputbar)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 56

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 14
                    anchors.bottomMargin: 14
                    spacing: 12

                    Text {
                        text: "󰍉"
                        color: "#cccccc"
                        font.family: Theme.fontFamily
                        font.pixelSize: 18
                        verticalAlignment: Text.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: "Applications"
                            color: "#555555"
                            font: searchInput.font
                            visible: searchInput.text.length === 0 && !searchInput.preeditText
                        }

                        TextInput {
                            id: searchInput
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            color: "#e8e8e8"
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            selectByMouse: true
                            clip: true
                            focus: true

                            onTextChanged: {
                                root.spotlightModel.query = text;
                                gridFlickable.contentY = 0;
                            }

                            Keys.onPressed: function (event) {
                                if (event.key === Qt.Key_Escape) {
                                    root.spotlightModel.close();
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Down) {
                                    root.spotlightModel.moveSelection(4);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Up) {
                                    root.spotlightModel.moveSelection(-4);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) {
                                    root.spotlightModel.moveSelection(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Tab) {
                                    root.spotlightModel.moveSelection(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Right && searchInput.cursorPosition === searchInput.text.length && root.spotlightModel.filteredApps.length > 1) {
                                    root.spotlightModel.moveSelection(1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Left && searchInput.cursorPosition === 0 && root.spotlightModel.selectedIndex > 0) {
                                    root.spotlightModel.moveSelection(-1);
                                    event.accepted = true;
                                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                    root.spotlightModel.activateSelected();
                                    event.accepted = true;
                                }
                            }
                        }
                    }
                }
            }

            // 1px Separation Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: "#12ffffff"
            }

            // =================================================================
            // 2. APPLICATION GRID VIEWPORT & SCROLLING
            // =================================================================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Flickable {
                    id: gridFlickable
                    anchors.fill: parent
                    anchors.margins: 16
                    clip: true
                    contentWidth: width
                    contentHeight: appGrid.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    GridLayout {
                        id: appGrid
                        width: gridFlickable.width
                        columns: 4
                        rowSpacing: 10
                        columnSpacing: 10

                        Repeater {
                            model: root.spotlightModel.filteredApps

                            delegate: Rectangle {
                                required property var modelData
                                required property int index

                                Layout.preferredWidth: Math.floor((appGrid.width - (3 * 10)) / 4)
                                Layout.preferredHeight: 88
                                color: (index === root.spotlightModel.selectedIndex || cardArea.containsMouse) ? "#18ffffff" : "transparent"
                                radius: 4

                                property bool isSelected: index === root.spotlightModel.selectedIndex

                                onIsSelectedChanged: {
                                    if (isSelected && gridFlickable.contentHeight > gridFlickable.height) {
                                        const itemTop = y;
                                        const itemBottom = y + height;
                                        if (itemTop < gridFlickable.contentY) {
                                            gridFlickable.contentY = itemTop;
                                        } else if (itemBottom > gridFlickable.contentY + gridFlickable.height) {
                                            gridFlickable.contentY = Math.min(gridFlickable.contentHeight - gridFlickable.height, itemBottom - gridFlickable.height);
                                        }
                                    }
                                }

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    width: parent.width - 12

                                    IconImage {
                                        Layout.alignment: Qt.AlignHCenter
                                        width: 48
                                        height: 48
                                        source: modelData.icon.indexOf("file://") === 0 ? modelData.icon : ("file://" + modelData.icon)
                                        implicitSize: 48
                                        asynchronous: true
                                        mipmap: true
                                    }

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: (index === root.spotlightModel.selectedIndex || cardArea.containsMouse) ? "#ffffff" : "#cccccc"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                        font.bold: (index === root.spotlightModel.selectedIndex || cardArea.containsMouse)
                                        horizontalAlignment: Text.AlignHCenter
                                        elide: Text.ElideRight
                                    }
                                }

                                MouseArea {
                                    id: cardArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor

                                    onEntered: {
                                        root.spotlightModel.selectedIndex = index;
                                    }

                                    onClicked: {
                                        root.spotlightModel.activate(modelData);
                                    }
                                }
                            }
                        }

                        // No applications placeholder
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            visible: root.spotlightModel.filteredApps.length === 0
                            Layout.columnSpan: 4

                            Text {
                                anchors.centerIn: parent
                                text: "No applications found"
                                color: "#555555"
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }
                        }

                        // Spacer item to preserve consistent grid height when results are few
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.columnSpan: 4
                            visible: root.spotlightModel.filteredApps.length > 0 && root.spotlightModel.filteredApps.length < 13
                        }
                    }
                }
            }
        }
    }
}
