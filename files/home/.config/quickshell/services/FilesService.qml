pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/FuzzySort.js" as FuzzySort
import "../lib/FuzzyFilter.js" as FuzzyFilter

Singleton {
    id: root

    property string searchText: ""
    property var preparedZoxide: []
    property var preparedFd: []
    property var focusedItem: filteredResults[0]
    property bool loading: searchProcess.running || detailsProcess.running || zoxideProcess.running
    property var detailsCache: ({})
    property var _preparedByPath: ({})

    readonly property string homeDir: Quickshell.env("HOME") || ""

    function expandTilde(q) {
        if (q === "~")
            return root.homeDir;
        if (q.startsWith("~/"))
            return root.homeDir + q.slice(1);
        return q;
    }

    Timer {
        id: searchDebounce
        interval: 150
        repeat: false
        onTriggered: root._doSearch()
    }

    property string focusedItemName: ""
    property string focusedItemPath: ""
    property string focusedItemIcon: "text-x-generic"
    property string focusedItemMime: ""
    property string focusedItemSize: "0 B"
    property bool focusedItemIsDir: false
    property bool focusedItemReadable: false
    property string focusedItemPreview: ""
    property int focusedItemLines: 0
    property int focusedItemChars: 0
    property int focusedItemFileCount: 0

    readonly property var filteredResults: {
        const raw = root.searchText.trim();
        if (!raw)
            return root.preparedZoxide.map(i => i.obj);

        const poolMap = new Map();
        root.preparedZoxide.forEach(item => poolMap.set(item.obj.path, item));
        root.preparedFd.forEach(item => poolMap.set(item.obj.path, item));

        const query = root.expandTilde(raw);

        // Path mode: list children of a directory, filtered by name prefix
        if (query.startsWith("/")) {
            let dir, prefix;
            if (query === root.homeDir || query.endsWith("/")) {
                dir = query.replace(/\/+$/, "") || "/";
                prefix = "";
            } else {
                const idx = query.lastIndexOf("/");
                dir = query.slice(0, idx) || "/";
                prefix = query.slice(idx + 1).toLowerCase();
            }

            return Array.from(poolMap.values()).map(w => w.obj).filter(o => {
                const p = o.path;
                const i = p.lastIndexOf("/");
                const parent = p.slice(0, i) || "/";
                const base = p.slice(i + 1).toLowerCase();
                return parent === dir && base.startsWith(prefix);
            }).sort((a, b) => {
                if (a.is_dir !== b.is_dir)
                    return a.is_dir ? -1 : 1;
                return (a.name || "").localeCompare(b.name || "");
            }).slice(0, 100);
        }

        return FuzzyFilter.search(query, Array.from(poolMap.values()), {
            limit: 100,
            all: true,
            keys: ["name", "path"],
            scoreFn: i => i.score + (i.obj.zoxide_score || 0),
            pick: item => item.obj.obj
        });
    }

    onSearchTextChanged: {
        if (!root.searchText.trim()) {
            searchDebounce.stop();
            searchProcess.running = false;
            root.preparedFd = [];
            return;
        }
        searchDebounce.restart();
    }

    function isMimeReadable(mime) {
        if (!mime)
            return false;
        if (mime.startsWith("text/"))
            return true;
        const readable_mimes = ["application/json", "application/xml", "application/javascript", "application/x-shellscript", "application/x-sh", "application/x-yaml", "application/toml", "application/x-ruby", "application/x-python", "application/x-perl",];
        return readable_mimes.includes(mime);
    }

    onFocusedItemChanged: {
        detailsProcess.running = false;
        if (!root.focusedItem) {
            root._clearDetails();
            return;
        }

        // Immediately sync basic info from the list item to prevent flicker
        root.focusedItemName = root.focusedItem.name || "";
        root.focusedItemPath = root.focusedItem.path || "";
        root.focusedItemIcon = root.focusedItem.icon || "text-x-generic";
        root.focusedItemMime = root.focusedItem.mime || "";
        root.focusedItemSize = root.focusedItem.size || "0 B";
        root.focusedItemIsDir = root.focusedItem.is_dir || false;

        // Calculate readability immediately so the UI doesn't swap modes (flicker)
        root.focusedItemReadable = root.isMimeReadable(root.focusedItemMime);

        // We DO NOT reset root.focusedItemPreview here.
        // Keeping the old text for a few ms until detailsProcess finishes
        // makes the transition seamless.
        if (root.detailsCache[root.focusedItem.path]) {
            root._applyDetails(root.detailsCache[root.focusedItem.path]);
        } else {
            root._fetchDetails();
        }
    }

    function _doSearch() {
        searchProcess.command = [Paths.filesFetcherScript, root.searchText];
        searchProcess.running = true;
    }

    function _fetchDetails() {
        if (!root.focusedItem)
            return;
        detailsProcess.command = [Paths.filesFetcherScript, "--details", root.focusedItem.path];
        detailsProcess.running = true;
    }

    function _applyDetails(data) {
        root.focusedItemName = data.name || "";
        root.focusedItemPath = data.path || "";
        root.focusedItemIcon = data.icon || "text-x-generic";
        root.focusedItemMime = data.mime || "";
        root.focusedItemSize = data.size || "0 B";
        root.focusedItemIsDir = data.is_dir || false;
        root.focusedItemReadable = data.readable || false;
        root.focusedItemPreview = data.preview || "";
        root.focusedItemLines = data.lines || 0;
        root.focusedItemChars = data.chars || 0;
        root.focusedItemFileCount = data.file_count || 0;
    }

    function _clearDetails() {
        root._applyDetails({});
    }

    function _prepareResults(raw) {
        const cache = root._preparedByPath;
        return raw.map(item => {
            const key = item.path || item.name;
            const hit = cache[key];
            if (hit && hit.obj.name === item.name && hit.obj.path === item.path && hit.obj.mime === item.mime && hit.obj.size === item.size && hit.obj.icon === item.icon && (hit.obj.zoxide_score || 0) === (item.zoxide_score || 0) && !!hit.obj.is_dir === !!item.is_dir)
                return hit;
            const wrapped = {
                obj: item,
                name: FuzzySort.prepare(item.name || ""),
                path: FuzzySort.prepare(item.path || "")
            };
            cache[key] = wrapped;
            return wrapped;
        });
    }

    Process {
        id: zoxideProcess
        command: [Paths.filesFetcherScript, "--zoxide"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.preparedZoxide = root._prepareResults(JSON.parse(text));
                } catch (e) {}
            }
        }
    }

    Process {
        id: searchProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.preparedFd = root._prepareResults(JSON.parse(text));
                } catch (e) {
                    root.preparedFd = [];
                }
            }
        }
    }

    Process {
        id: detailsProcess
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    const dc = root.detailsCache;
                    dc[data.path] = data;
                    const keys = Object.keys(dc);
                    if (keys.length > 100)
                        delete dc[keys[0]];
                    if (root.focusedItem && root.focusedItem.path === data.path) {
                        root._applyDetails(data);
                    }
                } catch (e) {}
            }
        }
    }

    function openFocused() {
        if (root.focusedItem)
            Quickshell.execDetached(["gio", "open", root.focusedItem.path]);
    }

    Component.onCompleted: {
        root.detailsCache = {};
        zoxideProcess.running = true;
    }
}
