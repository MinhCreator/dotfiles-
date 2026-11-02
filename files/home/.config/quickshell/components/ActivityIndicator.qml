pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs

Item {
    id: root

    property real size: 64
    property bool running: false
    property color color: Theme.colors.white

    property real progress: 0

    // Constants from adw-spinner-paintable.c
    readonly property real _pi: Math.PI
    readonly property int _spinDurationMs: 1200
    readonly property int _nCycles: 53
    readonly property real _startAngle: _pi * 0.35
    readonly property real _circleOpacity: 0.15
    readonly property real _minArcLength: _pi * 0.015
    readonly property real _maxArcLength: _pi * 0.9
    readonly property real _idleDistance: _pi * 0.9
    readonly property real _overlapDistance: _pi * 0.7
    readonly property real _extendDistance: _pi * 1.1
    readonly property real _contractDistance: _pi * 1.35
    readonly property real _cycleLength: _idleDistance + _extendDistance + _contractDistance - _overlapDistance

    // Fixed internal design space (the largest size Adw draws at).
    // Everything is drawn here, then scaled to `size`.
    readonly property real _ref: 64
    readonly property real _refRadius: 32
    readonly property real _refLineWidth: (_refRadius * 2) / 8 // 8
    readonly property real _refCircleRadius: _refRadius - _refLineWidth / 2 // 28

    readonly property real _arcStartRad: _normalizeAngle(progress + _arcStart(progress) + _startAngle)
    readonly property real _arcEndRad: _normalizeAngle(progress + _arcEnd(progress) + _startAngle)

    readonly property real _arcFromDeg: _arcEndRad * 180 / _pi
    readonly property real _arcSweepDeg: {
        let sweep = _arcStartRad - _arcEndRad;
        if (sweep < 0)
            sweep += 2 * _pi;
        return sweep * 180 / _pi;
    }

    visible: running
    width: size
    height: size

    NumberAnimation on progress {
        from: 0
        to: root._nCycles * 2 * Math.PI
        duration: root._spinDurationMs * root._nCycles
        loops: Animation.Infinite
        easing.type: Easing.Linear
        running: root.running
    }

    function _lerp(a, b, t) {
        return a * (1 - t) + b * t;
    }

    function _easeInOutSine(t) {
        return -(Math.cos(Math.PI * t) - 1) / 2;
    }

    function _normalizeAngle(angle) {
        const tau = 2 * Math.PI;
        angle = angle % tau;
        if (angle < 0)
            angle += tau;
        return angle;
    }

    function _arcStart(angle) {
        const l = _cycleLength;
        angle = angle % l;

        let t;
        if (angle > _extendDistance)
            t = 1;
        else
            t = _easeInOutSine(angle / _extendDistance);

        return _lerp(_minArcLength, _maxArcLength, t) - angle * _maxArcLength / l;
    }

    function _arcEnd(angle) {
        const l = _cycleLength;
        angle = angle % l;

        let t;
        if (angle < _extendDistance - _overlapDistance) {
            t = 0;
        } else if (angle > l - _idleDistance) {
            t = 1;
        } else {
            t = (angle - _extendDistance + _overlapDistance) / _contractDistance;
            t = _easeInOutSine(t);
        }

        return _lerp(0, _maxArcLength - _minArcLength, t) - angle * _maxArcLength / l;
    }

    // Everything is rendered at 64x64 into a texture and scaled down with
    // linear filtering. This avoids per-size stroke snapping artifacts.
    Item {
        id: canvas
        width: root._ref
        height: root._ref
        anchors.centerIn: parent
        scale: root.size / root._ref
        transformOrigin: Item.Center

        layer.enabled: true
        layer.smooth: true
        layer.mipmap: true
        layer.textureSize: Qt.size(root._ref * 2, root._ref * 2) // 2x supersample

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            // Track: drawn as two arcs that leave a gap exactly where the
            // moving arc will be, so alpha never stacks.
            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(root.color.r, root.color.g, root.color.b, root.color.a * root._circleOpacity)
                strokeWidth: root._refLineWidth
                capStyle: ShapePath.FlatCap

                PathAngleArc {
                    centerX: root._ref / 2
                    centerY: root._ref / 2
                    radiusX: root._refCircleRadius
                    radiusY: root._refCircleRadius
                    startAngle: root._arcFromDeg + root._arcSweepDeg
                    sweepAngle: 360 - root._arcSweepDeg
                }
            }

            // Moving arc (full alpha, round caps)
            ShapePath {
                fillColor: "transparent"
                strokeColor: root.color
                strokeWidth: root._refLineWidth
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root._ref / 2
                    centerY: root._ref / 2
                    radiusX: root._refCircleRadius
                    radiusY: root._refCircleRadius
                    startAngle: root._arcFromDeg
                    sweepAngle: root._arcSweepDeg
                }
            }
        }
    }
}
