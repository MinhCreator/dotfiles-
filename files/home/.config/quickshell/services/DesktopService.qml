pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs

Singleton {
    id: root
    readonly property int clockWidgetWidth: 300
    readonly property int clockWidgetHeight: 125
    readonly property var mainMonitor: Hyprland.monitors?.values.find(m => m.name === GlobalSettings.mainMonitor) ?? Hyprland.monitors?.values[0]

    property string wallpaperContentHash: ""
    property bool fetchPending: false

    function selectWallpaper(wallpaperPath: string, isTemporaryWallpaper: bool, contentHash: string) {
        if (GlobalData.wallpaperWebpPath !== Paths.wallpaperWebp)
            GlobalData.wallpaperWebpPath = Paths.wallpaperWebp;
        if (!isTemporaryWallpaper && wallpaperPath === GlobalData.wallpaperPath)
            return;
        GlobalData.wallpaperPath = wallpaperPath;
        root.wallpaperContentHash = contentHash ?? "";
        root.refresh();
    }

    function refresh() {
        if (!root.mainMonitor)
            return;
        if (dataFetcher.running) {
            root.fetchPending = true;
            return;
        }
        root.fetchPending = false;
        const hashArg = root.wallpaperContentHash !== "" ? ` --content-hash ${root.wallpaperContentHash}` : "";
        dataFetcher.exec(["sh", "-c", `
        python3 ${Paths.desktopWidgetScript} ${GlobalData.wallpaperPath}
        --screen-width ${mainMonitor.width}
        --screen-height ${mainMonitor.height}
        --widget-width ${clockWidgetWidth}
        --widget-height ${clockWidgetHeight}${hashArg}
        `]);
    }

    Process {
        id: dataFetcher
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (!root.mainMonitor)
                        return;
                    const data = JSON.parse(text);
                    data.x = data.x / root.mainMonitor.scale;
                    data.y = data.y / root.mainMonitor.scale;
                    GlobalData.desktopWidgetData = data;
                } catch (e) {}
                if (root.fetchPending)
                    root.refresh();
            }
        }
    }
}
