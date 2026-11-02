pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.services
import qs
import "../../lib/ColorUtils.js" as ColorUtils

Rectangle {
    id: root
    anchors.fill: parent
    color: "transparent"

    required property bool isMainMonitor
    property bool isSubmiting: false
    property bool showPassword: false

    Component.onCompleted: {
        color = "#33000000";
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.animations.duration.fast
        }
    }

    Loader {
        active: root.isMainMonitor
        anchors.centerIn: parent

        sourceComponent: StyledRectangle {
            id: container
            color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.70) : Theme.colors.bgBase
            border.width: 1
            border.color: Theme.colors.borderFrameMid
            shadow: true
            baseRadius: Theme.rounding.verylarge
            width: 500
            height: 220
            anchors.centerIn: parent
            scale: 0.95
            opacity: 0

            Component.onCompleted: {
                scale = 1;
                opacity = 1;
                inputField.forceActiveFocus();
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outCubic
                }
            }

            MaterialSymbol {
                iconName: "security"
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.margins: 6
                iconSize: 30
                opacity: 0.15
            }

            Column {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 20
                z: 2

                StyledText {
                    width: parent.width
                    height: parent.height - inputField.height - parent.spacing
                    text: PolkitService.cleanMessage
                    font.pixelSize: Theme.fontPixelSizes.larger
                    font.weight: Font.Medium
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                }

                Item {
                    width: parent.width
                    height: 54

                    StyledRectangle {
                        id: inputBackground
                        anchors.fill: parent
                        color: ColorUtils.transparentize(Theme.colors.bgBase, 0.50)
                        baseRadius: container.radius - ((width - container.width) / 2)
                        border.width: 1
                        border.color: ColorUtils.transparentize(root.isSubmiting ? Theme.colors.textMuted : Theme.colors.borderDim, 0.50)

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.animations.duration.verySlow
                                easing.type: Theme.animations.easing.outExpo
                            }
                        }

                        StyledTextField {
                            id: inputField
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 56
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            enabled: PolkitService.interactionAvailable
                            echoMode: root.showPassword ? TextInput.Normal : TextInput.Password
                            passwordCharacter: "•"
                            font.pixelSize: Theme.fontPixelSizes.hugeass
                            font.weight: Font.Medium
                            focus: true

                            Keys.onEnterPressed: inputField.submit()
                            Keys.onReturnPressed: inputField.submit()
                            Keys.onPressed: event => {
                                if (event.key === Qt.Key_Escape)
                                    PolkitService.cancel();
                            }

                            function submit() {
                                PolkitService.submit(inputField.text);
                                root.isSubmiting = true;
                            }

                            Connections {
                                target: PolkitService
                                function onInteractionAvailableChanged() {
                                    if (!PolkitService.interactionAvailable)
                                        return;
                                    inputField.text = "";
                                    root.showPassword = false;
                                    inputField.forceActiveFocus();
                                    root.isSubmiting = false;
                                }
                            }
                        }
                    }

                    Item {
                        id: toggleButton
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.rightMargin: (parent.height - height) / 2
                        width: 40
                        height: 40
                        z: 10

                        property bool hovered: false

                        StyledRectangle {
                            anchors.fill: parent
                            baseRadius: height / 2
                            color: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.50)
                            opacity: toggleButton.hovered ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.fast
                                }
                            }
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            iconName: root.showPassword ? "visibility_off" : "visibility"
                            color: Theme.colors.gray5
                            opacity: toggleButton.hovered ? 1 : 0.7

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.fast
                                }
                            }
                        }

                        MouseArea {
                            id: toggleArea
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: toggleButton.hovered = true
                            onExited: toggleButton.hovered = false
                            onClicked: {
                                root.showPassword = !root.showPassword;
                                inputField.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                propagateComposedEvents: true
                z: 1
                onClicked: mouse => {
                    inputField.forceActiveFocus();
                    mouse.accepted = false;
                }
            }
        }
    }
}
