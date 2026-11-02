pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/StringUtils.js" as StringUtils

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Search the web or enter URL..."
    pageName: "Web Search"
    isLoading: false

    // Logic Properties
    property string searchQuery: root.searchText.trim()
    property var suggestions: []

    readonly property bool isUrlInput: StringUtils.isUrl(root.searchQuery)

    currentItemPrimaryActionName: isUrlInput ? "Open URL" : "Search with Brave"
    pageIcon: isUrlInput ? "language" : "search"
    pageIconType: "symbol"

    // Search & Suggestions
    Timer {
        id: debounceTimer
        interval: 500
        repeat: false
        onTriggered: {
            if (root.searchQuery.length > 0 && !root.isUrlInput)
                root.fetchSuggestions(root.searchQuery);
            else {
                root.suggestions = [];
                root.isLoading = false;
            }
        }
    }

    onSearchTextChanged: {
        layout.listView.currentIndex = -1;
        if (root.searchQuery.length === 0) {
            root.suggestions = [];
            root.isLoading = false;
            debounceTimer.stop();
            return;
        }

        if (root.isUrlInput) {
            root.suggestions = [];
            root.isLoading = false;
            return;
        }

        root.isLoading = true;
        debounceTimer.restart();
    }

    Process {
        id: suggestionsProcess
        command: []
        stdout: SplitParser {
            onRead: data => {
                root.isLoading = false;
                try {
                    let parsed = JSON.parse(data);
                    root.suggestions = Array.isArray(parsed[1]) ? parsed[1] : [];
                } catch (e) {
                    root.suggestions = [];
                }
            }
        }
    }

    function fetchSuggestions(query) {
        suggestionsProcess.command = ["curl", "-s", "--compressed", `https://suggestqueries.google.com/complete/search?client=firefox&ie=UTF-8&oe=UTF-8&q=${encodeURIComponent(query)}`];
        suggestionsProcess.running = true;
    }

    // Actions
    function getSearchText() {
        if (layout.listView.currentIndex >= 0 && layout.listView.currentIndex < layout.listView.count)
            return root.suggestions[layout.listView.currentIndex];
        return root.searchQuery;
    }

    function primaryAction() {
        const q = getSearchText();
        if (!q)
            return;

        let targetUrl;
        if (root.isUrlInput && layout.listView.currentIndex === -1) {
            targetUrl = q.startsWith("http") ? q : "https://" + q;
        } else {
            targetUrl = `https://search.brave.com/search?q=${encodeURIComponent(q)}`;
        }

        Quickshell.execDetached(["sh", "-c", `xdg-open "${targetUrl}"`]);
        GlobalIpc.popup.showInfo(root.isUrlInput && layout.listView.currentIndex === -1 ? "Opening URL" : "Searching with Brave", "", 2000);
        GlobalStates.showLauncher = false;
    }

    function secondaryAction() {
        const q = getSearchText();
        if (!q)
            return;
        const url = `https://www.google.com/search?q=${encodeURIComponent(q)}`;
        Quickshell.execDetached(["sh", "-c", `xdg-open "${url}"`]);
        GlobalIpc.popup.showInfo("Searching with Google", "", 2000);
        GlobalStates.showLauncher = false;
    }

    // UI
    ListLayout {
        id: layout
        model: root.suggestions
        isEmpty: !root.suggestions || root.suggestions.length === 0
        emptyIcon: root.isUrlInput ? "link" : (root.searchQuery.length > 0 ? "search_off" : "public")
        emptyText: root.isUrlInput ? "Open " + root.searchQuery : (root.searchQuery.length > 0 ? "No suggestions" : "Type to search the web")

        headerComponent: Component {
            SectionHeader {
                title: "Suggestions"
            }
        }

        delegate: ListItemBackground {
            id: suggestionItem
            required property string modelData
            required property int index
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                spacing: 12

                MaterialSymbol {
                    iconName: "search"
                    iconSize: 22
                    color: suggestionItem.selected ? Theme.colors.white : Theme.colors.textSecondary
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontPixelSizes.large
                    horizontalAlignment: Text.AlignLeft
                    textFormat: Text.StyledText
                    text: StringUtils.highlightMatch(suggestionItem.modelData, root.searchQuery)
                }
            }
        }
    }
}
