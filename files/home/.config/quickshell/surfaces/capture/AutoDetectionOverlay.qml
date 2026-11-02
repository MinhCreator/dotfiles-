pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.components
import "../../lib/ColorUtils.js" as ColorUtils
import "../../lib/AppUtils.js" as AppUtils

Item {
    id: root

    property var regions: []
    property int hoveredIndex: -1
    property bool active: true

    signal regionClicked(var rect)

    anchors.fill: parent

    // Mouse interaction areas (low z-index, transparent)
    Repeater {
        model: root.active ? root.regions : []

        MouseArea {
            required property int index
            required property var modelData

            z: 33
            x: modelData.x
            y: modelData.y
            width: modelData.width
            height: modelData.height
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: root.hoveredIndex = index
            onExited: if (root.hoveredIndex === index)
                root.hoveredIndex = -1
            onClicked: {
                root.regionClicked({
                    x: Math.floor(x),
                    y: Math.floor(y),
                    width: Math.ceil(width),
                    height: Math.ceil(height)
                });
            }
        }
    }

    // Visual borders (high z-index, non-interactive)
    Repeater {
        model: root.active ? root.regions : []

        DashedRectangle {
            required property int index
            required property var modelData
            property bool isHovered: root.hoveredIndex === index

            enabled: false
            color: ColorUtils.transparentize(Theme.colors.primary, isHovered ? 0.15 : 0.0)
            borderWidth: 1
            borderColor: isHovered ? Theme.colors.color15 : Theme.colors.gray10
            z: isHovered ? 66 : 33
            x: modelData.x
            y: modelData.y
            implicitWidth: modelData.width
            implicitHeight: modelData.height

            MaterialSymbol {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dimensionsText.top
                iconName: parent.modelData?.icon ?? null
                iconSize: 32
                opacity: dimensionsText.opacity
                visible: parent.modelData.icon !== undefined
            }

            StyledIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: dimensionsText.top
                iconName: AppUtils.getAppIcon(parent.modelData.initialTitle, [...new Set(DesktopEntries.applications.values)], [parent.modelData.class])
                iconSize: 28
                useIconTheme: true
                placeHolder: "applications-system"
                opacity: dimensionsText.opacity
                visible: parent.modelData.title !== undefined && parent.modelData.icon === undefined
            }

            StyledText {
                id: dimensionsText
                anchors.centerIn: parent
                text: parent.modelData.title ?? `${parent.modelData.width} x ${parent.modelData.height}`
                font.pixelSize: Math.min((parent.modelData.width / text.length) * 1.50, Theme.fontPixelSizes.larger)
                font.weight: Font.Medium
                opacity: parent.isHovered ? 1 : 0
                color: Theme.colors.onPrimary
                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.faster
                    }
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animations.duration.faster
                }
            }

            Behavior on borderColor {
                ColorAnimation {
                    duration: Theme.animations.duration.faster
                }
            }
        }
    }
}
