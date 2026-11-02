pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import qs.services
import "../../lib/ColorUtils.js" as ColorUtils

PanelWindow {
    id: root
    screen: Quickshell.screens.find(s => s.name === GlobalSettings.mainMonitor) ?? Quickshell.screens[0]

    anchors {
        bottom: true
        left: true
        right: true
    }

    implicitHeight: 128
    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    WlrLayershell.namespace: "quickshell:onscreendisplay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}
    color: "transparent"

    property string osdType: OnScreenDisplayService.osdType
    property bool canShow: false
    property bool showPanel: OnScreenDisplayService.visible

    Timer {
        interval: 100
        repeat: false
        running: true
        onTriggered: root.canShow = true
    }

    // Helpers
    function resolveIcon(type: string): string {
        if (type === "brightness")
            return BrightnessService.materialSymbol;
        if (type === "mic")
            return AudioService.materialSymbolSource;
        return AudioService.materialSymbolSink;
    }

    function resolveValue(): string {
        if (osdType === "brightness") {
            const brightness = BrightnessService.getBrightness();
            return Math.round(brightness * 100) + "%";
        }
        if (osdType === "mic") {
            if (AudioService.source?.audio?.muted)
                return "muted";
            return Math.round(Math.min(AudioService.source?.audio?.volume ?? 0, 1.0) * 100) + "%";
        }
        if (AudioService.sink?.audio?.muted)
            return "muted";
        return Math.round(Math.min(AudioService.sink?.audio?.volume ?? 0, 1.5) * 100) + "%";
    }

    function resolveRatio(): real {
        if (osdType === "brightness")
            return BrightnessService.getBrightness();
        if (osdType === "mic")
            return Math.min(AudioService.source?.audio?.volume ?? 0, 1.0);
        return Math.min(AudioService.sink?.audio?.volume ?? 0, 1.5) / 1.5;
    }

    // UI
    Item {
        anchors.fill: parent

        StyledClippingRectangle {
            id: pill
            implicitWidth: 344
            implicitHeight: 58
            shadow: true
            baseRadius: height / 2
            color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase
            border.color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? Theme.colors.borderDim : Theme.colors.borderFrameMid
            border.width: 1
            visible: y < parent.height
            x: (parent.width / 2) - (width / 2)
            y: root.showPanel ? (parent.height / 2) - (height / 2) : parent.height

            Behavior on y {
                NumberAnimation {
                    duration: Theme.animations.duration.slower
                    easing.type: pill.y > pill.parent.height / 2 ? Theme.animations.easing.outBack : Theme.animations.easing.inBack
                }
            }

            // Fill bar
            StyledRectangle {
                readonly property real minWidth: height
                readonly property real maxWidth: parent.width - 8

                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.margins: 4
                width: minWidth + (maxWidth - minWidth) * root.resolveRatio()
                baseRadius: height / 2
                color: ColorUtils.transparentize(Theme.colors.color8, 0.60)

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animations.duration.slower
                        easing.type: Theme.animations.easing.outCirc
                    }
                }
            }

            // Icon stack — one item per OSD type, flip on type change
            Item {
                id: iconSlot
                width: pill.height
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom

                property real flipScale: 1.0
                property string previousType

                Component.onCompleted: previousType = root.osdType

                transform: Scale {
                    origin.x: iconSlot.width / 2
                    origin.y: iconSlot.height / 2
                    xScale: iconSlot.flipScale
                }

                SequentialAnimation {
                    id: flipAnimation
                    NumberAnimation {
                        target: iconSlot
                        property: "flipScale"
                        from: 1
                        to: 0
                        duration: Theme.animations.duration.fast
                        easing.type: Theme.animations.easing.inQuad
                    }
                    ScriptAction {
                        script: iconSlot.previousType = root.osdType
                    }
                    NumberAnimation {
                        target: iconSlot
                        property: "flipScale"
                        from: 0
                        to: 1
                        duration: Theme.animations.duration.fast
                        easing.type: Theme.animations.easing.outQuad
                    }
                }

                Connections {
                    target: root
                    function onOsdTypeChanged() {
                        if (!root.showPanel) {
                            flipAnimation.stop();
                            iconSlot.flipScale = 1.0;
                            iconSlot.previousType = root.osdType;
                        } else {
                            flipAnimation.restart();
                        }
                    }
                }

                Repeater {
                    model: OnScreenDisplayService.osdTypes
                    delegate: MaterialSymbol {
                        required property string modelData
                        required property int index

                        anchors.centerIn: parent
                        visible: iconSlot.previousType === modelData
                        iconName: root.resolveIcon(modelData)
                        iconSize: 28
                        color: Theme.colors.white
                    }
                }
            }

            // Value label — centered over the whole bar
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 12

                text: root.resolveValue()
                font.pixelSize: Theme.fontPixelSizes.normal
                font.weight: Font.DemiBold
                color: root.osdType === "volume" && (AudioService.sink?.audio?.volume ?? 0) > 1.0 ? Theme.colors.error : Theme.colors.textBright

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outExpo
                    }
                }
            }
        }
    }
}
