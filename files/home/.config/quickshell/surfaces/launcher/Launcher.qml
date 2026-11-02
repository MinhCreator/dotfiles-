pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.surfaces.launcher
import qs

Scope {
    id: scope

    function toggle() {
        GlobalStates.showLauncher = !GlobalStates.showLauncher;
    }

    function execute(id) {
        LauncherService.executeCommandById(id);
    }

    function launch(mode) {
        LauncherService.pushByName(mode, true);
        if (!GlobalStates.showLauncher)
            GlobalStates.showLauncher = true;
    }

    LazyLoader {
        id: windowLoader
        active: GlobalStates.showLauncher && !GlobalCache.loadLockScreen
        component: LauncherWindow {}
    }
}
