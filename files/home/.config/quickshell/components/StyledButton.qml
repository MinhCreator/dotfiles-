pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components
import "../lib/ColorUtils.js" as ColorUtils

StyledRectangle {
    id: root

    property string text: ""
    property string iconName: ""
    property int iconSize: 24
    property int spacing: 8
    property color textColor: Theme.colors.white
    property color backgroundColor: Theme.colors.gray4
    property int textPixelSize: Theme.fontPixelSizes.normal

    signal clicked

    implicitWidth: contentRow.implicitWidth + 48
    implicitHeight: 48
    baseRadius: height / 2
    color: mouseArea.containsPress ? ColorUtils.transparentize(root.backgroundColor, 0.40) : mouseArea.containsMouse ? ColorUtils.transparentize(root.backgroundColor, 0.80) : ColorUtils.transparentize(root.backgroundColor, 0.60)
    border.color: Theme.colors.borderFrame
    border.width: 1
    opacity: enabled ? 1 : 0.5

    Behavior on color {
        ColorAnimation {
            duration: Theme.animations.duration.fast
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: root.spacing

        MaterialSymbol {
            visible: root.iconName !== ""
            iconName: root.iconName
            iconSize: root.iconSize
            color: root.textColor
            anchors.verticalCenter: parent.verticalCenter
        }

        StyledText {
            visible: root.text !== ""
            text: root.text
            color: root.textColor
            font.pixelSize: root.textPixelSize
            font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
