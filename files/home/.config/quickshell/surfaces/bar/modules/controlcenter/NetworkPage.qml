pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking
import qs
import qs.components
import qs.services
import qs.surfaces.bar.modules.controlcenter.components
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    Component.onCompleted: {
        if (NetworkService.wifiInterface)
            NetworkService.wifiInterface.scannerEnabled = true;
    }
    Component.onDestruction: {
        if (NetworkService.wifiInterface)
            NetworkService.wifiInterface.scannerEnabled = false;
    }

    ControlCenterEmptyState {
        anchors.fill: parent
        shown: NetworkService.allNetworks.length === 0
        iconName: NetworkService.wifiOn ? "android_wifi_4_bar" : "android_wifi_4_bar_off"
        text: !NetworkService.wifiOn ? "Wi-Fi off" : "Searching for networks..."
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
                text: "Wi-Fi"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
            }

            StyledIconButton {
                iconName: "tune"
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "XDG_CURRENT_DESKTOP=GNOME gnome-control-center wifi"]);
                    GlobalStates.expandedBarModule = "";
                }
            }

            StyledSwitch {
                implicitWidth: 64
                implicitHeight: 28
                checked: NetworkService.wifiOn
                onClicked: NetworkService.toggleWifi()
            }
        }

        StyledListView {
            id: networkList
            Layout.fillWidth: true
            Layout.fillHeight: true
            showScrollBar: false
            spacing: 8
            model: NetworkService.allNetworks

            delegate: StyledRectangle {
                id: networkDelegate
                required property Network modelData
                required property int index
                property bool isWired: modelData.device?.type === DeviceType.Wired
                property bool isConnected: modelData.connected
                property bool isConnecting: modelData.state === ConnectionState.Connecting
                property bool isKnown: modelData.known
                property bool isHovered: false
                property bool showPasswordInput: false

                height: showPasswordInput ? 108 : 54
                width: networkList.width
                baseRadius: Theme.rounding.normal
                color: isHovered ? ColorUtils.transparentize(Theme.colors.white, 0.07) : isConnected || isConnecting ? ColorUtils.transparentize(Theme.colors.white, 0.10) : "transparent"
                border.color: ColorUtils.transparentize(Theme.colors.white, 0.20)
                border.width: isConnected ? 1 : 0

                Connections {
                    target: networkDelegate.isWired ? null : networkDelegate.modelData
                    function onConnectionFailed(reason) {
                        if (reason === ConnectionFailReason.NoSecrets) {
                            networkDelegate.showPasswordInput = true;
                        }
                    }
                }

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.animations.duration.slower
                        easing.type: Theme.animations.easing.outBack
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 54
                        spacing: 8

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignLeft
                            iconSize: 28
                            iconName: {
                                if (networkDelegate.isWired)
                                    return networkDelegate.isConnected ? "lan" : "settings_ethernet";
                                const strength = networkDelegate.modelData.signalStrength * 100 || 0;
                                if (strength >= 75)
                                    return "signal_wifi_4_bar";
                                if (strength >= 50)
                                    return "network_wifi_3_bar";
                                if (strength >= 25)
                                    return "network_wifi_2_bar";
                                if (strength > 0)
                                    return "network_wifi_1_bar";
                                return "signal_wifi_0_bar";
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                text: {
                                    if (networkDelegate.isWired)
                                        return networkDelegate.modelData.name || NetworkService.ethernetInterface?.name || "Wired";
                                    return networkDelegate.modelData.name;
                                }
                                font.weight: Font.DemiBold
                                font.pixelSize: Theme.fontPixelSizes.small
                                horizontalAlignment: Text.AlignLeft
                                Layout.fillWidth: true
                            }

                            StyledText {
                                visible: networkDelegate.isWired || (networkDelegate.isConnected && NetworkService.ipFor(networkDelegate.modelData) !== "")
                                text: {
                                    const ip = NetworkService.ipFor(networkDelegate.modelData);
                                    if (networkDelegate.isWired) {
                                        if (networkDelegate.isConnecting)
                                            return "Connecting…";
                                        if (networkDelegate.isConnected && ip !== "")
                                            return ip;
                                        if (networkDelegate.isConnected)
                                            return "Connected";
                                        return "No connection";
                                    }
                                    return ip;
                                }
                                font.pixelSize: Theme.fontPixelSizes.smaller
                                color: Theme.colors.textSecondary
                                horizontalAlignment: Text.AlignLeft
                                Layout.fillWidth: true
                            }
                        }

                        ActivityIndicator {
                            Layout.alignment: Qt.AlignLeft
                            running: networkDelegate.isConnecting
                            size: 24
                        }

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignLeft
                            visible: !networkDelegate.isConnecting && !!iconName
                            iconSize: 24
                            iconName: {
                                if (networkDelegate.isConnected)
                                    return "check_circle";
                                if (!networkDelegate.isWired) {
                                    if (networkDelegate.isKnown)
                                        return "lock_open_right";
                                    if (NetworkService.isSecured(networkDelegate.modelData?.security))
                                        return "lock";
                                }
                                return "";
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: networkDelegate.showPasswordInput
                        Layout.fillWidth: true
                        opacity: networkDelegate.showPasswordInput ? 1 : 0
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animations.duration.normal
                                easing.type: Theme.animations.easing.outCirc
                            }
                        }
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
                    onEntered: networkDelegate.isHovered = true
                    onExited: networkDelegate.isHovered = false
                    onClicked: {
                        const net = networkDelegate.modelData;
                        if (networkDelegate.isWired) {
                            if (net.connected)
                                net.disconnect();
                            else
                                net.connect();
                        } else {
                            if (net.connected)
                                net.disconnect();
                            net.connect();
                        }
                    }
                }
            }
        }
    }
}
