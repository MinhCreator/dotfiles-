pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string materialSymbol: "colorize"
    property string _currentFormat: "hex"

    signal colorPicked(var colorEntry)

    function pick(format = "hex", delay = 0.2) {
        root._currentFormat = format;
        pickerProcess.exec(["sh", "-c", `sleep ${delay} && hyprpicker --format=${format}`]);
    }

    Process {
        id: pickerProcess
        stdout: StdioCollector {
            onStreamFinished: {
                const rawOutput = text.trim();
                if (!rawOutput)
                    return;

                const extracted = root._extractColor(rawOutput, root._currentFormat);
                if (!extracted)
                    return;
                copyProcess.exec(["wl-copy", extracted]);

                const magickColor = root._getMagickColor(extracted, root._currentFormat);
                const filename = extracted.replace(/[ %#]/g, "_");
                const previewPath = Paths.colorPickerTempDir + "/" + filename + ".png";

                magickProcess.lastExtracted = extracted;
                magickProcess.lastPreviewPath = previewPath;
                magickProcess.exec(["magick", "-size", "64x64", "xc:" + magickColor, previewPath]);

                const hexColor = root._toHex(extracted, root._currentFormat);
                const colorEntry = {
                    color: extracted,
                    hex: hexColor,
                    type: root._currentFormat,
                    timestamp: new Date().getTime()
                };

                const colors = GlobalCache.pickedColors || [];
                colors.push(colorEntry);

                // New reference so pickedColorsChanged fires (reverse() mutates in place).
                GlobalCache.pickedColors = colors.slice().reverse();
                root.colorPicked(colorEntry);
            }
        }
    }

    Process {
        id: copyProcess
    }

    Process {
        id: magickProcess
        property string lastExtracted
        property string lastPreviewPath
        onExited: {
            notifyProcess.exec(["notify-send", "Color Picked ( " + root._currentFormat + " )", lastExtracted, "-i", lastPreviewPath, "-a", "Color Picker", "-t", "7500"]);
        }
    }

    Process {
        id: notifyProcess
    }

    function _extractColor(output, format) {
        if (format === "hex") {
            const match = output.match(/#[0-9A-Fa-f]{6}/);
            return match ? match[0] : null;
        } else if (format === "rgb") {
            const match = output.match(/[0-9]+ [0-9]+ [0-9]+/);
            return match ? match[0].replace(/ /g, ", ") : null;
        }
        return null;
    }

    function _toHex(extracted, format) {
        if (format === "hex")
            return extracted;
        // _extractColor yields "r, g, b" for rgb; raw triplets are not valid QML colors.
        const m = (extracted || "").match(/(\d+),\s*(\d+),\s*(\d+)/);
        if (!m)
            return "";
        const to2 = n => ("0" + Math.max(0, Math.min(255, parseInt(n, 10))).toString(16)).slice(-2);
        return "#" + to2(m[1]) + to2(m[2]) + to2(m[3]);
    }

    function _getMagickColor(color, format) {
        if (format === "hex")
            return color;
        if (format === "rgb")
            return "rgb(" + color + ")";
        return color;
    }
}
