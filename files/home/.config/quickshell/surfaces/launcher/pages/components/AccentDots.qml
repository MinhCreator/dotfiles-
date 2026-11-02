pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import "../../../../lib/ColorUtils.js" as ColorUtils

// Shared wallpaper accent-color dots overlay.
// Anchors itself to the bottom of its parent; parent must be the grid container.
Item {
    id: root

    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    height: 56
    z: 10

    RowLayout {
        anchors.centerIn: parent
        spacing: 8

        Repeater {
            model: 8

            delegate: StyledRectangle {
                id: colorDot
                required property var index
                property int indicatorIndex: index + 1
                property bool focused: indicatorIndex === WallpaperService.currentAccentColorIndex
                property int size: focused ? 56 : 40

                shadow: true
                implicitWidth: size
                implicitHeight: 40
                color: WallpaperService.accentColors[index] ?? "transparent"
                baseRadius: width / 2

                StyledRectangle {
                    anchors.fill: parent
                    border.width: 1
                    border.color: ColorUtils.transparentize(Theme.colors.white, 0.65)
                    baseRadius: parent.radius
                    color: "transparent"
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animations.duration.verySlow
                        easing.type: Theme.animations.easing.outCirc
                    }
                }

                Behavior on size {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outCirc
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: WallpaperService.setColorIndex(colorDot.indicatorIndex)
                }
            }
        }
    }
}
