pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components
import "../../../../lib/ColorUtils.js" as ColorUtils

StyledRectangle {
    id: root

    property alias text: content.text

    baseRadius: Theme.rounding.small
    color: ColorUtils.transparentize(Theme.colors.white, 0.10)
    border.width: 1
    border.color: ColorUtils.transparentize(Theme.colors.white, 0.16)

    Flickable {
        anchors.fill: parent
        anchors.margins: 10
        contentWidth: width
        contentHeight: content.implicitHeight
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        clip: true

        StyledText {
            id: content
            width: parent.width
            textFormat: Text.PlainText
            font.pixelSize: Theme.fontPixelSizes.small
            font.family: Theme.fontFamilies.monospace
            horizontalAlignment: Text.AlignLeft
            wrapMode: Text.WordWrap
        }
    }
}
