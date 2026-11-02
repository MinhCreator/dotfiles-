.pragma library
.import "FuzzyFilter.js" as FuzzyFilter

/**
 * Finds an application icon based on a query string by searching through desktop entries.
 * @param {string} query - The search query (e.g., app name, process name, or stream name).
 * @param {Array} apps - The list of application desktop entries to search in.
 * @param {string[]} [alternatives=[]] - Alternative strings to try if the primary query fails.
 * @returns {string} The icon name found, or the original query if no match is found.
 */
function getAppIcon(query, apps, alternatives = []) {
    if (!query) return "";
    if (!apps || apps.length === 0) return query;

    const searchFields = ['name', 'id', 'genericName'];
    const invalidPattern = /^[^a-zA-Z0-9]+$/;

    for (const q of [query, ...alternatives]) {
        if (!q || invalidPattern.test(q)) continue;

        const filtered = FuzzyFilter.search(q, apps, {
            threshold: 0,
            limit: 1,
            all: false,
            keys: searchFields,
            pick: "raw"
        });

        const icon = filtered[0]?.obj?.icon;
        if (icon) return icon;
    }

    return query;
}

/**
 * Finds the HyprlandToplevel matching a given DesktopEntry, using multiple
 * fields in order of reliability: Wayland appId > IPC class > IPC initialClass > desktop entry id stem.
 * @param {object} app - A DesktopEntry object.
 * @param {Array} toplevels - Hyprland.toplevels.values
 * @returns {object|null} The matching HyprlandToplevel, or null if not found.
 */
function findToplevelForApp(app, toplevels) {
    if (!app || !toplevels) return null;

    return toplevels.find(toplevel => {
        const ipc = toplevel.lastIpcObject;

        if (toplevel.wayland?.appId) {
            const appId = toplevel.wayland.appId.toLowerCase();
            if (app.startupClass && appId === app.startupClass.toLowerCase()) return true;
            if (app.id && appId === app.id.replace(/\.desktop$/, "").toLowerCase()) return true;
        }

        if (app.startupClass) {
            const sc = app.startupClass.toLowerCase();
            if (ipc.class?.toLowerCase() === sc) return true;
            if (ipc.initialClass?.toLowerCase() === sc) return true;
        }

        if (app.id) {
            const idStem = app.id.replace(/\.desktop$/, "").toLowerCase();
            if (ipc.class?.toLowerCase() === idStem) return true;
            if (ipc.initialClass?.toLowerCase() === idStem) return true;
        }

        return false;
    }) ?? null;
}

/**
 * Returns true if at least one running toplevel matches the given DesktopEntry.
 * @param {object} app - A DesktopEntry object.
 * @param {Array} toplevels - Hyprland.toplevels.values
 * @returns {boolean}
 */
