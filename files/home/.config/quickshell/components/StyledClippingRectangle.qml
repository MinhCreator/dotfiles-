pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs

ClippingRectangle {
    id: root

    // Rounding
    property real baseRadius: 0
    property bool forceRounding: false

    // Shadow
    property bool shadow: false
    property bool forceShadow: false
    property color shadowColor: "#DD000000"
    property real shadowBlur: 1.05
    property real shadowVerticalOffset: 0
    property real shadowHorizontalOffset: 0

    readonly property bool _rounded: GlobalSettings.enableRounding || root.forceRounding
    readonly property bool _shadowActive: root.forceShadow ? true : (root.shadow && GlobalSettings.enableShadow && !GlobalSettings.isPowerSaverEnabled)

    radius: _rounded ? baseRadius : 0

    layer.enabled: _shadowActive
    layer.effect: MultiEffect {
        shadowEnabled: root._shadowActive
        shadowColor: root.shadowColor
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
        shadowHorizontalOffset: root.shadowHorizontalOffset
    }
}
