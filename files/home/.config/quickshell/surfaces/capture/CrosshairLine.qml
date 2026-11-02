import QtQuick
import qs

Canvas {
    required property bool isVertical
    required property bool isActive
    property bool fadeVisible: true

    width: isVertical ? 1 : parent.width
    height: isVertical ? parent.height : 1
    opacity: (isActive && fadeVisible) ? 1.0 : 0.0
    visible: isActive
    z: 10

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onVisibleChanged: if (visible)
        requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        ctx.strokeStyle = Theme.colors.gray11;
        ctx.lineWidth = 1;
        ctx.setLineDash([8, 8]);
        ctx.beginPath();
        if (isVertical) {
            ctx.moveTo(0.5, 0);
            ctx.lineTo(0.5, height);
        } else {
            ctx.moveTo(0, 0.5);
            ctx.lineTo(width, 0.5);
        }
        ctx.stroke();
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animations.duration.verySlow
            easing.type: Theme.animations.easing.outExpo
        }
    }
}
