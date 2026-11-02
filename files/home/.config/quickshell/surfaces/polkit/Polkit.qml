pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs

Scope {
    id: root

    Loader {
        active: PolkitService.active && !GlobalCache.loadLockScreen
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: panelWindow
                required property var modelData
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                WlrLayershell.namespace: "quickshell:polkit"
                WlrLayershell.keyboardFocus: panelWindow.screen.name === GlobalSettings.mainMonitor ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                WlrLayershell.layer: WlrLayer.Overlay
                exclusionMode: ExclusionMode.Ignore

                PolkitContent {
                    isMainMonitor: panelWindow.screen.name === GlobalSettings.mainMonitor
                }
            }
        }
    }
}
