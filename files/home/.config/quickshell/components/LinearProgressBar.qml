pragma ComponentBehavior: Bound
import QtQuick
import qs
import "../lib/ColorUtils.js" as ColorUtils

Item {
    id: root
    property real value: 0
    property real radius: -1
    property color fillColor: ColorUtils.transparentize(Theme.colors.color13, 0.65)
    property color backgroundColor: ColorUtils.transparentize(Theme.colors.bgBase, 0.72)
    property color borderColor: Theme.colors.borderFrameMid
    property bool enableAnimation: true
    property bool enableBorder: true
    property bool enableClick: false
    signal clicked(real value)

    readonly property real _radius: root.radius >= 0 ? root.radius : root.height / 2
    readonly property real _clamped: Math.max(0, Math.min(1, root.value))

    implicitHeight: 10
    implicitWidth: 100

    StyledClippingRectangle {
        anchors.fill: parent
        baseRadius: root._radius
        shadow: false
        color: "transparent"
        border.width: 0

        // 1. Background
        StyledRectangle {
            anchors.fill: parent
            color: root.backgroundColor
            baseRadius: root._radius
            z: 1
        }

        // 2. Border
        StyledRectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: root.enableBorder ? 1 : 0
            border.color: root.borderColor
            baseRadius: root._radius + 2
            z: 2
        }

        // 3. Fill
        StyledRectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root._clamped
            color: root.fillColor
            baseTopLeftRadius: root._radius
            baseBottomLeftRadius: root._radius
            baseTopRightRadius: 0
            baseBottomRightRadius: 0
            z: 3

            Behavior on width {
                enabled: root.enableAnimation
                NumberAnimation {
                    duration: Theme.animations.duration.slower
                    easing.type: Theme.animations.easing.outExpo
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enableClick
            cursorShape: root.enableClick ? Qt.PointingHandCursor : Qt.ArrowCursor
            z: 4

            onClicked: mouse => {
                const newValue = Math.max(0, Math.min(1, mouse.x / width));
                root.value = newValue;
                root.clicked(newValue);
            }
        }
    }
}
