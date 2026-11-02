pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../lib/FileUtils.js" as FileUtils
import "../lib/FuzzyFilter.js" as FuzzyFilter

Singleton {
    id: root

    property var tasks: []
    property var projects: []
    property var labels: []
    property var sections: []
    property var user: ({})
    property bool syncing: false

    Component.onCompleted: {
        root._loadTasks();
        root._loadStatus();
    }

    // Files are written atomically (tmp+rename) by $BN_SCRIPTS/todoist, which
    // file watchers miss. The script notifies explicitly via
    // qs ipc call tasks reload, so no watchChanges here.
    FileView {
        id: tasksJson
        path: FileUtils.trimFileProtocol(Paths.todoistTasksFile)
        blockLoading: true
        onLoaded: root._onTasksLoaded()
    }

    FileView {
        id: statusJson
        path: FileUtils.trimFileProtocol(Paths.todoistStatusFile)
        blockLoading: true
        onLoaded: root._onStatusLoaded()
    }

    // Coalesces bursts (placeholder + queue + drain + sync + status writes).
    Timer {
        id: reloadDebounce
        interval: 150
        onTriggered: {
            root._retryCount = 0;
            root._loadTasks();
            root._loadStatus();
        }
    }

    property int _retryCount: 0
    readonly property int _maxRetries: 8

    Timer {
        id: loadRetryTimer
        interval: 250
        onTriggered: {
            if (root._retryCount >= root._maxRetries)
                return;
            root._retryCount++;
            root._loadTasks();
            root._loadStatus();
        }
    }

    function _onStatusLoaded() {
        const text = statusJson.text();
        if (!text)
            return;
        try {
            root.syncing = !!JSON.parse(text).syncing;
        } catch (e) {}
    }

    // Task creation
    property var _createCallback: null

    Process {
        id: addTaskProcess

        property string stderrText: ""

        command: []
        stderr: StdioCollector {
            onStreamFinished: addTaskProcess.stderrText = this.text
        }

        onExited: (exitCode, exitStatus) => {
            const cb = root._createCallback;
            root._createCallback = null;
            const ok = exitCode === 0;

            if (ok) {
                GlobalIpc.popup.showInfo("Task Added", "", 1000);
                root.reload();
            } else {
                GlobalIpc.popup.showError("Failed to add task", addTaskProcess.stderrText.trim() || `todoist exited with code ${exitCode}`, 5000);
            }

            addTaskProcess.stderrText = "";
            if (cb)
                cb(ok);
        }
    }

    function _loadTasks() {
        tasksJson.reload();
        root._parseTasks();
    }

    function _onTasksLoaded() {
        root._parseTasks();
    }

    function _parseTasks() {
        const text = tasksJson.text();
        if (!text) {
            loadRetryTimer.restart();
            return;
        }
        try {
            const data = JSON.parse(text);
            root.tasks = data.todos.reverse() || [];
            root.projects = data.projects || [];
            root.labels = data.labels || [];
            root.sections = data.sections || [];
            root.user = data.user || {};
        } catch (e) {
            loadRetryTimer.restart();
        }
    }

    function _loadStatus() {
        statusJson.reload();
        const text = statusJson.text();
        if (!text) {
            loadRetryTimer.restart();
            return;
        }
        try {
            const data = JSON.parse(text);
            root.syncing = !!data.syncing;
        } catch (e) {
            loadRetryTimer.restart();
        }
    }

    // Todoist domain helpers
    readonly property var todoistColorMap: ({
            "berry_red": "#B8255F",
            "red": "#DC4C3E",
            "orange": "#C77100",
            "yellow": "#B29104",
            "olive_green": "#949C31",
            "lime_green": "#65A33A",
            "green": "#369307",
            "mint_green": "#42A393",
            "teal": "#148FAD",
            "sky_blue": "#319DC0",
            "light_blue": "#6988A4",
            "blue": "#4180FF",
            "grape": "#692EC2",
            "violet": "#CA3FEE",
            "lavender": "#A4698C",
            "magenta": "#E05095",
            "salmon": "#C9766F",
            "charcoal": "#808080",
            "grey": "#999999",
            "taupe": "#8F7A69"
        })

    readonly property var priorityOptions: ["P1", "P2", "P3", "P4"]
    readonly property var projectOptions: projects.map(p => ({
                text: "#" + p.name,
                value: p.id
            }))

    function sectionsFor(projectId) {
        return [
            {
                text: "No section",
                value: null
            },
            ...sections.filter(s => s.project_id === projectId).map(s => ({
                        text: s.name,
                        value: s.id
                    }))];
    }

    function projectByName(name) {
        if (!name)
            return null;
        return projects.find(e => e.name === name) ?? null;
    }

    function colorFor(colorName) {
        return todoistColorMap[colorName] ?? Theme.colors.textSecondary;
    }

    function labelColor(labelName) {
        const label = labels.find(l => l.name === labelName);
        return colorFor(label?.color);
    }

    function priorityColor(priority, noneColor) {
        switch (priority) {
        case 1:
            return todoistColorMap.red;
        case 2:
            return todoistColorMap.orange;
        case 3:
            return todoistColorMap.blue;
        default:
            return noneColor;
        }
    }

    function filterTasks(query) {
        if (!query)
            return tasks;
        const prepared = tasks.map(t => ({
                    obj: t,
                    content: t.content || "",
                    description: t.description || "",
                    project: t.project || ""
                }));
        return FuzzyFilter.search(query, prepared, {
            threshold: 0,
            limit: 999,
            all: true,
            keys: ["content", "description", "project"],
            pick: item => item.obj.obj
        });
    }

    function createTask(title, description, projectId, sectionId, labels, priority, dueString, callback) {
        if (addTaskProcess.running) {
            GlobalIpc.popup.showInfo("Still adding the previous task…", "", 1500);
            if (callback)
                callback(false);
            return;
        }

        const payload = {
            content: title,
            description: description || null,
            project_id: projectId || null,
            section_id: sectionId || null,
            labels: labels ?? [],
            priority: priority ?? 4
        };

        if (dueString)
            payload.due_string = dueString;

        _createCallback = callback;
        addTaskProcess.stderrText = "";
        addTaskProcess.command = [Quickshell.env("BN_SCRIPTS") + "/todoist", "add-json", JSON.stringify(payload)];
        addTaskProcess.running = true;
    }

    // Actions (the todoist script notifies via qs ipc call tasks reload
    // after each write; removal is optimistic so the list reacts instantly,
    // disk reload reconciles right after).
    function completeTask(id) {
        if (!id)
            return;
        root.tasks = root.tasks.filter(t => t.id !== id);
        Quickshell.execDetached(["sh", "-c", `$BN_SCRIPTS/todoist done ${id}`]);
        GlobalIpc.popup.showInfo("Task Completed", "", 2000);
    }

    function deleteTask(id) {
        if (!id)
            return;
        root.tasks = root.tasks.filter(t => t.id !== id);
        Quickshell.execDetached(["sh", "-c", `$BN_SCRIPTS/todoist del ${id}`]);
    }

    function openTaskInBrowser(id) {
        if (!id)
            return;
        Quickshell.execDetached(["xdg-open", `https://app.todoist.com/app/task/${id}`]);
        GlobalIpc.popup.showInfo("Opening task in browser", "", 3000);
    }

    function openSite() {
        Quickshell.execDetached(["xdg-open", `https://app.todoist.com/app`]);
        GlobalIpc.popup.showInfo("Opening Todoist in browser", "", 3000);
    }

    function sync() {
        Quickshell.execDetached(["sh", "-c", "$BN_SCRIPTS/todoist sync"]);
        GlobalIpc.popup.showInfo("Syncing Tasks", "", 2000);
    }

    function reload() {
        reloadDebounce.restart();
    }
}
