import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root

    property int size: 30
    property int lineWidth: 2
    property real value: 0
    property color primaryColor: Theme.colors.primary
    property color secondaryColor: Theme.colors.borderMid
    property real gapAngle: 360 / 18
    property int animationDuration: 1000
    property var easingType: Easing.OutExpo
    property bool enableAnimation: true

    width: size
    height: size

    signal animationFinished

    property real degree: value * 360
    property real centerX: width / 2
    property real centerY: height / 2
    property real arcRadius: Math.min(width, height) / 2 - lineWidth
    property real startAngle: -90

    Behavior on degree {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: root.animationDuration
            easing.type: root.easingType
        }
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.secondaryColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle + root.degree + root.gapAngle
                sweepAngle: -(root.degree + root.gapAngle * 2) > -360 ? 360 - root.degree - root.gapAngle * 2 : 0
            }
        }

        ShapePath {
            strokeColor: root.primaryColor
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"
            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle
                sweepAngle: Math.max(root.degree, 0.01)
            }
        }
    }
}
