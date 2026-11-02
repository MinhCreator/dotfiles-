pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.services
import qs

Singleton {
    id: root

    property alias systemClock: systemClock
    readonly property string materialSymbol: "schedule"

    // Countdown
    property int countdownTotal: 0
    property int countdownRemaining: 0
    property int countdownCentiseconds: 0
    property bool countdownRunning: false
    property bool countdownPaused: false

    property double _countdownEndTime: 0
    property double _pausedRemainingMs: 0

    readonly property bool countdownEditable: !root.countdownRunning && !root.countdownPaused

    // Stopwatch
    property int stopwatchElapsed: 0
    property int stopwatchCentiseconds: 0
    property bool stopwatchRunning: false
    property bool stopwatchPaused: !root.stopwatchRunning && root.stopwatchElapsed > 0

    property double _stopwatchStartTime: 0

    // Rehydrate from storage on start
    Component.onCompleted: {
        const cd = GlobalCache.countdown;
        if (cd) {
            try {
                const s = JSON.parse(cd);
                root.countdownTotal = s.total ?? 0;
                root.countdownRemaining = s.remaining ?? 0;
                root.countdownRunning = s.running ?? false;
                root.countdownPaused = s.paused ?? false;

                if (root.countdownRunning) {
                    root._countdownEndTime = Date.now() + root.countdownRemaining * 1000;
                } else if (root.countdownPaused) {
                    root._pausedRemainingMs = root.countdownRemaining * 1000;
                }

                root.countdownCentiseconds = 0;
            } catch (_) {}
        }

        const sw = GlobalCache.stopwatch;
        if (sw) {
            try {
                const s = JSON.parse(sw);
                root.stopwatchElapsed = s.elapsed ?? 0;
                root.stopwatchRunning = s.running ?? false;

                if (root.stopwatchRunning) {
                    root._stopwatchStartTime = Date.now() - root.stopwatchElapsed * 1000;
                }
            } catch (_) {}
        }
    }

    // Persist helpers
    function persistCountdown() {
        GlobalCache.countdown = JSON.stringify({
            total: root.countdownTotal,
            remaining: root.countdownRemaining,
            running: root.countdownRunning,
            paused: root.countdownPaused
        });
    }

    function persistStopwatch() {
        GlobalCache.stopwatch = JSON.stringify({
            elapsed: root.stopwatchElapsed,
            running: root.stopwatchRunning
        });
    }

    // Countdown timer (~32 fps tick, enough for centisecond display)
    Timer {
        id: countdownTick
        interval: 31
        repeat: true
        running: root.countdownRunning

        onTriggered: {
            const now = Date.now();
            const remainingMs = root._countdownEndTime - now;

            if (remainingMs <= 0) {
                root.countdownRunning = false;
                root.countdownPaused = false;
                root.countdownRemaining = 0;
                root.countdownCentiseconds = 0;
                NotificationService.notifySend("-a", "Clock", "-i", "alarm-clock", "-u", "normal", "Countdown finished", "Your countdown of " + root.formatDuration(root.countdownTotal) + " has elapsed.");
                root.persistCountdown();
                return;
            }

            const oldRemaining = root.countdownRemaining;
            root.countdownRemaining = Math.floor(remainingMs / 1000);
            root.countdownCentiseconds = Math.floor((remainingMs % 1000) / 10);

            if (oldRemaining !== root.countdownRemaining) {
                root.persistCountdown();
            }
        }
    }

    // Stopwatch timer (~32 fps tick, enough for centisecond display)
    Timer {
        id: stopwatchTick
        interval: 31
        repeat: true
        running: root.stopwatchRunning

        onTriggered: {
            const now = Date.now();
            const elapsedMs = now - root._stopwatchStartTime;

            const oldElapsed = root.stopwatchElapsed;
            root.stopwatchElapsed = Math.floor(elapsedMs / 1000);
            root.stopwatchCentiseconds = Math.floor((elapsedMs % 1000) / 10);

            if (oldElapsed !== root.stopwatchElapsed) {
                root.persistStopwatch();
            }
        }
    }

    // Countdown API
    function countdownStart(secs: int) {
        if (secs <= 0)
            return;
        root.countdownTotal = secs;
        root.countdownRemaining = secs;
        root.countdownCentiseconds = 0;
        root.countdownRunning = true;
        root.countdownPaused = false;
        root._countdownEndTime = Date.now() + (secs * 1000);
        root.persistCountdown();
    }

    function countdownPause() {
        root._pausedRemainingMs = root._countdownEndTime - Date.now();
        root.countdownRunning = false;
        root.countdownPaused = true;
        root.persistCountdown();
    }

    function countdownResume() {
        if (root.countdownRemaining <= 0 && root.countdownCentiseconds <= 0 && root._pausedRemainingMs <= 0)
            return;
        root._countdownEndTime = Date.now() + root._pausedRemainingMs;
        root.countdownRunning = true;
        root.countdownPaused = false;
        root.persistCountdown();
    }

    function countdownReset() {
        root.countdownRunning = false;
        root.countdownPaused = false;
        root.countdownTotal = 0;
        root.countdownRemaining = 0;
        root.countdownCentiseconds = 0;
        root._pausedRemainingMs = 0;
        root.persistCountdown();
    }

    // Stopwatch API
    function stopwatchStart() {
        root._stopwatchStartTime = Date.now() - (root.stopwatchElapsed * 1000 + root.stopwatchCentiseconds * 10);
        root.stopwatchRunning = true;
        root.persistStopwatch();
    }

    function stopwatchPause() {
        root.stopwatchRunning = false;
        root.persistStopwatch();
    }

    function stopwatchReset() {
        root.stopwatchRunning = false;
        root.stopwatchElapsed = 0;
        root.stopwatchCentiseconds = 0;
        root._stopwatchStartTime = 0;
        root.persistStopwatch();
    }

    // Shared utilities
    function formatDuration(secs: int): string {
        const h = String(Math.floor(secs / 3600)).padStart(2, '0');
        const m = String(Math.floor((secs % 3600) / 60)).padStart(2, '0');
        const s = String(secs % 60).padStart(2, '0');
        if (h > 0)
            return h + "h " + m + "m " + s + "s";
        if (m > 0)
            return m + "m " + s + "s";
        return s + "s";
    }

    // System Clock
    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

}
