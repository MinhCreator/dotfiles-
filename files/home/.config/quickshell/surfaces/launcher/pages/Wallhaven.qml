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

    placeHolder: "Search wallpapers on Wallhaven..."
    pageName: "Wallhaven"
    pageIcon: "image"
    pageIconType: "phosphor"
    currentItemPrimaryActionName: "Set Wallpaper"
    currentItemSecondaryActionName: "Save Wallpaper"
    isLoading: WallhavenService.isLoading
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
        if (isLoading && WallhavenService.totalResults === 0)
            gridView.positionViewAtBeginning();
    }

    onSearchTextChanged: {
        if (WallhavenService.setQuery(searchText))
            WallhavenService.searchDebounced();
    }

    Component.onCompleted: {
        WallhavenService.activate();
        root.searchText = WallhavenService.query;
    }

    function currentItem() {
        if (gridView.currentIndex !== -1)
            return WallhavenService.items.get(gridView.currentIndex);
        return null;
    }

    function primaryAction() {
        if (root.showKeySheet) {
            saveKeySheet();
            return;
        }
        WallhavenService.primaryAction(currentItem());
    }

    function secondaryAction() {
        if (root.showKeySheet) {
            saveKeySheet();
            return;
        }
        WallhavenService.secondaryAction(currentItem());
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
        keyField.text = GlobalSettings.wallpaperProviderKeys?.["wallhaven"] ?? "";
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
            delete keys["wallhaven"];
        else
            keys["wallhaven"] = t;
        GlobalSettings.wallpaperProviderKeys = keys;
        closeKeySheet();
        WallhavenService.fetch();
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

            // Categories
            Row {
                spacing: 6
                Repeater {
                    model: 3
                    delegate: StyledIconButton {
                        required property int index
                        property bool active: WallhavenService.categories[index] === "1"
                        iconName: ["public", "temple_buddhist", "group"][index]
                        iconSize: 22
                        width: height
                        alwaysShowBackground: active
                        backgroundColor: active ? Theme.colors.color8 : Theme.colors.gray5
                        backgroundTransparency: 0.60
                        color: active ? Theme.colors.white : Theme.colors.gray13
                        inactiveOpacity: active ? 1.0 : 0.35
                        onClicked: {
                            WallhavenService.toggleCategory(index);
                        }
                    }
                }
            }

            Separator {}

            // Purity
            Row {
                spacing: 6
                Repeater {
                    model: 3
                    delegate: StyledIconButton {
                        required property int index
                        property bool active: WallhavenService.purity[index] === "1"
                        iconName: ["shield", "draw", "error"][index]
                        iconSize: 22
                        width: height
                        alwaysShowBackground: active
                        backgroundColor: active ? Theme.colors.color8 : Theme.colors.gray5
                        backgroundTransparency: 0.60
                        color: active ? Theme.colors.white : Theme.colors.gray13
                        inactiveOpacity: active ? 1.0 : 0.35
                        onClicked: {
                            WallhavenService.togglePurity(index);
                        }
                    }
                }
            }

            Separator {}

            // Sorting
            StyledComboBox {
                id: sortingComboBox
                Layout.preferredWidth: 164
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                currentIndex: model.findIndex(item => item.value === WallhavenService.sorting)
                focusPolicy: Qt.NoFocus

                model: [
                    {
                        text: "Date Added",
                        value: "date_added",
                        icon: "calendar_month"
                    },
                    {
                        text: "Relevance",
                        value: "relevance",
                        icon: "swap_vert"
                    },
                    {
                        text: "Random",
                        value: "random",
                        icon: "shuffle"
                    },
                    {
                        text: "Views",
                        value: "visibility",
                        icon: "visibility"
                    },
                    {
                        text: "Favorites",
                        value: "favorite",
                        icon: "favorite"
                    },
                    {
                        text: "Toplist",
                        value: "toplist",
                        icon: "trending_up"
                    }
                ]

                onActivated: {
                    WallhavenService.sorting = model[sortingComboBox.currentIndex].value;
                    WallhavenService.fetchDebounced();
                }
            }

            Separator {
                visible: toprangeComboBox.visible
            }

            // Top Range (only if sorting is toplist)
            StyledComboBox {
                id: toprangeComboBox
                Layout.preferredWidth: 120
                Layout.preferredHeight: 38
                colorBg: ColorUtils.transparentize(Theme.colors.bgSurface, 0.50)
                visible: WallhavenService.sorting === "toplist"
                currentIndex: model.findIndex(item => item.value === WallhavenService.toprange)
                focusPolicy: Qt.NoFocus

                model: [
                    {
                        text: "1 Day",
                        value: "1d"
                    },
                    {
                        text: "1 Week",
                        value: "1w"
                    },
                    {
                        text: "1 Month",
                        value: "1m"
                    },
                    {
                        text: "3 Months",
                        value: "3m"
                    },
                    {
                        text: "6 Months",
                        value: "6m"
                    },
                    {
                        text: "1 Year",
                        value: "1y"
                    }
                ]

                onActivated: {
                    WallhavenService.toprange = model[toprangeComboBox.currentIndex].value;
                    WallhavenService.fetchDebounced();
                }
            }

            Separator {}

            // Order
            StyledIconButton {
                iconName: WallhavenService.order === "desc" ? "arrow_downward" : "arrow_upward"
                onClicked: {
                    WallhavenService.order = WallhavenService.order === "desc" ? "asc" : "desc";
                    WallhavenService.fetchDebounced();
                }
            }

            Separator {}

            // Refresh button
            StyledIconButton {
                iconName: "refresh"
                onClicked: WallhavenService.fetch()
                enabled: !WallhavenService.isLoading
            }

            // Retry failed thumbnails
            StyledIconButton {
                iconName: "cloud_sync"
                visible: WallhavenService.failedCount > 0
                enabled: !WallhavenService.thumbBusy
                onClicked: WallhavenService.retryAllFailed()
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
                model: WallhavenService.items
                cellWidth: Math.floor(width / 3) & ~1
                cellHeight: cellWidth * 0.6
                clip: true
                focus: true

                onContentYChanged: {
                    if (contentHeight > 0 && contentY + height > contentHeight * 0.8 && !WallhavenService.isLoading) {
                        WallhavenService.loadNextPage();
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
                                WallhavenService.requestAutoRetry(retryId);
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
                                    WallhavenService.retryThumb(itemDelegate.itemId);
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
                text: "No wallpapers found"
                visible: WallhavenService.itemCount === 0 && !WallhavenService.isLoading
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
                text: "Wallhaven API Key"
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
