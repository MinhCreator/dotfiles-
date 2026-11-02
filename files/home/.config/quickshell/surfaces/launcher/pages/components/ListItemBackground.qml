pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components
import "../../../../lib/ColorUtils.js" as ColorUtils

StyledRectangle {
    id: root
    property bool selected: false
    color: selected ? ColorUtils.transparentize(Theme.colors.white, 0.10) : "transparent"
    border.width: selected ? 1 : 0
    border.color: ColorUtils.transparentize(Theme.colors.white, 0.16)
    baseRadius: Theme.rounding.small
    height: 48
}
