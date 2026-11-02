pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.SystemTray
import qs
import qs.components
import qs.surfaces.bar.modules.controlcenter.components
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root
    property var selectedItem: SystemTray.items.values[0] ?? null

    onSelectedItemChanged: {
        menuStack.clear();
        if (selectedItem) {
            menuStack.push(menuPageComponent, {
                menuHandle: selectedItem.menu,
                title: selectedItem.title,
                isRoot: true
            });
        }

        if (selectedItem && SystemTray.items.indexOf(selectedItem) === -1) {
            selectedItem = null;
        }
    }

    // Empty state
    ControlCenterEmptyState {
        iconName: "web_asset"
        anchors.fill: parent
        shown: root.selectedItem === null || SystemTray.items.values.length === 0
        centerOffset: SystemTray.items.values.length === 0 ? 0 : (leftSection.width + contentRow.spacing) / 2
        text: SystemTray.items.values.length === 0 ? "No active tray applications" : "Select an application"
    }

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
                text: "System Tray"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // Body: icon sidebar + detail panel
        RowLayout {
            id: contentRow
            Layout.fillWidth: true
            Layout.fillHeight: true

            visible: SystemTray.items.values.length > 0

            spacing: 16

            // Left: icon list
            Rectangle {
                id: leftSection
                Layout.preferredWidth: 54
                Layout.fillHeight: true
                color: "transparent"

                StyledListView {
                    id: iconList
                    anchors.fill: parent
                    model: SystemTray.items.values
                    spacing: 8
                    showScrollBar: false

                    delegate: StyledRectangle {
                        id: iconDelegate
                        required property SystemTrayItem modelData
                        property bool isSelected: iconDelegate.modelData === root.selectedItem
                        property bool isHovered: false

                        width: iconList.width
                        height: width
                        baseRadius: width / 3.0
                        color: isHovered ? ColorUtils.transparentize(Theme.colors.white, 0.075) : isSelected ? ColorUtils.transparentize(Theme.colors.white, 0.15) : "transparent"
                        border.color: isHovered || isSelected ? Theme.colors.borderFrame : "transparent"
                        border.width: 1

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.animations.duration.standard
                                easing.type: Theme.animations.easing.outQuad
                            }
                        }

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.animations.duration.standard
                                easing.type: Theme.animations.easing.outQuad
                            }
                        }

                        SymbolicIcon {
                            anchors.centerIn: parent
                            iconName: iconDelegate.modelData.icon
                            iconSize: 24
                            useProtocol: true
                            useColor: false
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.selectedItem !== iconDelegate.modelData)
                                    root.selectedItem = iconDelegate.modelData;
                            }
                            onEntered: iconDelegate.isHovered = true
                            onExited: iconDelegate.isHovered = false
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.preferredWidth: 1
                Layout.fillHeight: true
                color: ColorUtils.transparentize(Theme.colors.white, 0.1)
            }

            // Right: detail / entries panel
            Item {
                id: rightSection
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true

                // Detail view when an item is selected
                StackView {
                    id: menuStack
                    anchors.fill: parent
                    visible: root.selectedItem !== null

                    pushEnter: Transition {
                        NumberAnimation {
                            property: "x"
                            from: menuStack.width
                            to: 0
                            duration: Theme.animations.duration.slower
                            easing.type: Theme.animations.easing.outCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.animations.duration.slower
                        }
                    }
                    pushExit: Transition {
                        NumberAnimation {
                            property: "x"
                            from: 0
                            to: -menuStack.width
                            duration: Theme.animations.duration.slower
                            easing.type: Theme.animations.easing.outCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: Theme.animations.duration.slower
                        }
                    }
                    popEnter: Transition {
                        NumberAnimation {
                            property: "x"
                            from: -menuStack.width
                            to: 0
                            duration: Theme.animations.duration.slower
                            easing.type: Theme.animations.easing.outCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 0
                            to: 1
                            duration: Theme.animations.duration.slower
                        }
                    }
                    popExit: Transition {
                        NumberAnimation {
                            property: "x"
                            from: 0
                            to: menuStack.width
                            duration: Theme.animations.duration.slower
                            easing.type: Theme.animations.easing.outCubic
                        }
                        NumberAnimation {
                            property: "opacity"
                            from: 1
                            to: 0
                            duration: Theme.animations.duration.slower
                        }
                    }
                }
            }
        }
    }

    Component {
        id: menuPageComponent

        ColumnLayout {
            id: pageRoot
            required property var menuHandle
            required property string title
            property bool isRoot: false

            spacing: 12

            // Header for the page
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                StyledIconButton {
                    visible: !pageRoot.isRoot
                    iconName: "chevron_left"
                    iconSize: 20
                    onClicked: menuStack.pop()
                }

                SymbolicIcon {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    iconName: root.selectedItem ? root.selectedItem.icon : ""
                    useProtocol: true
                    useColor: false
                    iconSize: 32
                    visible: pageRoot.isRoot
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    Layout.minimumHeight: Layout.preferredHeight
                    Layout.maximumHeight: Layout.preferredHeight
                    spacing: 0

                    StyledText {
                        text: pageRoot.title
                        font.pixelSize: Theme.fontPixelSizes.normal
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignLeft
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: root.selectedItem ? root.selectedItem.tooltipDescription : ""
                        font.pixelSize: Theme.fontPixelSizes.smaller
                        color: Theme.colors.textSecondary
                        horizontalAlignment: Text.AlignLeft
                        maximumLineCount: 1
                        visible: pageRoot.isRoot && root.selectedItem && root.selectedItem.tooltipDescription !== ""
                        Layout.fillWidth: true
                    }
                }
            }

            // Action buttons (only on root page)
            RowLayout {
                Layout.fillWidth: true
                visible: pageRoot.isRoot && root.selectedItem && !root.selectedItem.onlyMenu
                spacing: 8

                StyledButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    backgroundColor:  ColorUtils.transparentize(Theme.colors.white, 0.20)
                    implicitHeight: 36
                    text: "Activate"
                    textPixelSize: Theme.fontPixelSizes.small
                    onClicked: if (root.selectedItem) {
                        GlobalStates.expandedBarModule = "";
                        root.selectedItem.activate();
                    }
                }

                StyledButton {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    backgroundColor:  ColorUtils.transparentize(Theme.colors.white, 0.20)
                    implicitWidth: 36
                    implicitHeight: 36
                    text: ""
                    iconName: "more_horiz"
                    iconSize: 22
                    onClicked: if (root.selectedItem)
                        root.selectedItem.secondaryActivate()
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 1
                color: ColorUtils.transparentize(Theme.colors.white, 0.1)
                visible: pageRoot.isRoot && root.selectedItem && root.selectedItem.hasMenu
            }

            // Menu list
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                QsMenuOpener {
                    id: menuOpener
                    menu: pageRoot.menuHandle
                }

                StyledListView {
                    anchors.fill: parent
                    model: menuOpener.children
                    spacing: 2
                    showScrollBar: false
                    animationsEnabled: false

                    delegate: Item {
                        id: menuDelegate
                        required property var modelData
                        width: ListView.view.width
                        height: modelData.isSeparator ? 9 : 38

                        // Separator
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            height: 1
                            color: ColorUtils.transparentize(Theme.colors.white, 0.1)
                            visible: menuDelegate.modelData.isSeparator
                        }

                        // Regular menu entry
                        StyledRectangle {
                            anchors.fill: parent
                            baseRadius: Theme.rounding.small
                            color: entryMouse.containsMouse ? ColorUtils.transparentize(Theme.colors.white, 0.1175) : "transparent"
                            visible: !menuDelegate.modelData.isSeparator
                            border.color: Theme.colors.borderFrame
                            border.width: entryMouse.containsMouse ? 1 : 0

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 6

                                // Checkbox / radio indicator
                                StyledCheckBox {
                                    size: 22
                                    enabled: menuDelegate.modelData.enabled
                                    visible: QsMenuButtonType.toString(menuDelegate.modelData.buttonType) === "CheckBox"
                                    checkState: menuDelegate.modelData.checkState
                                }

                                // Radio button (custom implementation)
                                StyledRectangle {
                                    Layout.preferredWidth: 18
                                    Layout.preferredHeight: 18
                                    baseRadius: 9
                                    border.width: 1.5
                                    border.color: (menuDelegate.modelData.checked ?? false) ? Theme.colors.primary : ColorUtils.transparentize(Theme.colors.white, 0.3)
                                    color: "transparent"
                                    visible: QsMenuButtonType.toString(menuDelegate.modelData.buttonType) === "RadioButton"

                                    StyledRectangle {
                                        anchors.centerIn: parent
                                        width: 10
                                        height: 10
                                        baseRadius: 5
                                        color: Theme.colors.primary
                                        visible: menuDelegate.modelData.checked ?? false
                                    }
                                }

                                SymbolicIcon {
                                    iconName: {
                                        if (menuDelegate.modelData.icon.startsWith("file://"))
                                            return menuDelegate.modelData.icon.slice(7);
                                        if (menuDelegate.modelData.icon.length > 13)
                                            return menuDelegate.modelData.icon.slice(13);
                                        return menuDelegate.modelData.icon || "";
                                    }
                                    iconSize: 24
                                    usePlaceHolder: false
                                    useColor: false
                                    opacity: (menuDelegate.modelData.enabled ?? true) ? 1.0 : 0.4
                                }

                                StyledText {
                                    text: menuDelegate.modelData.text || ""
                                    font.pixelSize: Theme.fontPixelSizes.normal
                                    font.weight: Font.Medium
                                    horizontalAlignment: Text.AlignLeft
                                    opacity: (menuDelegate.modelData.enabled ?? true) ? 1.0 : 0.4
                                    Layout.fillWidth: true
                                }

                                MaterialSymbol {
                                    visible: menuDelegate.modelData.hasChildren
                                    iconName: "chevron_right"
                                    iconSize: 16
                                    opacity: 0.5
                                }
                            }

                            MouseArea {
                                id: entryMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                enabled: menuDelegate.modelData.enabled
                                visible: enabled
                                onClicked: {
                                    if (menuDelegate.modelData.hasChildren) {
                                        menuStack.push(menuPageComponent, {
                                            menuHandle: menuDelegate.modelData,
                                            title: menuDelegate.modelData.text,
                                            isRoot: false
                                        });
                                    } else {
                                        menuDelegate.modelData.triggered();
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
