pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    readonly property var durations: [
        {
            label: "15 minutes",
            value: 15 * 60
        },
        {
            label: "30 minutes",
            value: 30 * 60
        },
        {
            label: "60 minutes",
            value: 60 * 60
        },
        {
            label: "2 hours",
            value: 120 * 60
        },
        {
            label: "3 hours",
            value: 180 * 60
        },
        {
            label: "Infinite",
            value: 0
        },
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            spacing: 12

            StyledText {
                text: "Inhibitor"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            StyledText {
                text: InhibitorService.selectedDuration === 0 ? "Infinite" : ClockService.formatDuration(InhibitorService.remainingTime)
                font.pixelSize: Theme.fontPixelSizes.small
                font.weight: Font.Medium
                horizontalAlignment: Text.AlignRight
                opacity: InhibitorService.inhibit ? 1.0 : 0.4

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                    }
                }
            }

            StyledSwitch {
                implicitWidth: 64
                implicitHeight: 28
                checked: InhibitorService.inhibit
                onClicked: InhibitorService.toggleInhibit()
                enabled: InhibitorService.toggleInhibitEnabled
            }
        }

        // Duration List
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8

            Repeater {
                model: root.durations
                delegate: StyledRectangle {
                    id: durationDelegate
                    required property var modelData
                    readonly property bool isSelected: InhibitorService.selectedDuration === modelData.value
                    property bool isHovered: false

                    Layout.fillWidth: true
                    Layout.preferredHeight: 54
                    baseRadius: Theme.rounding.normal
                    color: isHovered ? ColorUtils.transparentize(Theme.colors.white, 0.07) : isSelected ? ColorUtils.transparentize(Theme.colors.white, 0.10) : "transparent"
                    border.color: ColorUtils.transparentize(Theme.colors.white, 0.20)
                    border.width: isSelected ? 1 : 0

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animations.duration.normal
                            easing.type: Theme.animations.easing.outCirc
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 12

                        StyledCheckBox {
                            size: 22
                            bgRadius: Theme.rounding.verysmall
                            checked: durationDelegate.isSelected
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.NoButton
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        StyledText {
                            text: durationDelegate.modelData.label
                            font.weight: durationDelegate.isSelected ? Font.DemiBold : Font.Normal
                            font.pixelSize: Theme.fontPixelSizes.small
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        onEntered: durationDelegate.isHovered = true
                        onExited: durationDelegate.isHovered = false
                        onClicked: InhibitorService.updateDuration(durationDelegate.modelData.value)
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            } // Spacer
        }
    }
}
