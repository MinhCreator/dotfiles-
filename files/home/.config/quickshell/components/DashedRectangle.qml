import QtQuick
import qs

Item {
    id: root

    property color color: "transparent"
    property real borderWidth: 1
    property color borderColor: Theme.colors.color16
    property var dashPattern: [8, 8]

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.borderWidth
        color: root.color
    }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            ctx.strokeStyle = root.borderColor;
            ctx.lineWidth = root.borderWidth;
            ctx.setLineDash(root.dashPattern);
            var inset = root.borderWidth / 2;
            ctx.strokeRect(inset, inset, width - root.borderWidth, height - root.borderWidth);
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
    }

    onColorChanged: canvas.requestPaint()
    onBorderWidthChanged: canvas.requestPaint()
    onBorderColorChanged: canvas.requestPaint()
    onDashPatternChanged: canvas.requestPaint()

    Behavior on borderColor {
        ColorAnimation {
            duration: Theme.animations.duration.faster
        }
    }
    Behavior on color {
        ColorAnimation {
            duration: Theme.animations.duration.faster
        }
    }
}
