pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/FuzzyFilter.js" as FuzzyFilter
import "../lib/FileUtils.js" as FileUtils
import "../lib/ColorUtils.js" as ColorUtils
import qs

Singleton {
    id: root

    property var clipboardHistory: []
    property string searchText: ""
    property var focusedItem: null

    readonly property string decodedContent: root._textFor(root.focusedItem)
    readonly property string focusedFilePath: root._imagePathFor(root.focusedItem)

    property var _incoming: []
    property var _dumpedHashes: ({})
    property var _decodedCache: ({})
    property string _pendingDecodeHash: ""

    onFocusedItemChanged: root._triggerDecodeFor(root.focusedItem)
    Component.onCompleted: _doReload()
    Component.onDestruction: lister.running = false

    property var filteredHistory: {
        const query = root.searchText.trim();
        let history = root.clipboardHistory;
        if (query) {
            history = FuzzyFilter.search(query, history, {
                limit: 999,
                all: true,
                keys: ["content"]
            });
        }
        return [...history].sort(function (a, b) {
            if (a.isPinned && !b.isPinned)
                return -1;
            if (!a.isPinned && b.isPinned)
                return 1;
            return b.timestamp - a.timestamp;
        });
    }

    Timer {
        id: reloadDebounce
        interval: 120
        repeat: false
        onTriggered: root._doReload()
    }

    Timer {
        id: decodeDebounce
        interval: 120
        repeat: false
        onTriggered: root._startDecode()
    }

    // Processes
    Process {
        id: lister
        command: ["bnclip", "list"]
        stdout: SplitParser {
            onRead: data => {
                const parts = data.split("\t");
                if (parts.length < 5)
                    return;
                const hash = parts[0].trim();
                const preview = parts.slice(4).join("\t").trim();
                if (!hash || !preview)
                    return;
                root._incoming = root._incoming.concat([
                    {
                        id: hash,
                        mime: parts[1].trim(),
                        kind: root._kindForPreview(preview),
                        isPinned: parts[2].trim() === "true",
                        timestamp: Number(parts[3]) || 0,
                        content: preview
                    }
                ]);
            }
        }
        onRunningChanged: {
            if (!running) {
                root.clipboardHistory = root._incoming;
                root._incoming = [];
                root._triggerDecodeFor(root.focusedItem);
            }
        }
    }

    Process {
        id: textProc
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.focusedItem || root.focusedItem.id !== root._pendingDecodeHash)
                    return;
                root._pendingDecodeHash = "";
                root._cacheDecoded(root.focusedItem.id, text);
            }
        }
    }

    Process {
        id: dumpProc
        property string hash: ""
        property string ext: ""
        onExited: (exitCode, exitStatus) => {
            const hash = dumpProc.hash;
            const ext = dumpProc.ext;
            dumpProc.hash = "";
            dumpProc.ext = "";
            if (exitCode !== 0 || !hash)
                return;
            root._dumpedHashes = Object.assign({}, root._dumpedHashes, {
                [hash]: "file://" + FileUtils.trimFileProtocol(Paths.bnclipDecodeTempDir) + "/" + hash + "." + ext
            });
        }
    }

    function _kindForPreview(preview) {
        if (preview.startsWith("[[ image"))
            return "image";
        if (preview.startsWith("[[ file:"))
            return "file";
        if (preview.startsWith("[[ directory:"))
            return "directory";
        if (ColorUtils.isColor(preview))
            return "color";
        return "text";
    }

    function entryIcon(kind) {
        if (kind === "directory")
            return "folder";
        if (kind === "image")
            return "image-x-generic";
        return "text-x-generic";
    }

    function _extForMime(mime) {
        const ext = ((mime || "").split("/")[1] || "bin").split("+")[0];
        return ext === "jpeg" ? "jpg" : ext;
    }

    function _validHash(hash) {
        return /^[0-9a-f]{16}$/.test(hash || "");
    }

    // Detail
    function _imagePathFor(item) {
        if (!item || item.kind !== "image")
            return "";
        return root._dumpedHashes[item.id] || "";
    }

    function _textFor(item) {
        if (!item || item.kind === "image")
            return "";
        const cached = root._decodedCache[item.id];
        return cached === undefined ? "" : cached;
    }

    function _cacheDecoded(hash, text) {
        const cache = Object.assign({}, root._decodedCache);
        cache[hash] = text;
        const keys = Object.keys(cache);
        if (keys.length > 50)
            delete cache[keys[0]];
        root._decodedCache = cache;
    }

    // Decode trigger
    function _triggerDecodeFor(row) {
        decodeDebounce.stop();

        const sameTextFlight = textProc.running && !!row && root._pendingDecodeHash === row.id;
        const sameDumpFlight = dumpProc.running && !!row && dumpProc.hash === row.id;
        if (!sameTextFlight)
            root._pendingDecodeHash = "";
        if (!row) {
            textProc.running = false;
            dumpProc.running = false;
            return;
        }
        if (row.kind === "image") {
            if (root._dumpedHashes[row.id] || sameDumpFlight) {
                textProc.running = false;
                if (!sameDumpFlight)
                    dumpProc.running = false;
                return;
            }
            textProc.running = false;
            dumpProc.running = false;
            root._ensureImageDump(row);
        } else {
            if (root._decodedCache[row.id] !== undefined || sameTextFlight) {
                if (!sameTextFlight)
                    textProc.running = false;
                dumpProc.running = false;
                return;
            }
            textProc.running = false;
            dumpProc.running = false;
            decodeDebounce.restart();
        }
    }

    function _startDecode() {
        if (!root.focusedItem || !root._validHash(root.focusedItem.id))
            return;
        root._pendingDecodeHash = root.focusedItem.id;
        textProc.command = ["bnclip", "decode", root.focusedItem.id];
        textProc.running = true;
    }

    function _ensureImageDump(row) {
        const hash = row.id;
        if (!root._validHash(hash))
            return;
        if (root._dumpedHashes[hash])
            return;
        dumpProc.hash = hash;
        dumpProc.ext = root._extForMime(row.mime);
        const dir = FileUtils.trimFileProtocol(Paths.bnclipDecodeTempDir);
        dumpProc.command = ["sh", "-c", `mkdir -p '${dir}' && bnclip decode '${hash}' > '${dir}/${hash}.${dumpProc.ext}'`];
        dumpProc.running = true;
    }

    // Actions
    function _copyCommand(item, withPaste) {
        const paste = withPaste ? " && wl-paste | wtype -" : "";
        if (item.mime === "text/uri-list")
            return `bnclip decode '${item.id}' | wl-copy --type text/uri-list${paste}`;
        if ((item.mime || "").startsWith("image/"))
            return `bnclip decode '${item.id}' | wl-copy --type ${item.mime}${paste}`;
        return `bnclip decode '${item.id}' | wl-copy${paste}`;
    }

    function _runCopy(item, withPaste) {
        if (!item || !root._validHash(item.id))
            return;
        Quickshell.execDetached(["sh", "-c", root._copyCommand(item, withPaste)]);
    }

    function copyFocused() {
        root._runCopy(root.focusedItem, false);
    }

    function pasteFocused() {
        root._runCopy(root.focusedItem, true);
    }

    function reload() {
        reloadDebounce.restart();
    }

    function deleteEntry(id) {
        if (!id)
            return;
        root.clipboardHistory = root.clipboardHistory.filter(e => e.id !== id);
        const decoded = Object.assign({}, root._decodedCache);
        delete decoded[id];
        root._decodedCache = decoded;
        const dumped = Object.assign({}, root._dumpedHashes);
        delete dumped[id];
        root._dumpedHashes = dumped;
        Quickshell.execDetached(["bnclip", "delete", id]);
    }

    function togglePinFocused() {
        if (!root.focusedItem)
            return false;
        const nowPinned = !root.focusedItem.isPinned;
        Quickshell.execDetached(["bnclip", "pin", root.focusedItem.id]);
        reloadDebounce.restart();
        return nowPinned;
    }

    function wipe() {
        root.clipboardHistory = [];
        root._decodedCache = ({});
        root._dumpedHashes = ({});
        Quickshell.execDetached(["bnclip", "wipe"]);
        GlobalIpc.popup.showInfo("Clipboard cleared", "", 1000);
        reloadDebounce.restart();
    }

    function _doReload() {
        root._incoming = [];
        lister.running = false;
        lister.running = true;
    }
}
