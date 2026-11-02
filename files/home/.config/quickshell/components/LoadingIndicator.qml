pragma ComponentBehavior: Bound

import QtQuick
import qs

StyledRectangle {
    id: root

    property real containerWidth: width
    property color indicatorColor: Theme.colors.color12
    property bool isLoading: false

    height: parent.height
    width: containerWidth * 0.20
    color: indicatorColor
    opacity: isLoading ? 1.0 : 0.0
    visible: opacity > 0
    baseRadius: height / 2
    x: -width

    NumberAnimation on x {
        running: root.visible && root.isLoading
        from: -root.width
        to: root.containerWidth
        duration: Theme.animations.duration.veryLong
        loops: Animation.Infinite
        easing.type: Theme.animations.easing.inOutQuad
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.animations.duration.standard
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animations.duration.standard
        }
    }
}
