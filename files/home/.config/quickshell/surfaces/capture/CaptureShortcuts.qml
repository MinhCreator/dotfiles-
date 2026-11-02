import QtQuick
import qs

Item {
    id: root

    required property var window
    required property var selection

    Shortcut {
        sequence: "Escape"
        onActivated: GlobalStates.showScreenCapture = false
    }

    Shortcut {
        sequences: ["Return", "Enter"]
        onActivated: {
            if (root.selection.visible && root.selection.width > 0 && root.selection.height > 0) {
                root.selection.captureSelection();
            } else if (root.window.selectionMode === "monitor") {
                const r = root.window.activeOverlayRegions[0];
                root.window.startCrop(r.x, r.y, r.width, r.height, root.window.getFinalPath());
            }
        }
    }

    // Selection Modes
    Shortcut { sequence: "R"; onActivated: root.window.selectionMode = "region" }
    Shortcut { sequence: "S"; onActivated: root.window.selectionMode = "selection" }
    Shortcut { sequence: "M"; onActivated: root.window.selectionMode = "monitor" }
    Shortcut { sequence: "W"; onActivated: root.window.selectionMode = "windows" }

    // Capture Modes
    Shortcut { sequence: "1"; onActivated: root.window.captureMode = "snapshot" }
    Shortcut { sequence: "2"; onActivated: root.window.captureMode = "recording" }
    Shortcut { sequence: "3"; onActivated: root.window.captureMode = "ask google" }
    Shortcut { sequence: "4"; onActivated: root.window.captureMode = "ocr" }
    Shortcut { sequence: "TAB"; onActivated: root.window.nextCaptureMode() }
    Shortcut { sequence: "BACKTAB"; onActivated: root.window.prevCaptureMode() }
}
