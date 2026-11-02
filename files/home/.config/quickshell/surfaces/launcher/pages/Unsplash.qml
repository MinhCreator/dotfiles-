pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import qs.surfaces.launcher.pages.components
import "../../../lib/ColorUtils.js" as ColorUtils

BasePage {
    id: root

    placeHolder: "Search photos on Unsplash..."
    pageName: "Unsplash"
    pageIcon: "image"
    pageIconType: "phosphor"
    currentItemPrimaryActionName: "Set Wallpaper"
    currentItemSecondaryActionName: "Save Wallpaper"
    isLoading: UnsplashService.isLoading
    outerMargins: 0

    catchEscape: root.showKeySheet
    enableSearchbar: !root.showKeySheet

    property bool showKeySheet: false
    property bool showKeyText: false

    searchbarActions: [apiKeyAction]

    property Component apiKeyAction: Component {
        StyledIconButton {
            iconName: "key"
            implicitWidth: 42
            implicitHeight: 42
            onClicked: root.openKeySheet()
        }
    }

    component Separator: StyledRectangle {
        Layout.preferredWidth: 2
        Layout.preferredHeight: 24
        opacity: 0.15
        baseRadius: width / 2
    }

    onIsLoadingChanged: {
        if (isLoading && UnsplashService.totalResults === 0)
            gridView.positionViewAtBeginning();
    }

    onSearchTextChanged: {
        if (UnsplashService.setQuery(searchText))
            UnsplashService.searchDebounced();
    }

    Component.onCompleted: {
        UnsplashService.activate();
        root.searchText = UnsplashService.query;
    }

    function currentItem() {
        if (gridView.currentIndex !== -1)
            return UnsplashService.items.get(gridView.currentIndex);
        return null;
    }

    function primaryAction() {
        if (root.showKeySheet) {
            saveKeySheet();
            return;
        }
        UnsplashService.primaryAction(currentItem());
    }

    function secondaryAction() {
        if (root.showKeySheet) {
            saveKeySheet();
            return;
        }
        UnsplashService.secondaryAction(currentItem());
    }

    function escapeAction() {
        closeKeySheet();
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

    // API-key sheet
    function openKeySheet() {
        keyField.text = GlobalSettings.wallpaperProviderKeys?.["unsplash"] ?? "";
        root.showKeyText = false;
        root.showKeySheet = true;
        Qt.callLater(() => keyField.forceActiveFocus());
    }

    function closeKeySheet() {
        root.showKeySheet = false;
    }

    function saveKeySheet() {
        if (!root.showKeySheet)
            return;
        const keys = Object.assign({}, GlobalSettings.wallpaperProviderKeys || {});
        const t = keyField.text.trim();
        if (t === "")
            delete keys["unsplash"];
        else
            keys["unsplash"] = t;
        GlobalSettings.wallpaperProviderKeys = keys;
        closeKeySheet();
        UnsplashService.fetch();
        UnsplashService.fetchTopics();
    }

    // Content
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Filter Bar
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 8
            spacing: 10

            Item {
                Layout.fillWidth: true
            }

            // Topic
            StyledComboBox {
                id: topicComboBox
                Layout.preferredWidth: 160
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                focusPolicy: Qt.NoFocus
                currentIndex: {
                    const topics = UnsplashService.topics || [];
                    for (let i = 0; i < topics.length; i++) {
                        if ((topics[i].slug || topics[i].id) === UnsplashService.topic)
                            return i + 1;
                    }
                    return 0;
                }
                model: {
                    const topics = UnsplashService.topics || [];
                    let list = [{
                        text: "Search",
                        value: ""
                    }];
                    for (let i = 0; i < topics.length; i++) {
                        list.push({
                            text: topics[i].title || topics[i].slug || topics[i].id,
                            value: topics[i].slug || topics[i].id
                        });
                    }
                    return list;
                }

                onActivated: {
                    UnsplashService.topic = model[topicComboBox.currentIndex].value;
                    UnsplashService.fetch();
                }
            }

            Separator {}

            // Order (search mode)
            StyledComboBox {
                id: orderComboBox
                Layout.preferredWidth: 140
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                visible: UnsplashService.topic === ""
                currentIndex: model.findIndex(item => item.value === UnsplashService.orderBy)
                focusPolicy: Qt.NoFocus

                model: [
                    {
                        text: "Relevant",
                        value: "relevant"
                    },
                    {
                        text: "Latest",
                        value: "latest"
                    }
                ]

                onActivated: {
                    UnsplashService.orderBy = model[orderComboBox.currentIndex].value;
                    UnsplashService.fetchDebounced();
                }
            }

            // Order (topic mode)
            StyledComboBox {
                id: topicOrderComboBox
                Layout.preferredWidth: 140
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                visible: UnsplashService.topic !== ""
                currentIndex: model.findIndex(item => item.value === UnsplashService.topicOrderBy)
                focusPolicy: Qt.NoFocus

                model: [
                    {
                        text: "Latest",
                        value: "latest"
                    },
                    {
                        text: "Oldest",
                        value: "oldest"
                    },
                    {
                        text: "Popular",
                        value: "popular"
                    }
                ]

                onActivated: {
                    UnsplashService.topicOrderBy = model[topicOrderComboBox.currentIndex].value;
                    UnsplashService.fetchDebounced();
                }
            }

            Separator {}

            // Color
            StyledComboBox {
                id: colorComboBox
                Layout.preferredWidth: 140
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                visible: UnsplashService.topic === ""
                currentIndex: Math.max(0, model.findIndex(item => item.value === UnsplashService.color))
                focusPolicy: Qt.NoFocus

                model: [
                    {
                        text: "Any color",
                        value: ""
                    },
                    {
                        text: "B&W",
                        value: "black_and_white"
                    },
                    {
                        text: "Black",
                        value: "black"
                    },
                    {
                        text: "White",
                        value: "white"
                    },
                    {
                        text: "Yellow",
                        value: "yellow"
                    },
                    {
                        text: "Orange",
                        value: "orange"
                    },
                    {
                        text: "Red",
                        value: "red"
                    },
                    {
                        text: "Purple",
                        value: "purple"
                    },
                    {
                        text: "Magenta",
                        value: "magenta"
                    },
                    {
                        text: "Green",
                        value: "green"
                    },
                    {
                        text: "Teal",
                        value: "teal"
                    },
                    {
                        text: "Blue",
                        value: "blue"
                    }
                ]

                onActivated: {
                    UnsplashService.color = model[colorComboBox.currentIndex].value;
                    UnsplashService.fetchDebounced();
                }
            }

            Separator {
                visible: colorComboBox.visible
            }

            // Orientation
            StyledComboBox {
                id: orientationComboBox
                Layout.preferredWidth: 140
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                currentIndex: model.findIndex(item => item.value === UnsplashService.orientation)
                focusPolicy: Qt.NoFocus

                model: [
                    {
                        text: "Landscape",
                        value: "landscape"
                    },
                    {
                        text: "Portrait",
                        value: "portrait"
                    },
                    {
                        text: "Squarish",
                        value: "squarish"
                    }
                ]

                onActivated: {
                    UnsplashService.orientation = model[orientationComboBox.currentIndex].value;
                    UnsplashService.fetchDebounced();
                }
            }

            Separator {}

            // Refresh button
            StyledIconButton {
                iconName: "refresh"
                onClicked: UnsplashService.fetch()
                enabled: !UnsplashService.isLoading
            }

            // Retry failed thumbnails
            StyledIconButton {
                iconName: "cloud_sync"
                visible: UnsplashService.failedCount > 0
                enabled: !UnsplashService.thumbBusy
                onClicked: UnsplashService.retryAllFailed()
            }

            Item {
                Layout.fillWidth: true
            }
        }

        // Grid
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            GridView {
                id: gridView
                anchors.fill: parent
                model: UnsplashService.items
                cellWidth: Math.floor(width / 3) & ~1
                cellHeight: cellWidth * 0.6
                clip: true
                focus: true

                onContentYChanged: {
                    if (contentHeight > 0 && contentY + height > contentHeight * 0.8 && !UnsplashService.isLoading) {
                        UnsplashService.loadNextPage();
                    }
                }

                footer: Item {
                    width: gridView.width
                    height: 94
                }

                delegate: Item {
                    id: itemDelegate
                    required property int index
                    required property var modelData

                    readonly property string itemId: modelData.id ?? ""
                    readonly property string itemState: modelData.state ?? "ready"
                    readonly property bool isReady: itemState === "ready" && wallpaperImage.status === Image.Ready

                    // Failed cells retry themselves while on screen (bounded by maxAutoRetries).
                    // Capture id/state by value: the delegate may be recycled before callLater fires.
                    onItemStateChanged: {
                        const retryId = itemDelegate.itemId;
                        const retryState = itemDelegate.itemState;
                        Qt.callLater(() => {
                            if (retryState === "failed")
                                UnsplashService.requestAutoRetry(retryId);
                        });
                    }

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
                            baseRadius: parent.radius + 0
                            color: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.25)

                            Image {
                                id: wallpaperImage
                                anchors.fill: parent
                                source: itemDelegate.itemState === "ready" && itemDelegate.modelData.thumb !== "" ? "file://" + itemDelegate.modelData.thumb : ""
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
                            }

                            // Loading / failed overlay
                            StyledRectangle {
                                anchors.fill: parent
                                baseRadius: Theme.rounding.normal + 2
                                border.color: ColorUtils.transparentize(Theme.colors.borderDim, 0.72)
                                border.width: 1
                                color: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.25)
                                visible: !itemDelegate.isReady

                                ActivityIndicator {
                                    size: 54
                                    anchors.centerIn: parent
                                    running: itemDelegate.itemState === "loading"
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    visible: itemDelegate.itemState === "failed"

                                    MaterialSymbol {
                                        iconName: "cloud_off"
                                        iconSize: 42
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        color: Theme.colors.textMuted
                                    }

                                    StyledText {
                                        text: "Tap to retry"
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        font.pixelSize: Theme.fontPixelSizes.normal
                                        color: Theme.colors.textMuted
                                    }
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
                                    text: itemDelegate.modelData.badge !== "" ? `${itemDelegate.modelData.title} | ${itemDelegate.modelData.badge}` : itemDelegate.modelData.title
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
                            onClicked: {
                                if (itemDelegate.itemState === "failed") {
                                    UnsplashService.retryThumb(itemDelegate.itemId);
                                    return;
                                }
                                gridView.currentIndex = itemDelegate.index;
                            }
                            onDoubleClicked: root.primaryAction()
                        }
                    }
                }
            }

            EmptyState {
                anchors.fill: parent
                iconName: "image"
                text: (UnsplashService.topic === "" && UnsplashService.query.trim() === "") ? "Type something to search on Unsplash..." : "No photos found"
                visible: UnsplashService.itemCount === 0 && !UnsplashService.isLoading
            }

            AccentDots {}
        }
    }

    // API-key sheet
    Sheet {
        shown: root.showKeySheet
        onClosed: root.closeKeySheet()
        maxWidth: 480
        overlayZ: 20
        contentHeight: keySheetContent.implicitHeight

        ColumnLayout {
            id: keySheetContent
            anchors.fill: parent
            spacing: 12

            StyledText {
                text: "Unsplash API Key"
                font.pixelSize: Theme.fontPixelSizes.large
                font.weight: Font.DemiBold
            }

            StyledRectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                baseRadius: height / 2
                color: Theme.colors.gray1
                border.width: 1
                border.color: keyField.activeFocus ? Theme.colors.borderMid : ColorUtils.transparentize(Theme.colors.borderMid, 0.6)

                StyledTextField {
                    id: keyField
                    anchors.fill: parent
                    anchors.leftMargin: 18
                    anchors.rightMargin: 6
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "Paste API key..."
                    echoMode: root.showKeyText ? TextInput.Normal : TextInput.Password
                    passwordCharacter: "•"
                    font.family: Theme.fontFamilies.monospace
                    onAccepted: root.saveKeySheet()
                    Keys.onEscapePressed: event => {
                        event.accepted = true;
                        root.closeKeySheet();
                    }

                    actions: StyledIconButton {
                        iconName: root.showKeyText ? "visibility_off" : "visibility"
                        iconSize: 22
                        implicitWidth: 34
                        implicitHeight: 34
                        onClicked: {
                            root.showKeyText = !root.showKeyText;
                            keyField.forceActiveFocus();
                        }
                    }
                }
            }

            StyledButton {
                Layout.fillWidth: true
                implicitHeight: 42
                text: "Save"
                onClicked: root.saveKeySheet()
            }
        }
    }
}
