pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs

Singleton {
    id: root

    readonly property string providerId: "unsplash"
    readonly property string displayName: "Unsplash"
    readonly property bool requiresApiKey: true

    property string query: ""
    property string orderBy: "relevant"
    property string color: ""
    property string orientation: "landscape"
    property string topic: ""
    property int perPage: 24
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

    readonly property bool isLoading: fetchProcess.running || topicProcess.running
    readonly property bool isApplying: downloadSetProcess.running
    readonly property bool isSaving: downloadSaveProcess.running
    readonly property bool thumbBusy: thumbProcess.running
    property int failedCount: 0

    property var topics: []

    // Provider contract functions
    function activate() {
        if (wallpaperModel.count === 0)
            fetch();
        if (topics.length === 0)
            fetchTopics();
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

    function apiKey() {
        return GlobalSettings.wallpaperProviderKeys?.["unsplash"] ?? "";
    }

    function fetch(append = false) {
        if (fetchProcess.running)
            fetchProcess.running = false;

        // Search mode needs a query; topic mode does not. Never fire a
        // doomed search request for a blank query.
        if (root.topic === "" && root.query.trim() === "") {
            if (!append)
                reset();
            return;
        }

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
        if (root.topic !== "") {
            fetchProcess.exec([Paths.wallpaperFetcherScript, "unsplash", "topic-photos", "--topic", topic, "--page", currentPage.toString(), "--per_page", perPage.toString(), "--order_by", topicOrderBy, "--orientation", orientation, "--apikey", apiKey()]);
        } else {
            fetchProcess.exec([Paths.wallpaperFetcherScript, "unsplash", "fetch", "--query", query, "--page", currentPage.toString(), "--per_page", perPage.toString(), "--order_by", orderBy, "--color", color, "--orientation", orientation, "--apikey", apiKey()]);
        }
    }

    function loadNextPage() {
        if (fetchProcess.running)
            return;
        if (currentPage < lastPage) {
            currentPage++;
            fetch(true);
        }
    }

    function fetchTopics() {
        topicProcess.exec([Paths.wallpaperFetcherScript, "unsplash", "topics", "--per_page", "30", "--order_by", "featured", "--apikey", apiKey()]);
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
            console.warn("[Unsplash] retryThumb: id not in model:", id);
            return;
        }

        const item = wallpaperModel.get(index);
        if (item.state === "ready") {
            console.warn("[Unsplash] retryThumb: already ready:", id);
            return;
        }
        if (!item.thumbUrl) {
            // No thumbnail URL to retry with: refetch for fresh metadata
            console.warn("[Unsplash] retryThumb: no thumb URL, refetching:", id);
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
        downloadSetProcess.exec([Paths.wallpaperFetcherScript, "unsplash", "download", "--url", wp.path, "--id", wp.id]);
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
        downloadSaveProcess.exec([Paths.wallpaperFetcherScript, "unsplash", "download", "--url", wp.path, "--id", wp.id, "--save"]);
        return true;
    }

    // Internals
    property string topicOrderBy: "latest"
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
        interval: 400
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

    function fullUrlFor(photo) {
        const urls = photo.urls || {};
        return urls.raw || urls.full || urls.regular || urls.small || "";
    }

    function itemForPhoto(photo) {
        const urls = photo.urls || {};
        const desc = photo.alt_description || photo.description || photo.slug || photo.id;
        const badge = photo.width && photo.height ? `${photo.width}x${photo.height}` : "";
        return {
            id: photo.id,
            title: desc,
            image: fullUrlFor(photo),
            thumb: photo.local_thumb || "",
            badge: badge,
            state: "loading",
            animated: false,
            url: (photo.links && photo.links.html) || "",
            path: fullUrlFor(photo),
            thumbUrl: photo.thumb_url || "",
            thumbAttempts: 0,
            isPlaceholder: false
        };
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

        if (!data || data.error) {
            removePlaceholders();
            return;
        }

        let photos = [];
        if (Array.isArray(data.results)) {
            photos = data.results;
            root.totalResults = data.total || photos.length;
            const totalPages = data.total_pages || 1;
            root.lastPage = totalPages;
        } else if (Array.isArray(data.data) || Array.isArray(data)) {
            photos = Array.isArray(data.data) ? data.data : data;
            root.totalResults = root.placeholderStartIndex + photos.length;
            root.lastPage = photos.length >= root.perPage ? root.currentPage + 1 : root.currentPage;
        } else {
            removePlaceholders();
            return;
        }

        for (let i = 0; i < photos.length; i++) {
            const item = itemForPhoto(photos[i]);
            if (root.placeholderStartIndex + i < wallpaperModel.count) {
                wallpaperModel.set(root.placeholderStartIndex + i, item);
            } else {
                wallpaperModel.append(item);
            }
        }

        // Remove remaining placeholders if any
        if (photos.length < root.pageSize) {
            const actualCount = root.placeholderStartIndex + photos.length;
            while (wallpaperModel.count > actualCount) {
                wallpaperModel.remove(wallpaperModel.count - 1);
            }
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

    function handleTopicsLine(line) {
        if (!line.startsWith("META "))
            return;
        let data;
        try {
            data = JSON.parse(line.substring(5));
        } catch (e) {
            return;
        }
        const list = Array.isArray(data.data) ? data.data : (Array.isArray(data) ? data : []);
        if (list.length > 0)
            root.topics = list;
    }

    function flushRetryQueue() {
        if (_retryQueue.length === 0 || thumbProcess.running)
            return;
        const batch = _retryQueue.splice(0, _retryQueue.length);
        thumbProcess.exec([Paths.wallpaperFetcherScript, "unsplash", "thumbs", "--items", JSON.stringify(batch)]);
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
        id: topicProcess
        stdout: SplitParser {
            onRead: data => root.handleTopicsLine(data.trim())
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
