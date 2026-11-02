pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.components
import qs.surfaces.bar.modules.controlcenter
import qs
import "../../../lib/ColorUtils.js" as ColorUtils

BarModule {
    id: root
    name: "controlCenter"
    enableClickToExpand: false
    expandedWidth: 520
    expandedHeight: 634
    baseWidth: ControlCenterService.model.count * (Theme.sizes.barModuleBaseHeight + 4.8)
    onIsExpandedChanged: {
        if (isExpanded) {
            ControlCenterService._syncBarModel();
            ControlCenterService.refreshExpandedList();
        }
    }

    // Bar content
    initialContent: Item {
        ListView {
            id: barListView
            anchors.fill: parent
            anchors.margins: 2
            orientation: ListView.Horizontal
            spacing: (width - (count * height)) / (count - 1)
            model: ControlCenterService.model
            interactive: false
            highlightMoveDuration: 0
            highlightResizeDuration: 0

            Binding {
                target: barListView
                property: "currentIndex"
                value: ControlCenterService.currentBarIndex
            }

            Timer {
                interval: Theme.animations.duration.slower
                running: true
                repeat: false
                onTriggered: barListView.highlightMoveDuration = Theme.animations.duration.slower
            }

            highlight: StyledRectangle {
                width: barListView.height
                height: barListView.height
                baseRadius: height / 2
                color: ColorUtils.transparentize(Theme.colors.color8, 0.60)
            }

            moveDisplaced: Transition {
                NumberAnimation {
                    properties: "x"
                    duration: Theme.animations.duration.slower
                    easing.type: Theme.animations.easing.outExpo
                }
            }
            move: Transition {
                NumberAnimation {
                    properties: "x"
                    duration: Theme.animations.duration.slower
                    easing.type: Theme.animations.easing.outExpo
                }
            }

            delegate: Item {
                id: barIconDelegate
                required property int index
                required property string moduleId
                readonly property bool isCurrentItem: ListView.isCurrentItem

                readonly property var def: ControlCenterService.moduleDefs.find(m => m.id === moduleId)
                readonly property bool active: ControlCenterService.activeFor(moduleId)
                onActiveChanged: ControlCenterService.onActiveChanged(moduleId)

                width: barListView.height
                height: barListView.height
                opacity: active || isCurrentItem ? 1.0 : 0.35

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.slower
                        easing.type: Theme.animations.easing.outExpo
                    }
                }

                StyledRectangle {
                    id: hoverRect
                    width: parent.height
                    height: parent.height
                    anchors.centerIn: parent
                    baseRadius: height / 2
                    color: "transparent"

                    StyledRectangle {
                        visible: barIconDelegate.isCurrentItem
                        anchors.fill: parent
                        baseRadius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: ColorUtils.transparentize(Theme.colors.white, 0.10)
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.animations.duration.slower
                            easing.type: Theme.animations.easing.outExpo
                        }
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    color: barIconDelegate.isCurrentItem && !barIconDelegate.active ? Theme.colors.color12 : ControlCenterService.activeColorFor(barIconDelegate.moduleId)
                    iconName: ControlCenterService.statusIconFor(barIconDelegate.moduleId)
                    filled: ControlCenterService.filledStateFor(barIconDelegate.moduleId)
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: barIconDelegate.def.interactive
                    hoverEnabled: true
                    cursorShape: barIconDelegate.def.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton)
                            ControlCenterService.onLeftClickFor(barIconDelegate.moduleId, root.name);
                    }

                    onHoveredChanged: {
                        if (containsMouse && barIconDelegate.def.interactive)
                            hoverRect.color = ColorUtils.transparentize(Theme.colors.color16, 0.10);
                        else
                            hoverRect.color = "transparent";
                    }
                }
            }
        }
    }

    // Expanded content
    expandedContent: Item {
        id: expandedContentItem
        Component.onCompleted: forceActiveFocus()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Tab) {
                ControlCenterService.currentExpandableIndex = Math.min(ControlCenterService.currentExpandableIndex + 1, ControlCenterService.expandableModules.length - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                ControlCenterService.currentExpandableIndex = Math.max(ControlCenterService.currentExpandableIndex - 1, 0);
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = false
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 8

            // Tab bar
            StyledTabBar {
                id: styledTabBar
                Layout.fillWidth: true
                Layout.preferredHeight: 36
                Layout.topMargin: 10

                entries: ControlCenterService.expandableModules
                currentIndex: ControlCenterService.currentExpandableIndex
                onClicked: index => ControlCenterService.currentExpandableIndex = index

                activeColor: ColorUtils.transparentize(Theme.colors.white, 0.15)
                hoveredColor: ColorUtils.transparentize(Theme.colors.white, 0.07)
                iconName: entry => entry.expandedIcon
                entryText: entry => entry.name
                iconSize: 24
                spacing: 6

                Binding {
                    target: styledTabBar
                    property: "currentIndex"
                    value: ControlCenterService.currentExpandableIndex
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: ColorUtils.transparentize(Theme.colors.white, 0.15)
            }

            // Content
            SwipeView {
                id: swipeView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                currentIndex: ControlCenterService.currentExpandableIndex
                Component.onCompleted: contentItem.highlightMoveDuration = 200

                onCurrentIndexChanged: {
                    if (currentIndex !== -1 && currentIndex !== ControlCenterService.currentExpandableIndex && (contentItem.moving || contentItem.dragging))
                        ControlCenterService.currentExpandableIndex = currentIndex;
                }

                Connections {
                    target: ControlCenterService
                    function onCurrentExpandableIndexChanged() {
                        if (swipeView.currentIndex !== ControlCenterService.currentExpandableIndex)
                            swipeView.currentIndex = ControlCenterService.currentExpandableIndex;
                    }
                }

                Repeater {
                    model: ControlCenterService.expandableModules
                    delegate: Loader {
                        required property var modelData

                        // Expose SwipeView attached props as regular properties
                        readonly property bool isCurrent: SwipeView.isCurrentItem
                        readonly property bool isNext: SwipeView.isNextItem
                        readonly property bool isPrevious: SwipeView.isPreviousItem

                        sourceComponent: ControlCenterService.pageMap[modelData.id] ?? null
                        active: isCurrent || isNext || isPrevious || false

                        // Push isCurrent into the loaded component whenever it changes
                        onIsCurrentChanged: {
                            if (item && item.hasOwnProperty("isCurrentItem"))
                                item.isCurrentItem = isCurrent;
                        }
                        onLoaded: {
                            if (item.hasOwnProperty("isCurrentItem"))
                                item.isCurrentItem = isCurrent;
                        }
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: event => event.accepted = true
            z: -1
        }
    }
}
