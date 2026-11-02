pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import qs.surfaces.launcher.pages.components
import qs.surfaces.launcher.pages.layouts
import "../../../lib/ColorUtils.js" as ColorUtils
import "../../../lib/DateUtils.js" as DateUtils

BasePage {
    id: root
    navTarget: layout
    placeHolder: "Filter tasks..."
    pageIcon: "task_alt"
    pageIconType: "symbol"
    pageName: "Tasks"
    isLoading: TasksService.syncing

    catchEscape: showTaskSheet
    enableSearchbar: !showTaskSheet
    outerMargins: 0

    property Component addTaskAction: Component {
        StyledIconButton {
            iconName: "add_2"
            inactiveOpacity: 0.35
            implicitWidth: 42
            implicitHeight: 42
            onClicked: root.openTaskSheet()
        }
    }

    property Component syncTaskAction: Component {
        StyledIconButton {
            enabled: !root.isLoading
            opacity: root.isLoading ? 0.35 : 1
            iconName: "sync"
            inactiveOpacity: 0.35
            implicitWidth: 42
            implicitHeight: 42
            onClicked: TasksService.sync()
        }
    }

    searchbarActions: [addTaskAction, syncTaskAction]

    readonly property var focusedTask: layout.currentModelData ?? null
    readonly property var focusedProjectObject: TasksService.projectByName(root.focusedTask?.project)

    // New-task sheet state
    property bool showTaskSheet: false
    property bool taskSubmitting: false
    property var sheetLabels: []

    readonly property var sheetProjectEntry: TasksService.projectOptions[projectCombo.currentIndex] ?? null
    readonly property string sheetProjectId: root.sheetProjectEntry?.value ?? ""
    readonly property var sheetSectionOptions: TasksService.sectionsFor(root.sheetProjectId)

    readonly property var filteredTasks: TasksService.filterTasks(root.searchText.trim())

    Component.onCompleted: TasksService._loadStatus()
    onFilteredTasksChanged: layout.resetToTopInstant()

    // Sheet actions
    function openTaskSheet() {
        titleField.text = "";
        descriptionArea.text = "";
        projectCombo.currentIndex = 0;
        sectionCombo.currentIndex = 0;
        prioritySelector.currentIndex = 3;
        dueField.text = "";
        sheetLabels = [];
        showTaskSheet = true;
        titleField.forceActiveFocus();
    }

    function closeTaskSheet() {
        showTaskSheet = false;
    }

    function submitTaskSheet() {
        if (taskSubmitting)
            return;

        const title = titleField.text.trim();
        if (!title)
            return;

        const prioIndex = prioritySelector.currentIndex;
        taskSubmitting = true;
        TasksService.createTask(title, descriptionArea.text.trim(), projectCombo.currentValue?.value ?? null, sectionCombo.currentValue?.value ?? null, root.sheetLabels, prioIndex >= 0 ? prioIndex + 1 : 4, dueField.text.trim() || null, ok => {
            taskSubmitting = false;
            if (ok)
                closeTaskSheet();
        });
    }

    function toggleSheetLabel(name) {
        if (sheetLabels.includes(name))
            sheetLabels = sheetLabels.filter(l => l !== name);
        else
            sheetLabels = [...sheetLabels, name];
    }

    // Page actions
    function primaryAction() {
        if (showTaskSheet) {
            submitTaskSheet();
            return;
        }
        if (root.focusedTask) {
            TasksService.openTaskInBrowser(root.focusedTask.id);
            GlobalStates.showLauncher = false;
        }
    }

    function secondaryAction() {
        if (showTaskSheet) {
            submitTaskSheet();
            return;
        }
        openTaskSheet();
    }

    function escapeAction() {
        closeTaskSheet();
    }

    function nextItem() {
        if (!showTaskSheet)
            layout.moveNext();
    }

    function previousItem() {
        if (!showTaskSheet)
            layout.movePrevious();
    }

    SplitLayout {
        id: layout
        model: root.filteredTasks
        isEmpty: TasksService.tasks.length === 0 && !TasksService.syncing
        anchors.margins: 12
        anchors.topMargin: 0

        headerComponent: Component {
            SectionHeader {
                title: TasksService.syncing ? "Syncing tasks..." : "Your Tasks"
            }
        }

        delegate: ListItemBackground {
            id: taskRow
            required property var modelData
            required property int index
            selected: ListView.isCurrentItem
            width: ListView.view.width

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                StyledCheckBox {
                    size: 20
                    bgColor: checkState === Qt.Checked ? ColorUtils.transparentize(borderColor, 0.75) : ColorUtils.transparentize(Theme.colors.bgBase, 0.40)
                    fgColor: ColorUtils.transparentize(Theme.colors.bgSurface, 0.85)
                    borderWidth: 2
                    borderColor: TasksService.priorityColor(taskRow.modelData.priority, TasksService.todoistColorMap.charcoal)
                    onClicked: TasksService.completeTask(taskRow.modelData.id)
                }

                StyledText {
                    Layout.fillWidth: true
                    text: taskRow.modelData.content
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                }

                StyledIconButton {
                    id: deleteButton
                    iconName: "delete"
                    inactiveOpacity: 0.25
                    visible: taskRow.selected
                    onClicked: if (root.focusedTask)
                        TasksService.deleteTask(root.focusedTask.id)
                }
            }
        }

        // Right-pane empty / no-selection state
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.focusedTask || root.filteredTasks.length === 0

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 8

                MaterialSymbol {
                    iconName: layout.isEmpty ? "checklist" : root.filteredTasks.length === 0 ? "search_off" : "task_alt"
                    iconSize: 64
                    opacity: 0.2
                    Layout.alignment: Qt.AlignCenter
                }

                StyledText {
                    text: {
                        if (TasksService.syncing && TasksService.tasks.length === 0)
                            return "Syncing tasks...";
                        if (layout.isEmpty)
                            return "No tasks yet";
                        if (root.filteredTasks.length === 0)
                            return "No matching tasks";
                        return "Select a task";
                    }
                    opacity: 0.5
                    font.pixelSize: Theme.fontPixelSizes.normal
                    font.weight: Font.DemiBold
                    Layout.alignment: Qt.AlignCenter
                }

                StyledText {
                    visible: layout.isEmpty && !TasksService.syncing
                    text: "Press Enter or + to create one"
                    font.pixelSize: Theme.fontPixelSizes.smaller
                    color: Theme.colors.textSecondary
                    opacity: 0.45
                    Layout.alignment: Qt.AlignCenter
                }
            }
        }

        // Scrollable title + description
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 8
            visible: !!root.focusedTask
            clip: true

            Flickable {
                id: contentScroll
                anchors.fill: parent
                contentWidth: width
                contentHeight: scrollColumn.implicitHeight
                flickableDirection: Flickable.VerticalFlick
                clip: true

                Column {
                    id: scrollColumn
                    width: contentScroll.width
                    spacing: 12

                    StyledText {
                        width: parent.width
                        text: root.focusedTask?.content ?? ""
                        font.pixelSize: Theme.fontPixelSizes.larger
                        font.weight: Font.DemiBold
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                    }

                    StyledText {
                        width: parent.width
                        visible: !!root.focusedTask?.description
                        text: root.focusedTask?.description ?? ""
                        textFormat: TextEdit.MarkdownText
                        font.pixelSize: Theme.fontPixelSizes.small
                        color: Theme.colors.textSecondary
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                    }
                }
            }
        }

        Divider {
            vertical: false
            opacity: 0.12
            visible: !!root.focusedTask
        }

        // Metadata table — single source of truth for task details
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: metaRows.implicitHeight + 16
            clip: true
            visible: !!root.focusedTask

            MetaRows {
                id: metaRows
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 8
                anchors.leftMargin: 14
                anchors.rightMargin: 14
                rows: {
                    const t = root.focusedTask;
                    if (!t)
                        return [];

                    const result = [
                        {
                            label: "Priority",
                            value: t.priority ? "P" + t.priority : "None",
                            color: TasksService.priorityColor(t.priority, Theme.colors.textPrimary)
                        }
                    ];

                    if (t.project && root.focusedProjectObject)
                        result.push({
                            label: "Project",
                            component: projectChipComponent
                        });

                    if (t.labels && t.labels.length > 0)
                        result.push({
                            label: "Labels",
                            component: labelsChipsComponent
                        });

                    if (t.subtask_count > 0)
                        result.push({
                            label: "Subtasks",
                            value: String(t.subtask_count)
                        });

                    if (t.due_date) {
                        const diff = DateUtils.compareToNow(t.due_date);
                        let dueColor = Theme.colors.textPrimary;
                        if (diff < 0)
                            dueColor = TasksService.todoistColorMap.red;
                        else if (diff === 0)
                            dueColor = TasksService.todoistColorMap.green;
                        else if (diff === 1)
                            dueColor = TasksService.todoistColorMap.orange;
                        else if (diff <= 7)
                            dueColor = TasksService.todoistColorMap.grape;

                        result.push({
                            label: "Due",
                            value: DateUtils.formatFullDate(t.due_date),
                            color: dueColor
                        });
                    }

                    if (t.is_local)
                        result.push({
                            label: "Sync",
                            value: "Pending"
                        });

                    return result;
                }
            }
        }

        Component {
            id: projectChipComponent

            StyledRectangle {
                readonly property string chipColor: TasksService.colorFor(root.focusedProjectObject?.color)

                implicitHeight: 18
                implicitWidth: chipText.implicitWidth + 12
                baseRadius: height / 2
                color: ColorUtils.transparentize(chipColor, 0.35)
                border.width: 1
                border.color: ColorUtils.transparentize(chipColor, 0.75)

                StyledText {
                    id: chipText
                    anchors.centerIn: parent
                    text: `#${root.focusedTask?.project ?? ""}${root.focusedTask?.section ? ` / ${root.focusedTask.section}` : ""}`
                    font.pixelSize: Theme.fontPixelSizes.smallest
                    font.weight: Font.Bold
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }

        Component {
            id: labelsChipsComponent

            RowLayout {
                spacing: 6

                Repeater {
                    model: root.focusedTask?.labels ?? []

                    delegate: StyledRectangle {
                        id: labelChip
                        required property var modelData
                        required property int index
                        readonly property string chipColor: TasksService.labelColor(modelData)
                        Layout.preferredHeight: 18
                        Layout.preferredWidth: chipText.implicitWidth + 12
                        Layout.alignment: Qt.AlignHCenter

                        baseRadius: height / 2
                        color: ColorUtils.transparentize(chipColor, 0.35)
                        border.width: 1
                        border.color: ColorUtils.transparentize(chipColor, 0.75)

                        StyledText {
                            id: chipText
                            anchors.centerIn: parent
                            text: "@" + parent.modelData
                            font.pixelSize: Theme.fontPixelSizes.smallest
                            font.weight: Font.Bold
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }
            }
        }
    }

    // New Task sheet
    Sheet {
        shown: root.showTaskSheet
        onClosed: root.closeTaskSheet()
        maxWidth: 650
        contentHeight: sheetContent.implicitHeight

        ColumnLayout {
            id: sheetContent
            anchors.fill: parent
            spacing: 12

            StyledText {
                text: "New Task"
                font.pixelSize: Theme.fontPixelSizes.large
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14

                // Left: main fields
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 12

                    // Title
                    StyledRectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        baseRadius: height / 2
                        color: Theme.colors.gray1
                        border.width: 1
                        border.color: titleField.activeFocus ? Theme.colors.borderMid : ColorUtils.transparentize(Theme.colors.borderMid, 0.6)

                        StyledTextField {
                            id: titleField
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: "Task title"
                            onAccepted: root.submitTaskSheet()
                            Keys.onEscapePressed: event => {
                                event.accepted = true;
                                root.closeTaskSheet();
                            }
                        }
                    }

                    // Description
                    StyledRectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 100
                        baseRadius: Theme.rounding.normal
                        color: Theme.colors.gray1
                        border.width: 1
                        border.color: descriptionArea.activeFocus ? Theme.colors.borderMid : ColorUtils.transparentize(Theme.colors.borderMid, 0.6)

                        Flickable {
                            id: descriptionScroll
                            anchors.fill: parent
                            anchors.margins: 10
                            contentWidth: width
                            contentHeight: descriptionArea.implicitHeight
                            clip: true

                            TextArea.flickable: StyledTextArea {
                                id: descriptionArea
                                width: descriptionScroll.width
                                wrapMode: TextEdit.Wrap
                                placeholderText: "Description (optional)"
                                Keys.onEscapePressed: event => {
                                    event.accepted = true;
                                    root.closeTaskSheet();
                                }
                            }
                        }
                    }

                    // Project | Section
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        StyledComboBox {
                            id: projectCombo
                            Layout.fillWidth: true
                            model: TasksService.projectOptions
                            onCurrentIndexChanged: sectionCombo.currentIndex = 0
                            focusPolicy: Qt.NoFocus
                        }

                        StyledComboBox {
                            id: sectionCombo
                            enabled: root.sheetSectionOptions.length > 1
                            Layout.fillWidth: true
                            model: root.sheetSectionOptions
                            focusPolicy: Qt.NoFocus
                        }
                    }
                }

                Divider {
                    vertical: true
                    opacity: 0.10
                }

                // Right rail
                ColumnLayout {
                    Layout.preferredWidth: 185
                    Layout.fillHeight: true
                    spacing: 12

                    // Priority radios
                    StyledSelector {
                        id: prioritySelector
                        readonly property color activeColor: [TasksService.todoistColorMap.red, TasksService.todoistColorMap.orange, TasksService.todoistColorMap.blue, Theme.colors.textPrimary][currentIndex]
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        entries: TasksService.priorityOptions
                        showBorder: false
                        backgroundColor: "transparent"
                        indicatorColor: ColorUtils.transparentize(activeColor, 0.30)
                        indicatorBorderColor: ColorUtils.transparentize(activeColor, 0.60)
                        currentIndex: 3

                        delegate: Component {
                            Item {
                                id: prioritySlot
                                property var modelData
                                property int index
                                readonly property color slotColor: [TasksService.todoistColorMap.red, TasksService.todoistColorMap.orange, TasksService.todoistColorMap.blue, Theme.colors.textPrimary][index]
                                readonly property bool isActive: prioritySlot.index === prioritySelector.currentIndex

                                StyledText {
                                    text: prioritySlot.modelData
                                    anchors.centerIn: parent
                                    color: prioritySlot.slotColor
                                    font.pixelSize: Theme.fontPixelSizes.small
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    // Due
                    StyledRectangle {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        baseRadius: height / 2
                        color: Theme.colors.gray1
                        border.width: 1
                        border.color: dueField.activeFocus ? Theme.colors.borderMid : ColorUtils.transparentize(Theme.colors.borderMid, 0.6)

                        StyledTextField {
                            id: dueField
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            verticalAlignment: TextInput.AlignVCenter
                            placeholderText: "Today, aug 30, every day"
                            onAccepted: root.submitTaskSheet()
                            Keys.onEscapePressed: event => {
                                event.accepted = true;
                                root.closeTaskSheet();
                            }
                        }
                    }

                    Item {
                        Layout.preferredHeight: 8
                    }

                    // Labels
                    Flow {
                        Layout.fillWidth: true
                        visible: TasksService.labels.length > 0
                        spacing: 6

                        Repeater {
                            model: TasksService.labels

                            delegate: StyledRectangle {
                                id: sheetLabelChip
                                required property var modelData
                                required property int index
                                readonly property bool isSelected: root.sheetLabels.includes(modelData.name)
                                readonly property string chipColor: TasksService.colorFor(modelData.color)

                                width: sheetLabelRow.implicitWidth + 20
                                height: 26
                                baseRadius: height / 2
                                color: ColorUtils.transparentize(chipColor, isSelected ? 0.25 : 0.60)
                                border.width: 1
                                border.color: ColorUtils.transparentize(chipColor, isSelected ? 0.35 : 0.85)

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animations.duration.normal
                                    }
                                }

                                Row {
                                    id: sheetLabelRow
                                    anchors.centerIn: parent
                                    spacing: 4

                                    MaterialSymbol {
                                        visible: sheetLabelChip.isSelected
                                        iconName: "check"
                                        iconSize: 14
                                        color: Theme.colors.white
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    StyledText {
                                        text: "@" + sheetLabelChip.modelData.name
                                        font.pixelSize: Theme.fontPixelSizes.smaller
                                        font.weight: Font.Bold
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.toggleSheetLabel(sheetLabelChip.modelData.name)
                                }
                            }
                        }
                    }

                    Item {
                        Layout.preferredHeight: 8
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    StyledButton {
                        Layout.fillWidth: true
                        implicitHeight: 42
                        text: root.taskSubmitting ? "Adding…" : "Add Task"
                        enabled: !root.taskSubmitting && titleField.text.trim() !== ""
                        onClicked: root.submitTaskSheet()
                        border.width: 1
                        border.color: ColorUtils.transparentize(Theme.colors.white, 0.2)
                    }
                }
            }
        }
    }
}
