import QtQuick
import QtQuick.Controls
import QtQuick.Controls.impl
import qs
import "../lib/ColorUtils.js" as ColorUtils

CheckBox {
    id: root
    property real size: 24
    property color bgColor: checkState === Qt.Checked ? Theme.colors.white : ColorUtils.transparentize(Theme.colors.bgBase, 0.40)
    property color fgColor: Theme.colors.bgSurface
    property real bgRadius: Theme.rounding.small
    property color borderColor: Theme.colors.borderMid
    property color textColor: Theme.colors.white
    property real borderWidth: 1

    padding: 0
    spacing: 0
    indicator: StyledRectangle {
        implicitWidth: root.size
        implicitHeight: root.size
        x: root.text ? (root.mirrored ? root.width - width - root.rightPadding : root.leftPadding) : root.leftPadding + (root.availableWidth - width) / 2
        y: root.topPadding + (root.availableHeight - height) / 2
        color: root.bgColor
        opacity: root.enabled ? 1 : 0.5
        baseRadius: root.bgRadius
        border.color: root.borderColor
        border.width: root.borderWidth

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.faster
            }
        }

        // Checkmark for checked state
        Canvas {
            anchors.fill: parent
            visible: root.checkState === Qt.Checked
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.strokeStyle = root.fgColor;
                ctx.lineWidth = 3;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";

                var w = width;
                var h = height;
                ctx.beginPath();
                ctx.moveTo(w * 0.25, h * 0.5);
                ctx.lineTo(w * 0.45, h * 0.7);
                ctx.lineTo(w * 0.75, h * 0.3);
                ctx.stroke();
            }
        }

        // Dash/minus for partially checked state
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.5
            height: 2
            color: root.fgColor
            visible: root.checkState === Qt.PartiallyChecked
        }
    }

    contentItem: CheckLabel {
        leftPadding: root.indicator && !root.mirrored ? root.indicator.width + root.spacing : 0
        rightPadding: root.indicator && root.mirrored ? root.indicator.width + root.spacing : 0
        text: root.text
        color: root.textColor
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.NoButton // don’t block interaction
    }
}
