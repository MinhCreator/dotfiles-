pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/FuzzySort.js" as FuzzySort
import "../lib/StringUtils.js" as StringUtils

Singleton {
    id: root

    property var commands: []
    property alias isLoading: processes.running

    Process {
        id: processes
        running: true
        command: ["python3", Paths.commandsFetcherScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const rawCommands = StringUtils.safeParse(this.text, []);
                root.commands = rawCommands.map(cmd => FuzzySort.prepare(cmd));
            }
        }
    }

    function refresh() {
        processes.running = false;
        processes.running = true;
    }
}
