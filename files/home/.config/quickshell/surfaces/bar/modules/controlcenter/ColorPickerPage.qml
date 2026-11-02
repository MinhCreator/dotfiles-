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

    Connections {
        target: ColorPickerService
        function onColorPicked(colorEntry) {
            colorGrid.model = GlobalCache.pickedColors.slice();
        }
    }

    ControlCenterEmptyState {
        anchors.fill: parent
        shown: colorGrid.count === 0
        iconName: "colorize"
        text: "No colors picked"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: 12

            StyledText {
                text: "Color Picker"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
            }

            StyledIconButton {
                iconName: "delete_forever"
                visible: colorGrid.count > 0
                onClicked: {
                    colorGrid.model = [];
                    GlobalCache.pickedColors = [];
                }
            }

            StyledIconButton {
                iconName: "colorize"
                onClicked: ColorPickerService.pick("hex", 0)
            }
        }

        GridView {
            id: colorGrid
            Layout.fillWidth: true
            Layout.fillHeight: true
            cellWidth: width / 4
            cellHeight: cellWidth
            model: GlobalCache.pickedColors
            visible: count > 0
            clip: true

            delegate: Item {
                id: delegateRoot
                required property var modelData
                required property int index

                width: colorGrid.cellWidth
                height: colorGrid.cellHeight

                StyledRectangle {
                    id: colorRect
                    anchors.fill: parent
                    anchors.margins: 4
                    baseRadius: Theme.rounding.small
                    color: delegateRoot.modelData.hex || delegateRoot.modelData.color

                    StyledRectangle {
                        anchors.fill: parent
                        baseRadius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: ColorUtils.transparentize(Theme.colors.white, 0.20)
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        hoverEnabled: true

                        onClicked: mouse => {
                            if (mouse.button === Qt.RightButton) {
                                const colors = GlobalCache.pickedColors;
                                const idx = colors.length - 1 - delegateRoot.index;
                                colors.splice(idx, 1);
                                GlobalCache.pickedColors = colors.slice();
                                colorGrid.model = GlobalCache.pickedColors;
                            } else {
                                Quickshell.execDetached(["wl-copy", delegateRoot.modelData.color]);
                                if (GlobalIpc.popup) {
                                    GlobalIpc.popup.showInfo("Color copied", "", 3000);
                                }
                            }
                        }

                        StyledRectangle {
                            anchors.fill: parent
                            baseRadius: colorRect.radius
                            opacity: parent.containsMouse ? 1 : 0

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: "#99000000"
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.fast
                                }
                            }
                        }

                        StyledText {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 6
                            text: delegateRoot.modelData.color
                            font.weight: Font.DemiBold
                            font.pixelSize: Theme.fontPixelSizes.smaller
                            opacity: parent.containsMouse ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Theme.animations.duration.fast
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
