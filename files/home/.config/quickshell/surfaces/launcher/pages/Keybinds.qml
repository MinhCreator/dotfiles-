pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/StringUtils.js" as StringUtils
import "../../../lib/FuzzyFilter.js" as FuzzyFilter

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Search keybindings..."
    pageIcon: "keyboard"
    pageIconType: "symbol"
    pageName: "Keybinds"

    readonly property var rawBindings: HyprlandService.keybinds.filter(b => b.has_description && b.description !== "" && b.submap === "" && !b.mouse).map(b => {
        const modString = StringUtils.parseHyprlandModMask(b.modmask, " + ");
        b.keybinding = modString ? `${modString} + ${b.key}` : b.key;
        return b;
    })

    readonly property var filteredBindings: {
        const query = root.searchText.trim();
        if (query === "")
            return rawBindings;

        return FuzzyFilter.search(query, rawBindings, {
            threshold: 0,
            limit: 999,
            all: true,
            keys: ["description", "keybinding"]
        });
    }

    ListLayout {
        id: layout
        model: root.filteredBindings
        isEmpty: root.filteredBindings.length === 0 && !HyprlandService.keybindsLoading
        emptyIcon: "keyboard"
        emptyText: "No keybinds found"

        headerComponent: Component {
            SectionHeader {
                title: "Keybinds"
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

                MaterialSymbol {
                    id: keyboardSymbol
                    iconName: "keyboard"
                    color: itemDelegate.selected ? Theme.colors.white : Theme.colors.textSecondary
                    iconSize: 30
                }

                StyledText {
                    text: itemDelegate.modelData.keybinding
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.DemiBold
                    color: itemDelegate.selected ? Theme.colors.textBright : Theme.colors.textPrimary
                    Layout.maximumWidth: (parent.width * 0.5) - (parent.spacing * 2) - keyboardSymbol.width
                }

                Item {
                    Layout.fillWidth: true
                }

                StyledText {
                    text: itemDelegate.modelData.description
                    font.pixelSize: Theme.fontPixelSizes.small
                    font.weight: Font.Medium
                    color: Theme.colors.textSecondary
                    Layout.maximumWidth: (parent.width * 0.5) - (parent.spacing * 2)
                    elide: Text.ElideRight
                }
            }
        }
    }
}
