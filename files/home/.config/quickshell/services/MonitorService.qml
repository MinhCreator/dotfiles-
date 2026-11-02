pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs
import "../lib/StringUtils.js" as StringUtils

Singleton {
    id: root

    property var monitors: []
    property bool dataChanged: false

    // Revert/confirm state
    property var previousMonitors: []
    property var pendingPreviousJson: []
    property bool showConfirmPopup: false
    property int confirmTimer: 10
    readonly property int confirmTimerDuration: 10

    Component.onCompleted: fetchMonitors()

    Timer {
        id: fetchDelayTimer
        interval: 200
        onTriggered: root.fetchMonitors()
    }

    Timer {
        id: confirmCountdown
        interval: 1000
        repeat: true
        running: root.showConfirmPopup
        onTriggered: {
            root.confirmTimer--;
            if (root.confirmTimer <= 0) {
                root.revertChanges();
            }
        }
    }

    Process {
        id: monitorFetchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = StringUtils.safeParse(text, []);
                if (parsed.length > 0) {
                    root.monitors = parsed;
                    root.dataChanged = !root.dataChanged;
                    if (root.previousMonitors.length === 0)
                        root.updateBaseline();
                }
            }
        }
    }

    function fetchMonitors() {
        monitorFetchProcess.exec(["hyprctl", "monitors", "all", "-j"]);
    }

    // Snapshot the current known-good state. Call this whenever you want
    // a fresh "safe" baseline (e.g. on startup / after a confirmed apply).
    function updateBaseline() {
        root.previousMonitors = JSON.parse(JSON.stringify(root.monitors));
    }

    // Apply a candidate config and arm the auto-revert countdown.
    function applyPendingConfig(configs, changedNames) {
        root.pendingPreviousJson = HyprlandService.getMonitorsJson();
        root.pushConfig(configs, changedNames || []);
        root.showConfirmPopup = true;
        root.confirmTimer = root.confirmTimerDuration;
    }

    function revertChanges() {
        confirmCountdown.stop();
        root.showConfirmPopup = false;
        HyprlandService.setMonitorsJson(Array.isArray(root.pendingPreviousJson) ? root.pendingPreviousJson : []);
        root.pendingPreviousJson = [];
        DesktopService.refresh();
        fetchDelayTimer.restart();
        GlobalIpc.popup.showInfo("Display Settings Reverted", "", 2000);
    }

    function keepChanges() {
        confirmCountdown.stop();
        root.showConfirmPopup = false;
        root.pendingPreviousJson = [];
        root.updateBaseline();
        GlobalIpc.popup.showInfo("Display Settings Saved", "", 2000);
    }

    // Low-level: actually push a config to hyprctl. No confirm/revert logic.
    function pushConfig(configs, changedNames) {
        const changed = new Set(changedNames || []);
        const formattedConfigs = configs.map(cfg => {
            const mode = `${cfg.width}x${cfg.height}@${cfg.refreshRate}`;
            const position = `${cfg.x}x${cfg.y}`;

            let mirrorName = "";
            if (cfg.mirrorOf && cfg.mirrorOf !== "none" && cfg.mirrorOf !== "") {
                const mirrorId = parseInt(cfg.mirrorOf);
                const mirrorMonitor = configs.find(m => m.id === mirrorId);
                mirrorName = mirrorMonitor ? mirrorMonitor.name : "";
            }

            return {
                output: cfg.name,
                mode: mode,
                position: position,
                scale: Number(cfg.scale),
                transform: cfg.transform ?? 0,
                disabled: cfg.disabled ?? false,
                mirror: mirrorName
            };
        });

        const formattedByOutput = {};
        for (const cfg of formattedConfigs)
            formattedByOutput[cfg.output] = cfg;

        const existing = HyprlandService.getMonitorsJson();
        const existingConfigs = Array.isArray(existing) ? existing : [];
        const seen = new Set();
        const mergedConfigs = existingConfigs.map(entry => {
            const output = entry.output;
            seen.add(output);
            if (changed.has(output) && formattedByOutput[output])
                return Object.assign({}, entry, formattedByOutput[output]);
            return entry;
        });
        for (const cfg of formattedConfigs) {
            if (!seen.has(cfg.output))
                mergedConfigs.push(cfg);
        }

        HyprlandService.setMonitorsJson(mergedConfigs);
        DesktopService.refresh();
        fetchDelayTimer.restart();
    }

    // Public entry point used by the page: stage local edits and start
    // the confirm/revert flow.
    function setMonitors(configs, changedNames) {
        root.applyPendingConfig(configs, changedNames);
    }
}
