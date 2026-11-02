pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/FuzzyFilter.js" as FuzzyFilter

Singleton {
    id: root

    // Provider contract
    readonly property string providerId: "local"
    readonly property string displayName: "Local"
    readonly property bool requiresApiKey: false

    property string query: ""
    readonly property bool isLoading: false

    // Local state
    property var wallpapers: JSON.parse(wallpapersJsonFile.text())
    property var accentColors: colorsFile.text().split("\n")
    property int currentAccentColorIndex: Number(colorIndexFile.text())

    property var filteredWallpapers: {
        const q = root.query.trim();
        const showHidden = q.startsWith("/");

        let baseList = (root.wallpapers || []).filter(wp => {
            const isHidden = (wp.name || "").startsWith(".");
            return showHidden ? isHidden : !isHidden;
        });

        if (q === "" || q === "/")
            return baseList;

        const searchTerms = showHidden ? q.substring(1) : q;

        return FuzzyFilter.search(searchTerms, baseList, {
            threshold: 0,
            limit: 999,
            all: true,
            keys: ["name", "ext"]
        });
    }

    // Normalized items for the shared grid delegate:
    // id / title / image (full-res) / thumb / badge / state / animated
    property var items: root.filteredWallpapers.map(wp => ({
                id: wp.image,
                title: (wp.name || "") + (wp.ext || ""),
                image: wp.image,
                thumb: wp.thumbnail,
                badge: "",
                state: "ready",
                animated: (wp.ext || "").toLowerCase() === ".gif"
            }))
    readonly property int itemCount: items.length

    FileView {
        id: wallpapersJsonFile
        path: Qt.resolvedUrl(Paths.wallpapersJsonFile)
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    FileView {
        id: colorsFile
        path: Qt.resolvedUrl(Paths.wallpaperColorsFile)
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    FileView {
        id: colorIndexFile
        path: Qt.resolvedUrl(Paths.wallpaperSelectedColorIndexFile)
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    // Provider contract functions
    function activate() {
    }

    function deactivate() {
    }

    function setQuery(q) {
        if (root.query !== q)
            root.query = q;
    }

    function retryItem(id) {
        // Local images load synchronously from disk: nothing to retry
    }

    function requestAutoRetry(id) {
    }

    function setColorIndex(newIndex) {
        if (newIndex !== root.currentAccentColorIndex && newIndex >= 0 && newIndex <= root.accentColors.length) {
            colorIndexFile.setText(newIndex);
            Quickshell.execDetached(["sh", "-c", `sleep 0.2 && $BN_SCRIPTS/select-wallpaper --refresh`]);
        }
    }

    function indexOfCurrentWallpaper() {
        const path = GlobalData.wallpaperPath;
        return root.filteredWallpapers.findIndex(wp => wp.image === path);
    }

    function primaryAction(wp) {
        secondaryAction(wp);
        GlobalStates.showLauncher = false;
    }

    function secondaryAction(wp) {
        if (!wp)
            return;
        if (wp.image === GlobalData.wallpaperPath) {
            GlobalIpc.popup.showInfo("Wallpaper Already Set", "", 2000);
            return;
        }
        Quickshell.execDetached(["sh", "-c", `$BN_SCRIPTS/select-wallpaper ${wp.image}`]);
        GlobalIpc.popup.showInfo("Wallpaper Applied", "", 2000);
    }
}
