pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/FileUtils.js" as FileUtils

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Search files and folders..."
    currentItemPrimaryActionName: "Open"
    pageIcon: "folder"
    pageIconType: "symbol"
    pageName: "Files"
    isLoading: FilesService.loading

    onSearchTextChanged: {
        FilesService.searchText = root.searchText;
        layout.resetToTopInstant();
    }

    Component.onDestruction: FilesService.searchText = ""

    function primaryAction() {
        if (FilesService.focusedItem) {
            FilesService.openFocused();
            GlobalIpc.popup.showInfo(`Opening ${FilesService.focusedItemMime === "inode/directory" ? "folder" : "file"}`, FilesService.focusedItemPath, 2000);
            GlobalStates.showLauncher = false;
        }
    }

    function secondaryAction() {
        if (FilesService.focusedItemPath)
            root.searchText = FilesService.focusedItemPath + (FilesService.focusedItemMime === "inode/directory" ? "/" : "");
    }

    SplitLayout {
        id: layout
        model: FilesService.filteredResults

        headerComponent: Component {
            SectionHeader {
                title: FilesService.searchText ? "Search Results" : "Recent Folders (Zoxide)"
            }
        }

        Binding {
            target: FilesService
            property: "focusedItem"
            value: layout.listView.currentItem ? layout.listView.currentItem.modelData : null
        }

        delegate: ListItemBackground {
            id: fileItem
            required property var modelData
            required property int index
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                StyledIcon {
                    iconName: fileItem.modelData.icon
                    iconSize: 24
                    useIconTheme: true
                }

                StyledText {
                    text: fileItem.modelData.name
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        EmptyState {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !FilesService.focusedItem
            iconName: "folder"
            text: "No results found"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            visible: !!FilesService.focusedItem

            // Top: Visual Preview
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Image Preview
                Image {
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: FilesService.focusedItemMime.startsWith("image/")
                    source: visible ? "file://" + FilesService.focusedItemPath : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    smooth: true
                    sourceSize.width: 800
                    sourceSize.height: 600
                }

                // Text Preview
                TextPreview {
                    anchors.fill: parent
                    anchors.topMargin: layout.spacing
                    anchors.bottomMargin: layout.spacing
                    visible: FilesService.focusedItemReadable && !FilesService.focusedItemMime.includes("image/")
                    text: FilesService.focusedItemPreview.trim()
                }

                // Icon Fallback
                StyledIcon {
                    anchors.centerIn: parent
                    iconSize: 128
                    useIconTheme: true
                    iconName: FilesService.focusedItemIcon
                    visible: !FilesService.focusedItemReadable && !FilesService.focusedItemMime.startsWith("image/")
                    backer.cache: false
                }
            }

            Divider {
                vertical: false
                opacity: 0.12
            }

            // Bottom: Metadata
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: metaRows.implicitHeight + 16
                clip: true

                MetaRows {
                    id: metaRows
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14
                    rows: [
                        {
                            label: "Name",
                            value: FilesService.focusedItemName
                        },
                        {
                            label: "Type",
                            value: FilesService.focusedItemMime
                        },
                        {
                            label: "Size",
                            value: FilesService.focusedItemSize
                        },
                        {
                            label: "Path",
                            value: FileUtils.trimFileProtocol(FilesService.focusedItemPath)
                        },
                        ...(FilesService.focusedItemIsDir ? [
                                {
                                    label: "Items",
                                    value: String(FilesService.focusedItemFileCount)
                                }
                            ] : []), ...(FilesService.focusedItemReadable ? [
                                {
                                    label: "Lines",
                                    value: String(FilesService.focusedItemLines)
                                },
                                {
                                    label: "Chars",
                                    value: String(FilesService.focusedItemChars)
                                }
                            ] : [])
                    ]
                }
            }
        }
    }
}
