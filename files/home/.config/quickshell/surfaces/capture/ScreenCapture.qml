pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../../lib/FileUtils.js" as FileUtils

Scope {
    id: root

    property bool isDragging: false
    property bool saveToTemp: false
    property string customPath: ""
    property string pendingScreenshotPath: ""
    property string pendingCropFinalPath: ""
    property string pendingCropMode: ""

    function startRegionCapture(toTemp: bool, path: string): void {
        saveToTemp = toTemp;
        customPath = path;
        GlobalStates.showScreenCapture = true;
    }

    // Runs in manager scope so the per-monitor SelectionWindows can close
    // instantly on all monitors while slow Lens/OCR work continues.
    function startCrop(screenName: string, screenX: int, screenY: int, tempImagePath: string, captureMode: string, cropX: int, cropY: int, cropW: int, cropH: int, finalPath: string): void {
        if (captureMode === "recording") {
            GlobalData.recordingRegion = {
                x: screenX + cropX,
                y: screenY + cropY,
                width: cropW,
                height: cropH,
                screen: screenName
            };
            Quickshell.execDetached(["sh", "-c", `${Paths.screenRecordScript} start ${screenName} ${cropW}x${cropH}+${cropX}+${cropY} quickshell notif`]);
            GlobalStates.showScreenCapture = false;
            return;
        }

        pendingCropMode = captureMode;
        pendingCropFinalPath = finalPath;
        if (captureMode === "snapshot") {
            cropProcess.command = ["sh", "-c", `magick '${tempImagePath}' -crop ${cropW}x${cropH}+${cropX}+${cropY} +repage '${finalPath}'`];
        } else if (captureMode === "ask google") {
            cropProcess.command = ["sh", "-c", `notify-send -a Screenshot -i google-lens 'Screenshot taken' 'Opening Google Lens...' && magick '${tempImagePath}' -crop ${cropW}x${cropH}+${cropX}+${cropY} +repage /tmp/bnsplit/screenshots/lens && ${Paths.lensScript} /tmp/bnsplit/screenshots/lens`];
            // cropProcess.command = ["sh", "-c", `notify-send -a Screenshot -i google-lens 'Screenshot taken' 'Opening Google Lens...' && magick '${tempImagePath}' -crop ${cropW}x${cropH}+${cropX}+${cropY} +repage /tmp/bnsplit/screenshots/lens && xdg-open "https://lens.google.com/uploadbyurl?url=$(curl -sF 'files[]=@/tmp/bnsplit/screenshots/lens' 'https://uguu.se/upload' | jq -r '.files[0].url')"`];
        } else if (captureMode === "ocr") {
            cropProcess.command = ["sh", "-c", `notify-send -a Screenshot -i text-x-generic 'Screenshot taken' 'Text extracted and copied to clipboard' && magick '${tempImagePath}' -crop ${cropW}x${cropH}+${cropX}+${cropY} +repage /tmp/bnsplit/screenshots/ocr && tesseract /tmp/bnsplit/screenshots/ocr stdout -l $(tesseract --list-langs | awk 'NR>1{print $1}' | tr $'\\n' '+' | sed 's/+$//') | wl-copy`];
        } else {
            pendingCropMode = "";
            pendingCropFinalPath = "";
            GlobalStates.showScreenCapture = false;
            return;
        }
        cropProcess.running = true;
        // Hide overlay on every monitor immediately; result arrives via onExited.
        GlobalStates.showScreenCapture = false;
    }

    function generateFilename(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH'h'mm'm'ss's'") + ".png";
    }

    function sanitizePath(path: string): string {
        if (!path)
            return path;
        let cleaned = path.replace(/^["']|["']$/g, '');
        if (cleaned.startsWith('~/')) {
            cleaned = (Quickshell.env("HOME") || "") + cleaned.substring(1);
        }
        return cleaned;
    }

    function captureMonitor(customPath: string): void {
        const outputPath = customPath || `${Paths.screenshotDir}/${generateFilename()}`;
        pendingScreenshotPath = FileUtils.trimFileProtocol(outputPath);
        monitorCaptureProcess.command = ["grim", "--", pendingScreenshotPath];
        monitorCaptureProcess.running = true;
    }

    function handleScreenshotSuccess(filePath: string): void {
        Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < "${filePath}"`]);
        Quickshell.execDetached(["bash", "-c", `notify-send -i "${filePath}" -a "Screenshot" "Screenshot Taken" "Saved and copied to clipboard" -t 0 -A "open=Open Screenshot" | while read action; do [ "$action" = "open" ] && xdg-open "${filePath}"; done`]);
    }

    Process {
        id: monitorCaptureProcess
        running: false
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.pendingScreenshotPath) {
                root.handleScreenshotSuccess(root.pendingScreenshotPath);
                root.pendingScreenshotPath = "";
            }
        }
    }

    Process {
        id: cropProcess
        running: false
        command: []
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && root.pendingCropMode === "snapshot" && root.pendingCropFinalPath) {
                root.handleScreenshotSuccess(root.pendingCropFinalPath);
            }
            root.pendingCropMode = "";
            root.pendingCropFinalPath = "";
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: windowLoader
            required property ShellScreen modelData
            active: GlobalStates.showScreenCapture && !GlobalCache.loadLockScreen

            component: SelectionWindow {
                screen: windowLoader.modelData
                manager: root
            }
        }
    }

    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: recordingOverlayLoader
            required property ShellScreen modelData
            active: GlobalData.isRecording && GlobalData.recordingRegion !== null

            component: RecordingOverlay {
                screen: recordingOverlayLoader.modelData
            }
        }
    }
}
