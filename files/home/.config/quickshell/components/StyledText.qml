import QtQuick
import qs

Text {
    id: root

    renderType: Text.QtRendering
    verticalAlignment: Text.AlignVCenter
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight

    font.hintingPreference: Font.PreferFullHinting
    font.family: Theme.fontFamilies.text ?? "sans-serif"
    font.pixelSize: Theme.fontPixelSizes.small

    color: Theme.colors.textBright
    linkColor: Theme.colors.primary
}
