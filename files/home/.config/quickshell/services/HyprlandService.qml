pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs
import "../lib/StringUtils.js" as StringUtils

Singleton {
    id: root
    property bool focusedWorkspaceHasMaximized: Hyprland.activeToplevel?.wayland?.maximized ?? false
    property bool focusedWorkspaceHasFullscreen: (Hyprland?.focusedWorkspace?.hasFullscreen && !Hyprland.activeToplevel?.wayland?.maximized) ?? false
    property bool focusedWorkspaceHasNoWindows: (Hyprland?.focusedWorkspace?.toplevels.values.length === 0) ?? false

    property bool blurEnabled: false
    property string currentFocusedWindowAddress: ""
    property string currentSubmap: ""
    property var currentSpecialWorkspace: false

    property var keybinds: []
    readonly property bool keybindsLoading: bindsProcess.running

    Component.onCompleted: fetchKeybinds()

    Process {
        id: bindsProcess
        stdout: StdioCollector {
            onStreamFinished: root.keybinds = StringUtils.safeParse(text, [])
        }
    }

    function getMonitorOfScreen(screen: ShellScreen): HyprlandMonitor {
        return Hyprland.monitors.values.find(m => m.name === screen.name) ?? Hyprland.focusedMonitor;
    }

    function fetchKeybinds() {
        bindsProcess.exec(["hyprctl", "binds", "-j"]);
    }

    Connections {
        target: Hyprland
        function onRawEvent(e) {
            if (e.name === "configreloaded") {
                MonitorService.fetchMonitors();
                root.fetchKeybinds();
            }

            if (e.name === "openwindow" || e.name === "closewindow") {
                Hyprland.refreshToplevels();
            }

            if (e.name === "monitoradded") {
                MonitorService.fetchMonitors();
                GlobalIpc.popup.showInfo(`Monitor added <b>${e.data}<\b>`, "", 5000);
            }

            if (e.name === "monitorremoved") {
                MonitorService.fetchMonitors();
                GlobalIpc.popup.showInfo(`Monitor removed <b>${e.data}<\b>`, "", 5000);
            }

            if (e.name === "activespecial") {
                root.currentSpecialWorkspace = e.data.split(",")[0].trim() || false;
            }

            if (e.name === "submap") {
                const hiddenSubmaps = ["alttab"];
                if (hiddenSubmaps.includes(e.data.toLowerCase()) || (e.data === "" && root.currentSubmap === ""))
                    return;
                if ((e.data || "") === "")
                    GlobalIpc.popup.showInfo("Submap switched -> <b>Default<\b>", "", 3000);
                else
                    GlobalIpc.popup.showInfo(`Submap switched -> <b>${StringUtils.capitalize(e.data)}<\b>`, "", -1);
                root.currentSubmap = e.data || "";
            }

            if (e.name === "activewindowv2") {
                const address = e.data.trim();
                if (address !== root.currentFocusedWindowAddress && root.currentFocusedWindowAddress !== "") {
                    GlobalCache.lastFocusedWindowAddress = root.currentFocusedWindowAddress;
                }
                root.currentFocusedWindowAddress = address;
            }
        }
    }

    FileView {
        id: ioFileView
        path: ""
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    function _readJson(path) {
        ioFileView.path = path;
        ioFileView.reload();
        const content = ioFileView.text();
        try {
            return content ? JSON.parse(content) : [];
        } catch (e) {
            return {};
        }
    }

    function _writeJson(path, data) {
        ioFileView.path = path;
        ioFileView.setData(JSON.stringify(data, null, 2));
        ioFileView.path = "";
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    function getGeneralJson() {
        return _readJson(Paths.hlGeneralJson);
    }
    function setGeneralJson(data) {
        _writeJson(Paths.hlGeneralJson, data);
    }

    function getDecorationJson() {
        return _readJson(Paths.hlDecorationJson);
    }
    function setDecorationJson(data) {
        _writeJson(Paths.hlDecorationJson, data);
    }

    function getMonitorsJson() {
        return _readJson(Paths.hlMonitorsJson);
    }
    function setMonitorsJson(data) {
        _writeJson(Paths.hlMonitorsJson, data);
    }

    function getRulesJson() {
        return _readJson(Paths.hlRulesJson);
    }
    function setRulesJson(data) {
        _writeJson(Paths.hlRulesJson, data);
    }

    function getPowerSaverJson() {
        return _readJson(Paths.hlPowerSaverJson);
    }
    function setPowerSaverJson(data) {
        _writeJson(Paths.hlPowerSaverJson, data);
    }

    function setDPMS(value: bool) {
        GlobalSettings.hyprlandDPMS = value;
    }
    function toggleDPMS(value: bool) {
        GlobalSettings.hyprlandDPMS = !GlobalSettings.hyprlandDPMS;
    }
}
