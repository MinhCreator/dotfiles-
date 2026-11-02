pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    function formatPreset(secs) {
        if (secs < 60)
            return "+" + secs + "s";
        if (secs < 3600)
            return "+" + Math.floor(secs / 60) + "m";
        const h = Math.floor(secs / 3600), m = Math.floor((secs % 3600) / 60);
        return "+" + (m > 0 ? h + "h " + m + "m" : h + "h");
    }

    function saveCountdown() {
        const h = parseInt(hoursField.text) || 0;
        const m = parseInt(minutesField.text) || 0;
        const s = parseInt(secondsField.text) || 0;
        const total = h * 3600 + m * 60 + s;
        ClockService.countdownTotal = total;
        ClockService.countdownRemaining = ClockService.countdownTotal;
        ClockService.countdownCentiseconds = 0;
        ClockService.persistCountdown();
    }

    component TimeField: StyledTextField {
        font.pixelSize: Theme.fontPixelSizes.hugeass + 2
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        implicitWidth: 50
        color: Theme.colors.textBright
        Keys.onLeftPressed: event => event.accepted = true
        Keys.onRightPressed: event => event.accepted = true

        onActiveFocusChanged: {
            if (!activeFocus && !ClockService.countdownRunning && !ClockService.countdownPaused) {
                root.saveCountdown();
            }
        }

        validator: RegularExpressionValidator {
            regularExpression: /^[0-5][0-9]$/
        }
    }

    component ClockCard: StyledRectangle {
        id: card
        property string label
        default property alias content: inner.data

        Layout.fillWidth: true
        Layout.fillHeight: true
        baseRadius: Theme.rounding.large
        color: ColorUtils.transparentize(Theme.colors.white, 0.040)
        border.width: 1
        border.color: ColorUtils.transparentize(Theme.colors.white, 0.15)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 4
            StyledText {
                text: card.label
                font.weight: Font.Medium
                opacity: 0.75
            }
            Item {
                id: inner
                Layout.fillWidth: true
                Layout.fillHeight: true
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            StyledText {
                text: "Clock"
                font.pixelSize: Theme.fontPixelSizes.larger
                horizontalAlignment: Text.AlignLeft
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            StyledIconButton {
                iconName: "apps"
                onClicked: {
                    Quickshell.execDetached(["gnome-clocks"]);
                    GlobalStates.expandedBarModule = "";
                }
            }
        }

        // Stopwatch
        ClockCard {
            label: "Stopwatch"

            CircularProgressFilled {
                id: stopwatch
                anchors.centerIn: parent
                size: parent.height
                showText: false
                enableAnimation: false
                value: (ClockService.stopwatchElapsed % 60 + ClockService.stopwatchCentiseconds / 100) / 60
                primaryColor: ColorUtils.transparentize(Theme.colors.color6, 0.70)
                secondaryColor: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.0)
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: -8
                    RowLayout {
                        spacing: -10
                        TimeField {
                            enabled: false
                            text: String(Math.floor(ClockService.stopwatchElapsed / 3600)).padStart(2, '0')
                        }
                        StyledText {
                            text: ":"
                            font.pixelSize: Theme.fontPixelSizes.hugeass + 2
                            font.weight: Font.Bold
                        }
                        TimeField {
                            enabled: false
                            text: String(Math.floor((ClockService.stopwatchElapsed % 3600) / 60)).padStart(2, '0')
                        }
                        StyledText {
                            text: ":"
                            font.pixelSize: Theme.fontPixelSizes.hugeass + 2
                            font.weight: Font.Bold
                        }
                        TimeField {
                            enabled: false
                            text: String(ClockService.stopwatchElapsed % 60).padStart(2, '0')
                        }
                    }
                    StyledText {
                        Layout.leftMargin: 12
                        text: "." + String(ClockService.stopwatchCentiseconds).padStart(2, '0')
                        font.pixelSize: Theme.fontPixelSizes.small
                        opacity: 0.6
                    }
                }
            }

            ColumnLayout {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: stopwatch.right
                anchors.leftMargin: 12
                spacing: 12

                StyledIconButton {
                    implicitWidth: 48
                    implicitHeight: 48
                    alwaysShowBackground: true
                    iconSize: 36
                    iconFilled: true
                    iconName: ClockService.stopwatchRunning ? "pause" : "play_arrow"
                    onClicked: ClockService.stopwatchRunning ? ClockService.stopwatchPause() : ClockService.stopwatchStart()
                }
                StyledIconButton {
                    implicitWidth: 48
                    implicitHeight: 48
                    alwaysShowBackground: true
                    iconSize: 36
                    iconName: "restart_alt"
                    onClicked: ClockService.stopwatchReset()
                }
            }
        }

        // Countdown
        ClockCard {
            label: "Countdown"

            CircularProgressFilled {
                id: countdown
                anchors.centerIn: parent
                size: parent.height
                showText: false
                value: ClockService.countdownTotal > 0 ? (ClockService.countdownRemaining + ClockService.countdownCentiseconds / 100) / ClockService.countdownTotal : 0
                enableAnimation: false
                primaryColor: ColorUtils.transparentize(Theme.colors.color6, 0.70)
                secondaryColor: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.0)

                RowLayout {
                    anchors.centerIn: parent
                    spacing: -10
                    TimeField {
                        id: hoursField
                        objectName: "hours"
                        enabled: ClockService.countdownEditable
                        text: String(Math.floor(ClockService.countdownRemaining / 3600)).padStart(2, '0')
                        Binding on text {
                            value: String(Math.floor(ClockService.countdownRemaining / 3600)).padStart(2, '0')
                            when: !hoursField.activeFocus
                        }
                    }
                    StyledText {
                        text: ":"
                        font.pixelSize: Theme.fontPixelSizes.hugeass + 2
                        font.weight: Font.Bold
                    }
                    TimeField {
                        id: minutesField
                        enabled: ClockService.countdownEditable
                        text: String(Math.floor((ClockService.countdownRemaining % 3600) / 60)).padStart(2, '0')
                        Binding on text {
                            value: String(Math.floor((ClockService.countdownRemaining % 3600) / 60)).padStart(2, '0')
                            when: !minutesField.activeFocus
                        }
                    }
                    StyledText {
                        text: ":"
                        font.pixelSize: Theme.fontPixelSizes.hugeass + 2
                        font.weight: Font.Bold
                    }
                    TimeField {
                        id: secondsField
                        enabled: ClockService.countdownEditable
                        text: String(ClockService.countdownRemaining % 60).padStart(2, '0')
                        Binding on text {
                            value: String(ClockService.countdownRemaining % 60).padStart(2, '0')
                            when: !minutesField.activeFocus
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.verticalCenter: countdown.verticalCenter
                anchors.left: countdown.right
                anchors.leftMargin: 12
                spacing: 12

                StyledIconButton {
                    implicitWidth: 48
                    implicitHeight: 48
                    alwaysShowBackground: true
                    iconSize: 36
                    iconFilled: true
                    iconName: ClockService.countdownRunning ? "pause" : "play_arrow"
                    onClicked: {
                        if (ClockService.countdownRunning) {
                            ClockService.countdownPause();
                        } else if (ClockService.countdownPaused) {
                            ClockService.countdownResume();
                        } else {
                            root.saveCountdown();
                            ClockService.countdownStart(ClockService.countdownTotal);
                        }
                    }
                }
                StyledIconButton {
                    implicitWidth: 48
                    implicitHeight: 48
                    alwaysShowBackground: true
                    iconSize: 36
                    iconName: "restart_alt"
                    onClicked: ClockService.countdownReset()
                }
            }
        }
    }
}
