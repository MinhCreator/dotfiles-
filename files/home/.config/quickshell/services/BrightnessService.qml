pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs

Singleton {
    id: root

    signal brightnessChanged

    property list<var> ddcMonitors: []
    readonly property var ddcMonitorMap: {
        const map = {};
        for (const m of ddcMonitors)
            map[m.connector] = m;
        return map;
    }
    property bool backlightAvailable: false
    readonly property var internalPanelPattern: /^(eDP|LVDS|DSI)-?/

    property list<BrightnessMonitor> monitors: []

    property bool hyprsunsetEnabled: GlobalSettings.hyprsunsetEnabled
    property bool hyprsunsetRunning: false
    property string materialSymbol: "wb_sunny"

    function toggleHyprsunset() {
        GlobalSettings.hyprsunsetEnabled = !GlobalSettings.hyprsunsetEnabled;
    }

    function getMonitor(screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name)): var {
        return monitors.find(m => m.screen === screen);
    }

    function setBrightness(value: real, screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name)): var {
        getMonitor(screen)?.setBrightness(value);
    }

    function getBrightness(screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor.name)): var {
        return getMonitor(screen)?.brightness ?? 0;
    }

    function increaseBrightness(val = 0.05): void {
        const focusedName = Hyprland.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.stepBrightness(val);
    }

    function decreaseBrightness(val = 0.05): void {
        const focusedName = Hyprland.focusedMonitor.name;
        const monitor = monitors.find(m => focusedName === m.screen.name);
        if (monitor)
            monitor.stepBrightness(-val);
    }

    function syncHyprsunset() {
        if (root.hyprsunsetEnabled && !root.hyprsunsetRunning) {
            hyprsunsetStartProc.startDetached();
            root.hyprsunsetRunning = true;
        } else if (!root.hyprsunsetEnabled && root.hyprsunsetRunning) {
            hyprsunsetKillProc.running = true;
            root.hyprsunsetRunning = false;
        }
    }

    // Must run after both ddcDetectProc and backlightCheckProc have completed at least once.
    function rebuildMonitors(): void {
        for (const m of monitors)
            m.destroy();

        const next = [];
        for (const screen of Quickshell.screens) {
            const isDdc = screen.name in root.ddcMonitorMap;
            const isInternalPanel = root.internalPanelPattern.test(screen.name) && root.backlightAvailable;

            if (isDdc || isInternalPanel)
                next.push(monitorComp.createObject(root, {
                    screen,
                    isDdc,
                    busNum: isDdc ? root.ddcMonitorMap[screen.name].busNum : ""
                }));
        }

        root.monitors = next;
    }

    onHyprsunsetEnabledChanged: syncHyprsunset()

    reloadableId: "brightness"

    Component.onCompleted: {
        checkProc.running = true;
        ddcDetectProc.running = true;
        backlightCheckProc.running = true;
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            ddcDetectProc.running = true;
            backlightCheckProc.running = true;
        }
    }

    Process {
        id: checkProc
        command: ["pgrep", "-x", "hyprsunset"]
        stdout: SplitParser {
            onRead: data => {
                root.hyprsunsetRunning = data.trim() !== "";
                if (root.hyprsunsetEnabled && !root.hyprsunsetRunning) {
                    hyprsunsetStartProc.startDetached();
                    root.hyprsunsetRunning = true;
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.hyprsunsetRunning = false;
                if (root.hyprsunsetEnabled) {
                    hyprsunsetStartProc.startDetached();
                    root.hyprsunsetRunning = true;
                }
            }
        }
    }

    Process {
        id: hyprsunsetStartProc
        command: ["hyprsunset"]
    }

    Process {
        id: hyprsunsetKillProc
        command: ["pkill", "hyprsunset"]
    }

    Process {
        id: ddcDetectProc
        command: ["ddcutil", "detect", "--brief"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.ddcMonitors = text.trim().length === 0 ? [] : text.trim().split("\n\n").filter(d => d.startsWith("Display ")).map(d => ({
                            busNum: d.match(/I2C bus:[ ]*\/dev\/i2c-([0-9]+)/)?.[1] ?? "",
                            connector: (d.match(/DRM connector:\s+(.*)/)?.[1] ?? "").replace(/^card\d+-/, "")
                        }));
                root.rebuildMonitors();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.ddcMonitors = [];
                root.rebuildMonitors();
            }
        }
    }

    Process {
        id: backlightCheckProc
        command: ["sh", "-c", "brightnessctl g 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backlightAvailable = text.trim().length > 0;
                root.rebuildMonitors();
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                root.backlightAvailable = false;
                root.rebuildMonitors();
            }
        }
    }

    component BrightnessMonitor: QtObject {
        id: monitor

        required property ShellScreen screen
        required property bool isDdc
        property string busNum: ""
        property real brightness
        property real queuedBrightness: NaN
        property bool ready: false

        function stepBrightness(delta: real): void {
            monitor.setBrightness(monitor.brightness + delta);
        }

        onBrightnessChanged: {
            if (monitor.ready) {
                root.brightnessChanged();
            }
        }

        function initialize() {
            monitor.ready = false;
            if (monitor.isDdc) {
                initProc.command = ["ddcutil", "-b", monitor.busNum, "getvcp", "10", "--brief"];
            } else {
                initProc.command = ["sh", "-c", `echo "$(brightnessctl g) $(brightnessctl m)"`];
            }
            initProc.running = true;
        }

        readonly property Process initProc: Process {
            stdout: StdioCollector {
                onStreamFinished: {
                    if (monitor.isDdc) {
                        const parts = text.trim().split(" ");
                        const cur = parts[3];
                        const max = parts[4];
                        monitor.brightness = parseInt(cur) / parseInt(max);
                    } else {
                        const [current, max] = text.trim().split(" ");
                        monitor.brightness = parseInt(current) / parseInt(max);
                    }
                    monitor.ready = true;
                }
            }
        }

        readonly property Timer debounceTimer: Timer {
            interval: 500
            onTriggered: {
                if (!isNaN(monitor.queuedBrightness)) {
                    monitor.setBrightness(monitor.queuedBrightness);
                    monitor.queuedBrightness = NaN;
                }
            }
        }

        function setBrightness(value: real): void {
            value = Math.max(0.01, Math.min(1, value));
            const rounded = Math.round(value * 100);
            if (Math.round(brightness * 100) === rounded)
                return;

            if (monitor.isDdc && debounceTimer.running) {
                monitor.queuedBrightness = value;
                return;
            }

            brightness = value;

            if (monitor.isDdc)
                Quickshell.execDetached(["ddcutil", "-b", monitor.busNum, "setvcp", "10", `${rounded}`]);
            else
                Quickshell.execDetached(["brightnessctl", "s", `${rounded}%`, "--quiet"]);

            if (monitor.isDdc)
                debounceTimer.restart();
        }

        Component.onCompleted: {
            initialize();
        }
    }

    Component {
        id: monitorComp
        BrightnessMonitor {}
    }
}
