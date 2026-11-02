import QtQuick
import qs
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils

StyledClippingRectangle {
    id: root

    shadow: true
    property string name: "_barModule_"
    property int baseWidth: Theme.sizes.barModuleBaseHeight
    property int expandedWidth: 500
    property int expandedHeight: 500
    property bool isHovered: false
    property bool enableClickToExpand: true
    property bool enableAnimation: true
    property bool isExpanded: false
    required property bool compactBar

    property string hotAlign: "center"

    readonly property real collapsedHotX: root.hotAlign === "left" ? root.x : root.hotAlign === "right" ? root.x + root.implicitWidth - root.baseWidth : root.x + (root.implicitWidth - root.baseWidth) / 2
    readonly property real collapsedHotRight: root.collapsedHotX + root.baseWidth

    readonly property bool wantsExpanded: GlobalStates.expandedBarModule === root.name && !GlobalCache.loadLockScreen
    readonly property bool isAnimating: expandSequence.running || collapseSequence.running
    readonly property bool isCompactResting: compactBar && !collapseSequence.running && animY === 0

    property Component initialContent: null
    property Component expandedContent: null

    property real animY: 0
    property real animHeight: Theme.sizes.barModuleBaseHeight
    property real animWidth: baseWidth

    function dur(base) {
        return root.enableAnimation ? base : 0;
    }

    Behavior on animHeight {
        enabled: root.enableAnimation && (root.isExpanded && !expandSequence.running && !collapseSequence.running)
        NumberAnimation {
            duration: Theme.animations.duration.slower
            easing.type: Theme.animations.easing.outBack
        }
    }

    Behavior on animWidth {
        enabled: root.enableAnimation && (root.isExpanded && !expandSequence.running && !collapseSequence.running)
        NumberAnimation {
            duration: Theme.animations.duration.slower
            easing.type: Theme.animations.easing.outBack
        }
    }

    onExpandedHeightChanged: {
        if (root.isExpanded && !expandSequence.running && !collapseSequence.running) {
            animHeight = expandedHeight;
        }
    }

    onExpandedWidthChanged: {
        if (root.isExpanded && !expandSequence.running && !collapseSequence.running) {
            animWidth = expandedWidth;
        }
    }

    signal rightButtonClicked

    baseRadius: (Theme.sizes.barModuleBaseHeight / 2) + 16

    color: isCompactResting ? "transparent" : (GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase)
    border.color: isCompactResting ? "transparent" : Theme.colors.borderFrame
    border.width: 1
    clip: true

    Behavior on color {
        enabled: root.enableAnimation && collapseSequence.running
        ColorAnimation {
            duration: Theme.animations.duration.verySlow
            easing.type: Theme.animations.easing.outCirc
        }
    }

    Behavior on border.color {
        enabled: root.enableAnimation && collapseSequence.running
        ColorAnimation {
            duration: Theme.animations.duration.slow
            easing.type: Theme.animations.easing.linear
        }
    }

    y: animY
    implicitHeight: animHeight
    implicitWidth: animWidth

    onWantsExpandedChanged: applyExpandedStateIfIdle()

    Component.onCompleted: {
        isExpanded = wantsExpanded;
    }

    function applyExpandedStateIfIdle() {
        if (isAnimating)
            return;
        if (isExpanded !== wantsExpanded)
            isExpanded = wantsExpanded;
    }

    onIsExpandedChanged: {
        loaderOpacitySequence.stop();
        loaderOpacitySequence.start();

        if (isExpanded) {
            expandSequence.start();
        } else {
            collapseSequence.start();
        }
    }

    Behavior on baseWidth {
        enabled: root.enableAnimation
        NumberAnimation {
            duration: Theme.animations.duration.slower
            easing.type: Theme.animations.easing.outBack
        }
    }

    SequentialAnimation {
        id: loaderOpacitySequence

        NumberAnimation {
            target: loader
            property: "opacity"
            to: 0
            duration: root.dur(Theme.animations.duration.faster)
            easing.type: Theme.animations.easing.outExpo
        }

        ScriptAction {
            script: {
                loader.sourceComponent = root.isExpanded ? root.expandedContent : root.initialContent;
            }
        }

        PauseAnimation {
            duration: root.dur(Theme.animations.duration.slower)
        }

        NumberAnimation {
            target: loader
            property: "opacity"
            to: 1
            duration: root.dur(Theme.animations.duration.normal)
            easing.type: Theme.animations.easing.outExpo
        }
    }

    SequentialAnimation {
        id: expandSequence

        NumberAnimation {
            target: root
            property: "animY"
            to: Theme.sizes.barHeight + 12
            duration: root.dur(Theme.animations.duration.normal)
            easing.type: Theme.animations.easing.outBack
        }

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "animHeight"
                to: root.expandedHeight
                duration: root.dur(Theme.animations.duration.slower)
                easing.type: Theme.animations.easing.outBack
            }
            NumberAnimation {
                target: root
                property: "animWidth"
                to: root.expandedWidth
                duration: root.dur(Theme.animations.duration.slower)
                easing.type: Theme.animations.easing.outBack
            }
        }

        ScriptAction {
            script: {
                if (animHeight !== expandedHeight)
                    animHeight = expandedHeight;
                if (animWidth !== expandedWidth)
                    animWidth = expandedWidth;
            }
        }

        onFinished: root.applyExpandedStateIfIdle()
    }

    SequentialAnimation {
        id: collapseSequence

        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "animHeight"
                to: Theme.sizes.barModuleBaseHeight
                duration: root.dur(Theme.animations.duration.standard)
                easing.type: Theme.animations.easing.outExpo
            }
            NumberAnimation {
                target: root
                property: "animWidth"
                to: root.baseWidth
                duration: root.dur(Theme.animations.duration.standard)
                easing.type: Theme.animations.easing.outExpo
            }
        }

        NumberAnimation {
            target: root
            property: "animY"
            to: 0
            duration: root.dur(Theme.animations.duration.slower)
            easing.type: Theme.animations.easing.outBack
        }

        onFinished: root.applyExpandedStateIfIdle()
    }

    Item {
        anchors.fill: parent

        Loader {
            id: loader
            anchors.fill: parent
            active: true
            focus: true
            sourceComponent: root.initialContent
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.enableClickToExpand
            hoverEnabled: enabled
            cursorShape: !root.enableClickToExpand || root.isExpanded || root.animY > 0 ? undefined : Qt.PointingHandCursor
            onEntered: root.isHovered = true
            onExited: root.isHovered = false
            acceptedButtons: Qt.LeftButton | Qt.RightButton

            onClicked: mouse => {
                if (!root.enableClickToExpand) {
                    mouse.accepted = true;
                    return;
                }

                switch (mouse.button) {
                case Qt.LeftButton:
                    if (!root.isExpanded)
                        GlobalStates.expandedBarModule = root.name;
                    else
                        GlobalStates.expandedBarModule = "";

                    break;
                case Qt.RightButton:
                    root.rightButtonClicked();
                    break;
                }
                mouse.accepted = true;
            }
        }
    }
}
