pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs
import qs.services
import qs.components

BarModule {
    id: root
    name: "battery"
    hotAlign: "right"

    baseWidth: Theme.sizes.barModuleBaseHeight + 12
    enableClickToExpand: !isExpanded
    expandedHeight: 260
    expandedWidth: 480

    property UPowerDevice batteryDevice: UPower.devices.values.length > 0 ? UPower.devices.values[0] : null
    property real percentage: batteryDevice ? batteryDevice.percentage : 0
    property bool isCharging: batteryDevice ? batteryDevice.state === UPowerDeviceState.Charging : false
    property bool isDischarging: batteryDevice ? batteryDevice.state === UPowerDeviceState.Discharging : false
    property bool isFullyCharged: batteryDevice ? (batteryDevice.state === UPowerDeviceState.FullyCharged || (batteryDevice.state === UPowerDeviceState.PendingCharge && BatteryService.autoManageEnabled)) : false

    property bool isCritical: percentage <= 0.15 && !isCharging && !isFullyCharged
    property bool isWarning: percentage <= 0.25 && !isCharging && !isCritical && !isFullyCharged

    property bool showBoltIcon: isCharging || isDischarging || (isFullyCharged && BatteryService.autoManageEnabled)

    property color accent: isCharging ? Theme.colors.success : isWarning ? Theme.colors.warning : isCritical ? Theme.colors.error : Theme.colors.white

    function formatTime(sec, label = "") {
        return `${Math.floor(sec / 3600)}h, ${Math.floor((sec % 3600) / 60)}m ${label}`;
    }

    Behavior on accent {
        ColorAnimation {
            duration: Theme.animations.duration.slower
            easing.type: Theme.animations.easing.outExpo
        }
    }

    initialContent: Item {
        anchors.fill: parent

        MaterialSymbol {
            id: boltIcon
            property bool chargeBlocked: root.isFullyCharged && BatteryService.autoManageEnabled
            iconName: {
                if (root.isCharging)
                    return "keyboard_double_arrow_up";
                if (root.isDischarging)
                    return "keyboard_double_arrow_down";
                if (chargeBlocked)
                    return "shield";
                return "";
            }
            iconSize: 14
            color: percentageText.color
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 5
            filled: true
            weight: 600
            grad: 100
            visible: opacity > 0 && iconName !== ""
            opacity: root.showBoltIcon && percentageText.color !== Theme.colors.white ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outExpo
                }
            }
        }

        StyledText {
            id: percentageText
            text: Math.floor(root.percentage * 100)
            anchors.centerIn: parent
            anchors.fill: parent
            anchors.rightMargin: root.showBoltIcon ? -13 : 0
            color: {
                if (root.isWarning)
                    return Theme.colors.warning;
                if (root.isCritical)
                    return Theme.colors.error;
                if (root.isCharging)
                    return Theme.colors.success;
                return Theme.colors.textBright;
            }
            font.family: Theme.fontFamilies.main
            font.pixelSize: Theme.fontPixelSizes.small
            font.weight: Font.DemiBold

            Behavior on anchors.rightMargin {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outExpo
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animations.duration.slower
                    easing.type: Theme.animations.easing.outExpo
                }
            }
        }
    }

    expandedContent: Item {

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true

                CircularProgress {
                    Layout.preferredHeight: size
                    lineWidth: 6
                    size: 72
                    value: root.percentage
                    primaryColor: root.accent
                    secondaryColor: Theme.colors.borderDim
                    gapAngle: 0

                    StyledText {
                        text: Math.floor(root.percentage * 100)
                        anchors.centerIn: parent
                        color: root.accent
                        font.family: Theme.fontFamilies.main
                        font.pixelSize: Theme.fontPixelSizes.huge
                        font.weight: Font.DemiBold
                    }
                }

                Row {
                    spacing: 0
                    StyledText {
                        text: {
                            if (root.batteryDevice.timeToEmpty > 0)
                                return root.formatTime(root.batteryDevice.timeToEmpty);
                            if (root.batteryDevice.timeToFull > 0)
                                return root.formatTime(root.batteryDevice.timeToFull);
                            if (root.isFullyCharged)
                                return "Full";
                            return "Estimating";
                        }
                        font.family: Theme.fontFamilies.main
                        font.pixelSize: Theme.fontPixelSizes.hugeass
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: {
                            if (root.batteryDevice.timeToEmpty > 0)
                                return "to empty";
                            if (root.batteryDevice.timeToFull > 0)
                                return "to full";
                            if (root.isFullyCharged)
                                return "";
                            return " ...";
                        }
                        font.family: Theme.fontFamilies.main
                        font.pixelSize: Theme.fontPixelSizes.large + 1
                        font.weight: Font.Medium
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: height / 12
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                ColumnLayout {
                    Layout.preferredWidth: 100
                    spacing: 4

                    Row {
                        spacing: 4
                        MaterialSymbol {
                            iconName: "bolt"
                            filled: true
                            iconSize: 24
                        }
                        StyledText {
                            text: root.batteryDevice.changeRate.toFixed(1) + "W"
                            font.family: Theme.fontFamilies.main
                            font.pixelSize: Theme.fontPixelSizes.larger
                            font.weight: Font.DemiBold
                        }
                    }

                    Row {
                        spacing: 4
                        MaterialSymbol {
                            iconName: "favorite"
                            filled: true
                            iconSize: 24
                        }
                        StyledText {
                            visible: root.batteryDevice.healthSupported
                            text: root.batteryDevice.healthPercentage.toFixed(1) + "%"
                            font.family: Theme.fontFamilies.main
                            font.pixelSize: Theme.fontPixelSizes.larger
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledSwitch {
                    implicitWidth: 62
                    implicitHeight: 28
                    Layout.leftMargin: 2
                    Layout.alignment: Qt.AlignVCenter
                    checked: BatteryService.autoManageEnabled
                    onClicked: BatteryService.toggleAutoManage()
                }

                StyledText {
                    text: "Preserve Battery Health"
                    font.pixelSize: Theme.fontPixelSizes.large
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 3
                spacing: 8

                StyledSwitch {
                    Layout.leftMargin: 2
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 62
                    implicitHeight: 28
                    checked: GlobalSettings.forcePowerSaver || PowerProfiles.profile === PowerProfile.PowerSaver
                    enabled: PowerProfiles.profile !== PowerProfile.PowerSaver
                    onClicked: {
                        const newValue = !GlobalSettings.forcePowerSaver;
                        GlobalSettings.forcePowerSaver = newValue;
                        PowerSaverService.applyPowerSaverMode(newValue);
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Reduce Visual Effects"
                    font.pixelSize: Theme.fontPixelSizes.large
                    font.weight: Font.Medium
                    opacity: PowerProfiles.profile !== PowerProfile.PowerSaver ? 1 : 0.65

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.animations.duration.normal
                            easing.type: Theme.animations.easing.outQuad
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 3
                spacing: 8

                StyledSwitch {
                    implicitWidth: 62
                    implicitHeight: 28
                    Layout.leftMargin: 2
                    Layout.alignment: Qt.AlignVCenter
                    checked: InhibitorService.inhibit
                    onClicked: InhibitorService.toggleInhibit()
                    enabled: InhibitorService.toggleInhibitEnabled
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: "Keep System Awake"
                    font.pixelSize: Theme.fontPixelSizes.large
                    font.weight: Font.Medium
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: InhibitorService.selectedDuration === 0 ? "" : `[${ClockService.formatDuration(InhibitorService.remainingTime)}]`
                    font.pixelSize: Theme.fontPixelSizes.small
                    font.weight: Font.Normal
                    opacity: 0.5
                }
            }

            Item {
                Layout.fillHeight: true
            }

            StyledSelector {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                entries: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
                currentIndex: entries.indexOf(PowerProfiles.profile)
                displayText: entry => PowerProfile.toString(entry)
                onClicked: PowerProfilesService.setPowerProfile(entries[currentIndex])
            }
        }
    }
}
