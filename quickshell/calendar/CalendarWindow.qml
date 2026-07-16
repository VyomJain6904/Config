pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

PopupWindow {
    id: root

    required property var calendarModel
    required property var panelWindow

    readonly property int popupWidth: 450
    readonly property int popupHeight: 520
    readonly property int edgeMargin: Theme.rowSpacing

    visible: calendarModel.visible
    implicitWidth: popupWidth
    implicitHeight: popupHeight
    anchor.window: panelWindow
    anchor.rect.x: (panelWindow.width - popupWidth) / 2
    anchor.rect.y: 0
    grabFocus: true
    color: Theme.transparent

    onVisibleChanged: if (!visible) root.calendarModel.close()

    property date currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()

    function updateMonth(offset) {
        let m = currentMonth + offset;
        let y = currentYear;
        if (m < 0) {
            m = 11;
            y--;
        } else if (m > 11) {
            m = 0;
            y++;
        }
        currentMonth = m;
        currentYear = y;
        generateDays();
    }

    property var days: []

    function generateDays() {
        let firstDay = new Date(currentYear, currentMonth, 1).getDay();
        let daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate();
        let newDays = [];

        for (let i = 0; i < firstDay; i++) {
            newDays.push(0);
        }
        for (let i = 1; i <= daysInMonth; i++) {
            newDays.push(i);
        }
        root.days = newDays;
    }

    Component.onCompleted: {
        generateDays();
    }

    ShellSurface {
        id: content

        Connections {
            target: root._backingWindow
            function onActiveChanged() {
                if (!root._backingWindow.active) {
                    root.calendarModel.close();
                }
            }
        }

        anchors.fill: parent
        anchors.bottomMargin: 12
        focus: true

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.calendarModel.close();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: Theme.popupSpacing

            // Title Row
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.rowSpacing

                ShellButton {
                    label: "<<"
                    Layout.preferredWidth: implicitWidth
                    onActivated: root.updateMonth(-12)
                }

                ShellButton {
                    label: "<"
                    Layout.preferredWidth: implicitWidth
                    onActivated: root.updateMonth(-1)
                }

                UiText {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.formatDateTime(new Date(root.currentYear, root.currentMonth, 1), "MMMM yyyy")
                    color: Theme.textStrong
                    font.pixelSize: Theme.titleFontSize
                    font.bold: true
                }

                ShellButton {
                    label: ">"
                    Layout.preferredWidth: implicitWidth
                    onActivated: root.updateMonth(1)
                }

                ShellButton {
                    label: ">>"
                    Layout.preferredWidth: implicitWidth
                    onActivated: root.updateMonth(12)
                }

                ShellButton {
                    label: "Today"
                    Layout.preferredWidth: implicitWidth
                    onActivated: {
                        root.currentMonth = root.currentDate.getMonth()
                        root.currentYear = root.currentDate.getFullYear()
                        root.generateDays()
                    }
                }

                UiText {
                    text: "x"
                    color: closeMouse.containsMouse ? Theme.accent : Theme.textMuted
                    font.pixelSize: Theme.titleFontSize
                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarModel.close()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.border }

            // Weekdays Row
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                Repeater {
                    model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                    delegate: UiText {
                        required property string modelData
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        color: Theme.textMuted
                        font.bold: true
                    }
                }
            }

            // Calendar Grid
            GridLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                columns: 7
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: root.days
                    delegate: Rectangle {
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 50
                        Layout.minimumWidth: 50
                        color: Theme.transparent
                        
                        property bool isToday: modelData !== 0 && 
                                               modelData === root.currentDate.getDate() && 
                                               root.currentMonth === root.currentDate.getMonth() && 
                                               root.currentYear === root.currentDate.getFullYear()

                        Rectangle {
                            anchors.centerIn: parent
                            width: Math.min(parent.width, parent.height)
                            height: width
                            radius: width / 2
                            color: isToday ? Theme.accent : Theme.transparent
                            
                            UiText {
                                anchors.centerIn: parent
                                text: modelData === 0 ? "" : modelData
                                color: isToday ? Theme.surface : Theme.textStrong
                                font.bold: isToday
                            }
                        }
                    }
                }
            }
        }
    }
}
