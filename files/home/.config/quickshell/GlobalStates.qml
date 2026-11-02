pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool showBar: true
    property bool showLauncher: false
    property bool showAltTabSwitcher: false
    property bool showScreenCapture: false
    property bool isNotificationActionsMenuOpenVisible: false
    property bool showNotificationHistory: false
    property bool isLocking: false
    property string expandedBarModule: ""
    property string currentLauncherPage: ""
}
