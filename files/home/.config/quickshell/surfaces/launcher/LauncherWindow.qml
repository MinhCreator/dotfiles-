pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.surfaces.launcher
import "../../lib/ColorUtils.js" as ColorUtils

PanelWindow {
    id: root

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "quickshell:launcher"
    implicitWidth: 1000
    implicitHeight: 750

    property Item currentPage: null

    function showItem(item) {
        if (!item)
            return;
        if (root.currentPage && root.currentPage !== item)
            root.currentPage.visible = false;
        if (item.parent !== pageHost)
            item.parent = pageHost;
        item.anchors.fill = pageHost;
        item.visible = true;
        root.currentPage = item;
        if (item.pageName !== undefined)
            GlobalStates.currentLauncherPage = item.pageName;
        const shown = item;
        Qt.callLater(() => {
            if (GlobalStates.showLauncher && LauncherService.currentItem === shown && shown.onShown)
                shown.onShown();
        });
    }

    StyledClippingRectangle {
        id: container
        width: 868
        height: 568
        shadow: true
        color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.85) : Theme.colors.bgBase
        focus: !searchbar.visible || !searchbar.enabled
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -48
        baseRadius: Theme.rounding.large
        border.color: Theme.colors.borderFrameMid
        border.width: 1

        property bool ctrlPressed: false

        scale: GlobalStates.showLauncher ? 1.0 : 0.95
        opacity: GlobalStates.showLauncher ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animations.duration.fast
                easing.type: Theme.animations.easing.outCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.fast
                easing.type: Theme.animations.easing.outCubic
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Control) {
                LauncherService.ctrlHolded = true;
            }

            if (event.key === Qt.Key_Escape) {
                if (event.modifiers & Qt.ShiftModifier) {
                    const currentItem = LauncherService.currentItem;
                    if (currentItem && currentItem.catchEscape) {
                        currentItem.escapeAction();
                    } else if (currentItem && currentItem.searchText !== "") {
                        currentItem.searchText = "";
                    } else if (LauncherService.stack.length > 1) {
                        LauncherService.pop();
                    } else {
                        GlobalStates.showLauncher = false;
                        LauncherService.reset();
                    }
                    event.accepted = true;
                } else {
                    GlobalStates.showLauncher = false;
                    LauncherService.reset();
                    event.accepted = true;
                }
                return;
            }

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (root.currentPage) {
                    if (event.modifiers & Qt.ControlModifier) {
                        root.currentPage.secondaryAction();
                    } else {
                        root.currentPage.primaryAction();
                    }
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_Tab) {
                if (root.currentPage)
                    root.currentPage.nextItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                if (root.currentPage)
                    root.currentPage.previousItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Down) {
                if (root.currentPage)
                    root.currentPage.downItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Up) {
                if (root.currentPage)
                    root.currentPage.upItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Right) {
                if (root.currentPage)
                    root.currentPage.rightItem();
                event.accepted = true;
            } else if (event.key === Qt.Key_Left) {
                if (root.currentPage)
                    root.currentPage.leftItem();
                event.accepted = true;
            } else if (event.modifiers & Qt.ControlModifier) {
                if (root.currentPage) {
                    if (event.key === Qt.Key_H) {
                        root.currentPage.leftItem();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_J) {
                        root.currentPage.downItem();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_K) {
                        root.currentPage.upItem();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_L) {
                        root.currentPage.rightItem();
                        event.accepted = true;
                    } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
                        root.currentPage.selectItem(event.key - Qt.Key_1);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_N) {
                        root.currentPage.nextItem();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_P) {
                        root.currentPage.previousItem();
                        event.accepted = true;
                    }
                }
            }
        }

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Control) {
                LauncherService.ctrlHolded = false;
                event.accepted = true;
            }
        }

        Component.onCompleted: {
            LauncherService.ctrlHolded = false;
        }

        // Searchbar disabled overlay
        Rectangle {
            anchors.top: mainColumn.top
            width: mainColumn.width
            height: mainColumn.height - content.height
            color: !searchbar.enabled && LauncherService.currentItem?.showSearchbarOverlay ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animations.duration.normal
                }
            }
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            spacing: 0

            // Searchbar
            StyledTextField {
                id: searchbar
                Layout.fillWidth: true
                Layout.minimumHeight: 60
                Layout.margins: 15
                Layout.topMargin: 12
                Layout.bottomMargin: 0
                Layout.leftMargin: 20
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.Medium
                placeholderText: LauncherService.currentItem ? LauncherService.currentItem.placeHolder : ""
                visible: LauncherService.currentItem ? LauncherService.currentItem.showSearchbar : false
                enabled: LauncherService.currentItem ? LauncherService.currentItem.enableSearchbar : false
                text: LauncherService.currentItem ? LauncherService.currentItem.searchText : ""
                focus: visible && enabled
                Keys.forwardTo: [container]

                actions: Repeater {
                    model: LauncherService.currentItem ? LauncherService.currentItem.searchbarActions : []
                    delegate: Loader {
                        required property var modelData
                        sourceComponent: modelData
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                onTextChanged: {
                    if (LauncherService.currentItem && text !== LauncherService.currentItem.searchText) {
                        LauncherService.currentItem.searchText = text;
                    }
                }

                Component.onCompleted: {
                    searchbar.select(0, searchbar.text.length);
                }

                Connections {
                    target: LauncherService
                    function onCurrentItemChanged() {
                        if (LauncherService.currentItem) {
                            searchbar.select(0, searchbar.text.length);
                        }
                    }
                }
            }

            // Separator
            Rectangle {
                id: separator
                Layout.fillWidth: true
                Layout.preferredHeight: 2
                Layout.leftMargin: 1
                Layout.rightMargin: 1
                color: ColorUtils.transparentize(Theme.colors.borderDim, 0.2)
                clip: true

                // The moving highlight
                LoadingIndicator {
                    containerWidth: separator.width
                    indicatorColor: (root.currentPage && root.currentPage.loadingBarColor) || Theme.colors.color12
                    isLoading: (root.currentPage && root.currentPage.isLoading) ?? false
                }
            }

            // Content
            Item {
                id: content
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: root.currentPage ? root.currentPage?.outerMargins : 12
                Layout.topMargin: searchbar.visible ? 0 : (root.currentPage ? root.currentPage.outerMargins : 12)

                Item {
                    id: pageHost
                    anchors.fill: parent
                }

                Connections {
                    target: LauncherService
                    function onPushed(item, replace) {
                        root.showItem(item);
                    }
                    function onPopped() {
                        root.showItem(LauncherService.currentItem);
                    }
                    function onResetStack() {
                        root.showItem(LauncherService.currentItem);
                    }
                }

                Component.onCompleted: root.showItem(LauncherService.currentItem)
            }
        }
    }
}
