pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import "../../lib/ColorUtils.js" as ColorUtils

PanelWindow {
    id: root
    color: "transparent"
    visible: ScreenShareService.active

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:screensharepicker"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    component PickerGrid: Item {
        id: pickerGrid
        required property var pages
        required property int tab
        property alias currentPageIndex: swipeable.currentIndex

        SwipeView {
            id: swipeable
            anchors.fill: parent
            spacing: 32
            clip: true
            interactive: true

            currentIndex: Math.floor(ScreenShareService.selectedIndex / ScreenShareService.itemsPerPage)

            Repeater {
                model: pickerGrid.pages

                Item {
                    id: pageItem
                    required property var modelData
                    required property int index
                    implicitWidth: swipeable.width
                    implicitHeight: swipeable.height

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 24

                        Repeater {
                            model: pageItem.modelData

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 24

                                Repeater {
                                    model: parent.modelData

                                    Item {
                                        id: pickerItem
                                        required property var modelData
                                        readonly property int flatIndex: ScreenShareService.currentModel.findIndex(m => pickerGrid.tab === 1 ? m.name === pickerItem.modelData.name : m.id === pickerItem.modelData.id)
                                        readonly property bool isSelected: pickerItem.flatIndex === ScreenShareService.selectedIndex
                                        property bool isHovered: false

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true

                                        StyledClippingRectangle {
                                            id: proportionalRect

                                            readonly property size windowSize: scv.sourceSize
                                            readonly property real windowAspect: windowSize.width > 0 ? windowSize.width / windowSize.height : 1
                                            readonly property real containerAspect: pickerItem.width > 0 ? pickerItem.width / pickerItem.height : 1

                                            anchors.centerIn: parent
                                            color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgSurface, 0.6) : Theme.colors.bgSurface
                                            baseRadius: Theme.rounding.normal
                                            opacity: 0

                                            width: {
                                                if (windowSize.width === 0 || windowSize.height === 0)
                                                    return pickerItem.width;
                                                return (windowAspect > containerAspect) ? pickerItem.width : pickerItem.height * windowAspect;
                                            }

                                            height: {
                                                if (windowSize.width === 0 || windowSize.height === 0)
                                                    return pickerItem.height;
                                                return (windowAspect > containerAspect) ? pickerItem.width / windowAspect : pickerItem.height;
                                            }

                                            Behavior on opacity {
                                                enabled: false
                                                NumberAnimation {
                                                    duration: Theme.animations.duration.slower
                                                    easing.type: Theme.animations.easing.outQuad
                                                }
                                            }

                                            Timer {
                                                interval: 100
                                                running: !scv.hasContent
                                                repeat: false
                                                onTriggered: proportionalRect.opacity = 1
                                            }

                                            ScreencopyView {
                                                id: scv
                                                anchors.fill: parent
                                                anchors.margins: 2
                                                captureSource: pickerItem.modelData.wayland
                                                paintCursor: true
                                                live: root.visible && swipeable.currentIndex === pageItem.index
                                                visible: hasContent
                                                onHasContentChanged: if (hasContent)
                                                    proportionalRect.opacity = 1
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onEntered: pickerItem.isHovered = true
                                                onExited: pickerItem.isHovered = false
                                                onClicked: ScreenShareService.selectAndActivate(pickerItem.flatIndex)
                                            }
                                        }

                                        StyledRectangle {
                                            anchors.fill: proportionalRect
                                            color: "transparent"
                                            baseRadius: proportionalRect.radius
                                            border.width: 1
                                            border.color: pickerItem.isSelected ? Theme.colors.white : (pickerItem.isHovered ? Theme.colors.textMuted : Theme.colors.borderMid)
                                            opacity: proportionalRect.opacity
                                        }

                                        StyledRectangle {
                                            id: titleTag
                                            implicitHeight: titleText.implicitHeight + 8
                                            implicitWidth: Math.min(titleText.implicitWidth + 16, proportionalRect.width - 16)
                                            anchors.bottom: proportionalRect.bottom
                                            anchors.horizontalCenter: proportionalRect.horizontalCenter
                                            anchors.bottomMargin: 8
                                            color: Theme.colors.bgElevated
                                            baseRadius: height / 2
                                            border.width: 1
                                            border.color: Theme.colors.borderMid
                                            opacity: proportionalRect.opacity

                                            StyledText {
                                                id: titleText
                                                anchors.centerIn: parent
                                                text: pickerGrid.tab === 1 ? pickerItem.modelData.name : (pickerItem.modelData.class || "Unknown")
                                                font.pixelSize: Theme.fontPixelSizes.small
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                width: parent.width - 12
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    StyledRectangle {
        id: container
        anchors.centerIn: parent
        width: root.screen.width * 0.6
        height: root.screen.height * 0.6
        shadow: true
        baseRadius: Theme.rounding.large
        color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase
        border.color: Theme.colors.borderFrameMid
        border.width: 1
        focus: true
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                if (event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)) {
                    ScreenShareService.switchPrevious();
                } else {
                    ScreenShareService.switchNext();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                ScreenShareService.cancel();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                ScreenShareService.activateSelected();
                event.accepted = true;
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 32
            spacing: 24

            Item {
                id: header
                Layout.fillWidth: true
                implicitHeight: 64

                RowLayout {
                    anchors.fill: parent
                    spacing: 24

                    StyledSelector {
                        id: tabSelector
                        Layout.preferredWidth: 248
                        Layout.preferredHeight: 44
                        entries: ["Windows", "Monitors"]
                        currentIndex: ScreenShareService.currentTab
                        onClicked: {
                            ScreenShareService.currentTab = currentIndex;
                            ScreenShareService.selectedIndex = 0;
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: ScreenShareService.currentPages.length
                            StyledRectangle {
                                required property int index
                                width: tabLoader.currentPageIndex === index ? 20 : 12
                                height: 12
                                baseRadius: height / 2
                                color: tabLoader.currentPageIndex === index ? Theme.colors.color16 : Theme.colors.textSecondary
                                opacity: tabLoader.currentPageIndex === index ? 1 : 0.4
                                Behavior on width {
                                    NumberAnimation {
                                        duration: Theme.animations.duration.normal
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Loader {
                id: tabLoader
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: ScreenShareService.currentTab === 0 ? windowsGrid : monitorsGrid
                readonly property int currentPageIndex: item?.currentPageIndex ?? 0
            }
        }
    }

    Component {
        id: windowsGrid
        PickerGrid {
            pages: ScreenShareService.windowPages
            tab: 0
        }
    }

    Component {
        id: monitorsGrid
        PickerGrid {
            pages: ScreenShareService.monitorPages
            tab: 1
        }
    }
}
