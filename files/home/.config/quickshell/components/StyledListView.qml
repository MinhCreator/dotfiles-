import QtQuick
import QtQuick.Controls
import qs

ListView {
    id: root

    property int animateInDuration: 250
    property int animateOutDuration: 250
    property int displacedDuration: 250
    property int scrollBarWidth: 8
    property bool animationsEnabled: true
    property bool highlightMoveEnabled: true
    property bool showScrollBar: true
    property bool smoothScrollEnabled: true
    property real scrollBuffer: 80

    property string transitionStyle: "slide"

    property int slideDistance: 300
    property string slideDirection: "right"

    property real popupScaleFrom: 0.0
    property real popupOpacityFrom: 0.0

    flickableDirection: Flickable.VerticalFlick
    highlightRangeMode: ListView.ApplyRange
    preferredHighlightBegin: scrollBuffer
    preferredHighlightEnd: height - scrollBuffer
    highlightMoveDuration: highlightMoveEnabled ? 200 : 0
    spacing: 8
    clip: true

    onCurrentIndexChanged: {
        if (currentIndex === 0) {
            contentYAnimation.to = originY;
            contentYAnimation.start();
        }

        if (showScrollBar) {
            scrollTimer.restart();
        }
    }

    function getInitialOffset() {
        switch (slideDirection) {
        case "left":
        case "top":
            return -slideDistance;
        case "bottom":
        case "right":
        default:
            return slideDistance;
        }
    }

    function getSlideProperty() {
        switch (slideDirection) {
        case "top":
        case "bottom":
            return "y";
        case "left":
        case "right":
        default:
            return "x";
        }
    }

    // Add transition
    add: Transition {
        enabled: root.animationsEnabled

        NumberAnimation {
            property: root.getSlideProperty()
            from: root.transitionStyle === "slide" ? root.getInitialOffset() : 0
            to: 0
            duration: root.animateInDuration
            easing.type: Theme.animations.easing.outExpo
        }

        NumberAnimation {
            property: "scale"
            from: root.transitionStyle === "popup" ? root.popupScaleFrom : 1.0
            to: 1.0
            duration: root.transitionStyle === "popup" ? root.animateInDuration : 0
            easing.type: Theme.animations.easing.outBack
        }

        NumberAnimation {
            property: "opacity"
            from: root.transitionStyle === "popup" ? root.popupOpacityFrom : 1.0
            to: 1.0
            duration: root.transitionStyle === "popup" ? root.animateInDuration : 0
            easing.type: Theme.animations.easing.outExpo
        }
    }

    // Remove transition
    remove: Transition {
        enabled: root.animationsEnabled

        NumberAnimation {
            property: root.getSlideProperty()
            from: 0
            to: root.transitionStyle === "slide" ? root.getInitialOffset() : 0
            duration: root.animateOutDuration
            easing.type: Theme.animations.easing.inExpo
        }

        NumberAnimation {
            property: "scale"
            from: 1.0
            to: root.transitionStyle === "popup" ? root.popupScaleFrom : 1.0
            duration: root.transitionStyle === "popup" ? root.animateOutDuration : 0
            easing.type: Theme.animations.easing.inBack
        }

        NumberAnimation {
            property: "opacity"
            from: 1.0
            to: root.transitionStyle === "popup" ? root.popupOpacityFrom : 1.0
            duration: root.transitionStyle === "popup" ? root.animateOutDuration : 0
            easing.type: Theme.animations.easing.inExpo
        }
    }

    // Displaced transition when removed
    removeDisplaced: Transition {
        enabled: root.animationsEnabled
        SequentialAnimation {
            PauseAnimation {
                duration: root.animateOutDuration
            }
            NumberAnimation {
                property: "y"
                duration: root.displacedDuration
                easing.type: Theme.animations.easing.outExpo
            }
        }
    }

    // Scroll bar
    ScrollBar.vertical: ScrollBar {
        id: scrollbar
        visible: root.showScrollBar
        width: root.scrollBarWidth
        active: root.moving || scrollTimer.running
        policy: ScrollBar.AsNeeded

        contentItem: StyledRectangle {
            implicitWidth: scrollbar.interactive ? 6 : 2
            implicitHeight: scrollbar.interactive ? 6 : 2

            baseRadius: width / 2
            color: scrollbar.pressed ? Theme.colors.outline : Theme.colors.white
            opacity: 0.0

            states: State {
                name: "active"
                when: scrollbar.policy === ScrollBar.AlwaysOn || (scrollbar.active && scrollbar.size < 1.0)
                PropertyChanges {
                    target: scrollbar.contentItem
                    opacity: 0.75
                }
            }

            transitions: Transition {
                from: "active"
                SequentialAnimation {
                    PauseAnimation {
                        duration: Theme.animations.duration.verySlow
                    }
                    NumberAnimation {
                        target: scrollbar.contentItem
                        duration: Theme.animations.duration.normal
                        property: "opacity"
                        to: 0.0
                    }
                }
            }
        }
    }

    // Faster mouse wheel scroll
    WheelHandler {
        enabled: root.smoothScrollEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (root.smoothScrollEnabled)
                root.flick(0, event.angleDelta.y * 10);
        }
    }

    NumberAnimation {
        id: contentYAnimation
        target: root
        property: "contentY"
        duration: root.smoothScrollEnabled ? Theme.animations.duration.slower : 0
        easing.type: Theme.animations.easing.outExpo
    }

    Timer {
        id: scrollTimer
        interval: 1000
        repeat: false
    }
}
