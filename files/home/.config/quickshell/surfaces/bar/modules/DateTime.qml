pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.components
import qs.services
import qs
import "../../../lib/ColorUtils.js" as ColorUtils

BarModule {
    id: root
    name: "dateTime"
    baseWidth: 200
    expandedWidth: 650
    expandedHeight: 362
    enableClickToExpand: !isExpanded

    property date selectedDate: new Date()
    readonly property var selectedEvents: CalendarService.eventsByDate[CalendarService.dateKey(selectedDate)] ?? []

    function openDate(date) {
        Quickshell.execDetached(["gnome-calendar", "--date", Qt.formatDate(date, "MM/dd/yyyy")]);
    }

    initialContent: Item {
        id: initialContentItem

        StyledText {
            id: dateTimeText
            anchors.centerIn: parent
            text: Qt.formatDateTime(ClockService.systemClock.date, "ddd, MMM dd  hh:mm:ss")
            font.weight: Font.DemiBold
            font.pixelSize: Theme.fontPixelSizes.datetime
            font.family: Theme.fontFamilies.text
        }
    }

    expandedContent: Item {
        id: expandedContentItem

        Component.onCompleted: {
            root.selectedDate = new Date();
            forceActiveFocus();
            ensureMonthData();
        }

        onCurrentMonthChanged: ensureMonthData()
        onCurrentYearChanged: ensureMonthData()

        property date currentDate: new Date()
        property int currentYear: currentDate.getFullYear()
        property int currentMonth: currentDate.getMonth()
        property bool isCurrentMonth: currentMonth === currentDate.getMonth()
        property bool isCurrentYear: currentYear === currentDate.getFullYear()
        property string monthName: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][currentMonth]

        Keys.onPressed: event => {
            if (event.key === Qt.Key_N || event.key === Qt.Key_L) {
                nextMonth();
                event.accepted = true;
            } else if (event.key === Qt.Key_P || event.key === Qt.Key_H) {
                previousMonth();
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                resetMonth();
                event.accepted = true;
            }
        }

        function nextMonth() {
            if (currentMonth === 11) {
                currentMonth = 0;
                currentYear++;
            } else {
                currentMonth++;
            }
            syncSelectionToMonth();
        }

        function previousMonth() {
            if (currentMonth === 0) {
                currentMonth = 11;
                currentYear--;
            } else {
                currentMonth--;
            }
            syncSelectionToMonth();
        }

        function resetMonth() {
            const today = new Date();
            currentYear = today.getFullYear();
            currentMonth = today.getMonth();
            root.selectedDate = today;
        }

        function syncSelectionToMonth() {
            const selected = root.selectedDate;
            if (selected.getFullYear() === currentYear && selected.getMonth() === currentMonth)
                return;

            const today = new Date();
            if (currentYear === today.getFullYear() && currentMonth === today.getMonth()) {
                root.selectedDate = today;
                return;
            }

            const lastDay = new Date(currentYear, currentMonth + 1, 0).getDate();
            root.selectedDate = new Date(currentYear, currentMonth, Math.min(today.getDate(), lastDay));
        }

        function ensureMonthData() {
            CalendarService.ensureMonth(currentYear, currentMonth);
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = false
        }

        // Main row
        RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 12

            // Calendar column
            Item {
                Layout.preferredWidth: 380
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        spacing: 0

                        StyledRectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: currentMonthText.implicitWidth + 32
                            Layout.margins: 4
                            color: ColorUtils.transparentize(Theme.colors.white, 0.125)
                            border.color: ColorUtils.transparentize(Theme.colors.white, 0.22)
                            baseRadius: height / 2
                            border.width: 1
                            clip: true

                            Behavior on Layout.preferredWidth {
                                NumberAnimation {
                                    duration: Theme.animations.duration.fast
                                    easing.type: Theme.animations.easing.outQuad
                                }
                            }

                            CalendarText {
                                id: currentMonthText
                                textContent: `${expandedContentItem.monthName} ${expandedContentItem.currentYear}`
                                anchors.centerIn: parent
                                font.pixelSize: 18
                                font.family: Theme.fontFamilies.main
                            }

                            MouseArea {
                                anchors.fill: parent
                                onPressed: mouse => {
                                    mouse.accepted = true;
                                    expandedContentItem.resetMonth();
                                }
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        NavigationButton {
                            type: "previous"
                            iconName: "chevron_left"
                            Layout.fillHeight: true
                            Layout.preferredWidth: height
                            Layout.margins: 4
                        }

                        NavigationButton {
                            type: "next"
                            iconName: "chevron_right"
                            Layout.fillHeight: true
                            Layout.preferredWidth: height
                            Layout.margins: 4
                        }
                    }

                    DayOfWeekRow {
                        id: weekdayHeaders
                        Layout.preferredWidth: monthCalendarGrid.width
                        Layout.alignment: Qt.AlignRight
                        locale: monthCalendarGrid.locale
                        delegate: CalendarText {
                            required property string shortName
                            textContent: shortName
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    RowLayout {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        WeekNumberColumn {
                            id: weekNumbers
                            Layout.fillHeight: true
                            Layout.leftMargin: -6
                            month: monthCalendarGrid.month
                            year: monthCalendarGrid.year
                            locale: monthCalendarGrid.locale
                            delegate: CalendarText {
                                required property int weekNumber
                                height: 20
                                width: height
                                textContent: weekNumber
                                color: Theme.colors.textMuted
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.leftMargin: -16
                            Layout.bottomMargin: 0
                            Layout.topMargin: 0
                            color: Theme.colors.borderFrameMid
                        }

                        MonthGrid {
                            id: monthCalendarGrid
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            Layout.leftMargin: -16
                            month: expandedContentItem.currentMonth
                            year: expandedContentItem.currentYear
                            locale: Qt.locale("en_GB")
                            delegate: Rectangle {
                                id: monthGridItem
                                required property var model
                                readonly property bool isSelected: CalendarService.dateKey(model.date) === CalendarService.dateKey(root.selectedDate)
                                color: "transparent"

                                StyledRectangle {
                                    anchors.centerIn: parent
                                    width: Math.min(parent.height, parent.width)
                                    height: width
                                    color: monthGridItem.model.today ? Theme.colors.color9 : monthGridItem.isSelected ? ColorUtils.transparentize(Theme.colors.color8, 1) : cellMouseArea.containsMouse ? ColorUtils.transparentize(Theme.colors.white, 0.07) : "transparent"
                                    border.width: cellMouseArea.containsMouse && !monthGridItem.isSelected && !monthGridItem.model.today ? 1 : 0
                                    border.color: Theme.colors.borderFrameMid
                                    baseRadius: height / 2

                                    CalendarText {
                                        anchors.centerIn: parent
                                        color: monthGridItem.model.today ? Theme.colors.bgBase : (monthGridItem.model.month === monthCalendarGrid.month || monthGridItem.isSelected ? Theme.colors.white : Theme.colors.textMuted)
                                        textContent: monthCalendarGrid.locale.toString(monthGridItem.model.date, "d")
                                        font.pixelSize: Theme.fontPixelSizes.small
                                        font.weight: Font.DemiBold
                                        font.family: Theme.fontFamilies.main
                                    }

                                    StyledRectangle {
                                        width: 4
                                        height: 4
                                        baseRadius: width / 2
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        anchors.bottom: parent.bottom
                                        anchors.bottomMargin: 4
                                        visible: CalendarService.hasEvents(monthGridItem.model.date)
                                        color: monthGridItem.model.today || monthGridItem.isSelected ? Theme.colors.bgBase : Theme.colors.color9
                                    }
                                }

                                MouseArea {
                                    id: cellMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: mouse => {
                                        mouse.accepted = true;
                                        if (mouse.button === Qt.RightButton) {
                                            root.openDate(monthGridItem.model.date);
                                            return;
                                        }
                                        root.selectedDate = monthGridItem.model.date;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                color: Theme.colors.borderFrameMid
            }

            // Events list
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    text: Qt.formatDate(root.selectedDate, "dddd, MMMM d")
                    font.family: Theme.fontFamilies.main
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    StyledListView {
                        id: eventList
                        anchors.fill: parent
                        model: root.selectedEvents
                        spacing: 8
                        showScrollBar: false
                        animationsEnabled: false

                        delegate: StyledRectangle {
                            id: eventDelegate
                            required property var modelData
                            required property int index

                            readonly property string timeLabel: modelData.allDay ? "All day" : Qt.formatDateTime(new Date(modelData.startEpoch * 1000), "hh:mm")
                            readonly property string metaLabel: [modelData.calendarName, modelData.location].filter(value => value).join(" · ")

                            width: eventList.width
                            height: 54
                            baseRadius: Theme.rounding.large
                            color: ColorUtils.transparentize(Theme.colors.white, 0.07)
                            border.color: ColorUtils.transparentize(Theme.colors.white, 0.15)
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                StyledRectangle {
                                    Layout.alignment: Qt.AlignVCenter
                                    Layout.preferredWidth: 3
                                    Layout.preferredHeight: 22
                                    baseRadius: 1.5
                                    color: eventDelegate.modelData.calendarColor || Theme.colors.color8
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                    spacing: 1

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: eventDelegate.modelData.summary || "(No title)"
                                            font.pixelSize: Theme.fontPixelSizes.small
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            text: eventDelegate.timeLabel
                                            color: Theme.colors.textSecondary
                                            font.pixelSize: Theme.fontPixelSizes.smaller
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: eventDelegate.metaLabel
                                        visible: text !== ""
                                        color: Theme.colors.textMuted
                                        font.pixelSize: Theme.fontPixelSizes.smaller
                                        horizontalAlignment: Text.AlignLeft
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.fill: parent
                        visible: root.selectedEvents.length === 0

                        ActivityIndicator {
                            id: emptyIndicator
                            anchors.centerIn: parent
                            size: 40
                            running: CalendarService.loading || opacity > 0
                            opacity: CalendarService.loading ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.normal
                                    easing.type: Theme.animations.easing.outCubic
                                }
                            }
                        }

                        StyledText {
                            id: emptyText
                            anchors.centerIn: parent
                            width: parent.width - 16
                            text: CalendarService.error !== "" ? CalendarService.error : "No events"
                            color: Theme.colors.textMuted
                            font.pixelSize: Theme.fontPixelSizes.normal
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            opacity: CalendarService.loading ? 0 : 1

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.normal
                                    easing.type: Theme.animations.easing.outCubic
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    component CalendarText: StyledText {
        id: calendarText
        property string textContent
        property bool colorAnimationEnabled: false
        text: textContent
        font.weight: Font.DemiBold

        Behavior on color {
            enabled: calendarText.colorAnimationEnabled
            ColorAnimation {
                duration: Theme.animations.duration.normal
            }
        }
    }

    component NavigationButton: StyledRectangle {
        id: navigationButton
        property string iconName
        property string type
        property bool isHovered: false

        color: ColorUtils.transparentize(Theme.colors.white, 0.125)
        border.color: ColorUtils.transparentize(Theme.colors.white, 0.22)
        baseRadius: width / 2
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => {
                mouse.accepted = true;
                navigationButton.type === "previous" ? previousMonth() : nextMonth();
            }
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: navigationButton.isHovered = true
            onExited: navigationButton.isHovered = false
        }

        MaterialSymbol {
            id: navigationButtonIcon
            iconName: parent.iconName
            color: Theme.colors.white
            anchors.centerIn: parent
        }
    }
}
