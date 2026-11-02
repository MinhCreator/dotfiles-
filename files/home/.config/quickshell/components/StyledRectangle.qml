pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import qs

Rectangle {
    id: root

    // Rounding
    property real baseRadius: 0
    property bool forceRounding: false
    property real baseTopLeftRadius: -1
    property real baseTopRightRadius: -1
    property real baseBottomLeftRadius: -1
    property real baseBottomRightRadius: -1

    // Shadow
    property bool shadow: false
    property bool forceShadow: false
    property real shadowBlur: 1.05
    property real shadowVerticalOffset: 0
    property real shadowHorizontalOffset: 0
    property color shadowColor: "#DD000000"

    readonly property bool _rounded: GlobalSettings.enableRounding || root.forceRounding
    readonly property bool _shadowActive: root.forceShadow ? true : (root.shadow && GlobalSettings.enableShadow && !GlobalSettings.isPowerSaverEnabled)

    radius: _rounded ? baseRadius : 0
    topLeftRadius: _rounded ? (baseTopLeftRadius >= 0 ? baseTopLeftRadius : baseRadius) : 0
    topRightRadius: _rounded ? (baseTopRightRadius >= 0 ? baseTopRightRadius : baseRadius) : 0
    bottomLeftRadius: _rounded ? (baseBottomLeftRadius >= 0 ? baseBottomLeftRadius : baseRadius) : 0
    bottomRightRadius: _rounded ? (baseBottomRightRadius >= 0 ? baseBottomRightRadius : baseRadius) : 0

    layer.enabled: _shadowActive
    layer.effect: MultiEffect {
        shadowEnabled: root._shadowActive
        shadowColor: root.shadowColor
        shadowBlur: root.shadowBlur
        shadowVerticalOffset: root.shadowVerticalOffset
        shadowHorizontalOffset: root.shadowHorizontalOffset
    }
}
