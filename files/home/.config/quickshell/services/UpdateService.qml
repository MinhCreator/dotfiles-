pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs
import "../lib/FileUtils.js" as FileUtils

Singleton {
    id: root
    readonly property string materialSymbol: "deployed_code_update"

    property int updateCount: 0
    property var updatesList: []
    property bool dbLock: false
    property alias checking: checkerProcess.running

    signal fileUpdated

    // Helpers
    function _sortByName(list) {
        return list.slice().sort((a, b) => a.name.localeCompare(b.name));
    }

    // File Monitoring
    Process {
        id: lockProbeProcess
        onExited: (exitCode, exitStatus) => {
            const present = exitCode === 0;
            if (root.dbLock !== present)
                root.dbLock = present;
        }
    }

    function refreshDbLock() {
        if (lockProbeProcess.running)
            return;
        lockProbeProcess.exec(["sh", "-c", "[ -f /var/lib/pacman/db.lck ]"]);
    }

    function removeDbLock() {
        rmDbLockProcess.exec(["pkexec", "rm", "/var/lib/pacman/db.lck"]);
    }

    Process {
        id: rmDbLockProcess
    }

    FileView {
        id: updatesJson
        path: FileUtils.trimFileProtocol(Paths.updatesJsonFile)
        watchChanges: false
        blockLoading: true
        onFileChanged: {
            this.reload();
            root._loadFromJson();
            root.fileUpdated();
        }
    }

    function _loadFromJson() {
        const text = updatesJson.text();
        if (!text) {
            root.updatesList = [];
            root.updateCount = 0;
            return;
        }
        try {
            const data = JSON.parse(text);
            root.updatesList = root._sortByName(data.updates || []);
            root.updateCount = root.updatesList.length;
        } catch (e) {}
    }

    // Update Checker
    Process {
        id: checkerProcess
        property var accumulated: []
        stdout: SplitParser {
            onRead: data => {
                const match = data.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/);
                if (match) {
                    checkerProcess.accumulated.push({
                        name: match[1],
                        currentVersion: match[2],
                        newVersion: match[3]
                    });
                } else {
                    const simpleMatch = data.match(/^(\S+)\s+(\S+)$/);
                    if (simpleMatch) {
                        checkerProcess.accumulated.push({
                            name: simpleMatch[1],
                            currentVersion: "",
                            newVersion: simpleMatch[2]
                        });
                    }
                }
            }
        }
        stderr: StdioCollector {
            id: stderrCollector
        }
        onExited: (exitCode, exitStatus) => {
            if (stderrCollector.text.trim() === "")
                root._finalizeParsed(checkerProcess.accumulated);
            checkerProcess.accumulated = [];
        }
    }

    // inotify — restart on reload
    Process {
        id: inotifyProcess
        command: ["inotifywait", "-q", "-m", "-e", "modify,create,delete,attrib", "/var/lib/pacman/", "/var/lib/pacman/sync/", "/var/lib/pacman/local/", FileUtils.trimFileProtocol(Paths.home) + "/.cache/yay/"]
        stdout: SplitParser {
            onRead: _ => {
                root.refreshDbLock();
                debounceTimer.restart();
            }
        }

        onRunningChanged: {
            if (!running)
                running = true;
        }
    }

    Timer {
        id: debounceTimer
        interval: 5000
        onTriggered: root.refresh(false)
    }

    Timer {
        id: periodicTimer
        interval: 33 * 60 * 1000
        running: true
        repeat: true
        onTriggered: root._timedCheck()
    }

    function _timedCheck() {
        if (Date.now() - GlobalData.lastUpdateCheck >= 30 * 60 * 1000)
            refresh(true);
    }

    function refresh(sync = false) {
        if (checkerProcess.running)
            return;
        checkerProcess.accumulated = [];
        if (sync)
            checkerProcess.exec(["sh", "-c", "sudo pacman -Sy > /dev/null && yay -Qu"]);
        else
            checkerProcess.exec(["yay", "-Qu"]);
    }

    function _finalizeParsed(parsed) {
        const prevCount = root.updateCount;

        root.updatesList = root._sortByName(parsed);
        root.updateCount = root.updatesList.length;
        GlobalData.lastUpdateCheck = Date.now();

        updatesJson.setText(JSON.stringify({
            updates: root.updatesList,
            timestamp: Date.now()
        }, null, 2));

        if (root.updateCount > 0 && root.updateCount > prevCount)
            root._sendNotification();
    }

    // Notification
    function _sendNotification() {
        if (!notificationProcess.running)
            notificationProcess.exec(["notify-send", "--app-name=Updates", "--icon=system-software-update", "--urgency=normal", "--wait", "--action=update=Update Now", "Updates Available: (" + root.updateCount + ")", "New updates are available."]);
    }

    Process {
        id: notificationProcess
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "update")
                    root._launchUpdate([]);
            }
        }
    }

    // Launcher
    function updateAll() {
        _launchUpdate([]);
    }

    function updateSelected(packages) {
        _launchUpdate(packages && packages.length > 0 ? packages : []);
    }

    function _launchUpdate(packages) {
        const yayCmd = packages.length > 0 ? ["yay", "-S", "--noconfirm", ...packages].join(" ") : "yay -Syu --noconfirm";
        Hyprland.dispatch(`hl.dsp.exec_cmd("kitty --title=quickshell-system-update bash ${Paths.systemUpdateScript} ${yayCmd}", { float = true, workspace = require('hyprland.lua.utils.workspaces').get_target_workspace('new', false) })`);
    }

    Component.onCompleted: {
        _timedCheck();
        root.refreshDbLock();
        updatesJson.reload();
        root._loadFromJson();
        inotifyProcess.running = true;
    }
}
