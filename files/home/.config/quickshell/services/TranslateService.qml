pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    property int port: 54321
    property bool serverActive: false
    property bool serverReady: false
    property bool busy: false
    property string sourceLang: "en"
    property string targetLang: "fr"
    property var availableLanguages: []
    property bool _stopping: false

    onSourceLangChanged: if (availableLanguages.length && (sourceLang === targetLang || !canTranslate(sourceLang, targetLang))) {
        const l = availableLanguages.find(l => l.code === (sourceLang === "auto" ? availableLanguages[0].code : sourceLang));
        if (l?.targets.length)
            targetLang = l.targets.find(t => t !== sourceLang) || l.targets[0];
    }

    onTargetLangChanged: if (availableLanguages.length && (targetLang === sourceLang || !canTranslate(sourceLang, targetLang))) {
        if (sourceLang !== "auto")
            (canTranslate(targetLang, sourceLang) ? swapLanguages() : sourceLang = "auto");
    }

    signal translationReady(var result)

    function canTranslate(s, t) {
        if (s === t)
            return false;
        if (s === "auto")
            return availableLanguages.some(l => l.targets.includes(t));
        return !!availableLanguages.find(l => l.code === s)?.targets.includes(t);
    }

    function swapLanguages() {
        if (!canTranslate(targetLang, sourceLang))
            return false;
        [sourceLang, targetLang] = [targetLang, sourceLang];
        return true;
    }

    function startServer() {
        if (!serverProcess.running) {
            _stopping = false;
            serverActive = true;
            serverProcess.running = true;
        }
    }
    function stopServer() {
        if (serverProcess.running) {
            _stopping = true;
            serverProcess.running = false;
        }
    }
    function translate(q) {
        if (serverReady && q.trim()) {
            busy = true;
            _apiCall(`http://localhost:${root.port}/translate`, "translate", JSON.stringify({
                q,
                source: sourceLang,
                target: targetLang,
                format: "text"
            }));
        }
    }

    function _apiCall(url, type, data = null) {
        let args = ["curl", "-s", "--max-time", "5"];
        if (data)
            args.push("-X", "POST", "-H", "Content-Type: application/json", "-d", data);
        apiProcess.type = type;
        apiProcess.exec([...args, url]);
    }

    function _applyLanguages(langs) {
        root.availableLanguages = langs;
        if (langs.length && !langs.find(l => l.code === root.targetLang))
            root.targetLang = langs[0].code;
        if (root.sourceLang !== "auto" && !langs.find(l => l.code === root.sourceLang))
            root.sourceLang = "auto";
    }

    Connections {
        target: GlobalStates
        function onCurrentLauncherPageChanged() {
            if (GlobalStates.currentLauncherPage.toLowerCase() === "translate" && GlobalStates.showLauncher && GlobalSettings.loadLauncher)
                root.startServer();
            else
                root.stopServer();
        }

        function onShowLauncherChanged() {
            if (GlobalStates.currentLauncherPage.toLowerCase() === "translate" && GlobalStates.showLauncher && GlobalSettings.loadLauncher)
                root.startServer();
            else
                root.stopServer();
        }
    }

    Process {
        id: serverProcess
        command: ["libretranslate", "--port", root.port.toString()]
        onStarted: readyPingTimer.start()
        onExited: (code, status) => {
            root.serverActive = root.serverReady = false;
            Quickshell.execDetached(["fuser", "-k", `${root.port}/tcp`]);
            if (!root._stopping && GlobalStates.showLauncher)
                restartTimer.start();
        }
    }

    Timer {
        id: restartTimer
        interval: 2000
        onTriggered: root.startServer()
    }

    Timer {
        id: readyPingTimer
        interval: 1000
        onTriggered: root._apiCall(`http://localhost:${root.port}/languages`, "health")
    }

    Process {
        id: apiProcess
        property string type
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const json = JSON.parse(text);
                    if (apiProcess.type === "translate")
                        root.translationReady(json);
                    else {
                        root._applyLanguages(json);
                        root.serverReady = root.serverActive = true;
                    }
                } catch (e) {
                    if (apiProcess.type === "health" && !root._stopping)
                        readyPingTimer.start();
                }
            }
        }
        onExited: root.busy = false
    }

    Component.onCompleted: if (GlobalStates.showLauncher && GlobalSettings.loadLauncher)
        root.startServer()
}
