pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import qs.surfaces.launcher
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Search for apps, pages and commands..."
    currentItemPrimaryActionName: layout.listView.currentItem?.modelData?.showIndicator ? "Focus Application" : "Open Application"
    pageIcon: "sort"
    pageIconType: "symbol"
    pageName: "Home"

    function _dispatchAction(isPrimary) {
        const item = layout.listView.currentItem?.modelData;
        if (!item)
            return;
        if (item.type === "application") {
            if (isPrimary)
                item.primaryAction?.();
            else
                item.secondaryAction?.();
            return;
        }
        const pool = item.type === "page" ? LauncherService.pages : item.type === "command" ? LauncherService.commands : null;
        const target = pool?.find(x => x.id === item.id);
        if (!target)
            return;
        if (isPrimary)
            target.primaryAction?.();
        else
            target.secondaryAction?.();
    }

    function primaryAction() {
        root._dispatchAction(true);
    }

    function secondaryAction() {
        root._dispatchAction(false);
    }

    function selectItem(index) {
        if (index < layout.listView.count) {
            root.selectionAnchored = true;
            layout.listView.currentIndex = index;
            primaryAction();
        }
    }

    function nextItem() {
        root.selectionAnchored = true;
        layout.moveNext();
    }

    function previousItem() {
        root.selectionAnchored = true;
        layout.movePrevious();
    }

    property bool selectionAnchored: false

    Connections {
        target: HomeService
        function onHomeItemsChanged() {
            if (!root.selectionAnchored && layout.listView.count > 0)
                layout.listView.currentIndex = 0;
        }
    }

    onSearchTextChanged: {
        root.selectionAnchored = false;
        HomeService.searchText = root.searchText;
        layout.resetToTopInstant();
    }

    Component.onDestruction: HomeService.searchText = ""

    property bool _primed: false

    // needed to fix some problems when doing this sequence
    // clipboard -> scrolling entries -> quick double shift+escape -> home with view list at wrong place
    function onShown() {
        const list = layout.listView;
        if (list.count === 0)
            return;
        let targetIndex = Math.min(Math.max(list.currentIndex, 0), list.count - 1);
        if (!root._primed) {
            root._primed = true;
            root.selectionAnchored = false;
            targetIndex = 0;
        } else if (!root.selectionAnchored) {
            targetIndex = 0;
        }
        layout.highlightMoveEnabled = false;
        list.smoothScrollEnabled = false;
        list.currentIndex = targetIndex;

        let attempts = 0;
        const place = () => {
            if (list.height <= 0 && attempts < 10) {
                attempts++;
                Qt.callLater(place);
                return;
            }
            if (targetIndex === 0)
                list.contentY = list.originY;
            else
                list.positionViewAtIndex(targetIndex, ListView.Contain);
            Qt.callLater(() => {
                list.smoothScrollEnabled = true;
                layout.highlightMoveEnabled = true;
            });
        };
        Qt.callLater(place);
    }

    ListLayout {
        id: layout
        model: ScriptModel {
            values: HomeService.homeItems
            objectProp: "id"
            comparisonMode: ObjectComparison.Identity
        }
        isEmpty: HomeService.homeItems.length === 0
        emptyIcon: "home"
        emptyText: "No results found"

        headerComponent: Component {
            SectionHeader {
                title: root.searchText.trim() === "" ? "Suggestions" : `Results (${HomeService.homeItems.length})`
            }
        }

        delegate: ListItemBackground {
            id: itemDelegate
            required property var modelData
            required property int index
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.margins: 2
                anchors.leftMargin: 6
                anchors.rightMargin: 8
                spacing: 4

                ColumnLayout {
                    spacing: 2

                    Loader {
                        id: iconLoader
                        active: true
                        sourceComponent: switch (itemDelegate.modelData.iconType) {
                        case "material":
                            return materialIcon;
                        case "symbolic":
                            return symbolicIcon;
                        case "theme":
                            return themeIcon;
                        }

                        Component {
                            id: materialIcon
                            MaterialSymbol {
                                iconName: itemDelegate.modelData.icon
                                iconSize: 30
                                color: Theme.colors.white
                            }
                        }

                        Component {
                            id: symbolicIcon
                            SymbolicIcon {
                                iconName: itemDelegate.modelData.icon
                                iconSize: 32
                                color: Theme.colors.white
                            }
                        }

                        Component {
                            id: themeIcon
                            StyledIcon {
                                iconName: itemDelegate.modelData.icon
                                iconSize: 32
                                placeHolder: "applications-system"
                                useIconTheme: true
                                replacements: ({
                                        "network-wired": "preferences-system-network" // Avahi stuffs
                                    })
                            }
                        }
                    }

                    StyledRectangle {
                        Layout.preferredWidth: 4
                        Layout.preferredHeight: 4
                        baseRadius: height / 2
                        color: Theme.colors.white
                        visible: itemDelegate.modelData.showIndicator
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                StyledText {
                    id: nameText
                    text: itemDelegate.modelData.name ?? ""
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.DemiBold
                }

                StyledText {
                    id: descriptionText
                    text: itemDelegate.modelData.description
                    font.pixelSize: Theme.fontPixelSizes.smaller
                    font.weight: Font.Normal
                    color: Theme.colors.textSecondary
                    opacity: 0.85
                    Layout.maximumWidth: parent.width - nameText.implicitWidth - typeText.implicitWidth - 80
                    Layout.leftMargin: 4
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    id: typeText
                    text: itemDelegate.modelData.type.charAt(0).toUpperCase() + itemDelegate.modelData.type.slice(1)
                    font.pixelSize: Theme.fontPixelSizes.small + 1
                    font.weight: Font.DemiBold
                    color: Theme.colors.textPrimary
                    Layout.preferredWidth: implicitWidth
                }
            }
        }
    }
}
