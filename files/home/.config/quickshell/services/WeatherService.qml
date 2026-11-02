pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/StringUtils.js" as StringUtils

Singleton {
    id: root
    property var data: StringUtils.safeParse(weatherFile.text(), {})

    Timer {
        interval: 1800000 + 180000  // 30 minutes + 3 minutes
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Quickshell.execDetached(["sh", "-c", `${Paths.weatherFetcherScript} --once`])
    }

    FileView {
        id: weatherFile
        path: Paths.weatherFile
        watchChanges: true
        blockLoading: true
        onFileChanged: {
            reload();
            const content = text();
            if (content)
                root.data = StringUtils.safeParse(content, {});
        }
    }
}
