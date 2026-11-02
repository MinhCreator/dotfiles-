import QtQuick
import qs
import qs.components

StyledRectangle {
    required property string text
    property int offsetX: 8
    property int offsetY: 8

    visible: text !== ""
    color: Theme.colors.bgSurface
    baseRadius: height / 2
    width: labelText.width + 16
    height: labelText.height + 16
    border.width: 1
    border.color: Theme.colors.gray6
    z: 15

    StyledText {
        id: labelText
        anchors.centerIn: parent
        text: parent.text
        font.pixelSize: Theme.fontPixelSizes.small
        font.weight: Font.Medium
    }
}
