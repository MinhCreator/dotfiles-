pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs
import "../lib/ColorUtils.js" as ColorUtils

Item {
    id: root

    property string textLabel: ""
    property string iconName: ""
    property real iconSize: 24
    property real backgroundTransparency: 0.10
    property color backgroundColor: Theme.colors.white
    property color color: Theme.colors.white
    property bool showBackground: true
    property bool showIcon: true
    property bool iconFilled: false
    property bool enableAnimation: true
    property bool alwaysShowBackground: false
    property bool enableBorder: true
    property int radius: height / 2
    property int textWeight: Font.Medium
    property int iconWeight: 300

    property bool holdToRepeat: false
    property int repeatDelay: 100
    property int repeatInitialDelay: 400

    property real inactiveOpacity: 0.35
    property real activeOpacity: 1

    property string iconMode: "icon" // "icon" | "text"

    property alias hovered: hoverHandler.hovered

    signal clicked

    implicitWidth: 32
    implicitHeight: 32
    enabled: true

    StyledRectangle {
        id: bg
        anchors.fill: parent
        baseRadius: root.radius
        color: ColorUtils.transparentize(root.backgroundColor, root.backgroundTransparency)
        visible: (root.alwaysShowBackground || root.showBackground)
        opacity: root.alwaysShowBackground || (root.enabled && hoverHandler.hovered) ? root.activeOpacity : 0
        border.color: ColorUtils.transparentize(root.backgroundColor, root.backgroundTransparency * 1.50)
        border.width: root.enableBorder ? 1 : 0

        Behavior on color {
            enabled: root.enableAnimation
            ColorAnimation {
                duration: Theme.animations.duration.slow
                easing.type: Theme.animations.easing.outQuad
            }
        }

        Behavior on border.color {
            enabled: root.enableAnimation
            ColorAnimation {
                duration: Theme.animations.duration.slow
                easing.type: Theme.animations.easing.outQuad
            }
        }

        Behavior on opacity {
            enabled: root.enableAnimation
            NumberAnimation {
                duration: Theme.animations.duration.slow
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }

    Loader {
        id: iconLoader
        anchors.centerIn: parent
        opacity: root.showIcon ? (root.enabled && hoverHandler.hovered ? root.activeOpacity : root.inactiveOpacity) : 0
        sourceComponent: root.iconMode === "text" ? textDelegate : iconDelegate

        Behavior on opacity {
            enabled: root.enableAnimation
            NumberAnimation {
                duration: Theme.animations.duration.slow
                easing.type: Theme.animations.easing.outQuad
            }
        }
    }

    component IconDelegate: MaterialSymbol {
        iconName: root.iconName
        iconSize: root.iconSize
        filled: root.iconFilled
        color: root.color
        weight: root.iconWeight
        anchors.centerIn: parent
    }

    component TextDelegate: StyledText {
        text: root.textLabel
        color: root.color
        font.pixelSize: root.iconSize
        font.weight: root.textWeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    Component {
        id: iconDelegate
        IconDelegate {}
    }

    Component {
        id: textDelegate
        TextDelegate {}
    }

    HoverHandler {
        id: hoverHandler
        acceptedButtons: Qt.NoButton
        blocking: false
        enabled: root.enabled
    }

    MouseArea {
        enabled: root.enabled
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (!root.holdToRepeat)
            root.clicked()
        onPressed: if (root.holdToRepeat) {
            root.clicked();
            repeatInitialTimer.start();
        }
        onReleased: {
            repeatInitialTimer.stop();
            repeatTimer.stop();
        }
    }

    Timer {
        id: repeatInitialTimer
        interval: root.repeatInitialDelay
        repeat: false
        onTriggered: repeatTimer.start()
    }

    Timer {
        id: repeatTimer
        interval: root.repeatDelay
        repeat: true
        onTriggered: root.clicked()
    }
}
