import QtQuick
import qs.components
import qs
import "../lib/ColorUtils.js" as ColorUtils

StyledRectangle {
    id: root

    property alias text: label.text
    property alias duration: timer.duration

    opacity: 0
    scale: opacity === 0 ? 0.9 : 1.0
    color: ColorUtils.transparentize(Theme.colors.bgSurface, 0.65)
    baseRadius: height / 2
    border.color: ColorUtils.transparentize(Theme.colors.borderMid, 0.5)
    border.width: 1
    visible: opacity !== 0

    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 8

    function show() {
        anim.restart();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animations.duration.fast
            easing.type: Theme.animations.easing.outCubic
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.animations.duration.fast
            easing.type: Theme.animations.easing.outBack
        }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        text: "Copied!"
        font.pixelSize: Theme.fontPixelSizes.smaller
        font.weight: Font.Medium
        color: Theme.colors.textSecondary
    }

    SequentialAnimation {
        id: anim
        ScriptAction {
            script: root.opacity = 1
        }
        PauseAnimation {
            id: timer
            duration: Theme.animations.duration.extraLong
        }
        ScriptAction {
            script: root.opacity = 0
        }
    }
}
