pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components

Item {
    id: root

    property alias title: label.text

    width: parent ? parent.width : 0
    height: 32

    StyledText {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 8
        font.pixelSize: Theme.fontPixelSizes.small
        font.weight: Font.DemiBold
        color: Theme.colors.textSecondary
        opacity: 0.5
    }
}
