import QtQuick
import QtQuick.Shapes
import qs
import qs.components

Item {
    id: root

    property int size: Math.min(height, width)
    property int lineWidth: 0
    property real value: 0
    property color primaryColor: Theme.colors.color7
    property color secondaryColor: Theme.colors.bgElevated
    property color contentColor: Theme.colors.white
    property bool enableAnimation: true
    property int animationDuration: 800
    property var easingType: Easing.OutCubic
    property bool showText: true
    property bool showIcon: false
    property string iconName: ""
    property int iconSize: 20

    implicitWidth: size
    implicitHeight: size

    property real degree: value * 360
    property real centerX: width / 2
    property real centerY: height / 2
    property real arcRadius: size / 2 - lineWidth / 2
    property real startAngle: -90

    Behavior on degree {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingType
        }
    }

    StyledRectangle {
        anchors.fill: parent
        anchors.margins: 0
        baseRadius: root.size / 2
        color: root.secondaryColor
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer
        visible: root.degree > 0

        ShapePath {
            id: primaryPath
            strokeColor: "transparent"
            strokeWidth: 0
            fillColor: root.primaryColor

            startX: root.centerX
            startY: root.centerY

            PathAngleArc {
                moveToStart: false
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle
                sweepAngle: root.degree
            }

            PathLine {
                x: primaryPath.startX
                y: primaryPath.startY
            }
        }
    }

    StyledText {
        visible: root.showText && !root.showIcon
        anchors.centerIn: parent
        text: Math.round(root.value * 100)
        font.pixelSize: root.size * 0.35
        font.weight: Font.Medium
        color: root.contentColor
    }

    MaterialSymbol {
        visible: root.showIcon && !root.showText
        anchors.centerIn: parent
        iconName: parent.iconName
        iconSize: root.iconSize
        color: root.contentColor
    }
}
