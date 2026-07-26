pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core

FloatingWindow {
    id: root

    required property var calendarModel

    readonly property int popupWidth: 460
    readonly property int popupHeight: 580

    visible: calendarModel.visible
    implicitWidth: popupWidth
    implicitHeight: popupHeight
    title: "Quickshell Utility"
    color: Theme.transparent

    property int selectedDay: currentDate.getDate()

    function getDateString(day) {
        if (day === 0)
            return "";
        const m = (root.currentMonth + 1).toString().padStart(2, '0');
        const d = day.toString().padStart(2, '0');
        return root.currentYear + "-" + m + "-" + d;
    }

    onVisibleChanged: {
        if (visible) {
            currentDate = new Date();
            currentMonth = currentDate.getMonth();
            currentYear = currentDate.getFullYear();
            selectedDay = currentDate.getDate();
            generateDays();
            content.forceActiveFocus();
        } else {
            root.calendarModel.close();
        }
    }

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
        selectedDay = 0;
        generateDays();
        if (root.calendarModel && root.calendarModel.refreshEventsForMonth) {
            root.calendarModel.refreshEventsForMonth(currentMonth + 1, currentYear);
        }
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

        anchors.fill: parent
        anchors.bottomMargin: 12
        focus: true

        Keys.onPressed: function (event) {
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
                    Layout.preferredWidth: 32
                    onActivated: root.updateMonth(-12)
                }

                ShellButton {
                    label: "<"
                    Layout.preferredWidth: 32
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
                    Layout.preferredWidth: 32
                    onActivated: root.updateMonth(1)
                }

                ShellButton {
                    label: ">>"
                    Layout.preferredWidth: 32
                    onActivated: root.updateMonth(12)
                }

                ShellButton {
                    label: "Today"
                    Layout.preferredWidth: implicitWidth
                    onActivated: {
                        root.currentMonth = root.currentDate.getMonth();
                        root.currentYear = root.currentDate.getFullYear();
                        root.selectedDay = root.currentDate.getDate();
                        root.generateDays();
                    }
                }

                Item {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20

                    UiText {
                        anchors.centerIn: parent
                        text: "x"
                        color: closeMouse.containsMouse ? Theme.accent : Theme.textMuted
                        font.pixelSize: Theme.titleFontSize
                        font.bold: true
                    }

                    MouseArea {
                        id: closeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.calendarModel.close()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

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
                columns: 7
                columnSpacing: 4
                rowSpacing: 4

                Repeater {
                    model: root.days
                    delegate: Rectangle {
                        required property int modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        color: Theme.transparent

                        property string dateStr: root.getDateString(modelData)
                        property var dayEvents: dateStr.length > 0 && root.calendarModel.eventsByDate ? (root.calendarModel.eventsByDate[dateStr] || []) : []
                        property bool hasEvents: dayEvents.length > 0
                        property bool isSelected: modelData !== 0 && modelData === root.selectedDay
                        property bool isToday: modelData !== 0 && modelData === root.currentDate.getDate() && root.currentMonth === root.currentDate.getMonth() && root.currentYear === root.currentDate.getFullYear()
                        property bool hasHoliday: dayEvents.some(function(e) { return e.is_holiday; })

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36
                            height: 36
                            radius: 18
                            color: isToday ? Theme.accent : (isSelected ? Theme.surfaceHover : Theme.transparent)
                            border.color: isSelected && !isToday ? Theme.accent : "transparent"
                            border.width: 1

                            UiText {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: (hasEvents && modelData !== 0) ? -3 : 0
                                text: modelData === 0 ? "" : modelData
                                color: isToday ? Theme.surface : Theme.textStrong
                                font.bold: isToday || isSelected
                                font.pixelSize: Theme.smallFontSize
                            }

                            Rectangle {
                                visible: hasEvents && modelData !== 0
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 4
                                width: 4
                                height: 4
                                radius: 2
                                color: isToday ? Theme.surface : (hasHoliday ? Theme.danger : Theme.success)
                            }

                            MouseArea {
                                anchors.fill: parent
                                enabled: modelData !== 0
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.selectedDay = modelData
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: Theme.border
            }

            // Events List Section
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                UiText {
                    text: root.selectedDay > 0 ? "Events for " + root.getDateString(root.selectedDay) : "Upcoming Events"
                    color: Theme.textStrong
                    font.bold: true
                    font.pixelSize: Theme.smallFontSize
                }

                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6

                    model: {
                        if (root.selectedDay > 0) {
                            const dateStr = root.getDateString(root.selectedDay);
                            if (dateStr && root.calendarModel.eventsByDate && root.calendarModel.eventsByDate[dateStr]) {
                                return root.calendarModel.eventsByDate[dateStr];
                            }
                            return [];
                        }
                        const mStr = (root.currentMonth + 1).toString().padStart(2, '0');
                        const prefix = root.currentYear + "-" + mStr + "-";
                        const allEvents = root.calendarModel.events || [];
                        const filtered = [];
                        for (let i = 0; i < allEvents.length; i++) {
                            if (allEvents[i].date && allEvents[i].date.startsWith(prefix)) {
                                filtered.push(allEvents[i]);
                            }
                        }
                        return filtered;
                    }

                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        implicitHeight: eventCol.implicitHeight + 14
                        color: modelData.is_holiday ? Theme.surfaceHover : Theme.surface
                        border.color: modelData.is_holiday ? Theme.borderStrong : Theme.border
                        border.width: modelData.is_holiday ? 1 : 0
                        radius: Theme.smallRadius

                        ColumnLayout {
                            id: eventCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            anchors.topMargin: 7
                            spacing: 3

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8

                                UiText {
                                    Layout.fillWidth: true
                                    text: modelData.summary || "Untitled Event"
                                    color: Theme.textStrong
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                UiText {
                                    text: (modelData.is_holiday ? "Holiday " : "") + ((modelData.time && modelData.time.length > 0) ? modelData.time : "All Day")
                                    color: modelData.is_holiday ? Theme.danger : Theme.accent
                                    font.pixelSize: Theme.tinyFontSize
                                    font.bold: true
                                }
                            }

                        }
                    }

                    UiText {
                        anchors.centerIn: parent
                        visible: parent.count === 0
                        text: "No events scheduled"
                        color: Theme.textMuted
                        font.pixelSize: Theme.smallFontSize
                    }
                }
            }
        }
    }
}
