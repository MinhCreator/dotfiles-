import QtQuick
import qs

Item {
    id: root

    property string iconName
    property real iconSize: 24
    property color color: Theme.colors.white
    property real fill: 0
    property bool filled: false
    property int weight: 300
    property int grad: 0
    readonly property real truncatedFill: fill.toFixed(1) // Reduce memory consumption spikes from constant font remapping

    onFilledChanged: fill = filled ? 1 : 0

    implicitWidth: iconSize
    implicitHeight: iconSize

    Text {
        anchors.fill: parent
        verticalAlignment: Text.AlignVCenter
        horizontalAlignment: Text.AlignHCenter
        renderType: Text.NativeRendering
        color: root.color
        text: root.iconName ?? ""

        font {
            hintingPreference: Font.PreferNoHinting
            family: Theme.fontFamilies.material
            pixelSize: root.iconSize
            weight: Font.Normal + (Font.DemiBold - Font.Normal) * root.truncatedFill
            variableAxes: {
                "FILL": root.truncatedFill,
                "wght": root.weight,
                "GRAD": root.grad,
                "opsz": root.iconSize
            }
        }
    }

    Behavior on fill { // Leaky leaky, no good
        NumberAnimation {
            duration: Theme.animations.duration.normal
            easing.type: Theme.animations.easing.outCubic
        }
    }
}
