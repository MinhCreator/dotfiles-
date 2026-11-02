pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/StringUtils.js" as StringUtils

Singleton {
    id: root

    property var processes: [] // [{"pid":"xxx","program":"xxx","command":"xxx","threads":0,"user":"xxx","mem":"xxxMB","cpu":0.0}]
    property bool getProcesses: false

    Process {
        id: processes
        running: root.getProcesses
        command: ["python3", Paths.processesFetcherScript]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                root.processes = StringUtils.safeParse(data, []);
            }
        }
    }

    function kill(process) {
        if (!process)
            return;
        GlobalIpc.dialog.showConfirm("Kill process", `Are you sure you want to kill the process '${process.program}' ?`, "Cancel", "Kill", "", `kill -9 ${process.pid}`);
        processes.running = false;
        processes.running = true;
    }

    function btop(process) {
        Quickshell.execDetached(process ? ["btop", process.program] : ["btop"]);
    }
}
