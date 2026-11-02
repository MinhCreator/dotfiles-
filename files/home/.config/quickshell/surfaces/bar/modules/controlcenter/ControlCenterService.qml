pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.services

Singleton {
    id: root
    property bool isLoading: false

    // Static module definitions
    readonly property var moduleDefs: [
        {
            id: "network",
            name: "Network",
            priority: 13,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "android_wifi_4_bar"
        },
        {
            id: "bluetooth",
            name: "Bluetooth",
            priority: 12,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "bluetooth"
        },
        {
            id: "audioOutput",
            name: "Audio",
            priority: 11,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "volume_up"
        },
        {
            id: "audioInput",
            name: "Microphone",
            priority: 10,
            interactive: true,
            hasPage: true,
            isAlias: true,
            aliasOf: "audioOutput",
            expandedIcon: "mic"
        },
        {
            id: "notifications",
            name: "Notifications",
            priority: 9,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "notifications"
        },
        {
            id: "screen",
            name: "Screen",
            priority: 8,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "wb_sunny"
        },
        {
            id: "update",
            name: "Update",
            priority: 7,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "deployed_code_update"
        },
        {
            id: "systray",
            name: "Systray",
            priority: 6,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "widgets"
        },
        {
            id: "colorPicker",
            name: "Color Picker",
            priority: 5,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "colorize"
        },
        {
            id: "clock",
            name: "Clock",
            priority: 4,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "schedule"
        },
        {
            id: "inhibitor",
            name: "Inhibitor",
            priority: 3,
            interactive: true,
            hasPage: true,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "moon_stars"
        },
        {
            id: "recording",
            name: "Recording",
            priority: 2,
            interactive: GlobalData.isRecording,
            hasPage: false,
            isAlias: false,
            aliasOf: "",
            expandedIcon: "videocam"
        },
        {
            id: "power",
            name: "Power",
            priority: 1,
            interactive: false,
            hasPage: false,
            isAlias: false,
            aliasOf: "",
            expandedIcon: PowerProfilesService.materialSymbol
        }
    ]

    // Page map
    readonly property var pageMap: ({
            "network": networkComponent,
            "bluetooth": bluetoothComponent,
            "audioOutput": audioComponent,
            "audioInput": audioComponent,
            "screen": screenComponent,
            "notifications": notificationsComponent,
            "update": updatesComponent,
            "systray": systrayComponent,
            "colorPicker": colorPickerComponent,
            "clock": clockComponent,
            "inhibitor": inhibitorComponent
        })

    // Page components
    Component {
        id: networkComponent
        NetworkPage {}
    }
    Component {
        id: bluetoothComponent
        BluetoothPage {}
    }
    Component {
        id: audioComponent
        AudioPage {}
    }
    Component {
        id: screenComponent
        ScreenPage {}
    }
    Component {
        id: notificationsComponent
        NotificationsPage {}
    }
    Component {
        id: systrayComponent
        SystrayPage {}
    }
    Component {
        id: colorPickerComponent
        ColorPickerPage {}
    }
    Component {
        id: updatesComponent
        UpdatesPage {}
    }
    Component {
        id: clockComponent
        ClockPage {}
    }
    Component {
        id: inhibitorComponent
        InhibitorPage {}
    }

    // Expandable modules (mirrors current bar order)
    property var expandableModules: []

    // Current expanded page index
    property int currentExpandableIndex: GlobalCache.controlCenterExpandableIndex
    property int currentBarIndex: GlobalCache.controlCenterBarIndex

    onCurrentExpandableIndexChanged: {
        GlobalCache.controlCenterExpandableIndex = currentExpandableIndex;
        _updateCurrentBarIndex();
    }

    onCurrentBarIndexChanged: GlobalCache.controlCenterBarIndex = currentBarIndex

    function _updateCurrentBarIndex() {
        currentBarIndex = _barModelIndexOf(expandableModules[currentExpandableIndex]?.id ?? "");
    }

    Component.onCompleted: {
        _buildBarModel();

        if (currentExpandableIndex === -1 || currentExpandableIndex >= expandableModules.length)
            currentExpandableIndex = expandableModules.length - 1;
    }

    // Dynamic resolvers
    // The ONLY place service/state reads happen. Safe here because they do NOT
    // affect list structure — only per-item display and active state.
    function activeFor(id) {
        switch (id) {
        case "network":
            return true;
        case "bluetooth":
            return true;
        case "audioOutput":
            return true;
        case "audioInput":
            return true;
        case "screen":
            return true;
        case "notifications":
            return !GlobalSettings.doNotDisturb;
        case "update":
            return UpdateService.updateCount > 0;
        case "systray":
            return true;
        case "colorPicker":
            return true;
        case "clock":
            return ClockService.countdownRunning || ClockService.stopwatchRunning || ClockService.countdownPaused || ClockService.stopwatchPaused;
        case "inhibitor":
            return InhibitorService.inhibit;
        case "recording":
            return GlobalData.isRecording;
        case "power":
            return PowerProfiles.profile !== PowerProfile.Balanced;
        default:
            return true;
        }
    }

    function activeColorFor(id) {
        switch (id) {
        case "recording":
            return GlobalData.isRecording ? Theme.colors.error : Theme.colors.white;
        default:
            return Theme.colors.white;
        }
    }

    function filledStateFor(id) {
        switch (id) {
        case "recording":
            return GlobalData.isRecording;
        default:
            return false;
        }
    }

    function statusIconFor(id) {
        switch (id) {
        case "network":
            return NetworkService.materialSymbol;
        case "bluetooth":
            return BluetoothService.materialSymbol;
        case "audioOutput":
            return AudioService.materialSymbolSink;
        case "audioInput":
            return AudioService.materialSymbolSource;
        case "screen":
            return BrightnessService.materialSymbol;
        case "notifications":
            return NotificationService.materialSymbol;
        case "update":
            return UpdateService.materialSymbol;
        case "colorPicker":
            return ColorPickerService.materialSymbol;
        case "clock":
            return ClockService.materialSymbol;
        case "inhibitor":
            return InhibitorService.materialSymbol;
        case "power":
            return PowerProfilesService.materialSymbol;
        case "recording":
            return GlobalData.isRecording ? "videocam" : "videocam_off";
        case "systray":
            return "widgets";
        default:
            return "";
        }
    }

    function onLeftClickFor(id, barName) {
        const def = moduleDefs.find(m => m.id === id);
        if (def.id === "recording" && GlobalData.isRecording) {
            Quickshell.execDetached(["sh", "-c", `${Paths.screenRecordScript} stop quickshell notif`]);
        }

        const targetId = (def && def.aliasOf) ? def.aliasOf : id;
        const idx = expandableModules.findIndex(m => m.id === targetId);
        if (idx !== -1) {
            currentExpandableIndex = idx;
            GlobalStates.expandedBarModule = barName;
        }
    }

    // Bar ListModel
    // Sorted: inactive (priority asc) then active (priority asc).
    // Uses ListModel.move() so the ListView can animate transitions.
    ListModel {
        id: barModel
    }

    readonly property alias model: barModel

    function _buildBarModel() {
        const sorted = _sortedDefs();
        barModel.clear();
        for (const def of sorted)
            barModel.append({
                moduleId: def.id
            });
        refreshExpandedList();
        _updateCurrentBarIndex();
    }

    function _sortedDefs() {
        const defs = [...moduleDefs];
        defs.sort((a, b) => {
            const aa = root.activeFor(a.id);
            const ba = root.activeFor(b.id);
            if (aa !== ba)
                return aa ? 1 : -1;
            return a.priority - b.priority;
        });
        return defs;
    }

    // Called by each delegate's onActiveChanged to move the item to its new position.
    function onActiveChanged(id) {
        _syncBarModel();
    }

    function _syncBarModel() {
        const sorted = _sortedDefs();
        for (let i = 0; i < sorted.length; i++) {
            const id = sorted[i].id;
            const curPos = _barModelIndexOf(id);
            if (curPos !== -1 && curPos !== i) {
                barModel.move(curPos, i, 1);
            }
        }
        _updateCurrentBarIndex();
    }

    // Snap the expanded list to the current bar order, keeping the selected
    // module selected. Called when the control center expands, not live.
    function refreshExpandedList() {
        const selectedId = expandableModules[currentExpandableIndex]?.id ?? "";
        expandableModules = _expandedFromBar();
        if (selectedId !== "") {
            const newIndex = expandableModules.findIndex(m => m.id === selectedId);
            if (newIndex !== -1 && newIndex !== currentExpandableIndex)
                currentExpandableIndex = newIndex;
        }
    }

    // Tabbable (hasPage && !isAlias) definitions in the current bar order.
    function _expandedFromBar() {
        const out = [];
        for (let i = 0; i < barModel.count; i++) {
            const id = barModel.get(i).moduleId;
            const def = moduleDefs.find(m => m.id === id);
            if (def && def.hasPage && !def.isAlias)
                out.push(def);
        }
        return out;
    }

    Connections {
        target: UpdateService
        function onUpdateCountChanged() {
            _syncBarModel();
        }
    }

    Connections {
        target: ClockService
        function onCountdownRunningChanged() {
            _syncBarModel();
        }
        function onStopwatchRunningChanged() {
            _syncBarModel();
        }
        function onCountdownPausedChanged() {
            _syncBarModel();
        }
        function onStopwatchPausedChanged() {
            _syncBarModel();
        }
    }

    Connections {
        target: InhibitorService
        function onInhibitChanged() {
            _syncBarModel();
        }
    }

    Connections {
        target: GlobalSettings
        function onIsRecordingChanged() {
            _syncBarModel();
        }
    }

    Connections {
        target: PowerProfiles
        ignoreUnknownSignals: true
        function onProfileChanged() {
            _syncBarModel();
        }
    }

    function _barModelIndexOf(id) {
        for (let i = 0; i < barModel.count; i++)
            if (barModel.get(i).moduleId === id)
                return i;
        return -1;
    }
}
