pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.services
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/DateUtils.js" as DateUtils
import "../../../lib/ColorUtils.js" as ColorUtils
import "../../../lib/StringUtils.js" as StringUtils

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Type to filter clipboard entries..."
    currentItemPrimaryActionName: "Copy"
    currentItemSecondaryActionName: "Pin / Unpin"
    pageIcon: "content_paste"
    pageIconType: "symbol"
    pageName: "Clipboard History"

    property bool showPinned: false
    property var displayedModel: ClipboardService.filteredHistory.filter(e => e.isPinned === root.showPinned)
    readonly property string focusedMime: ClipboardService.focusedItem ? (ClipboardService.focusedItem.mime || "") : ""
    readonly property string focusedKind: ClipboardService.focusedItem ? (ClipboardService.focusedItem.kind || "text") : ""
    readonly property bool focusedIsImage: root.focusedKind === "image"
    readonly property bool focusedIsGif: root.focusedMime === "image/gif"
    readonly property bool imageReady: root.focusedIsImage && ClipboardService.focusedFilePath !== ""

    property Component showPinnedAction: Component {
        StyledIconButton {
            iconName: "push_pin"
            inactiveOpacity: root.showPinned ? 1 : 0.35
            implicitWidth: 42
            implicitHeight: 42
            onClicked: root.leftItem()
        }
    }

    property Component wipeAction: Component {
        StyledIconButton {
            iconName: "delete_sweep"
            inactiveOpacity: 0.35
            implicitWidth: 42
            implicitHeight: 42
            onClicked: {
                GlobalStates.showLauncher = false;
                GlobalIpc.dialog.showConfirm("Clear clipboard history", "This deletes all entries, including pinned ones. Are you sure?", "Cancel", "Clear", "", "qs ipc call clipboard wipe");
            }
        }
    }

    searchbarActions: [showPinnedAction, wipeAction]

    onDisplayedModelChanged: layout.resetToTopInstant()

    onSearchTextChanged: {
        ClipboardService.searchText = root.searchText;
        layout.resetToTopInstant();
    }

    Component.onCompleted: {
        ClipboardService.reload();
    }

    Component.onDestruction: ClipboardService.searchText = ""

    function togglePinnedEntries() {
        root.showPinned = !root.showPinned;
        layout.resetToTopInstant();
    }

    function leftItem() {
        togglePinnedEntries();
    }

    function rightItem() {
        togglePinnedEntries();
    }

    function primaryAction() {
        ClipboardService.copyFocused();
        GlobalIpc.popup.showInfo("Copied to clipboard", "", 1000);
        GlobalStates.showLauncher = false;
    }

    function secondaryAction() {
        const item = ClipboardService.focusedItem;
        if (!item)
            return;
        const isPinned = ClipboardService.togglePinFocused();
        GlobalIpc.popup.showInfo(isPinned ? "Pinned entry" : "Unpinned entry", "", 1000);
    }

    SplitLayout {
        id: layout

        model: ScriptModel {
            values: root.displayedModel
            objectProp: "id"
            comparisonMode: ObjectComparison.Identity
            onValuesChanged: layout.resetToTopInstant()
        }

        headerComponent: Component {
            SectionHeader {
                title: (root.showPinned ? "Pinned" : "History") + ` (${root.displayedModel.length})`
            }
        }

        delegate: ListItemBackground {
            id: historyItem
            required property var modelData
            required property int index
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                MaterialSymbol {
                    iconName: historyItem.modelData.isPinned ? "push_pin" : "content_copy"
                    iconSize: 24
                    color: historyItem.selected ? Theme.colors.white : Theme.colors.textSecondary
                }

                StyledText {
                    Layout.fillWidth: true
                    text: historyItem.modelData.content
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                }

                StyledIconButton {
                    iconName: "delete"
                    visible: historyItem.selected
                    inactiveOpacity: 0.25
                    onClicked: ClipboardService.deleteEntry(historyItem.modelData.id)
                }
            }
        }

        Binding {
            target: ClipboardService
            property: "focusedItem"
            value: layout.listView.currentItem ? layout.listView.currentItem?.modelData : null
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !ClipboardService.focusedItem
            iconName: "content_copy"
            text: root.displayedModel.length === 0 ? (ClipboardService.searchText.trim() !== "" ? "No matching entries" : (root.showPinned ? "No pinned entries" : "Clipboard is empty")) : ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            visible: !!ClipboardService.focusedItem

            // TOP: preview (image file vs decoded text, as-is)
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Image preview
                Loader {
                    anchors.fill: parent
                    anchors.margins: 4
                    active: root.imageReady
                    sourceComponent: {
                        if (!active)
                            return null;
                        return root.focusedIsGif ? gifComponent : staticImageComponent;
                    }

                    Component {
                        id: staticImageComponent
                        Image {
                            source: ClipboardService.focusedFilePath
                            fillMode: Image.PreserveAspectFit
                            retainWhileLoading: true
                            asynchronous: true
                            cache: false
                        }
                    }

                    Component {
                        id: gifComponent
                        AnimatedImage {
                            source: ClipboardService.focusedFilePath
                            fillMode: Image.PreserveAspectFit
                            playing: true
                            retainWhileLoading: true
                            asynchronous: true
                            cache: false
                        }
                    }
                }

                // Color
                StyledRectangle {
                    anchors.centerIn: parent
                    visible: root.focusedKind === "color"
                    color: root.focusedKind === "color" ? ColorUtils.toQmlColor(ClipboardService.focusedItem.content) : "transparent"
                    baseRadius: Theme.rounding.large
                    shadow: true
                    width: 88
                    height: 88

                    StyledRectangle {
                        anchors.fill: parent
                        color: "transparent"
                        baseRadius: Theme.rounding.large
                        border.color: ColorUtils.transparentize(Theme.colors.white, 0.20)
                        border.width: 1
                    }
                }

                // Plain text
                TextPreview {
                    anchors.fill: parent
                    anchors.topMargin: layout.spacing
                    anchors.bottomMargin: layout.spacing
                    visible: !root.focusedIsImage && root.focusedKind !== "color"
                    text: ClipboardService.decodedContent ? ClipboardService.decodedContent.trim() : ""
                }
            }

            Divider {
                vertical: false
                opacity: 0.12
            }

            // BOTTOM: metadata (mime-derived only)
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: metaRows.implicitHeight + 16
                clip: true

                MetaRows {
                    id: metaRows
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    rows: [
                        {
                            label: "Type",
                            value: StringUtils.capitalize(root.focusedKind)
                        },
                        {
                            label: "Mime",
                            value: root.focusedMime
                        },
                        {
                            label: "Date",
                            value: ClipboardService.focusedItem ? DateUtils.formatFullDate(new Date(Math.floor(ClipboardService.focusedItem.timestamp / 1e6)).toISOString()) : ""
                        },
                        {
                            label: "Hash",
                            value: ClipboardService.focusedItem ? ClipboardService.focusedItem.id : ""
                        }
                    ]
                }
            }
        }
    }
}
