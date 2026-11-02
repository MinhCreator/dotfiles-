import QtQuick
import QtQuick.Controls
import qs
import "../lib/ColorUtils.js" as ColorUtils

Switch {
    id: root
    activeFocusOnTab: false
    focusPolicy: Qt.NoFocus
    implicitWidth: height * 2
    implicitHeight: 24

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    indicator: StyledRectangle {
        id: indicator
        anchors.fill: parent
        baseRadius: height / 2

        color: ColorUtils.transparentize(root.checked ? Theme.colors.color8 : Theme.colors.bgOverlay, root.enabled ? 0.65 : 0.35)
        border.color: ColorUtils.transparentize(root.checked ? Theme.colors.color8 : Theme.colors.borderMid, root.enabled ? 1 : 0.55)
        border.width: 1

        StyledRectangle {
            id: thumb
            y: (indicator.height - height) / 2
            width: indicator.width * 0.545
            height: indicator.height - 6
            baseRadius: height / 2

            forceShadow: true
            shadowColor: "#A0000000"
            shadowVerticalOffset: 2
            shadowHorizontalOffset: 1
            shadowBlur: 0.0

            color: root.enabled ? (root.checked ? Theme.colors.color16 : Theme.colors.textPrimary) : Theme.colors.textSecondary

            Behavior on x {
                enabled: !root.down
                NumberAnimation {
                    duration: Theme.animations.duration.slower
                    easing.type: Theme.animations.easing.outExpo
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outQuad
                }
            }
        }

        states: [
            State {
                name: "checked"
                when: root.checked
                PropertyChanges {
                    target: thumb
                    x: indicator.width - thumb.width - 3
                }
            },
            State {
                name: "unchecked"
                when: !root.checked
                PropertyChanges {
                    target: thumb
                    x: 3
                }
            }
        ]

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outQuad
            }
        }
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }
}
