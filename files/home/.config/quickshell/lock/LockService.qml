pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam
import qs.services
import qs

Singleton {
    id: root

    property bool locked: false
    property bool showUI: false
    property bool hasFailed: false
    property bool isLocking: false
    property bool lockInput: false
    property bool isAuthenticating: false
    property bool navigateBeforeLock: true
    property int lastTotalWindows: 0
    property var lastSpecialWorkspace: false
    property string passwordInput: ""
    onIsLockingChanged: GlobalStates.isLocking = root.isLocking

    function lock(navigateBeforeLock) {
        if (locked)
            return;
        root.isLocking = true;
        root.navigateBeforeLock = navigateBeforeLock;
        root.lastSpecialWorkspace = HyprlandService.currentSpecialWorkspace;
        Hyprland.dispatch(`hl.dsp.focus({ monitor = '${GlobalSettings.mainMonitor}' })`);
        if (root.navigateBeforeLock) {
            root.lastTotalWindows = Hyprland.focusedWorkspace.toplevels.values.length;
            if (root.lastSpecialWorkspace !== false)
                Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${root.lastSpecialWorkspace.replace("special:", "")}")`);
            Hyprland.dispatch("require('hyprland.lua.utils.workspaces'):go('new')");
        }
        shortcutInhibitor.enabled = true;
        if (Hyprland.monitors.values.length === 1) {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({cursor = {invisible = true} })"]);
        } else {
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({cursor = {inactive_timeout = 1} })"]);
        }
        GlobalCache.loadLockScreen = true;
        lockTimer.start();
    }

    function unlock() {
        shortcutInhibitor.enabled = false;
        showUI = false;
        unlockTimer.start();
    }

    function submit() {
        if (isAuthenticating || !pamContext.responseRequired)
            return;

        hasFailed = false;
        isAuthenticating = true;
        pamContext.respond(passwordInput);
    }

    ShortcutInhibitor {
        id: shortcutInhibitor
        enabled: false
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            WlrLayershell.namespace: "quickshell:shortcutinhibitor"
            WlrLayershell.keyboardFocus: shortcutInhibitor.enabled ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region {
                item: null
            }
        }
    }

    // Delay locking slightly to let the lock screen load
    Timer {
        id: lockTimer
        interval: 200
        triggeredOnStart: false
        onTriggered: {
            root.locked = true;
            root.showUI = true;
            pamContext.start();
            shortcutInhibitor.enabled = false;
            root.isLocking = false;
        }
    }

    // Delay unlocking slightly to let the hide animation play
    Timer {
        id: unlockTimer
        interval: 400
        onTriggered: {
            root.locked = false;
            GlobalCache.loadLockScreen = false;
            Quickshell.execDetached(["hyprctl", "eval", "hl.config({cursor = {invisible = false, inactive_timeout = 5} })"]);
            if (root.navigateBeforeLock) {
                if (root.lastSpecialWorkspace !== false)
                    Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${root.lastSpecialWorkspace.replace("special:", "")}")`);
                if (root.lastTotalWindows !== 0) {
                    Hyprland.dispatch("require('hyprland.lua.utils.workspaces'):go('back')");
                    root.lastTotalWindows = 0;
                }
            }
            root.navigateBeforeLock = true;
        }
    }

    Timer {
        interval: 3000
        running: root.hasFailed
        onTriggered: root.hasFailed = false
    }

    PamContext {
        id: pamContext

        onPamMessage: {
            if (messageIsError) {
                root.hasFailed = true;
                root.isAuthenticating = false;
            }
        }

        onCompleted: result => {
            root.isAuthenticating = false;
            if (result === PamResult.Success) {
                root.hasFailed = false;
                root.unlock();
            } else {
                root.hasFailed = true;
                pamContext.start(); // Restart session for next attempt
            }
        }
    }
}
