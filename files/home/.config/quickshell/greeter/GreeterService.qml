pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs

Singleton {
    id: root

    property var users: []
    property var sessions: []
    property string echoResponse: ""
    property bool isAuthenticating: false
    property bool authenticationHasFailed: false

    property string _pendingPassword: ""
    property string _pendingSessionType: ""
    property var _pendingSessionCmd: []
    property string _pendingSessionDesktop: ""
    property var _pendingDesktopNames: []

    Component.onCompleted: {
        fetchDiscoveryData();
    }

    function fetchDiscoveryData() {
        discoveryProcess.running = true;
    }

    function suspend() {
        Quickshell.execDetached(["systemctl", "suspend"]);
    }

    function restart() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function restartToBios() {
        Quickshell.execDetached(["systemctl", "reboot", "--firmware-setup"]);
    }

    function powerOff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    Timer {
        id: authenticationHasFailedTimer
        interval: 5000
        running: root.authenticationHasFailed && root.echoResponse === ""
        onTriggered: root.authenticationHasFailed = false
    }

    Process {
        id: discoveryProcess
        command: [Paths.greeterFetcherScript]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text);
                    root.users = (data.users || []).map(u => Object.assign({
                            text: u.name
                        }, u));
                    root.sessions = (data.sessions || []).map(s => Object.assign({
                            text: s.name
                        }, s));
                } catch (e) {
                    console.error("Failed to parse greeter discovery data:", e);
                }
            }
        }
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (echoResponse && message.toString().includes('left to unlock')) {
                root.echoResponse = message;
            }

            if (responseRequired && root._pendingPassword !== "") {
                Greetd.respond(root._pendingPassword);
                root._pendingPassword = "";
            }
        }

        function onAuthFailure(message) {
            root.isAuthenticating = false;
            root.authenticationHasFailed = true;
            root._pendingPassword = "";
        }

        function onReadyToLaunch() {
            root.isAuthenticating = false;
            let env = [`XDG_SESSION_TYPE=${root._pendingSessionType}`];
            if (root._pendingSessionDesktop !== "") {
                env.push(`XDG_SESSION_DESKTOP=${root._pendingSessionDesktop}`);
                env.push(`DESKTOP_SESSION=${root._pendingSessionDesktop}`);
            }
            let currentDesktop = root._pendingDesktopNames.length > 0
                ? root._pendingDesktopNames.join(":")
                : root._pendingSessionDesktop;
            if (currentDesktop !== "")
                env.push(`XDG_CURRENT_DESKTOP=${currentDesktop}`);
            Greetd.launch(root._pendingSessionCmd, env);
            Quickshell.execDetached(["killall", "Hyprland"]);
        }
    }

    function login(username, password, sessionCmd, sessionType, sessionDesktop, desktopNames) {
        root._pendingPassword = password;
        root._pendingSessionType = sessionType;
        root._pendingSessionCmd = typeof sessionCmd === "string" ? `sh -c '${sessionCmd}' >/dev/null 2>&1` : sessionCmd;
        root._pendingSessionDesktop = sessionDesktop || "";
        root._pendingDesktopNames = desktopNames || [];
        root.isAuthenticating = true;
        root.authenticationHasFailed = false;
        root.echoResponse = "";
        Greetd.createSession(username);
    }
}
