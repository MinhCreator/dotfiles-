pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property var flattenedToplevels: []
    property int selectedIndex: 0
    property int totalScreencopyViews: 0
    property int loadedScreencopyViews: 0

    readonly property bool isVisible: GlobalStates.showAltTabSwitcher

    // Window paging logic
    readonly property int itemsPerRow: 3
    readonly property int rowsPerPage: 3
    readonly property int itemsPerPage: itemsPerRow * rowsPerPage

    property var windowPages: {
        let pages = [];
        let filtered = flattenedToplevels;

        for (let i = 0; i < filtered.length; i += itemsPerPage) {
            let page = [];
            for (let j = 0; j < rowsPerPage; j++) {
                let row = [];
                let start = i + j * itemsPerRow;
                for (let k = 0; k < itemsPerRow && start + k < filtered.length; k++) {
                    row.push(filtered[start + k]);
                }
                if (row.length > 0)
                    page.push(row);
            }
            if (page.length > 0)
                pages.push(page);
        }
        return pages;
    }

    function updateToplevels() {
        let filtered = Hyprland.toplevels.values.filter(t => t.title !== "" && t.monitor !== null && t.initialClass !== "quickshell" && t.initialClass !== "");

        // Helper to normalize hex addresses
        const norm = addr => {
            if (typeof addr === "number")
                return addr.toString(16).toLowerCase();
            if (typeof addr === "string")
                return addr.toLowerCase().replace(/^0x/, "");
            return "";
        };

        // 1. Move active toplevel to index 0
        let active = Hyprland.activeToplevel;
        if (active) {
            let index = filtered.findIndex(t => norm(t.address) === norm(active.address));
            if (index !== -1) {
                let t = filtered.splice(index, 1)[0];
                filtered.unshift(t);
            }
        }

        // 2. Move last focused toplevel to index 1
        let lastAddr = norm(GlobalCache.lastFocusedWindowAddress);
        if (lastAddr !== "" && filtered.length > 1) {
            let lastIndex = filtered.findIndex(t => norm(t.address) === lastAddr);
            // Only move it if it's not already at index 1 or 0
            if (lastIndex > 1) {
                let t = filtered.splice(lastIndex, 1)[0];
                filtered.splice(1, 0, t);
            }
        }

        flattenedToplevels = filtered;
        totalScreencopyViews = filtered.length;
        loadedScreencopyViews = 0;
    }

    function switchNext() {
        if (!GlobalStates.showAltTabSwitcher) {
            updateToplevels();
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = 1;
            GlobalStates.showAltTabSwitcher = true;
        } else {
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = (selectedIndex + 1) % flattenedToplevels.length;
        }
    }

    function switchPrevious() {
        if (!GlobalStates.showAltTabSwitcher) {
            updateToplevels();
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = flattenedToplevels.length - 1;
            GlobalStates.showAltTabSwitcher = true;
        } else {
            if (flattenedToplevels.length === 0)
                return;
            selectedIndex = (selectedIndex - 1 + flattenedToplevels.length) % flattenedToplevels.length;
        }
    }

    function activateSelected() {
        if (GlobalStates.showAltTabSwitcher) {
            let toplevel = flattenedToplevels[selectedIndex];
            if (toplevel) {
                Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${toplevel.address}" })`);
            }
        }
        close();
    }

    function selectAndActivate(index) {
        selectedIndex = index;
        activateSelected();
    }

    function close() {
        GlobalStates.showAltTabSwitcher = false;
        Hyprland.dispatch('hl.dsp.submap("reset")');
    }

    function incrementLoadedViews() {
        loadedScreencopyViews++;
    }

    function getToplevelFlatIndex(toplevel) {
        return flattenedToplevels.indexOf(toplevel);
    }
}
