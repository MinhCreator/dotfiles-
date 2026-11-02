pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs

Singleton {
    id: root

    readonly property string providerId: "wallhaven"
    readonly property string displayName: "Wallhaven"
    readonly property bool requiresApiKey: true

    property string query: ""
    property string categories: "110"
    property string purity: "100"
    property string sorting: "date_added"
    property string order: "desc"
    property string toprange: "1m"
    property string ratios: "16x9,16x10,21x9,32x9,48x9"
    property int currentPage: 1
    property int lastPage: 1
    property int totalResults: 0

    property int pageSize: 24
    property int placeholderStartIndex: 0
    property int maxAutoRetries: 2

    ListModel {
        id: wallpaperModel
    }

    property alias items: wallpaperModel
    readonly property int itemCount: wallpaperModel.count

    property alias isLoading: fetchProcess.running
    readonly property bool isApplying: downloadSetProcess.running
    readonly property bool isSaving: downloadSaveProcess.running
    readonly property bool thumbBusy: thumbProcess.running
    property int failedCount: 0

    // Provider contract functions
    function activate() {
        if (wallpaperModel.count === 0)
            fetch();
    }

    function deactivate() {
    }

    function setQuery(q) {
        if (root.query !== q) {
            root.query = q;
            return true;
        }
        return false;
    }

    function retryItem(id) {
        retryThumb(id);
    }

    function toggleCategory(index) {
        const c = root.categories.split("");
        c[index] = c[index] === "1" ? "0" : "1";
        root.categories = c.join("");
        fetchDebounced();
    }

    function togglePurity(index) {
        const p = root.purity.split("");
        p[index] = p[index] === "1" ? "0" : "1";
        root.purity = p.join("");
        fetchDebounced();
    }

    function primaryAction(wp) {
        if (wp && !wp.isPlaceholder && wp.state === "ready")
            downloadAndSet(wp);
    }

    function secondaryAction(wp) {
        if (wp && !wp.isPlaceholder && wp.state === "ready")
            downloadAndSave(wp);
    }

    // Public API
    function reset() {
        _retryQueue = [];
        if (thumbProcess.running)
            thumbProcess.running = false;
        wallpaperModel.clear();
        currentPage = 1;
        lastPage = 1;
        totalResults = 0;
        placeholderStartIndex = 0;
        failedCount = 0;
    }

    function fetch(append = false) {
        if (fetchProcess.running)
            fetchProcess.running = false;

        if (!append) {
            reset();
        }

        placeholderStartIndex = wallpaperModel.count;
        for (let i = 0; i < pageSize; i++) {
            wallpaperModel.append({
                id: "",
                title: "",
                image: "",
                thumb: "",
                badge: "",
                state: "loading",
                animated: false,
                url: "",
                path: "",
                thumbUrl: "",
                thumbAttempts: 0,
                isPlaceholder: true
            });
        }
        fetchProcess.exec([Paths.wallpaperFetcherScript, "wallhaven", "fetch", "--query", query, "--categories", categories, "--purity", purity, "--sorting", sorting, "--order", order, "--toprange", toprange, "--ratios", ratios, "--page", currentPage.toString(), "--apikey", GlobalSettings.wallpaperProviderKeys?.["wallhaven"] ?? ""]);
    }

    function loadNextPage() {
        if (fetchProcess.running)
            return;
        if (currentPage < lastPage) {
            currentPage++;
            fetch(true);
        }
    }

    function queueThumbRetry(id, url) {
        for (let i = 0; i < _retryQueue.length; i++) {
            if (_retryQueue[i].id === id)
                return;
        }
        _retryQueue.push({
            id: id,
            url: url
        });
    }

    function retryThumb(id) {
        const index = indexOfId(id);
        if (index === -1) {
            console.warn("[Wallhaven] retryThumb: id not in model:", id);
            return;
        }

        const item = wallpaperModel.get(index);
        if (item.state === "ready") {
            console.warn("[Wallhaven] retryThumb: already ready:", id);
            return;
        }
        if (!item.thumbUrl) {
            // No thumbnail URL to retry with: refetch for fresh metadata
            console.warn("[Wallhaven] retryThumb: no thumb URL, refetching:", id);
            fetch();
            return;
        }

        item.thumbAttempts = (item.thumbAttempts || 0) + 1;
        item.state = "loading";
        wallpaperModel.set(index, item);
        updateFailedCount();

        queueThumbRetry(id, item.thumbUrl);
        flushRetryQueue();
    }

    function retryAllFailed() {
        for (let i = 0; i < wallpaperModel.count; i++) {
            const item = wallpaperModel.get(i);
            if (item.isPlaceholder || !item.thumbUrl || item.state !== "failed")
                continue;
            item.state = "loading";
            wallpaperModel.set(i, item);
            queueThumbRetry(item.id, item.thumbUrl);
        }
        updateFailedCount();
        // Flush defers while a thumb batch is in flight
        flushRetryQueue();
    }

    // Auto-retries a failed cell while it is on screen and attempt budget remains
    function requestAutoRetry(id) {
        const index = indexOfId(id);
        if (index === -1)
            return;

        const item = wallpaperModel.get(index);
        if (item.isPlaceholder || !item.thumbUrl || item.state !== "failed")
            return;
        if ((item.thumbAttempts || 0) >= maxAutoRetries)
            return;

        retryThumb(id);
    }

    function downloadAndSet(wp) {
        if (downloadSetProcess.running || downloadSaveProcess.running) {
            GlobalIpc.popup.showInfo("Still applying the previous wallpaper...", "", 3000);
            return false;
        }
        if (!wp || wp.id === root._activeDownloadId)
            return false;
        root._activeDownloadId = wp.id;
        root._setDest = "";
        root._setPopupUid = GlobalIpc.popup?.showProgress("Applying Wallpaper", wp.title ?? "") ?? -1;
        downloadSetProcess.exec([Paths.wallpaperFetcherScript, "wallhaven", "download", "--url", wp.path, "--id", wp.id]);
        return true;
    }

    function downloadAndSave(wp) {
        if (downloadSetProcess.running || downloadSaveProcess.running) {
            GlobalIpc.popup.showInfo("Still saving the previous wallpaper...", "", 3000);
            return false;
        }
        if (!wp || wp.id === root._activeSaveId)
            return false;
        root._activeSaveId = wp.id;
        root._saveDest = "";
        root._savePopupUid = GlobalIpc.popup?.showProgress("Saving Wallpaper", wp.title ?? "") ?? -1;
        downloadSaveProcess.exec([Paths.wallpaperFetcherScript, "wallhaven", "download", "--url", wp.path, "--id", wp.id, "--save"]);
        return true;
    }

    // Internals
    property var _retryQueue: []
    property string _activeDownloadId: ""
    property string _activeSaveId: ""
    property int _setPopupUid: -1
    property int _savePopupUid: -1
    property string _setDest: ""
    property string _saveDest: ""

    function handleDownloadSetLine(line) {
        if (line.startsWith("PROGRESS ")) {
            const v = parseFloat(line.substring(9));
            if (!isNaN(v) && root._setPopupUid !== -1)
                GlobalIpc.popup?.setProgress(root._setPopupUid, v);
        } else if (line !== "") {
            root._setDest = line;
        }
    }

    function handleDownloadSaveLine(line) {
        if (line.startsWith("PROGRESS ")) {
            const v = parseFloat(line.substring(9));
            if (!isNaN(v) && root._savePopupUid !== -1)
                GlobalIpc.popup?.setProgress(root._savePopupUid, v);
        } else if (line !== "") {
            root._saveDest = line;
        }
    }

    function finishDownloadSet() {
        const dest = root._setDest;
        const uid = root._setPopupUid;
        root._setDest = "";
        root._setPopupUid = -1;
        root._activeDownloadId = "";
        if (dest) {
            GlobalIpc.popup?.completeProgress(uid, true, "Wallpaper Applied", "", 5000);
            Quickshell.execDetached(["sh", "-c", `$BN_SCRIPTS/select-wallpaper --path ${dest}`]);
            DesktopService.selectWallpaper(dest);
        } else {
            GlobalIpc.popup?.completeProgress(uid, false, "Apply Failed", "", 5000);
        }
    }

    function finishDownloadSave() {
        const dest = root._saveDest;
        const uid = root._savePopupUid;
        root._saveDest = "";
        root._savePopupUid = -1;
        root._activeSaveId = "";
        if (dest) {
            GlobalIpc.popup?.completeProgress(uid, true, "Wallpaper Saved", "", 5000);
            Quickshell.execDetached(["sh", "-c", "$BN_SCRIPTS/wallwatch --refresh"]);
        } else {
            GlobalIpc.popup?.completeProgress(uid, false, "Download Failed", "", 5000);
        }
    }

    Timer {
        id: fetchDebounce
        interval: 1000
        repeat: false
        onTriggered: root.fetch()
    }

    Timer {
        id: searchDebounce
        interval: 500
        repeat: false
        onTriggered: root.fetch()
    }

    function fetchDebounced() {
        fetchDebounce.restart();
    }

    function searchDebounced() {
        searchDebounce.restart();
    }

    function indexOfId(id) {
        for (let i = 0; i < wallpaperModel.count; i++) {
            if (wallpaperModel.get(i).id === id)
                return i;
        }
        return -1;
    }

    function updateFailedCount() {
        let count = 0;
        for (let i = 0; i < wallpaperModel.count; i++) {
            const item = wallpaperModel.get(i);
            if (!item.isPlaceholder && item.state === "failed")
                count++;
        }
        failedCount = count;
    }

    // True while a thumbnail (re)download is queued but not yet started
    function isRetryQueued(id) {
        for (let i = 0; i < _retryQueue.length; i++) {
            if (_retryQueue[i].id === id)
                return true;
        }
        return false;
    }

    // Marks entries whose fetch process died before their THUMB line arrived.
    // Skips queued retries: their THUMB line is still coming from the next batch.
    function sweepLoadingEntries() {
        let dirty = false;
        for (let i = 0; i < wallpaperModel.count; i++) {
            const item = wallpaperModel.get(i);
            if (!item.isPlaceholder && item.state === "loading" && !isRetryQueued(item.id)) {
                item.state = "failed";
                wallpaperModel.set(i, item);
                dirty = true;
            }
        }
        if (dirty)
            updateFailedCount();
    }

    function handleMeta(jsonText) {
        let data;
        try {
            data = JSON.parse(jsonText);
        } catch (e) {
            data = null;
        }

        const removePlaceholders = () => {
            while (wallpaperModel.count > root.placeholderStartIndex) {
                wallpaperModel.remove(wallpaperModel.count - 1);
            }
        };

        if (!data || data.error || !data.data) {
            removePlaceholders();
            return;
        }

        const results = data.data;
        for (let i = 0; i < results.length; i++) {
            const wp = results[i];
            const ext = wp.file_type ? wp.file_type.split("/")[1] : "";
            const item = {
                id: wp.id,
                title: `${wp.id}.${ext}`,
                image: wp.path,
                thumb: wp.local_thumb || "",
                badge: wp.resolution || "",
                state: "loading",
                animated: false,
                url: wp.url,
                path: wp.path,
                thumbUrl: wp.thumb_url || "",
                thumbAttempts: 0,
                isPlaceholder: false
            };

            if (root.placeholderStartIndex + i < wallpaperModel.count) {
                wallpaperModel.set(root.placeholderStartIndex + i, item);
            } else {
                wallpaperModel.append(item);
            }
        }

        // Remove remaining placeholders if any
        if (results.length < root.pageSize) {
            const actualCount = root.placeholderStartIndex + results.length;
            while (wallpaperModel.count > actualCount) {
                wallpaperModel.remove(wallpaperModel.count - 1);
            }
        }

        if (data.meta) {
            root.currentPage = data.meta.current_page;
            root.lastPage = data.meta.last_page;
            root.totalResults = data.meta.total;
        }
    }

    function handleThumb(id, ok, path) {
        const index = indexOfId(id);
        if (index === -1)
            return;

        const item = wallpaperModel.get(index);
        if (ok) {
            item.thumb = path;
            item.state = "ready";
        } else {
            item.state = "failed";
        }
        wallpaperModel.set(index, item);
        updateFailedCount();
    }

    function handleLine(line) {
        if (line.startsWith("META "))
            handleMeta(line.substring(5));
        else if (line.startsWith("THUMB ")) {
            const parts = line.split(" ");
            handleThumb(parts[1], parts[2] === "ok", parts.slice(3).join(" "));
        }
    }

    function flushRetryQueue() {
        if (_retryQueue.length === 0 || thumbProcess.running)
            return;
        const batch = _retryQueue.splice(0, _retryQueue.length);
        thumbProcess.exec([Paths.wallpaperFetcherScript, "wallhaven", "thumbs", "--items", JSON.stringify(batch)]);
    }

    Process {
        id: fetchProcess
        stdout: SplitParser {
            onRead: data => root.handleLine(data.trim())
        }
        onRunningChanged: {
            // Anything still "loading" when the fetcher exits never completed
            if (!running)
                root.sweepLoadingEntries();
        }
    }

    Process {
        id: thumbProcess
        stdout: SplitParser {
            onRead: data => root.handleLine(data.trim())
        }
        onRunningChanged: {
            if (!running) {
                root.sweepLoadingEntries();
                root.flushRetryQueue();
            }
        }
    }

    Process {
        id: downloadSetProcess
        stdout: SplitParser {
            onRead: data => root.handleDownloadSetLine(data.trim())
        }
        onRunningChanged: {
            if (!running)
                root.finishDownloadSet();
        }
    }

    Process {
        id: downloadSaveProcess
        stdout: SplitParser {
            onRead: data => root.handleDownloadSaveLine(data.trim())
        }
        onRunningChanged: {
            if (!running)
                root.finishDownloadSave();
        }
    }
}
