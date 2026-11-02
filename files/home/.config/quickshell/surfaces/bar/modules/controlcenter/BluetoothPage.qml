pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import qs.surfaces.bar.modules.controlcenter.components
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    ControlCenterEmptyState {
        anchors.fill: parent
        shown: !BluetoothService.bluetoothEnabled || BluetoothService.devices.length === 0
        iconName: !BluetoothService.bluetoothEnabled ? "bluetooth_disabled" : "bluetooth"
        text: !BluetoothService.bluetoothEnabled ? "Bluetooth off" : "No devices found"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            spacing: 12

            StyledText {
                text: "Bluetooth"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
            }

            StyledIconButton {
                iconName: "tune"
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "XDG_CURRENT_DESKTOP=GNOME gnome-control-center bluetooth"]);
                    GlobalStates.expandedBarModule = "";
                }
            }

            StyledSwitch {
                implicitWidth: 64
                implicitHeight: 28
                checked: BluetoothService.bluetoothEnabled
                onClicked: BluetoothService.toggleBluetooth()
            }
        }

        StyledListView {
            id: deviceList
            Layout.fillWidth: true
            Layout.fillHeight: true
            showScrollBar: false
            spacing: 8
            model: BluetoothService.bluetoothEnabled ? BluetoothService.devices : []

            delegate: StyledRectangle {
                id: deviceDelegate
                required property var modelData
                required property int index
                property bool isConnected: modelData.connected
                property bool isConnecting: BluetoothService.getState(modelData.state) === "Connecting"
                property bool isHovered: false

                height: 54
                width: deviceList.width
                baseRadius: Theme.rounding.normal
                color: isHovered ? ColorUtils.transparentize(Theme.colors.white, 0.07) : isConnected || isConnecting ? ColorUtils.transparentize(Theme.colors.white, 0.10) : "transparent"
                border.color: ColorUtils.transparentize(Theme.colors.white, 0.20)
                border.width: isConnected ? 1 : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 8

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignLeft
                        iconSize: 28
                        iconName: BluetoothService.getMaterialSymbol(deviceDelegate.modelData.icon)
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: deviceDelegate.modelData.name
                            font.weight: Font.DemiBold
                            font.pixelSize: Theme.fontPixelSizes.small
                            horizontalAlignment: Text.AlignLeft
                            Layout.fillWidth: true
                        }

                        StyledText {
                            visible: deviceDelegate.modelData.batteryAvailable && deviceDelegate.isConnected
                            text: Math.round(deviceDelegate.modelData.battery * 100) + "%"
                            font.pixelSize: Theme.fontPixelSizes.smaller
                            color: Theme.colors.textSecondary
                            horizontalAlignment: Text.AlignLeft
                        }
                    }

                    ActivityIndicator {
                        Layout.alignment: Qt.AlignLeft
                        running: deviceDelegate.isConnecting
                        size: 24
                    }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignLeft
                        visible: !deviceDelegate.isConnecting && deviceDelegate.isConnected
                        iconSize: 24
                        iconName: "check_circle"
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outCirc
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: deviceDelegate.isConnected ? deviceDelegate.modelData.disconnect() : deviceDelegate.modelData.connect()
                    onEntered: deviceDelegate.isHovered = true
                    onExited: deviceDelegate.isHovered = false
                }
            }
        }
    }
}
