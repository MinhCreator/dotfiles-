pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/StringUtils.js" as StringUtils
import "../lib/FileUtils.js" as FileUtils

Singleton {
    id: root

    readonly property var calendars: root._data.calendars ?? []
    readonly property var days: {
        const keys = Object.keys(root._daysByDate).sort();
        const result = [];
        for (let i = 0; i < keys.length; i++)
            result.push({
                date: keys[i],
                events: root._daysByDate[keys[i]]
            });
        return result;
    }
    readonly property var events: {
        const result = [];
        const seen = {};
        for (const day of root.days) {
            for (const event of day.events) {
                if (seen[event.id])
                    continue;
                seen[event.id] = true;
                result.push(event);
            }
        }
        return result;
    }
    readonly property var eventsByDate: root._daysByDate
    readonly property var eventDates: {
        const result = {};
        for (const date in root._daysByDate)
            result[date] = true;
        return result;
    }
    readonly property var todayEvents: root.eventsForDate(root.todayDate)
    readonly property bool loading: root._loading
    readonly property string error: root._error
    readonly property string lastUpdated: root._data.generated_at ?? ""

    property date todayDate: new Date()
    property var _data: ({})
    property var _daysByDate: ({})
    property var _monthCache: ({})
    property var _pending: null
    property var _activeRequest: null
    property var _lastRequest: null
    property bool _loading: false
    property string _error: ""
    readonly property int cacheTtl: 600000
    readonly property int dataVersion: 2

    function dateKey(value) {
        if (value instanceof Date)
            return Qt.formatDate(value, "yyyy-MM-dd");
        return String(value);
    }

    function hasEvents(value) {
        const events = root._daysByDate[root.dateKey(value)];
        return events !== undefined && events.length > 0;
    }

    function eventsForDate(value) {
        return root._daysByDate[root.dateKey(value)] ?? [];
    }

    function ensureMonth(year, month) {
        const monthNumber = month + 1;
        const key = year + "-" + (monthNumber < 10 ? "0" : "") + monthNumber;
        const cached = root._monthCache[key];
        if (cached && Date.now() - cached.fetchedAt < root.cacheTtl)
            return;
        if (root._activeRequest?.key === key || root._pending?.key === key)
            return;

        // The grid shows a few days of the adjacent months, so fetch one week
        // on each side to keep those cells accurate too.
        const first = new Date(year, month, 1);
        const next = new Date(year, month + 1, 1);
        const start = new Date(first);
        const end = new Date(next);
        start.setDate(start.getDate() - 7);
        end.setDate(end.getDate() + 7);

        root._pending = {
            key: key,
            start: root.dateKey(start),
            end: root.dateKey(end)
        };
        root._lastRequest = root._pending;
        monthDebounce.restart();
    }

    function refresh() {
        const request = root._lastRequest;
        if (!request) {
            const now = new Date();
            root.ensureMonth(now.getFullYear(), now.getMonth());
            return;
        }
        root._pending = request;
        monthDebounce.restart();
    }

    function _runPending() {
        if (root._loading || root._pending === null)
            return;

        const request = root._pending;
        root._pending = null;
        root._activeRequest = request;
        root._lastRequest = request;
        root._loading = true;
        root._error = "";
        fetcher.exec(["python3", FileUtils.trimFileProtocol(Paths.calendarFetcherScript), "--start", request.start, "--end", request.end, "--key", request.key, "--output", FileUtils.trimFileProtocol(Paths.calendarFile), "--lock", FileUtils.trimFileProtocol(Paths.calendarLockFile)]);
    }

    function _handleOutput(text) {
        const payload = StringUtils.safeParse(text, null);
        if (!payload) {
            root._error = "Invalid calendar response";
            return;
        }
        if (payload.skipped)
            return;
        if (payload.available === false) {
            root._error = payload.error ?? "Calendar data unavailable";
            return;
        }
        if (payload.version !== root.dataVersion) {
            root._error = "Calendar data version mismatch";
            return;
        }

        root._data = payload;
        const key = payload.key ?? root._activeRequest?.key;
        if (!key)
            return;

        const cache = Object.assign({}, root._monthCache);
        cache[key] = {
            fetchedAt: Date.now()
        };
        root._monthCache = cache;
        if (payload.window)
            root._applyFetch(payload, payload.window.start, payload.window.end);
        root._error = (payload.errors ?? []).join("; ");
    }

    function _loadFromFile() {
        const payload = StringUtils.safeParse(calendarFile.text(), null);
        if (!payload || !payload.available || !payload.days)
            return;
        if (payload.version !== root.dataVersion) {
            root._data = ({});
            root._daysByDate = ({});
            root._monthCache = ({});
            return;
        }

        root._data = payload;

        const fetchedAt = Date.parse(payload.generated_at ?? "");
        if (payload.key) {
            const cache = Object.assign({}, root._monthCache);
            cache[payload.key] = {
                fetchedAt: isNaN(fetchedAt) ? 0 : fetchedAt
            };
            root._monthCache = cache;
        }
        if (payload.window)
            root._applyFetch(payload, payload.window.start, payload.window.end);
    }

    function _applyFetch(payload, start, end) {
        const byDate = Object.assign({}, root._daysByDate);

        for (const date in byDate) {
            if (date >= start && date < end)
                delete byDate[date];
        }

        for (const day of payload.days ?? []) {
            const events = day.events ?? [];
            if (events.length === 0) {
                delete byDate[day.date];
                continue;
            }
            byDate[day.date] = events.slice().sort(root._compareEvents);
        }

        root._daysByDate = byDate;
    }

    function _compareEvents(a, b) {
        if (a.allDay !== b.allDay)
            return a.allDay ? -1 : 1;
        const aStart = a.startEpoch ?? 0;
        const bStart = b.startEpoch ?? 0;
        if (aStart !== bStart)
            return aStart - bStart;
        return String(a.summary ?? "").localeCompare(String(b.summary ?? ""));
    }

    Component.onCompleted: {
        root._loadFromFile();
        const now = new Date();
        root.ensureMonth(now.getFullYear(), now.getMonth());
    }

    Timer {
        id: monthDebounce
        interval: 150
        onTriggered: root._runPending()
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.todayDate = new Date()
    }

    Process {
        id: fetcher
        stdout: StdioCollector {
            onStreamFinished: root._handleOutput(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() !== "")
                    root._error = text.trim();
            }
        }
        onExited: (exitCode, exitStatus) => {
            root._loading = false;
            root._activeRequest = null;
            if (exitCode !== 0 && root._error === "")
                root._error = "Calendar fetch failed (exit " + exitCode + ")";
            if (root._pending !== null)
                root._runPending();
        }
    }

    FileView {
        id: calendarFile
        path: Paths.calendarFile
        watchChanges: true
        blockLoading: true
        onLoaded: root._loadFromFile()
        onFileChanged: {
            reload();
            root._loadFromFile();
        }
    }
}
