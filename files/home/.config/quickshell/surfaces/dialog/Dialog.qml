pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs

Scope {
    id: scope

    readonly property string mainMonitorName: (GlobalSettings.mainMonitor || Quickshell.screens[0]?.name) ?? ""

    property bool isOpen: false
    property string kind: "" // "confirm" | "info"
    property string title: ""
    property string description: ""
    property string cancelText: "Cancel"
    property string proceedText: "Proceed"
    property string okText: "OK"
    property string cancelCommand: ""
    property string proceedCommand: ""
    property string okCommand: ""

    function close() {
        scope.kind = "";
        scope.isOpen = false;
    }

    function executeCommand(command) {
        if (command)
            Quickshell.execDetached(["sh", "-c", command]);
    }

    function showConfirm(title, description, cancelText, proceedText, cancelCommand, proceedCommand) {
        scope.title = title;
        scope.description = description;
        scope.cancelText = cancelText || "Cancel";
        scope.proceedText = proceedText || "Proceed";
        scope.cancelCommand = cancelCommand;
        scope.proceedCommand = proceedCommand;
        scope.kind = "confirm";
        scope.isOpen = true;
    }

    function showInfo(title, message, okText, okCommand) {
        scope.title = title;
        scope.description = message;
        scope.okText = okText || "OK";
        scope.okCommand = okCommand;
        scope.kind = "info";
        scope.isOpen = true;
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: dialogLoader
            required property ShellScreen modelData
            active: scope.isOpen && !GlobalCache.loadLockScreen

            component: DialogWindow {
                scope: scope
                screen: dialogLoader.modelData
            }
        }
    }
}
