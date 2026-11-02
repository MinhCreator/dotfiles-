import QtQuick
import QtQuick.Controls
import qs
import qs.components
import "../lib/ColorUtils.js" as ColorUtils

Slider {
    id: root

    property int handlePadding: 8
    property color leftColor: ColorUtils.transparentize(Theme.colors.color6, 0.80)
    property color rightColor: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.20)
    property color iconColor: Theme.colors.white
    property string iconName
    property real sliderHeight: height
    property real handleHeight: sliderHeight * 1.25
    property int iconSize: sliderHeight * 0.65
    property bool showIcon: true
    property real radiusBig: height / 2
    property real radiusSmall: Theme.rounding.unsharpen
    property bool leftBorder: true
    property bool rightBorder: true
    property color leftBorderColor: Theme.colors.borderFrame
    property color rightBorderColor: Theme.colors.borderFrame
    property color handleColor: Theme.colors.white
    property bool rotateIcon: false
    property bool isLoaded: false
    property bool animationEnabled: true

    property bool showValue: false
    property string valueText: ""
    property real valueTextWidth: 40

    from: 0
    to: 1
    value: 0.5
    wheelEnabled: false
    activeFocusOnTab: false
    focusPolicy: Qt.NoFocus
    implicitHeight: 32

    rightPadding: showValue ? valueTextWidth : 0

    Component.onCompleted: loadDelayTimer.start()

    StyledText {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: root.showValue
        text: root.valueText
        width: root.valueTextWidth
        horizontalAlignment: Text.AlignRight
        font.pixelSize: Theme.fontPixelSizes.small
        opacity: 0.5
    }

    Timer {
        id: loadDelayTimer
        interval: 100
        running: false
        repeat: false
        onTriggered: root.isLoaded = true
    }

    MouseArea {
        anchors.fill: parent
        onPressed: mouse => mouse.accepted = false
        cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
    }

    background: Item {
        id: background
        x: root.leftPadding
        y: root.topPadding + root.availableHeight / 2 - height / 2
        width: root.availableWidth
        height: root.sliderHeight

        MaterialSymbol {
            z: 10
            visible: root.showIcon
            iconSize: root.iconSize
            iconName: root.iconName
            anchors.verticalCenter: parent.verticalCenter
            x: {
                const iconPosition = leftBar.width - iconSize - anchors.margins;
                const minPosition = parent.width - rightBar.width + anchors.margins;
                return leftBar.width < (iconSize + anchors.margins * 1.2) ? minPosition : iconPosition;
            }

            rotation: {
                if (root.rotateIcon) {
                    return root.value * 360;
                } else {
                    return 0;
                }
            }
            anchors.margins: 10
            color: root.iconColor

            Behavior on rotation {
                enabled: root.isLoaded && root.animationEnabled
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outQuad
                }
            }
        }

        StyledRectangle {
            id: leftBar
            anchors.left: parent.left
            width: (root.visualPosition * parent.width) - root.handlePadding
            height: root.sliderHeight
            color: root.leftColor
            baseTopRightRadius: root.radiusSmall
            baseBottomRightRadius: root.radiusSmall
            baseTopLeftRadius: root.radiusBig
            baseBottomLeftRadius: root.radiusBig
            anchors.verticalCenter: parent.verticalCenter
            border.width: root.leftBorder ? 1 : 0
            border.color: root.leftBorderColor

            Behavior on width {
                enabled: root.isLoaded && root.animationEnabled
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outQuad
                }
            }
        }

        StyledRectangle {
            id: rightBar
            anchors.right: parent.right
            width: ((1 - root.visualPosition) * parent.width) - root.handlePadding
            height: root.sliderHeight
            color: root.rightColor
            baseTopRightRadius: root.radiusBig
            baseBottomRightRadius: root.radiusBig
            baseTopLeftRadius: root.radiusSmall
            baseBottomLeftRadius: root.radiusSmall
            anchors.verticalCenter: parent.verticalCenter
            border.width: root.rightBorder ? 1 : 0
            border.color: root.rightBorderColor

            Behavior on width {
                enabled: root.isLoaded && root.animationEnabled
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outQuad
                }
            }
        }
    }

    handle: StyledRectangle {
        x: root.leftPadding + (root.visualPosition * root.availableWidth) - (width / 2)
        y: root.topPadding + root.availableHeight / 2 - height / 2
        implicitWidth: root.pressed ? 1 : 2
        implicitHeight: root.handleHeight
        baseRadius: width / 2
        color: root.handleColor

        MouseArea {
            anchors.fill: parent
            onPressed: mouse => mouse.accepted = false
            cursorShape: root.pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }

        Behavior on x {
            enabled: root.isLoaded && root.animationEnabled
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }

    Behavior on leftColor {
        ColorAnimation {
            duration: Theme.animations.duration.fast
        }
    }
}
