pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import "../lib/ColorUtils.js" as ColorUtils

Item {
    id: root
    property var entries: []
    property int currentIndex: 0
    property var displayText: entry => String(entry)
    property int gap: 4
    property bool _animationReady: false
    property int animationEnableDelay: 500
    property bool interactive: true
    property bool showBorder: true
    property bool showIndicatorBorder: true
    property int orientation: Qt.Horizontal

    property real slotWidth: orientation === Qt.Horizontal ? width / ((entries && entries.length) || 1) : width
    property real slotHeight: orientation === Qt.Vertical ? height / ((entries && entries.length) || 1) : height

    property color borderColor: Theme.colors.borderFrameDim
    property color indicatorBorderColor: Theme.colors.borderMid
    property color indicatorColor: ColorUtils.transparentize(Theme.colors.white, 0.125)
    property color backgroundColor: ColorUtils.transparentize(Theme.colors.bgOverlay, 0.40)
    property Component delegate: defaultDelegate

    signal clicked

    Component.onCompleted: {
        animationEnableTimer.start();
    }

    Timer {
        id: animationEnableTimer
        interval: root.animationEnableDelay
        repeat: false
        running: false
        triggeredOnStart: false
        onTriggered: root._animationReady = true
    }

    Component {
        id: defaultDelegate
        StyledText {
            property var modelData
            property int index
            anchors.centerIn: parent
            text: (typeof root.displayText === "function") ? root.displayText(modelData) : (root.displayText || "")
            font.weight: Font.DemiBold
            font.family: Theme.fontFamilies.main
            opacity: root.currentIndex === index ? 1 : 0.5
            horizontalAlignment: Text.AlignHCenter
        }
    }

    StyledRectangle {
        anchors.fill: parent
        baseRadius: root.orientation === Qt.Horizontal ? height / 2 : width / 2
        border.width: root.showBorder ? 1 : 0
        border.color: root.borderColor
        color: root.backgroundColor
    }

    StyledRectangle {
        id: indicator
        readonly property int gap: root.gap
        readonly property real slotWidth: root.slotWidth
        readonly property real slotHeight: root.slotHeight
        visible: !!(root.entries && root.entries.length > 0)

        width: root.orientation === Qt.Horizontal ? slotWidth - gap * 2 : parent.width - gap * 2
        height: root.orientation === Qt.Vertical ? slotHeight - gap * 2 : parent.height - gap * 2

        baseRadius: root.orientation === Qt.Horizontal ? height / 2 : width / 2
        color: root.indicatorColor
        border.width: root.showIndicatorBorder ? 1 : 0
        border.color: root.indicatorBorderColor

        x: root.orientation === Qt.Horizontal ? root.currentIndex * slotWidth + gap : gap
        y: root.orientation === Qt.Vertical ? root.currentIndex * slotHeight + gap : gap

        Behavior on x {
            enabled: root._animationReady && root.orientation === Qt.Horizontal
            NumberAnimation {
                duration: Theme.animations.duration.slower
                easing.type: Theme.animations.easing.outExpo
            }
        }

        Behavior on y {
            enabled: root._animationReady && root.orientation === Qt.Vertical
            NumberAnimation {
                duration: Theme.animations.duration.slower
                easing.type: Theme.animations.easing.outExpo
            }
        }
    }

    component SlotLayout: Item {
        // Switches between RowLayout and ColumnLayout via Loader below
    }

    Loader {
        anchors.fill: parent
        sourceComponent: root.orientation === Qt.Vertical ? columnLayout : rowLayout
    }

    Component {
        id: rowLayout
        RowLayout {
            anchors.fill: parent
            spacing: 0
            Repeater {
                model: root.entries
                delegate: slotDelegate
            }
        }
    }

    Component {
        id: columnLayout
        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            Repeater {
                model: root.entries
                delegate: slotDelegate
            }
        }
    }

    Component {
        id: slotDelegate
        Item {
            id: delegateContainer
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: root.gap * 2
            Layout.rightMargin: root.gap * 2
            Loader {
                anchors.fill: parent
                sourceComponent: root.delegate
                onLoaded: {
                    item.modelData = delegateContainer.modelData;
                    item.index = delegateContainer.index;
                }
            }
            MouseArea {
                enabled: root.interactive
                visible: root.interactive
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    mouse.accepted = true;
                    root.currentIndex = delegateContainer.index;
                    root.clicked();
                }
            }
        }
    }
}
