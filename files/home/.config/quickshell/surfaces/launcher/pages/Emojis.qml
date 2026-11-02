pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.surfaces.launcher.pages.components
import "../../../lib/FuzzySort.js" as FuzzySort
import "../../../lib/ColorUtils.js" as ColorUtils
import "../../../store/Emojis.js" as Emojis

BasePage {
    id: root
    placeHolder: "Search emojis..."
    currentItemPrimaryActionName: "Copy Emoji"
    pageIcon: "face-smile"
    pageIconType: "symbol"
    pageName: "Emojis"
    catchEscape: showSkins
    isLoading: searchText.trim() !== "" && debouncedText !== searchText.trim()
    enableSearchbar: !showSkins
    outerMargins: 0

    readonly property int columns: 6
    readonly property int skinsColumns: 6
    property int currentEmojiIndex: 0
    property string debouncedText: ""
    property var preparedEmojis: []
    property bool isInitialized: false
    property bool showSkins: false
    property int currentSkinIndex: 0
    property var currentSkins: []

    property var filteredEmojis: {
        GlobalData.emojiScores;
        return generateFilteredEmojis(root.debouncedText);
    }
    property var rows: {
        root.columns;
        return generateRows(root.debouncedText, root.filteredEmojis);
    }

    function incrementEmojiScore(name) {
        let scores = Object.assign({}, GlobalData.emojiScores || {});
        scores[name] = Number(((scores[name] || 0) + 0.1).toFixed(1));

        let sortedEntries = Object.entries(scores).sort((a, b) => b[1] - a[1]).slice(0, 50);

        let newScores = {};
        for (let i = 0; i < sortedEntries.length; i++) {
            newScores[sortedEntries[i][0]] = sortedEntries[i][1];
        }

        GlobalData.emojiScores = newScores;
    }

    onFilteredEmojisChanged: currentEmojiIndex = 0
    onSearchTextChanged: {
        if (searchText.trim() === "") {
            debouncedText = "";
            debounceTimer.stop();
        } else {
            debounceTimer.restart();
        }
    }

    Component.onCompleted: {
        const start = Date.now();
        preparedEmojis = Emojis.emojis.map(e => ({
                    obj: e,
                    id: FuzzySort.prepare(e.id || ""),
                    name: FuzzySort.prepare(e.name || ""),
                    groupName: FuzzySort.prepare(e.groupName || "")
                }));
        isInitialized = true;
    }

    Timer {
        id: debounceTimer
        interval: 150
        onTriggered: root.debouncedText = root.searchText.trim()
    }

    // --- Helpers & Logic ---
    function generateFilteredEmojis(query) {
        if (!isInitialized)
            return Emojis.emojis;
        if (query === "") {
            const scores = GlobalData.emojiScores || {};
            const mostUsed = Object.entries(scores).sort((a, b) => b[1] - a[1]).slice(0, root.columns).map(([name, _]) => Emojis.emojis.find(e => e.name === name)).filter(e => !!e);
            return [...mostUsed, ...Emojis.emojis];
        }
        return FuzzySort.go(query, preparedEmojis, {
            threshold: 0.2,
            limit: 60,
            keys: ["id", "name", "groupName"]
        }).map(item => item.obj.obj);
    }

    function generateRows(query, emojis) {
        const result = [];
        const cols = root.columns;
        let emojiStartIndex = 0;

        if (query !== "") {
            result.push({
                type: "header",
                label: "Results"
            });
        } else {
            const mostUsedCount = emojis.length - Emojis.emojis.length;
            if (mostUsedCount > 0) {
                result.push({
                    type: "header",
                    label: "Most Used"
                });
                const chunk = emojis.slice(0, mostUsedCount).map((e, i) => ({
                            emoji: e,
                            index: i
                        }));
                result.push({
                    type: "row",
                    emojis: chunk,
                    startIndex: 0
                });
                emojiStartIndex = mostUsedCount;
            }
        }

        let lastGroup = -1;
        let chunk = [];

        for (let i = emojiStartIndex; i < emojis.length; i++) {
            const e = emojis[i];
            if (query === "" && e.group !== lastGroup) {
                if (chunk.length)
                    result.push({
                        type: "row",
                        emojis: chunk,
                        startIndex: i - chunk.length
                    });
                result.push({
                    type: "header",
                    label: e.groupName
                });
                lastGroup = e.group;
                chunk = [];
            }
            chunk.push({
                emoji: e,
                index: i
            });
            if (chunk.length === cols) {
                result.push({
                    type: "row",
                    emojis: chunk,
                    startIndex: i - (cols - 1)
                });
                chunk = [];
            }
        }
        if (chunk.length)
            result.push({
                type: "row",
                emojis: chunk,
                startIndex: emojis.length - chunk.length
            });
        return result;
    }

    function openSkins(e) {
        root.currentSkins = [e.name, ...e.skins];
        root.currentSkinIndex = 0;
        root.showSkins = true;
    }

    function executeAction(isSecondary) {
        const e = filteredEmojis[currentEmojiIndex];
        if (!e)
            return;

        if (!showSkins && e.skins?.length > 0)
            return openSkins(e);

        const name = showSkins ? currentSkins[currentSkinIndex] : e.name;
        incrementEmojiScore(e.name);
        Quickshell.clipboardText = name;

        if (isSecondary) {
            Quickshell.execDetached(["sh", "-c", `sleep 0.2 && wtype "${name}"`]);
            GlobalIpc.popup.showInfo(`Emoji pasted ${name}`, "", 1000);
        } else {
            GlobalIpc.popup.showInfo(`Emoji copied to clipboard ${name}`, "", 1000);
        }

        GlobalStates.showLauncher = showSkins = false;
    }

    // --- Navigation ---
    function primaryAction() {
        executeAction(false);
    }
    function secondaryAction() {
        executeAction(true);
    }
    function escapeAction() {
        showSkins = false;
    }

    function moveSelection(delta) {
        if (showSkins) {
            currentSkinIndex = Math.max(0, Math.min(currentSkins.length - 1, currentSkinIndex + delta));
        } else {
            const total = filteredEmojis.length;
            if (total === 0)
                return;
            currentEmojiIndex = Math.max(0, Math.min(total - 1, currentEmojiIndex + delta));

            const targetRow = rows.findIndex(r => r.type === "row" && r.emojis.some(e => e.index === currentEmojiIndex));
            if (targetRow !== -1)
                listView.currentIndex = targetRow;
        }
    }

    function nextItem() {
        moveSelection(1);
    }
    function previousItem() {
        moveSelection(-1);
    }
    function rightItem() {
        nextItem();
    }
    function leftItem() {
        previousItem();
    }
    function downItem() {
        moveSelection(showSkins ? 0 : root.columns);
    }
    function upItem() {
        moveSelection(showSkins ? 0 : -root.columns);
    }

    // Empty state
    Item {
        anchors.fill: parent
        visible: root.filteredEmojis.length === 0

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                iconName: "mood"
                iconSize: 64
                opacity: 0.2
                Layout.alignment: Qt.AlignCenter
            }

            StyledText {
                text: "No emojis found"
                opacity: 0.5
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignCenter
            }
        }
    }

    // --- UI Layout ---
    StyledListView {
        id: listView
        anchors.fill: parent
        model: root.rows
        anchors.margins: 16
        anchors.topMargin: 0
        scrollBarWidth: 6
        spacing: 8
        highlightMoveDuration: 0
        clip: true
        focus: true
        showScrollBar: true

        delegate: Item {
            id: rowDelegate
            required property var modelData
            readonly property real cellSize: Math.floor(listView.width / root.columns)
            width: listView.width
            height: modelData.type === "header" ? 32 : cellSize

            StyledText {
                visible: rowDelegate.modelData.type === "header"
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 4
                text: rowDelegate.modelData.label ?? ""
                font.pixelSize: Theme.fontPixelSizes.small
                font.capitalization: Font.Capitalize
                font.weight: Font.DemiBold
                color: Theme.colors.textSecondary
                opacity: 0.5
            }

            Row {
                visible: rowDelegate.modelData.type === "row"

                Repeater {
                    model: rowDelegate.modelData.type === "row" ? rowDelegate.modelData.emojis : []
                    delegate: Item {
                        id: cellDelegate
                        required property var modelData
                        readonly property bool isSelected: root.currentEmojiIndex === modelData.index
                        width: rowDelegate.cellSize
                        height: rowDelegate.cellSize

                        StyledRectangle {
                            anchors.fill: parent
                            anchors.margins: 4
                            baseRadius: Theme.rounding.normal
                            color: root.showSkins && cellDelegate.isSelected ? ColorUtils.transparentize(Theme.colors.bgOverlay, 0.72) : "transparent"
                            border.width: !root.showSkins && (cellDelegate.isSelected || cellMouseArea.containsMouse) ? 1 : 0
                            border.color: Theme.colors.white

                            StyledText {
                                anchors.centerIn: parent
                                text: cellDelegate.modelData.emoji.name
                                font.family: Theme.fontFamilies.emoji
                                font.pixelSize: parent.height * 0.5
                                renderType: Text.NativeRendering
                            }

                            StyledIconButton {
                                visible: cellDelegate.modelData.emoji.skins?.length > 0
                                anchors.top: parent.top
                                anchors.right: parent.right
                                iconSize: 20
                                iconName: "add"
                                onClicked: root.openSkins(cellDelegate.modelData.emoji)
                            }

                            MouseArea {
                                id: cellMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.currentEmojiIndex = cellDelegate.modelData.index
                                onDoubleClicked: root.primaryAction()
                            }
                        }
                    }
                }
            }
        }
    }

    // --- Skins Popup ---
    Sheet {
        shown: root.showSkins
        onClosed: root.showSkins = false
        contentMargins: 16
        contentWidth: skinsGrid.width
        contentHeight: skinsGrid.height

        Grid {
            id: skinsGrid
            anchors.centerIn: parent
            columns: root.skinsColumns
            spacing: 12

            Repeater {
                model: root.currentSkins
                delegate: Item {
                    id: skinDelegate
                    required property string modelData
                    required property int index
                    width: 64
                    height: 64

                    StyledRectangle {
                        anchors.fill: parent
                        baseRadius: Theme.rounding.normal
                        color: "transparent"
                        border.width: root.currentSkinIndex === skinDelegate.index ? 2 : 0
                        border.color: Theme.colors.color16
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: skinDelegate.modelData
                        font.family: Theme.fontFamilies.emoji
                        font.pixelSize: 48
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.currentSkinIndex = skinDelegate.index;
                            root.primaryAction();
                        }
                    }
                }
            }
            }
        }
}
