pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.components
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/ColorUtils.js" as ColorUtils

BasePage {
    id: root
    placeHolder: "Do math, convert units, or search your past calculations..."
    currentItemPrimaryActionName: "Copy Answer"
    pageIcon: "calculate"
    pageIconType: "symbol"
    pageName: "Calculator History"

    property string expression
    property var results
    property string calculatorResult: (root.results && root.results.length > 0) ? root.results[resultsSwipeView.currentIndex] ?? "" : ""
    property var calculatorHistory: GlobalData.calculatorHistory
    property int focusedHistoryIndex: -1

    property var filteredHistory: {
        const q = root.searchText.trim().toLowerCase();
        if (!q)
            return root.calculatorHistory;
        return root.calculatorHistory.filter(item => item.expression.toLowerCase().includes(q) || item.result.toLowerCase().includes(q));
    }

    onSearchTextChanged: {
        if (root.searchText.trim() === "") {
            root.expression = "";
            root.results = null;
            root.focusedHistoryIndex = -1;
        }
        calculatorProcess.calculateExpression(root.searchText);
    }

    onFilteredHistoryChanged: root.focusedHistoryIndex = -1

    // Helpers
    function swipeTo(index) {
        resultsSwipeView.contentItem.highlightMoveDuration = 300;
        resultsSwipeView.currentIndex = index;
    }

    // Actions
    function primaryAction() {
        if (root.focusedHistoryIndex >= 0 && root.focusedHistoryIndex < root.filteredHistory.length) {
            const item = root.filteredHistory[root.focusedHistoryIndex];
            root.searchText = item.expression;
            root.focusedHistoryIndex = -1;
            return;
        }
        if (!root.calculatorResult)
            return;
        Quickshell.clipboardText = root.calculatorResult;

        const newEntry = {
            expression: root.searchText,
            result: root.results[resultsSwipeView.currentIndex]
        };
        let history = root.calculatorHistory.filter(item => item.expression !== newEntry.expression || item.result !== newEntry.result);
        history.unshift(newEntry);
        history = history.slice(0, 25);

        GlobalIpc.popup.showInfo("Copied to clipboard", "", 1000);
        GlobalData.calculatorHistory = history;
        GlobalStates.showLauncher = false;
    }

    function secondaryAction() {
        if (!root.calculatorResult)
            return;
        root.searchText = "(" + root.calculatorResult + ")";
    }

    function nextItem() {
        if (root.filteredHistory.length === 0)
            return;
        root.focusedHistoryIndex = Math.min(root.focusedHistoryIndex + 1, root.filteredHistory.length - 1);
    }

    function previousItem() {
        if (root.focusedHistoryIndex <= 0)
            return;
        root.focusedHistoryIndex--;
    }

    function downItem() {
        if (!root.results || root.results.length <= 1)
            return;
        root.swipeTo((resultsSwipeView.currentIndex + 1) % root.results.length);
    }

    function upItem() {
        if (!root.results || root.results.length <= 1)
            return;
        root.swipeTo((resultsSwipeView.currentIndex - 1 + root.results.length) % root.results.length);
    }

    Component.onDestruction: calculatorProcess.running = false

    // Components
    component ResultText: StyledText {
        anchors.fill: parent
        anchors.margins: 8
        maximumLineCount: 3
        wrapMode: Text.Wrap
        font.pixelSize: Theme.fontPixelSizes.hugeass * 1.25
        font.weight: Font.Bold
    }

    // Process
    Process {
        id: calculatorProcess
        readonly property list<string> baseCommand: ["qalc"]
        environment: Object.assign({}, {
            XDG_CONFIG_HOME: Paths.dotconfDir
        })

        function calculateExpression(expression) {
            calculatorProcess.running = false;
            if (expression.trim() === "")
                return;
            calculatorProcess.command = baseCommand.concat(expression);
            calculatorProcess.running = true;
        }

        stdout: SplitParser {
            onRead: data => {
                const result = data.trim();
                if (result && result !== "error" && !result.toLowerCase().includes("error")) {
                    const parts = result.split(/[=≈]/).map(i => i.trim());
                    root.expression = parts[0];
                    root.results = parts.slice(1);
                    resultsSwipeView.contentItem.highlightMoveDuration = 0;
                    resultsSwipeView.currentIndex = root.results.length - 1;
                } else {
                    root.expression = null;
                    root.results = null;
                }
            }
        }

        stderr: SplitParser {
            onRead: data => {
                root.expression = null;
                root.results = null;
            }
        }
    }

    // UI
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 12

        // Result box
        StyledRectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 156
            Layout.topMargin: 12
            baseRadius: Theme.rounding.normal
            visible: !!(root.expression && root.results && root.results.length > 0)
            color: ColorUtils.transparentize(Theme.colors.white, 0.05)
            border.color: ColorUtils.transparentize(Theme.colors.white, 0.12)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                spacing: 0

                // Expression
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 4
                    ResultText {
                        text: root.expression ?? ""
                    }
                }

                // Divider
                Item {
                    Layout.preferredWidth: 26
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignCenter

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 4

                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.alignment: Qt.AlignCenter
                            color: Theme.colors.textMuted
                            opacity: 0.5
                        }
                        MaterialSymbol {
                            iconSize: 24
                            iconName: "equal"
                            Layout.alignment: Qt.AlignCenter
                        }
                        Rectangle {
                            Layout.fillHeight: true
                            Layout.preferredWidth: 1
                            Layout.alignment: Qt.AlignCenter
                            color: Theme.colors.textMuted
                            opacity: 0.5
                        }
                    }
                }

                // Results column
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 4

                    SwipeView {
                        id: resultsSwipeView
                        anchors.fill: parent
                        clip: true
                        orientation: Qt.Vertical
                        activeFocusOnTab: false

                        Repeater {
                            model: ScriptModel {
                                values: root.results ?? []
                            }
                            delegate: Item {
                                required property var modelData
                                ResultText {
                                    text: parent.modelData ?? ""
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }
                    }

                    StyledSelector {
                        id: resultSelector
                        anchors.right: parent.right
                        anchors.rightMargin: -0
                        anchors.verticalCenter: parent.verticalCenter
                        entries: root.results
                        implicitHeight: (width + 2) * (entries ? entries.length : 0)
                        implicitWidth: 14
                        orientation: Qt.Vertical
                        currentIndex: resultsSwipeView.currentIndex
                        indicatorColor: ColorUtils.transparentize(Theme.colors.color16, 1)
                        backgroundColor: ColorUtils.transparentize(Theme.colors.bgBase, 0.50)
                        borderColor: ColorUtils.transparentize(Theme.colors.white, 0.05)
                        showBorder: true
                        interactive: false
                        displayText: ""
                    }
                }
            }
        }

        // History list
        ListLayout {
            id: historyLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            fillParent: false
            model: root.filteredHistory
            currentIndex: root.focusedHistoryIndex
            isEmpty: !root.filteredHistory || root.filteredHistory.length === 0
            emptyIcon: "calculate"
            emptyText: root.searchText.trim() !== "" ? "No matching history" : "No history yet"
            emptyIconSize: 64

            headerComponent: Component {
                SectionHeader {
                    title: "History"
                }
            }

            delegate: ListItemBackground {
                id: historyItem
                required property var modelData
                required property int index
                selected: root.focusedHistoryIndex === historyItem.index
                width: ListView.view.width

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 2
                    anchors.leftMargin: 6
                    anchors.rightMargin: 8
                    spacing: 4

                    MaterialSymbol {
                        iconName: "history"
                        iconSize: 26
                        color: historyItem.selected ? Theme.colors.white : Theme.colors.textSecondary
                    }

                    StyledText {
                        text: historyItem.modelData.expression
                        font.pixelSize: Theme.fontPixelSizes.large
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignLeft
                        Layout.fillWidth: true
                    }

                    StyledText {
                        text: historyItem.modelData.result
                        font.pixelSize: Theme.fontPixelSizes.large
                        font.weight: Font.DemiBold
                        Layout.maximumWidth: parent.width * 0.45
                        Layout.minimumWidth: implicitWidth
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
    }
}
