pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/FuzzyFilter.js" as FuzzyFilter

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Search processes..."
    currentItemPrimaryActionName: "Kill Process"
    pageIcon: "memory"
    pageIconType: "symbol"
    isLoading: ProcessesService.processes.length === 0
    searchbarActions: [toggleSortOrder, selectSortCriteria]

    readonly property string sortCriteria: GlobalData.processesSortCriteria
    property bool isDescending: true

    readonly property int maxResults: 50

    ListModel {
        id: processesModel
    }

    Component.onCompleted: {
        ProcessesService.getProcesses = true;
        refreshSlots();
    }
    Component.onDestruction: ProcessesService.getProcesses = false

    property Component selectSortCriteria: Component {
        StyledComboBox {
            implicitWidth: 120
            implicitHeight: 38
            model: [
                {
                    value: "pid",
                    text: "PID"
                },
                {
                    value: "cpu",
                    text: "CPU"
                },
                {
                    value: "user",
                    text: "User"
                },
                {
                    value: "mem",
                    text: "Memory"
                },
                {
                    value: "threads",
                    text: "Threads"
                },
                {
                    value: "program",
                    text: "Program"
                },
                {
                    value: "command",
                    text: "Command"
                },
            ]
            currentIndex: model.findIndex(item => item.value === GlobalData.processesSortCriteria)
            onCurrentValueChanged: GlobalData.processesSortCriteria = model[currentIndex].value
            focusPolicy: Qt.NoFocus
        }
    }

    property Component toggleSortOrder: Component {
        StyledIconButton {
            iconName: root.isDescending ? "arrow_downward" : "arrow_upward"
            implicitWidth: 42
            implicitHeight: 42
            onClicked: root.isDescending = !root.isDescending
        }
    }

    component ProcessColumn: StyledText {
        property real preferredWidth: 0
        property bool fill: false

        Layout.preferredWidth: preferredWidth
        Layout.fillWidth: fill
        Layout.alignment: Qt.AlignVCenter
        font.pixelSize: Theme.fontPixelSizes.small
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignLeft
    }

    onFilteredProcessesChanged: refreshSlots()

    function refreshSlots() {
        const results = filteredProcesses;
        const n = Math.min(results.length, maxResults);
        const roles = ["pid", "program", "command", "threads", "user", "mem", "cpu"];

        while (processesModel.count > n)
            processesModel.remove(n);

        for (let i = 0; i < n; i++) {
            const p = results[i];
            const row = {
                pid: Number(p.pid),
                program: p.program,
                command: p.command,
                threads: p.threads,
                user: p.user || "root",
                mem: p.mem,
                cpu: p.cpu
            };
            if (i < processesModel.count) {
                const cur = processesModel.get(i);
                for (const r of roles) {
                    if (cur[r] !== row[r])
                        processesModel.setProperty(i, r, row[r]);
                }
            } else {
                processesModel.append(row);
            }
        }

        clampCurrentIndex();
    }

    function clampCurrentIndex() {
        const count = processesModel.count;
        if (count === 0) {
            setCurrentIndexInstant(-1);
        } else if (layout.listView.currentIndex >= count || layout.listView.currentIndex < 0) {
            setCurrentIndexInstant(0);
        }
    }

    function setCurrentIndexInstant(idx) {
        layout.highlightMoveEnabled = false;
        layout.listView.smoothScrollEnabled = false;
        layout.listView.currentIndex = idx;
        layout.listView.contentY = layout.listView.originY;
        Qt.callLater(restoreScrollMotion);
    }

    function restoreScrollMotion() {
        layout.listView.smoothScrollEnabled = true;
        layout.highlightMoveEnabled = true;
    }

    onSearchTextChanged: {
        refreshSlots();
        setCurrentIndexInstant(processesModel.count > 0 ? 0 : -1);
    }

    function onShown() {
        if (processesModel.count === 0)
            return;
        const list = layout.listView;
        const targetIndex = Math.min(Math.max(list.currentIndex, 0), processesModel.count - 1);
        layout.highlightMoveEnabled = false;
        list.smoothScrollEnabled = false;
        list.currentIndex = targetIndex;

        let attempts = 0;
        const place = () => {
            if (list.height <= 0 && attempts < 10) {
                attempts++;
                Qt.callLater(place);
                return;
            }
            if (targetIndex === 0)
                list.contentY = list.originY;
            else
                list.positionViewAtIndex(targetIndex, ListView.Contain);
            Qt.callLater(restoreScrollMotion);
        };
        Qt.callLater(place);
    }

    function primaryAction() {
        const p = filteredProcesses[layout.listView.currentIndex];
        if (p)
            ProcessesService.kill(p);
        GlobalStates.showLauncher = false;
    }

    function secondaryAction() {
        const p = filteredProcesses[layout.listView.currentIndex];
        if (p)
            root.searchText = p.pid;
    }

    function nextItem() {
        const last = processesModel.count - 1;
        if (last < 0)
            return;
        if (layout.listView.currentIndex < last)
            layout.listView.incrementCurrentIndex();
    }

    function previousItem() {
        if (layout.listView.currentIndex > 0)
            layout.listView.decrementCurrentIndex();
    }

    function sortValue(raw) {
        if (typeof raw === "number")
            return raw;
        if (typeof raw === "string") {
            const parsed = parseFloat(raw);
            if (!isNaN(parsed))
                return parsed;
            return raw.toLowerCase(); // fallback for genuinely textual fields like `program`
        }
        return raw;
    }

    function memValue(raw) {
        const m = /^\s*([\d.]+)\s*([KMGT]?I?B)?\s*$/i.exec(raw ?? "");
        if (!m)
            return -1;
        const mult = {
            B: 1,
            KB: 1024,
            MB: 1048576,
            GB: 1073741824,
            TB: 1099511627776
        };
        const unit = (m[2] || "B").toUpperCase().replace("IB", "B");
        return parseFloat(m[1]) * (mult[unit] ?? 1);
    }

    property var filteredProcesses: {
        const rawInput = searchText.trim();
        let results = [];

        // Filter: Numeric PID vs Fuzzy Text
        if (rawInput !== "" && /^\d+$/.test(rawInput)) {
            results = ProcessesService.processes.filter(p => p.pid.toString().includes(rawInput)).slice(0, root.maxResults);
        } else {
            results = FuzzyFilter.search(rawInput, ProcessesService.processes, {
                threshold: 0,
                limit: root.maxResults,
                all: true,
                keys: ["pid", "program"]
            });
        }

        results.sort((a, b) => {
            const isMem = root.sortCriteria === "mem";
            const valA = isMem ? (a.mem_bytes ?? root.memValue(a.mem)) : root.sortValue(a[root.sortCriteria]);
            const valB = isMem ? (b.mem_bytes ?? root.memValue(b.mem)) : root.sortValue(b[root.sortCriteria]);
            if (valA < valB)
                return root.isDescending ? 1 : -1;
            if (valA > valB)
                return root.isDescending ? -1 : 1;
            return 0;
        });
        return results;
    }

    ListLayout {
        id: layout
        model: processesModel
        isEmpty: processesModel.count === 0
        emptyIcon: "memory"
        emptyText: "No processes found"

        headerComponent: Component {
            Item {
                width: parent.width
                height: 32

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12
                    opacity: 0.5

                    ProcessColumn {
                        text: "Pid"
                        preferredWidth: 60
                        color: Theme.colors.textSecondary
                    }
                    ProcessColumn {
                        text: "Program"
                        preferredWidth: 130
                        color: Theme.colors.textSecondary
                    }
                    ProcessColumn {
                        text: "Command"
                        fill: true
                        color: Theme.colors.textSecondary
                    }
                    ProcessColumn {
                        text: "Threads"
                        preferredWidth: 70
                        color: Theme.colors.textSecondary
                    }
                    ProcessColumn {
                        text: "User"
                        preferredWidth: 70
                        color: Theme.colors.textSecondary
                    }
                    ProcessColumn {
                        text: "Memory"
                        preferredWidth: 80
                        color: Theme.colors.textSecondary
                    }
                    ProcessColumn {
                        text: "Cpu %"
                        preferredWidth: 60
                        color: Theme.colors.textSecondary
                    }
                }
            }
        }

        delegate: ListItemBackground {
            id: itemDelegate
            required property int index
            required property int pid
            required property string program
            required property string command
            required property int threads
            required property string user
            required property string mem
            required property real cpu
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                ProcessColumn {
                    text: itemDelegate.pid
                    preferredWidth: 60
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontPixelSizes.small
                }
                ProcessColumn {
                    text: itemDelegate.program
                    preferredWidth: 130
                    color: Theme.colors.white
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.DemiBold
                }
                ProcessColumn {
                    text: itemDelegate.command.replace('\n', '\t')
                    fill: true
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontPixelSizes.small
                    opacity: 0.4
                }
                ProcessColumn {
                    text: itemDelegate.threads
                    preferredWidth: 70
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontPixelSizes.small
                }
                ProcessColumn {
                    text: itemDelegate.user
                    preferredWidth: 70
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontPixelSizes.small
                }
                ProcessColumn {
                    text: itemDelegate.mem
                    preferredWidth: 80
                    color: Theme.colors.textPrimary
                    font.pixelSize: Theme.fontPixelSizes.small
                }
                ProcessColumn {
                    text: itemDelegate.cpu.toFixed(1)
                    preferredWidth: 60
                    color: itemDelegate.cpu > 80 ? Theme.colors.error : Theme.colors.textPrimary
                    font.pixelSize: Theme.fontPixelSizes.small
                }
            }
        }
    }
}
