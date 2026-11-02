pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components
import "../../../../lib/ColorUtils.js" as ColorUtils

Rectangle {
    id: root

    property bool shown: false
    property real maxWidth: 480
    property real contentMargins: 20
    property real contentWidth: -1
    required property real contentHeight
    property real extraHeight: 0
    property int overlayZ: 2

    readonly property real cardWidth: card.width
    default property alias content: inner.data

    signal closed

    anchors.fill: parent
    color: shown ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : "transparent"
    z: overlayZ

    Behavior on color {
        ColorAnimation {
            duration: Theme.animations.duration.normal
        }
    }

    MouseArea {
        anchors.fill: parent
        visible: root.shown
        hoverEnabled: true
        preventStealing: true
        propagateComposedEvents: false
        onClicked: mouse => {
            root.closed();
            mouse.accepted = true;
        }
    }

    StyledRectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 64, root.contentWidth < 0 ? root.maxWidth : root.contentWidth + root.contentMargins * 2)
        height: Math.min(parent.height - 64, root.contentHeight + root.contentMargins * 2 + root.extraHeight)
        color: Theme.colors.bgSurface
        baseRadius: Theme.rounding.verylarge
        border.color: Theme.colors.borderDim
        border.width: 1
        opacity: root.shown ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.fast
            }
        }

        MouseArea {
            enabled: root.shown
            anchors.fill: parent
            visible: root.shown
            onClicked: event => event.accepted = true
        }

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: root.contentMargins
        }
    }
}
