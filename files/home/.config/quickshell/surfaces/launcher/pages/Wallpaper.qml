pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components
import qs.services
import qs.surfaces.launcher.pages.components
import "../../../lib/ColorUtils.js" as ColorUtils
import "../../../lib/FileUtils.js" as FileUtils

BasePage {
    id: root
    placeHolder: "Search wallpapers..."
    currentItemPrimaryActionName: "Set Wallpaper"
    pageIcon: "image"
    pageIconType: "symbol"
    pageName: "Wallpapers"
    isLoading: root.imageLoadingCount > 0

    property var loadingSet: ({})
    readonly property int imageLoadingCount: Object.keys(loadingSet).length

    function setImageLoading(key, loading) {
        const has = key in loadingSet;
        if (loading === has)
            return;
        const copy = Object.assign({}, loadingSet);
        if (loading)
            copy[key] = true;
        else
            delete copy[key];
        loadingSet = copy; // reassign so bindings re-evaluate
    }

    onSearchTextChanged: WallpaperService.setQuery(searchText)

    Connections {
        target: WallpaperService
        function onItemsChanged() {
            Qt.callLater(root.syncCurrentWallpaperFocus);
        }
    }

    Component.onCompleted: {
        root.searchText = WallpaperService.query;
        WallpaperService.activate();
        Qt.callLater(syncCurrentWallpaperFocus);
    }

    function syncCurrentWallpaperFocus() {
        const index = WallpaperService.indexOfCurrentWallpaper();
        if (index !== -1) {
            gridView.currentIndex = index;
            if (index >= 6)
                gridView.positionViewAtIndex(Math.max(0, index - 3), GridView.Contain);
        } else {
            gridView.currentIndex = 0;
        }
    }

    function currentItem() {
        const items = WallpaperService.items;
        if (gridView.currentIndex >= 0 && gridView.currentIndex < items.length)
            return items[gridView.currentIndex];
        return null;
    }

    function primaryAction() {
        WallpaperService.primaryAction(currentItem());
    }

    function secondaryAction() {
        WallpaperService.secondaryAction(currentItem());
    }

    function nextItem() {
        gridView.moveCurrentIndexRight();
    }
    function previousItem() {
        gridView.moveCurrentIndexLeft();
    }
    function upItem() {
        gridView.moveCurrentIndexUp();
    }
    function downItem() {
        gridView.moveCurrentIndexDown();
    }
    function leftItem() {
        gridView.moveCurrentIndexLeft();
    }
    function rightItem() {
        gridView.moveCurrentIndexRight();
    }

    function selectItem(index) {
        WallpaperService.setColorIndex(index + 1);
    }

    // Content
    Item {
        anchors.fill: parent

        GridView {
            id: gridView
            anchors.fill: parent
            model: WallpaperService.items
            cellWidth: Math.floor(width / 3) & ~1 // Force even width to prevent sub-pixel rendering gaps
            cellHeight: cellWidth * 0.6
            clip: true
            focus: true

            header: Item {
                width: gridView.width
                visible: WallpaperService.itemCount !== 0
                height: visible ? 32 : 0

                StyledText {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    text: "Wallpapers"
                    font.pixelSize: Theme.fontPixelSizes.small
                    font.weight: Font.DemiBold
                    color: Theme.colors.textSecondary
                    opacity: 0.5
                }
            }

            footer: Item {
                width: gridView.width
                height: 94 // Height to accommodate dots (48) + spacing + margins
            }

            delegate: Item {
                id: itemDelegate
                required property var modelData
                required property int index

                readonly property string itemId: modelData.id ?? ""
                readonly property bool isReady: imageLoader.item?.status === Image.Ready
                readonly property bool isFinished: imageLoader.item && (imageLoader.item.status === Image.Ready || imageLoader.item.status === Image.Error)

                width: gridView.cellWidth
                height: gridView.cellHeight

                StyledRectangle {
                    id: wrapper
                    anchors.fill: parent
                    anchors.margins: 4
                    baseRadius: Theme.rounding.normal
                    color: "transparent"
                    readonly property bool isSelected: gridView.currentIndex === itemDelegate.index
                    readonly property bool isHovered: mouseArea.containsMouse

                    StyledClippingRectangle {
                        anchors.fill: parent
                        baseRadius: parent.radius + 1
                        color: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.25)

                        Loader {
                            id: imageLoader
                            anchors.fill: parent
                            asynchronous: true
                            sourceComponent: (modelData.animated ?? false) ? animatedDelegate : staticDelegate

                            Component {
                                id: staticDelegate
                                Image {
                                    readonly property bool loading: status === Image.Loading
                                    anchors.fill: parent
                                    source: itemDelegate.modelData.state === "ready" && itemDelegate.modelData.thumb !== "" ? "file://" + itemDelegate.modelData.thumb : ""
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: gridView.cellWidth * 2
                                    sourceSize.height: gridView.cellHeight * 2
                                    asynchronous: true
                                    cache: false
                                    opacity: itemDelegate.isReady ? 1 : 0
                                    visible: opacity > 0
                                    onLoadingChanged: root.setImageLoading(itemDelegate.itemId, loading)

                                    Component.onCompleted: root.setImageLoading(itemDelegate.itemId, loading)
                                    Component.onDestruction: root.setImageLoading(itemDelegate.itemId, false)

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.animations.duration.normal
                                            easing.type: Theme.animations.easing.outCubic
                                        }
                                    }
                                }
                            }

                            Component {
                                id: animatedDelegate
                                AnimatedImage {
                                    readonly property bool loading: status === AnimatedImage.Loading
                                    anchors.fill: parent
                                    source: "file://" + itemDelegate.modelData.image
                                    paused: !wrapper.isSelected
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: false
                                    sourceSize.width: gridView.cellWidth * 2
                                    sourceSize.height: gridView.cellHeight * 2
                                    opacity: itemDelegate.isReady ? 1 : 0
                                    visible: opacity > 0

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Theme.animations.duration.normal
                                            easing.type: Theme.animations.easing.outCubic
                                        }
                                    }

                                    onLoadingChanged: root.setImageLoading(itemDelegate.itemId, loading)

                                    Component.onCompleted: root.setImageLoading(itemDelegate.itemId, loading)
                                    Component.onDestruction: root.setImageLoading(itemDelegate.itemId, false)
                                }
                            }
                        }

                        // Loading overlay
                        StyledRectangle {
                            anchors.fill: parent
                            baseRadius: Theme.rounding.normal + 2
                            border.color: ColorUtils.transparentize(Theme.colors.borderDim, 0.72)
                            border.width: 1
                            color: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.25)
                            visible: !itemDelegate.isFinished

                            ActivityIndicator {
                                size: 54
                                anchors.centerIn: parent
                                running: true
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            visible: itemDelegate.isReady

                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop {
                                    position: 0.4
                                    color: "transparent"
                                }
                                GradientStop {
                                    position: 1.0
                                    color: ColorUtils.transparentize(Theme.colors.bgBase, 0.85)
                                }
                            }

                            StyledText {
                                text: itemDelegate.modelData.title
                                width: parent.width - 24
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 10
                                anchors.horizontalCenter: parent.horizontalCenter
                                elide: Text.ElideMiddle
                                color: Theme.colors.textSecondary
                                font.pixelSize: Theme.fontPixelSizes.smaller
                                font.weight: Font.Medium
                            }
                        }
                    }

                    StyledRectangle {
                        anchors.fill: parent
                        color: "transparent"
                        baseRadius: wrapper.radius
                        border.width: (wrapper.isSelected || (itemDelegate.isReady && wrapper.isHovered)) ? 2 : 1
                        border.color: wrapper.isSelected ? Theme.colors.white : wrapper.isHovered ? ColorUtils.transparentize(Theme.colors.white, 0.35) : Theme.colors.borderDim
                    }

                    MouseArea {
                        id: mouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: gridView.currentIndex = itemDelegate.index
                        onDoubleClicked: root.primaryAction()
                    }
                }
            }
        }

        EmptyState {
            anchors.fill: parent
            iconName: "image"
            text: `No wallpapers found at  "${FileUtils.trimFileProtocol(Paths.wallpaperDir)}"`
            visible: WallpaperService.itemCount === 0
        }

        AccentDots {}
    }
}
