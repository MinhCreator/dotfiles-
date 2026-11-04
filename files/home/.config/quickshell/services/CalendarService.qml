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
    property var _prefetch: []
    property var _activeRequest: null
    property var _lastRequest: null
    property bool _loading: false
    property string _error: ""
    readonly property int cacheTtl: 600000
    readonly property int dataVersion: 2
    readonly property var prefetchOffsets: [1, -1, 2, -2]

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

    // Builds the fetch window for a month. The grid shows a few days of the
    // adjacent months, so fetch one week on each side.
    function _buildRequest(year, month) {
        const first = new Date(year, month, 1);
        const y = first.getFullYear();
        const m = first.getMonth() + 1;
        const start = new Date(y, first.getMonth(), 1);
        const end = new Date(y, first.getMonth() + 1, 1);
        start.setDate(start.getDate() - 7);
        end.setDate(end.getDate() + 7);
        return {
            key: y + "-" + (m < 10 ? "0" : "") + m,
            start: root.dateKey(start),
            end: root.dateKey(end)
        };
    }

    function _isFresh(key) {
        const cached = root._monthCache[key];
        return cached !== undefined && Date.now() - cached.fetchedAt < root.cacheTtl;
    }

    function ensureMonth(year, month) {
        const request = root._buildRequest(year, month);
        root._lastRequest = request;

        // Neighbouring months are fetched in the background once the
        // visible one is done, so navigating usually hits the cache.
        root._prefetch = root.prefetchOffsets.map(offset => root._buildRequest(year, month + offset));

        if (root._isFresh(request.key) || root._activeRequest?.key === request.key)
            root._pending = null;
        else
            root._pending = request;
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

    function _nextRequest() {
        if (root._pending !== null) {
            const request = root._pending;
            root._pending = null;
            return request;
        }
        while (root._prefetch.length > 0) {
            const request = root._prefetch.shift();
            if (!root._isFresh(request.key))
                return request;
        }
        return null;
    }

    function _runPending() {
        if (root._loading || !daemon.running)
            return;

        const request = root._nextRequest();
        if (request === null)
            return;

        root._activeRequest = request;
        root._loading = true;
        root._error = "";
        daemon.write(JSON.stringify({
            start: request.start,
            end: request.end,
            key: request.key
        }) + "\n");
    }

    // Exactly one line comes back per request.
    function _handleOutput(text) {
        root._applyPayload(StringUtils.safeParse(text, null));
        root._loading = false;
        root._activeRequest = null;
        root._runPending();
    }

    function _applyPayload(payload) {
        if (!payload) {
            root._error = "Invalid calendar response";
            return;
        }
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
        if (key) {
            const cache = Object.assign({}, root._monthCache);
            cache[key] = {
                fetchedAt: Date.now()
            };
            root._monthCache = cache;
        }
        if (payload.window)
            root._applyFetch(payload, payload.window.start, payload.window.end);
        root._error = (payload.errors ?? []).join("; ");
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
        const now = new Date();
        root.ensureMonth(now.getFullYear(), now.getMonth());
    }

    Timer {
        id: monthDebounce
        interval: 40
        onTriggered: root._runPending()
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        onTriggered: root.todayDate = new Date()
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: daemon.running = true
    }

    Process {
        id: daemon
        running: true
        stdinEnabled: true
        command: ["python3", FileUtils.trimFileProtocol(Paths.calendarFetcherScript), "--serve"]
        stdout: SplitParser {
            onRead: data => root._handleOutput(data)
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
            if (root._error === "")
                root._error = "Calendar daemon exited (" + exitCode + ")";
            restartTimer.restart();
        }
        onRunningChanged: {
            if (running)
                monthDebounce.restart();
        }
    }
}
