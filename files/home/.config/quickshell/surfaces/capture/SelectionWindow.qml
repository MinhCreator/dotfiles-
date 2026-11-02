pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import "../../lib/FileUtils.js" as FileUtils

PanelWindow {
    id: window

    required property var manager

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: false

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: window.screen.name === Hyprland.focusedMonitor.name ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "quickshell:regionSelector"

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    readonly property string outputPath: {
        const filename = manager.generateFilename();
        if (manager.customPath)
            return `${manager.customPath}/${filename}`;
        return manager.saveToTemp ? `${Paths.screenshotTempDir}/${filename}` : `${Paths.screenshotDir}/${filename}`;
    }
    readonly property string tempImagePath: `${Paths.screenshotTempDir}/${window.screen.name}`
    readonly property bool isActiveMonitor: Hyprland.focusedMonitor.name === screen.name
    readonly property var ownMonitor: Hyprland.monitors.values.find(m => m.name === screen.name) ?? Hyprland.focusedMonitor
    readonly property int ownWorkspaceId: ownMonitor?.activeWorkspace?.id ?? Hyprland.focusedWorkspace.id

    readonly property bool mouseOverBar: {
        const inBar = mouseInput.currentMouseX >= toolbar.x && mouseInput.currentMouseX <= toolbar.x + toolbar.width && mouseInput.currentMouseY >= toolbar.y && mouseInput.currentMouseY <= toolbar.y + toolbar.height;

        return inBar || toolbar.isPopupVisible;
    }

    property string captureMode: "snapshot" // "snapshot" or "recording" or "ask google" or "ocr"
    property string selectionMode: "selection" // "selection" or "region" or "monitor" or "windows"
    property int hoveredRegionIndex: -1

    property var detectedWindows: []
    property var detectedAutoRegions: []
    property var activeOverlayRegions: []

    onCaptureModeChanged: {
        toolbar.captureMode = window.captureMode;
    }

    onSelectionModeChanged: {
        if (selectionMode !== "selection")
            selection.reset();

        if (selectionMode === "monitor")
            activeOverlayRegions = [
                {
                    "x": 0,
                    "y": 0,
                    "width": window.screen.width,
                    "height": window.screen.height,
                    "title": window.screen.name,
                    "icon": "desktop_windows"
                }
            ];
        else if (selectionMode === "windows")
            window.activeOverlayRegions = window.detectedWindows.map(w => ({
                        x: w.x - window.screen.x,
                        y: w.y - window.screen.y,
                        width: w.width,
                        height: w.height,
                        title: w.title,
                        class: w.class,
                        initialTitle: w.initialTitle
                    }));
        else
            window.activeOverlayRegions = window.detectedAutoRegions;
        toolbar.selectionMode = window.selectionMode;
    }

    function getFinalPath(): string {
        return FileUtils.trimFileProtocol(outputPath);
    }

    function hideWindow(): void {
        // Close overlay on every monitor, not just this window.
        GlobalStates.showScreenCapture = false;
    }

    function nextCaptureMode(): void {
        switch (window.captureMode) {
        case "snapshot":
            window.captureMode = "recording";
            break;
        case "recording":
            window.captureMode = "ask google";
            break;
        case "ask google":
            window.captureMode = "ocr";
            break;
        case "ocr":
            window.captureMode = "snapshot";
            break;
        default:
            break;
        }
    }

    function prevCaptureMode(): void {
        switch (window.captureMode) {
        case "ocr":
            window.captureMode = "ask google";
            break;
        case "ask google":
            window.captureMode = "recording";
            break;
        case "recording":
            window.captureMode = "snapshot";
            break;
        case "snapshot":
            window.captureMode = "ocr";
            break;
        default:
            break;
        }
    }

    function startCrop(cropX: int, cropY: int, cropW: int, cropH: int, finalPath: string): void {
        // Delegate to manager scope so processing outlives these windows.
        // Manager hides all monitor overlays instantly and runs Lens/OCR in background.
        manager.startCrop(window.screen.name, window.screen.x, window.screen.y, window.tempImagePath, window.captureMode, cropX, cropY, cropW, cropH, finalPath);
    }

    function checkRectOverlap(r1x: real, r1y: real, r1w: real, r1h: real, r2x: real, r2y: real, r2w: real, r2h: real): bool {
        return !(r1x + r1w <= r2x || r2x + r2w <= r1x || r1y + r1h <= r2y || r2y + r2h <= r1y);
    }

    function hasRegionOverlap(selectorX: real, selectorY: real, selectorW: real, selectorH: real): bool {
        if (selectionMode === "selection" || activeOverlayRegions.length === 0)
            return false;

        for (let i = 0; i < activeOverlayRegions.length; i++) {
            if (checkRectOverlap(selectorX, selectorY, selectorW, selectorH, activeOverlayRegions[i].x, activeOverlayRegions[i].y, activeOverlayRegions[i].width, activeOverlayRegions[i].height)) {
                return true;
            }
        }
        return false;
    }

    Process {
        id: getWindowsProcess
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = JSON.parse(this.text);
                window.detectedWindows = raw.filter(w => w.workspace.id === window.ownWorkspaceId).map(w => ({
                            x: w.at[0],
                            y: w.at[1],
                            width: w.size[0],
                            height: w.size[1],
                            title: w.title,
                            class: w.class,
                            initialTitle: w.initialTitle
                        }));
            }
        }
    }

    Process {
        id: getRegionsProcess
        running: false
        command: ["sh", "-c", `${Paths.rectDetectorScript} '${window.tempImagePath}'`]
        stdout: StdioCollector {
            onStreamFinished: {
                window.detectedAutoRegions = JSON.parse(this.text);
                if (window.selectionMode === "region")
                    window.activeOverlayRegions = window.detectedAutoRegions;
            }
        }
    }

    Process {
        id: captureProcess
        running: true
        command: ["sh", "-c", `grim -o ${window.screen.name} '${window.tempImagePath}'`]
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                GlobalStates.showScreenCapture = false;
                return;
            }
            getRegionsProcess.running = true;
            getWindowsProcess.running = true;
            screenshot.source = Qt.resolvedUrl(window.tempImagePath);
            window.visible = true;
        }
    }

    Connections {
        target: window.manager
        function onIsDraggingChanged() {
            if (window.manager.isDragging && !window.isActiveMonitor)
                selection.reset();
        }
    }

    CrosshairLine {
        id: verticalCrosshair
        isVertical: true
        isActive: window.isActiveMonitor && !selection.isMoving && !selection.isResizing
        visible: window.isActiveMonitor && mouseInput.mouseInitialized && window.selectionMode === "selection"
        fadeVisible: !window.mouseOverBar
    }

    CrosshairLine {
        id: horizontalCrosshair
        isVertical: false
        isActive: window.isActiveMonitor && !selection.isMoving && !selection.isResizing
        visible: window.isActiveMonitor && mouseInput.mouseInitialized && window.selectionMode === "selection"
        fadeVisible: !window.mouseOverBar
    }

    InfoLabel {
        id: cursorInfo
        x: Math.min(mouseInput.currentMouseX + offsetX, parent.width - width - 4)
        y: Math.max(mouseInput.currentMouseY - height - offsetY, 4)
        text: mouseInput.mouseInitialized && window.isActiveMonitor && !selection.isMoving && !selection.isResizing && window.selectionMode === "selection" && !window.mouseOverBar ? `${Math.floor(mouseInput.currentMouseX)}, ${Math.floor(mouseInput.currentMouseY)}` : ""
    }

    Image {
        id: screenshot
        anchors.fill: parent
        visible: status === Image.Ready
        focus: true
        cache: false
        asynchronous: true
    }

    CaptureShortcuts {
        window: window
        selection: selection
    }

    Rectangle {
        anchors.fill: screenshot
        color: "#60000000"
    }

    CaptureToolbar {
        id: toolbar
        captureMode: window.captureMode
        selectionMode: window.selectionMode
        isInteractionActive: window.manager.isDragging || selection.isMoving || selection.isResizing
        isWindowVisible: window.visible

        onCaptureModeChanged: window.captureMode = captureMode
        onSelectionModeChanged: window.selectionMode = selectionMode

        onClosed: GlobalStates.showScreenCapture = false
        onPopupClosed: screenshot.forceActiveFocus()
    }

    MouseArea {
        id: mouseInput
        visible: window.selectionMode === "selection"
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: {
            if (selection.isMoving)
                return Qt.ClosedHandCursor;
            if (selection.isResizing)
                return selection.resizeCursor;
            if (selection.visible && !pressed) {
                const edge = selection.getEdgeAt(currentMouseX, currentMouseY);
                if (edge !== "")
                    return selection.getCursorForEdge(edge);
                if (selection.contains(currentMouseX, currentMouseY))
                    return Qt.OpenHandCursor;
            }
            return Qt.CrossCursor;
        }

        property real dragStartX: 0
        property real dragStartY: 0
        property real currentMouseX: 0
        property real currentMouseY: 0
        property bool mouseInitialized: false

        onPositionChanged: mouse => {
            currentMouseX = mouse.x;
            currentMouseY = mouse.y;
            mouseInitialized = true;
            verticalCrosshair.x = mouse.x - 0.5;
            horizontalCrosshair.y = mouse.y - 0.5;
            if (pressed) {
                if (selection.isMoving) {
                    selection.moveSelection(mouse.x - dragStartX, mouse.y - dragStartY);
                    dragStartX = mouse.x;
                    dragStartY = mouse.y;
                } else if (selection.isResizing) {
                    selection.resizeSelection(mouse.x, mouse.y);
                } else {
                    selection.updateGeometry(Math.min(dragStartX, mouse.x), Math.min(dragStartY, mouse.y), Math.abs(mouse.x - dragStartX), Math.abs(mouse.y - dragStartY));
                }
            }
        }

        onPressed: mouse => {
            dragStartX = mouse.x;
            dragStartY = mouse.y;

            if (selection.visible) {
                const edge = selection.getEdgeAt(mouse.x, mouse.y);
                if (edge !== "") {
                    selection.startResize(edge, mouse.x, mouse.y);
                } else if (selection.contains(mouse.x, mouse.y)) {
                    selection.isMoving = true;
                } else {
                    selection.startSelection(dragStartX, dragStartY);
                }
            } else {
                selection.startSelection(dragStartX, dragStartY);
            }
            window.manager.isDragging = true;
        }

        onReleased: mouse => {
            window.manager.isDragging = false;
            selection.isMoving = false;
            selection.isResizing = false;
        }
    }

    SelectionRectangle {
        id: selection
        window: window
        screenshot: screenshot
    }

    AutoDetectionOverlay {
        active: window.selectionMode !== "selection"
        regions: window.activeOverlayRegions
        hoveredIndex: window.hoveredRegionIndex
        onHoveredIndexChanged: window.hoveredRegionIndex = hoveredIndex

        onRegionClicked: rect => {
            window.startCrop(rect.x, rect.y, rect.width, rect.height, window.getFinalPath());
        }
    }
}
