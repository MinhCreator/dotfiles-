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
    placeHolder: "Enter command and arguments..."
    pageName: "Commands"
    isLoading: CommandsService.isLoading
    pageIcon: "terminal"
    pageIconType: "symbol"

    property string firstWord: {
        const trimmed = searchText.trim();
        const spaceIndex = trimmed.indexOf(" ");
        return spaceIndex === -1 ? trimmed : trimmed.substring(0, spaceIndex);
    }

    property string args: {
        const trimmed = searchText.trim();
        const spaceIndex = trimmed.indexOf(" ");
        return spaceIndex === -1 ? "" : trimmed.substring(spaceIndex + 1);
    }

    property var filteredCommands: {
        const query = root.firstWord;
        if (query === "")
            return [];

        return FuzzyFilter.search(query, CommandsService.commands, {
            threshold: 0,
            limit: 50,
            all: false,
            pick: "target"
        });
    }

    onFilteredCommandsChanged: {
        layout.resetToTopInstant();
    }

    function _resolveCommand() {
        if (layout.listView.currentIndex >= 0 && layout.listView.currentIndex < filteredCommands.length)
            return filteredCommands[layout.listView.currentIndex];
        if (root.firstWord !== "")
            return root.firstWord;
        return "";
    }

    function _executeCommand(commandToExec) {
        if (commandToExec === "")
            return false;
        const fullCommand = commandToExec + (root.args !== "" ? " " + root.args : "");
        Quickshell.execDetached(["sh", "-c", fullCommand]);
        GlobalIpc.popup.showInfo("Executing Command", fullCommand, 2000);
        return true;
    }

    function primaryAction() {
        if (_executeCommand(_resolveCommand()))
            GlobalStates.showLauncher = false;
    }

    function secondaryAction() {
        _executeCommand(_resolveCommand());
    }

    ListLayout {
        id: layout
        model: root.filteredCommands
        isEmpty: root.filteredCommands.length === 0
        emptyIcon: root.searchText === "" ? "keyboard" : "search_off"
        emptyText: root.searchText === "" ? "Type to search system commands" : "No matching commands"

        headerComponent: Component {
            SectionHeader {
                title: "Available Commands"
            }
        }

        delegate: ListItemBackground {
            id: itemDelegate
            required property string modelData
            required property int index
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                MaterialSymbol {
                    iconName: "terminal"
                    iconSize: 28
                    color: itemDelegate.selected ? Theme.colors.white : Theme.colors.textSecondary
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontPixelSizes.large
                    text: StringUtils.highlightMatch(itemDelegate.modelData, root.firstWord)
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }
}
