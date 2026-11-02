pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

Singleton {
    id: root

    property var windows: []
    property var monitors: []
    property bool active: false

    property int currentTab: 0 // 0: Windows, 1: Monitors
    property int selectedIndex: 0

    // Paging logic
    readonly property int itemsPerRow: 3
    readonly property int rowsPerPage: 3
    readonly property int itemsPerPage: itemsPerRow * rowsPerPage

    readonly property var currentModel: currentTab === 0 ? windows : monitors

    property var windowPages: createPages(windows)
    property var monitorPages: createPages(monitors)
    readonly property var currentPages: currentTab === 0 ? windowPages : monitorPages

    function createPages(items) {
        let pages = [];
        for (let i = 0; i < items.length; i += itemsPerPage) {
            let page = [];
            for (let j = 0; j < rowsPerPage; j++) {
                let row = [];
                let start = i + j * itemsPerRow;
                for (let k = 0; k < itemsPerRow && start + k < items.length; k++) {
                    row.push(items[start + k]);
                }
                if (row.length > 0)
                    page.push(row);
            }
            if (page.length > 0)
                pages.push(page);
        }
        return pages;
    }

    function start(sharingList: string): void {
        parseSharingList(sharingList);
        root.monitors = Quickshell.screens.map(s => ({
            name: s.name,
            wayland: s
        }));

        // Refresh pages
        windowPages = createPages(windows);
        monitorPages = createPages(monitors);

        root.selectedIndex = 0;
        root.active = true;
    }

    function parseSharingList(list: string): void {
        const entries = list.split("[HA>]").filter(e => e.length > 0);
        const parsedWindows = [];

        for (const entry of entries) {
            const parts = entry.split("[HE>]");
            if (parts.length < 2)
                continue;

            const metadata = parts[0];
            const addressRaw = parts[1];
            const metaParts = metadata.split("[HT>]");
            if (metaParts.length < 2)
                continue;

            const idAndClass = metaParts[0];
            const title = metaParts[1];
            const idAndClassParts = idAndClass.split("[HC>]");
            if (idAndClassParts.length < 2)
                continue;

            const id = idAndClassParts[0];
            const className = idAndClassParts[1];

            let addressHex = "";
            try {
                addressHex = addressRaw.toString(16).toLowerCase();
            } catch (e) {
                console.warn("Failed to parse address:", addressRaw);
            }

            const toplevel = Hyprland.toplevels.values.find(t => t.lastIpcObject.title === title && t.lastIpcObject.class === className);

            parsedWindows.push({
                id: id,
                class: className,
                title: title,
                address: addressHex,
                wayland: toplevel ? toplevel.wayland : null
            });
        }
        root.windows = parsedWindows;
    }

    function switchNext() {
        if (currentModel.length === 0)
            return;
        selectedIndex = (selectedIndex + 1) % currentModel.length;
    }

    function switchPrevious() {
        if (currentModel.length === 0)
            return;
        selectedIndex = (selectedIndex - 1 + currentModel.length) % currentModel.length;
    }

    function activateSelected() {
        if (!active || currentModel.length === 0)
            return;
        const item = currentModel[selectedIndex];
        if (currentTab === 1) {
            selectMonitor(item.name);
        } else {
            selectWindow(item.id);
        }
    }

    function selectAndActivate(index) {
        selectedIndex = index;
        activateSelected();
    }

    function selectWindow(id: string): void {
        GlobalIpc.emitScreenshareSelection(`[SELECTION]/window:${id}`);
        close();
    }

    function selectMonitor(name: string): void {
        GlobalIpc.emitScreenshareSelection(`[SELECTION]/screen:${name}`);
        close();
    }

    function cancel(): void {
        GlobalIpc.emitScreenshareSelection("");
        close();
    }

    function close(): void {
        root.active = false;
        root.currentTab = 0;
        GlobalCache.loadScreenSharePicker = false;
    }
}
