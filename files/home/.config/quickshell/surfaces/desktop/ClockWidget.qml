pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs.components
import qs.services
import qs.lock
import qs

Item {
    id: root

    required property var desktopData
    readonly property color shadowColor: "#FF000000"
    property int textHorizontalAlignment: Text.AlignHCenter

    Binding {
        target: root
        property: "textHorizontalAlignment"
        value: {
            let widgetMid = root.desktopData.x + DesktopService.clockWidgetWidth / 2;
            let screenMid = DesktopService.mainMonitor?.width / 2;
            if (Math.abs(widgetMid - screenMid) <= DesktopService.clockWidgetWidth / 2) {
                return Text.AlignHCenter;
            }
            return widgetMid < screenMid ? Text.AlignLeft : Text.AlignRight;
        }
    }

    implicitWidth: DesktopService.clockWidgetWidth
    implicitHeight: DesktopService.clockWidgetHeight
    opacity: LockService.showUI ? 0 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animations.duration.slowest
            easing.type: Theme.animations.easing.outQuad
        }
    }

    Behavior on textHorizontalAlignment {
        NumberAnimation {
            duration: Theme.animations.duration.normal
            easing.type: Theme.animations.easing.linear
        }
    }

    Behavior on x {
        NumberAnimation {
            duration: Theme.animations.duration.verySlow
            easing.type: Theme.animations.easing.outBack
        }
    }

    Behavior on y {
        NumberAnimation {
            duration: Theme.animations.duration.verySlow
            easing.type: Theme.animations.easing.outBack
        }
    }

    component ClockText: StyledText {
        Layout.fillWidth: true
        horizontalAlignment: root.textHorizontalAlignment
        renderType: Text.NativeRendering
        font.weight: Font.DemiBold
        font.family: Theme.fontFamilies.outfit

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.65
            shadowHorizontalOffset: 2
            shadowVerticalOffset: 2
            shadowColor: root.shadowColor
        }
    }

    ColumnLayout {
        anchors.fill: parent

        ClockText {
            id: timeText
            Layout.fillHeight: true
            text: Qt.formatDateTime(ClockService.systemClock.date, "hh:mm")
            font.pixelSize: Theme.fontPixelSizes.giant - 34
            font.weight: Font.Bold
        }

        ClockText {
            id: dateText
            Layout.topMargin: -16
            Layout.leftMargin: 8
            Layout.rightMargin: 8
            Layout.preferredHeight: 32
            text: Qt.formatDateTime(ClockService.systemClock.date, "ddd, MMM dd")
            font.pixelSize: Theme.fontPixelSizes.large
        }
    }
}
