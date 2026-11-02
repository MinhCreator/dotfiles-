pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "./lib/ColorUtils.js" as ColorUtils

Singleton {
    id: root
    property var _colors: {
        try {
            return JSON.parse(colorjson.text());
        } catch (e) {
            return {};
        }
    }

    FileView {
        id: colorjson
        path: Paths.colorsJsonFile
        watchChanges: true
        blockLoading: true
        onFileChanged: this.reload()
    }

    readonly property var colors: ({
            source: _colors.source,
            color1: _colors.color1,
            color2: _colors.color2,
            color3: _colors.color3,
            color4: _colors.color4,
            color5: _colors.color5,
            color6: _colors.color6,
            color7: _colors.color7,
            color8: _colors.color8,
            color9: _colors.color9,
            color10: _colors.color10,
            color11: _colors.color11,
            color12: _colors.color12,
            color13: _colors.color13,
            color14: _colors.color14,
            color15: _colors.color15,
            color16: _colors.color16,
            primary: _colors.color6,
            onPrimary: _colors.color16,
            bgBase: _colors.bgBase,
            bgSurface: _colors.bgSurface,
            bgElevated: _colors.bgElevated,
            bgOverlay: _colors.bgOverlay,
            borderDim: _colors.borderDim,
            borderMid: _colors.borderMid,
            borderFrame: ColorUtils.transparentize(_colors.white, 0.175),
            borderFrameMid: ColorUtils.transparentize(_colors.borderMid, 0.72),
            borderFrameDim: ColorUtils.transparentize(_colors.borderDim, 0.72),
            textMuted: ColorUtils.transparentize(_colors.textBright, 0.33),
            textSecondary: ColorUtils.transparentize(_colors.textBright, 0.53),
            textPrimary: ColorUtils.transparentize(_colors.textBright, 0.78),
            textBright: _colors.textBright,
            success: _colors.success,
            info: _colors.info,
            warning: _colors.warning,
            error: _colors.error,
            white: _colors.white,
            black: _colors.black,
            gray1: _colors.gray1,
            gray2: _colors.gray2,
            gray3: _colors.gray3,
            gray4: _colors.gray4,
            gray5: _colors.gray5,
            gray6: _colors.gray6,
            gray7: _colors.gray7,
            gray8: _colors.gray8,
            gray9: _colors.gray9,
            gray10: _colors.gray10,
            gray11: _colors.gray11,
            gray12: _colors.gray12,
            gray13: _colors.gray13,
            gray14: _colors.gray14,
            gray15: _colors.gray15,
            gray16: _colors.gray16
        })

    readonly property var fontFamilies: ({
            main: "Google Sans Flex",
            text: "Roboto",
            outfit: "Outfit",
            monospace: "JetBrainsMono NF",
            runde: "Open Runde",
            emoji: "Noto Color Emoji",
            material: "Material Symbols Sharp"
        })

    readonly property var fontPixelSizes: ({
            smallest: 10,
            smaller: 12,
            small: 14,
            normal: 16,
            datetime: 17,
            large: 18,
            larger: 20,
            huge: 22,
            hugeass: 24,
            giant: 128
        })

    readonly property var rounding: ({
            unsharpen: 4,
            unsharpenmore: 6,
            verysmall: 8,
            small: 10,
            normal: 12,
            large: 24,
            launcher: 32,
            verylarge: 32
        })

    readonly property var sizes: ({
            barHeight: 40,
            barModuleBaseHeight: 36,
            notificationPopupWidth: 460,
            notificationPopupHeight: 110
        })

    readonly property var animations: ({
            duration: ({
                    instant: 0,
                    fastest: 50,
                    faster: 100,
                    fast: 150,
                    normal: 200,
                    standard: 250,
                    slow: 300,
                    slower: 350,
                    slowest: 400,
                    verySlow: 500,
                    long: 750,
                    veryLong: 1000,
                    extraLong: 1200
                }),
            easing: ({
                    // x1
                    linear: Easing.Linear,
                    // x2
                    inQuad: Easing.InQuad,
                    outQuad: Easing.OutQuad,
                    inOutQuad: Easing.InOutQuad,
                    // x3
                    inCubic: Easing.InCubic,
                    outCubic: Easing.OutCubic,
                    inOutCubic: Easing.InOutCubic,
                    // x4
                    inQuart: Easing.InQuart,
                    outQuart: Easing.OutQuart,
                    inOutQuart: Easing.InOutQuart,
                    // x5
                    inQuint: Easing.InQuint,
                    outQuint: Easing.OutQuint,
                    inOutQuint: Easing.InOutQuint,
                    // circ
                    inCirc: Easing.InCirc,
                    outCirc: Easing.OutCirc,
                    inOutCirc: Easing.InOutCirc,
                    // expo
                    inExpo: Easing.InExpo,
                    outExpo: Easing.OutExpo,
                    inOutExpo: Easing.InOutExpo,
                    // back
                    inBack: Easing.InBack,
                    outBack: Easing.OutBack,
                    inOutBack: Easing.InOutBack
                })
        })
}
