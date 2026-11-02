pragma ComponentBehavior: Bound
pragma Singleton

import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.surfaces.launcher

Singleton {
    id: root

    component QsShortcut: GlobalShortcut {
        appid: "quickshell"
    }

    function isLocked(): bool {
        return GlobalCache.loadLockScreen;
    }

    function toggleLauncher(): void {
        if (root.isLocked())
            return;
        GlobalStates.showLauncher = !GlobalStates.showLauncher;
    }

    function launchMode(mode: string): void {
        if (root.isLocked())
            return;
        LauncherService.pushByName(mode, true);
        if (!GlobalStates.showLauncher)
            GlobalStates.showLauncher = true;
    }

    function toggleBarModule(name: string): void {
        if (root.isLocked())
            return;
        const modules = ["resources", "mprisPlayers", "dateTime", "weather", "controlCenter", "battery"];
        if (!modules.includes(name))
            return;
        if (name !== GlobalStates.expandedBarModule)
            GlobalStates.expandedBarModule = name;
        else
            GlobalStates.expandedBarModule = "";
    }

    // Launcher
    QsShortcut {
        name: "launcher-toggle"
        description: "Toggle launcher"
        onPressed: root.toggleLauncher()
    }
    QsShortcut {
        name: "launcher-clipboard"
        description: "Open launcher on clipboard"
        onPressed: root.launchMode("clipboard")
    }
    QsShortcut {
        name: "launcher-files"
        description: "Open launcher on files"
        onPressed: root.launchMode("files")
    }
    QsShortcut {
        name: "launcher-calculator"
        description: "Open launcher on calculator"
        onPressed: root.launchMode("calculator")
    }
    QsShortcut {
        name: "launcher-tasks"
        description: "Open launcher on tasks"
        onPressed: root.launchMode("tasks")
    }
    QsShortcut {
        name: "launcher-emojis"
        description: "Open launcher on emojis"
        onPressed: root.launchMode("emojis")
    }
    QsShortcut {
        name: "launcher-processes"
        description: "Open launcher on processes"
        onPressed: root.launchMode("processes")
    }
    QsShortcut {
        name: "launcher-wallpaper"
        description: "Open launcher on wallpaper"
        onPressed: root.launchMode("wallpaper")
    }
    QsShortcut {
        name: "launcher-wallhaven"
        description: "Open launcher on wallhaven"
        onPressed: root.launchMode("wallhaven")
    }
    QsShortcut {
        name: "launcher-keybinds"
        description: "Open launcher on keybinds"
        onPressed: root.launchMode("keybinds")
    }
    QsShortcut {
        name: "launcher-monitors"
        description: "Open launcher on monitors"
        onPressed: root.launchMode("monitors")
    }
    QsShortcut {
        name: "launcher-translate"
        description: "Open launcher on translate"
        onPressed: root.launchMode("translate")
    }
    QsShortcut {
        name: "launcher-websearch"
        description: "Open launcher on web search"
        onPressed: root.launchMode("websearch")
    }
    QsShortcut {
        name: "launcher-commands"
        description: "Open launcher on commands"
        onPressed: root.launchMode("commands")
    }
    QsShortcut {
        name: "launcher-unsplash"
        description: "Open launcher on unsplash"
        onPressed: root.launchMode("unsplash")
    }

    // Bar modules
    QsShortcut {
        name: "bar-resources"
        description: "Toggle bar resources module"
        onPressed: root.toggleBarModule("resources")
    }
    QsShortcut {
        name: "bar-mpris"
        description: "Toggle bar media players module"
        onPressed: root.toggleBarModule("mprisPlayers")
    }
    QsShortcut {
        name: "bar-datetime"
        description: "Toggle bar date and time module"
        onPressed: root.toggleBarModule("dateTime")
    }
    QsShortcut {
        name: "bar-weather"
        description: "Toggle bar weather module"
        onPressed: root.toggleBarModule("weather")
    }
    QsShortcut {
        name: "bar-controlcenter"
        description: "Toggle bar control center module"
        onPressed: root.toggleBarModule("controlCenter")
    }
    QsShortcut {
        name: "bar-battery"
        description: "Toggle bar battery module"
        onPressed: root.toggleBarModule("battery")
    }
    QsShortcut {
        name: "bar-close"
        description: "Close expanded bar module"
        onPressed: GlobalStates.expandedBarModule = ""
    }

    // Alt Tab
    QsShortcut {
        name: "alttab-next"
        description: "Show switcher and select next window, activate on release"
        onPressed: if (!root.isLocked())
            AltTabService.switchNext()
    }
    QsShortcut {
        name: "alttab-previous"
        description: "Show switcher and select previous window, activate on release"
        onPressed: if (!root.isLocked())
            AltTabService.switchPrevious()
    }
    QsShortcut {
        name: "alttab-close"
        description: "Close window switcher without switching"
        onPressed: AltTabService.close()
    }
}
