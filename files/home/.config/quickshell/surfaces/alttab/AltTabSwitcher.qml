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
import "../../lib/AppUtils.js" as AppUtils

PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:alttabswitcher"
    anchors {
      top: true
      bottom: true
      right: true
      left: true
    }

    property bool show: false

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: root.show = true
    }

    StyledRectangle {
        id: background
        visible: root.show
        anchors.centerIn: parent
        implicitWidth: root.screen.width * 0.75
        implicitHeight: root.screen.height * 0.75
        color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase
        shadow: true
        baseRadius: Theme.rounding.large
        border.color: Theme.colors.borderFrameMid
        border.width: 1
    }

    Item {
        id: container
        anchors.fill: background
        anchors.margins: 48
        opacity: root.show && AltTabService.totalScreencopyViews > 0 ? 1 : 0
        focus: true

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Alt) {
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                if (event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)) {
                    AltTabService.switchPrevious();
                } else {
                    AltTabService.switchNext();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_Escape) {
                AltTabService.close();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                AltTabService.activateSelected();
                event.accepted = true;
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Alt) {
                AltTabService.activateSelected();
                event.accepted = true;
            }
        }

        Item {
            id: indicators
            implicitWidth: parent.width
            implicitHeight: AltTabService.windowPages.length > 1 ? 64 : 0
            visible: AltTabService.windowPages.length > 1
            anchors.top: parent.top

            Row {
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: AltTabService.windowPages.length
                    StyledRectangle {
                        required property int index
                        anchors.verticalCenter: parent.verticalCenter
                        width: swipeable.currentIndex === index ? 24 : 12
                        height: 12
                        baseRadius: 6
                        color: swipeable.currentIndex === index ? Theme.colors.color16 : Theme.colors.textSecondary
                        opacity: swipeable.currentIndex === index ? 1 : 0.4

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.animations.duration.normal
                                easing.type: Theme.animations.easing.outCubic
                            }
                        }
                    }
                }
            }
        }

        SwipeView {
            id: swipeable
            implicitWidth: parent.width
            implicitHeight: parent.height - indicators.height
            anchors.bottom: parent.bottom
            spacing: 48
            interactive: true

            Component.onCompleted: {
                setCurrentIndex(Math.floor(AltTabService.selectedIndex / AltTabService.itemsPerPage));
            }

            Connections {
                target: AltTabService
                function onSelectedIndexChanged() {
                    let page = Math.floor(AltTabService.selectedIndex / AltTabService.itemsPerPage);
                    if (swipeable.currentIndex !== page) {
                        swipeable.setCurrentIndex(page);
                    }
                }
            }

            Repeater {
                model: AltTabService.windowPages

                Item {
                    id: windowPageItem
                    required property var modelData
                    required property int index
                    implicitWidth: swipeable.width
                    implicitHeight: swipeable.height
                    clip: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 32

                        Repeater {
                            model: windowPageItem.modelData

                            RowLayout {
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                spacing: 32

                                Repeater {
                                    model: parent.modelData

                                    Item {
                                        id: toplevelItem
                                        required property var modelData
                                        readonly property int flatIndex: AltTabService.getToplevelFlatIndex(modelData)
                                        readonly property bool isSelected: flatIndex === AltTabService.selectedIndex

                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        opacity: scv.hasContent ? 1 : 0
                                        visible: opacity !== 0

                                        Behavior on opacity {
                                            enabled: false
                                            NumberAnimation {
                                                duration: Theme.animations.duration.slower
                                                easing.type: Theme.animations.easing.outQuad
                                            }
                                        }

                                        StyledClippingRectangle {
                                            id: proportionalRect

                                            property bool isHovered: false
                                            readonly property size windowSize: scv.sourceSize
                                            readonly property real windowAspect: windowSize.width > 0 ? windowSize.width / windowSize.height : 1
                                            readonly property real containerAspect: toplevelItem.width > 0 ? toplevelItem.width / toplevelItem.height : 1

                                            anchors.centerIn: parent
                                            border.color: toplevelItem.isSelected ? Theme.colors.white : isHovered ? Theme.colors.textMuted : Theme.colors.borderMid
                                            border.width: 1
                                            color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgSurface, 0.6) : Theme.colors.bgSurface
                                            baseRadius: Theme.rounding.normal + 2

                                            width: {
                                                if (windowSize.width === 0 || windowSize.height === 0)
                                                    return toplevelItem.width;
                                                return (windowAspect > containerAspect) ? toplevelItem.width : toplevelItem.height * windowAspect;
                                            }

                                            height: {
                                                if (windowSize.width === 0 || windowSize.height === 0)
                                                    return toplevelItem.height;
                                                return (windowAspect > containerAspect) ? toplevelItem.width / windowAspect : toplevelItem.height;
                                            }

                                            ScreencopyView {
                                                id: scv
                                                anchors.fill: parent
                                                captureSource: toplevelItem.modelData.wayland
                                                live: root.show && swipeable.currentIndex === windowPageItem.index

                                                onHasContentChanged: {
                                                    if (hasContent) {
                                                        AltTabService.incrementLoadedViews();
                                                    }
                                                }
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: AltTabService.selectAndActivate(toplevelItem.flatIndex)
                                                onEntered: proportionalRect.isHovered = true
                                                onExited: proportionalRect.isHovered = false
                                            }
                                        }

                                        StyledIcon {
                                            iconName: AppUtils.getAppIcon(toplevelItem.modelData.lastIpcObject["initialClass"], [...new Set(DesktopEntries.applications.values)])
                                            iconSize: 24
                                            useIconTheme: true
                                            placeHolder: "applications-system"
                                            anchors.top: proportionalRect.top
                                            anchors.left: proportionalRect.left
                                            anchors.margins: 8
                                        }

                                        StyledRectangle {
                                            id: titleTag
                                            implicitHeight: titleText.implicitHeight + 12
                                            implicitWidth: Math.min(titleText.implicitWidth + 24, proportionalRect.width - 24)
                                            anchors.bottom: proportionalRect.bottom
                                            anchors.horizontalCenter: proportionalRect.horizontalCenter
                                            anchors.bottomMargin: 12
                                            color: Theme.colors.bgElevated
                                            baseRadius: height / 2
                                            border.width: 1
                                            border.color: Theme.colors.borderMid

                                            StyledText {
                                                id: titleText
                                                anchors.centerIn: parent
                                                text: toplevelItem.modelData.title
                                                font.pixelSize: Theme.fontPixelSizes.small
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                                width: parent.width - 16
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
}
