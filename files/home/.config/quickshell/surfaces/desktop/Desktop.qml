pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) ?? Quickshell.screens[0]

    color: "transparent"
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:desktop"

    property var desktopData: GlobalData.desktopWidgetData

    Item {
        anchors.fill: parent

        ClockWidget {
            desktopData: root.desktopData
            x: root.desktopData.x
            y: root.desktopData.y
        }
    }
}
