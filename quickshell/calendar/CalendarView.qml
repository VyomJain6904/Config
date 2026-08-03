import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.core

/**
 * ─────────────────────────────────────────────────────────────────────────────
 *                     CALENDAR VIEW (CalendarView.qml)
 * ─────────────────────────────────────────────────────────────────────────────
 * Interactive calendar month grid and chronological event timeline display.
 * Integrates directly with `CalendarModel` to manage event rendering, dates,
 * holiday tracking, and mouse wheel/click month navigation.
 * ─────────────────────────────────────────────────────────────────────────────
 */
ColumnLayout {
    id: root

    // ── External Model Reference ─────────────────────────────────────────────
    required property var calendarModel

    Layout.fillWidth: true
    Layout.fillHeight: true
    spacing: Theme.popupSpacing

    // ── Date & Calendar State ────────────────────────────────────────────────
    property date currentDate: new Date()
    property int currentMonth: currentDate.getMonth()
    property int currentYear: currentDate.getFullYear()
    property int selectedDay: 0
    property var days: []

    // =========================================================================
    // 1. HELPER FUNCTIONS & FORMATTING
    // =========================================================================

    function getDateString(day) {
        if (day === 0) {
            return "";
        }
        const m = (currentMonth + 1).toString().padStart(2, '0');
        const d = day.toString().padStart(2, '0');
        return currentYear + "-" + m + "-" + d;
    }

    function formatEventBadge(dateStr, timeStr, isHoliday) {
        let datePart = "";
        if (dateStr) {
            const parts = dateStr.split("-");
            if (parts.length === 3) {
                const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
                const mIdx = parseInt(parts[1], 10) - 1;
                const d = parseInt(parts[2], 10);
                if (mIdx >= 0 && mIdx < 12) {
                    datePart = months[mIdx] + " " + d;
                }
            }
        }
        const tYear = currentDate.getFullYear();
        const tMonth = (currentDate.getMonth() + 1).toString().padStart(2, '0');
        const tDay = currentDate.getDate().toString().padStart(2, '0');
        const todayStr = tYear + "-" + tMonth + "-" + tDay;
        if (dateStr === todayStr) {
            datePart = "Today";
        }

        const timePart = (timeStr && timeStr.length > 0) ? timeStr : "All Day";
        if (isHoliday) {
            return (datePart ? datePart + " • " : "") + "Holiday (" + timePart + ")";
        }
        return datePart ? (datePart + " • " + timePart) : timePart;
    }

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
        root.calendarModel.refreshEventsForMonth(currentMonth + 1, currentYear);
    }

    function generateDays() {
        const firstDay = new Date(currentYear, currentMonth, 1).getDay();
        const totalDays = new Date(currentYear, currentMonth + 1, 0).getDate();
        const list = [];
        for (let i = 0; i < firstDay; i++) {
            list.push(0);
        }
        for (let d = 1; d <= totalDays; d++) {
            list.push(d);
        }
        while (list.length % 7 !== 0) {
            list.push(0);
        }
        days = list;
    }

    Component.onCompleted: generateDays()

    // =========================================================================
    // 2. MONTH NAVIGATION HEADER
    // =========================================================================

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
            label: "T"
            Layout.preferredWidth: implicitWidth
            onActivated: {
                root.currentMonth = root.currentDate.getMonth();
                root.currentYear = root.currentDate.getFullYear();
                root.selectedDay = root.currentDate.getDate();
                root.generateDays();
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }

    // ── Weekdays Header ──────────────────────────────────────────────────────
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

    // =========================================================================
    // 3. CALENDAR MONTH GRID CONTAINER
    // =========================================================================

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 230

        GridLayout {
            anchors.fill: parent
            columns: 7
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: root.days
                delegate: Rectangle {
                    required property int modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 34
                    color: Theme.transparent

                    property string dateStr: root.getDateString(modelData)
                    property var dayEvents: dateStr.length > 0 && root.calendarModel.eventsByDate ? (root.calendarModel.eventsByDate[dateStr] || []) : []
                    property bool hasEvents: dayEvents.length > 0
                    property bool isSelected: modelData !== 0 && modelData === root.selectedDay
                    property bool isToday: modelData !== 0 && modelData === root.currentDate.getDate() && root.currentMonth === root.currentDate.getMonth() && root.currentYear === root.currentDate.getFullYear()
                    property bool hasHoliday: dayEvents.some(function (e) {
                        return e.is_holiday;
                    })

                    Rectangle {
                        anchors.centerIn: parent
                        width: 32
                        height: 32
                        radius: 16
                        color: modelData === 0
                            ? Theme.transparent
                            : (isToday
                                ? Theme.buttonSelectedBackground
                                : (isSelected ? Theme.buttonFocusBackground : (dayMouse.containsMouse ? Theme.buttonHoverBackground : Theme.buttonBackground)))
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
                            id: dayMouse
                            anchors.fill: parent
                            enabled: modelData !== 0
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.selectedDay = modelData
                        }
                    }
                }
            }

            MouseArea {
                width: parent.width
                height: parent.height
                z: 10
                acceptedButtons: Qt.NoButton
                hoverEnabled: false

                property double lastWheelTime: 0

                onWheel: function (wheel) {
                    const now = Date.now();
                    if (now - lastWheelTime < 250) {
                        return;
                    }
                    let delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x;
                    if (delta < 0) {
                        lastWheelTime = now;
                        root.updateMonth(1);
                    } else if (delta > 0) {
                        lastWheelTime = now;
                        root.updateMonth(-1);
                    }
                }
            }
        }
    } // End Item (Month Grid Container)

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 1
        color: Theme.border
    }

    // =========================================================================
    // 4. CHRONOLOGICAL EVENT TIMELINE
    // =========================================================================

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
                const allEvents = root.calendarModel.events || [];

                // 1. Specific Date Selection View: Show ALL events (personal + holidays) for that date
                if (root.selectedDay > 0) {
                    const dateStr = root.getDateString(root.selectedDay);
                    return allEvents.filter(function (e) {
                        return e.date === dateStr;
                    });
                }

                // 2. Default Upcoming Events View: Show ONLY National Holidays
                const mStr = (root.currentMonth + 1).toString().padStart(2, '0');
                const prefix = root.currentYear + "-" + mStr + "-";
                const holidaysOnly = allEvents.filter(function (e) {
                    return e.is_holiday === true;
                });
                const monthHolidays = holidaysOnly.filter(function (e) {
                    return e.date && e.date.startsWith(prefix);
                });

                if (monthHolidays.length > 0) {
                    return monthHolidays;
                }
                return holidaysOnly.filter(function (e) {
                    return e.date >= prefix + "01";
                });
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
                            text: root.formatEventBadge(modelData.date, modelData.time, modelData.is_holiday)
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
                text: root.calendarModel.loading ? "Loading events..." : "No events scheduled"
                color: Theme.textMuted
                font.pixelSize: Theme.smallFontSize
            }
        }
    }
}
