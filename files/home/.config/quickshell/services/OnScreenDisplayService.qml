pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs

Singleton {
    id: root

    readonly property var osdTypes: ["volume", "mic", "brightness"]
    property string osdType: "volume"
    property bool visible: false

    function show(type: string): void {
        if (GlobalCache.loadLockScreen)
            return;
        root.osdType = type;
        root.visible = true;
        hideTimer.restart();
    }

    function hide(): void {
        root.visible = false;
    }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        onTriggered: root.visible = false
    }
}