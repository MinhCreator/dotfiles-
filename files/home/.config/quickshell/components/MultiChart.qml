pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs
import "../lib/ColorUtils.js" as ColorUtils

Item {
    id: root

    property var series: []
    property var seriesNames: []
    property var seriesIcons: []
    property real seriesIconSize: 14
    property bool seriesIconFilled: true
    property bool showDots: false
    property real lineWidth: 2
    property real dotRadius: 3
    property string unit: ""
    property bool autoScale: false
    property real scaleStep: 1024
    property var scaleUnits: []
    property int yLabelCount: 4

    property var colorPalette: [Theme.colors.color7, Theme.colors.color11, Theme.colors.color7, Theme.colors.color14, Theme.colors.color9, Theme.colors.color12,]

    readonly property real legendH: root.seriesNames.length > 0 ? Math.max(Theme.fontPixelSizes.smaller + 12, root.seriesIconSize + 8) : 0
    readonly property real chartH: root.height - root.legendH

    readonly property real yLabelW: {
        if (!root.series || root.series.length === 0)
            return 40;
        const longest = root.fmtVal(root.globalMax).length;
        return longest * (Theme.fontPixelSizes.smaller * 0.6) + 8;
    }

    readonly property real padLeft: root.yLabelW
    readonly property real padRight: 8
    readonly property real padTop: 8
    readonly property real padBot: 8
    readonly property real drawW: root.width - root.padLeft - root.padRight
    readonly property real drawH: root.chartH - root.padTop - root.padBot

    readonly property real globalMin: {
        let min = Infinity;
        for (const s of (root.series ?? []))
            for (const v of s)
                if (v < min)
                    min = v;
        return isFinite(min) ? min : 0;
    }
    readonly property real globalMax: {
        let max = -Infinity;
        for (const s of (root.series ?? []))
            for (const v of s)
                if (v > max)
                    max = v;
        const m = isFinite(max) ? max : 1;
        return m === root.globalMin ? root.globalMin + 1 : m;
    }

    function fmtVal(v) {
        if (root.autoScale && root.scaleUnits.length > 0) {
            let i = 0, val = v;
            while (val >= root.scaleStep && i < root.scaleUnits.length - 1) {
                val /= root.scaleStep;
                i++;
            }
            return val.toFixed(1) + " " + root.scaleUnits[i];
        }
        return v.toFixed(1) + (root.unit ? " " + root.unit : "");
    }

    function px(i, len) {
        return root.padLeft + i * (len > 1 ? root.drawW / (len - 1) : 0);
    }

    function py(v) {
        return root.padTop + root.drawH - (v - root.globalMin) / (root.globalMax - root.globalMin) * root.drawH;
    }

    function buildPoints(s) {
        if (!s || s.length === 0)
            return [];
        return s.map((v, i) => Qt.point(root.px(i, s.length), root.py(v)));
    }

    function buildFillPoints(s) {
        if (!s || s.length === 0)
            return [];
        const pts = s.map((v, i) => Qt.point(root.px(i, s.length), root.py(v)));
        pts.push(Qt.point(root.px(s.length - 1, s.length), root.chartH - root.padBot));
        pts.push(Qt.point(root.px(0, s.length), root.chartH - root.padBot));
        pts.push(pts[0]);
        return pts;
    }

    // --- y axis grid lines + labels ---
    Repeater {
        id: yAxisRepeater
        model: root.yLabelCount + 1

        delegate: Item {
            id: yAxisDelegate
            required property int index

            readonly property real v: root.globalMin + (root.globalMax - root.globalMin) * (yAxisDelegate.index / root.yLabelCount)
            readonly property real yy: root.py(yAxisDelegate.v)

            Shape {
                width: root.width
                height: root.chartH
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: ColorUtils.transparentize(Theme.colors.borderDim, 0.5)
                    strokeWidth: 0.5
                    fillColor: "transparent"
                    dashPattern: [3, 4]
                    startX: root.padLeft
                    startY: yAxisDelegate.yy
                    PathLine {
                        x: root.padLeft + root.drawW
                        y: yAxisDelegate.yy
                    }
                }
            }

            Text {
                x: 0
                y: yAxisDelegate.yy - implicitHeight / 2
                width: root.padLeft - 6
                horizontalAlignment: Text.AlignRight
                text: root.fmtVal(yAxisDelegate.v)
                font.pixelSize: Theme.fontPixelSizes.smaller
                font.family: Theme.fontFamilies.main
                color: Theme.colors.textMuted
            }
        }
    }

    // --- fills + lines ---
    Repeater {
        id: seriesRepeater
        model: root.series ? root.series.length : 0

        delegate: Item {
            id: seriesDelegate
            required property int index

            readonly property var s: root.series[seriesDelegate.index]
            readonly property color col: root.colorPalette[seriesDelegate.index % root.colorPalette.length]

            Shape {
                width: root.width
                height: root.chartH
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: "transparent"
                    strokeWidth: 0
                    fillColor: ColorUtils.transparentize(seriesDelegate.col, 0.12)
                    PathPolyline {
                        path: root.buildFillPoints(seriesDelegate.s)
                    }
                }
            }

            Shape {
                width: root.width
                height: root.chartH
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeColor: seriesDelegate.col
                    strokeWidth: root.lineWidth
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin
                    PathPolyline {
                        path: root.buildPoints(seriesDelegate.s)
                    }
                }
            }

            Repeater {
                id: dotsRepeater
                model: root.showDots ? Math.ceil((seriesDelegate.s?.length ?? 0) / Math.max(1, Math.ceil((seriesDelegate.s?.length ?? 0) / 60))) : 0

                delegate: StyledRectangle {
                    id: dotDelegate
                    required property int index

                    readonly property int stride: Math.max(1, Math.ceil((seriesDelegate.s?.length ?? 0) / 60))
                    readonly property int dataIndex: Math.min(dotDelegate.index * dotDelegate.stride, seriesDelegate.s.length - 1)

                    x: root.px(dotDelegate.dataIndex, seriesDelegate.s.length) - root.dotRadius
                    y: root.py(seriesDelegate.s[dotDelegate.dataIndex]) - root.dotRadius
                    width: root.dotRadius * 2
                    height: root.dotRadius * 2
                    baseRadius: root.dotRadius
                    color: seriesDelegate.col
                }
            }
        }
    }

    // --- legend ---
    Row {
        id: legendRow
        visible: root.seriesNames.length > 0
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        height: root.legendH
        spacing: 14

        Repeater {
            id: legendRepeater
            model: root.seriesNames.length

            delegate: Row {
                id: legendItemRow
                required property int index
                spacing: 5
                anchors.verticalCenter: legendRow.verticalCenter

                readonly property color col: root.colorPalette[legendItemRow.index % root.colorPalette.length]
                readonly property string iconName: legendItemRow.index < root.seriesIcons.length ? (root.seriesIcons[legendItemRow.index] ?? "") : ""

                StyledRectangle {
                    id: legendDot
                    visible: legendItemRow.iconName === ""
                    width: 6
                    height: 6
                    baseRadius: 3
                    color: legendItemRow.col
                    anchors.verticalCenter: legendItemRow.verticalCenter
                }

                MaterialSymbol {
                    visible: legendItemRow.iconName !== ""
                    iconName: legendItemRow.iconName
                    iconSize: root.seriesIconSize
                    filled: root.seriesIconFilled
                    color: legendItemRow.col
                    anchors.verticalCenter: legendItemRow.verticalCenter
                }

                Text {
                    id: legendLabel
                    text: root.seriesNames[legendItemRow.index]
                    font.pixelSize: Theme.fontPixelSizes.smaller
                    font.family: Theme.fontFamilies.main
                    color: Theme.colors.textSecondary
                    anchors.verticalCenter: legendItemRow.verticalCenter
                }
            }
        }
    }
}
