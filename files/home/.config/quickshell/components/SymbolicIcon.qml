import QtQuick
import Quickshell.Widgets
import Quickshell
import Qt5Compat.GraphicalEffects
import qs

Item {
    id: root
    required property string iconName
    property color color: Theme.colors.white
    property real iconSize: 24
    property bool usePlaceHolder: true
    property bool useColor: true
    property bool useProtocol: false
    implicitWidth: iconSize
    implicitHeight: iconSize
    visible: root.usePlaceHolder ? true : Quickshell.iconPath(root.iconName, true)

    IconImage {
        id: icon
        anchors.fill: parent
        source: root.useProtocol ? root.iconName : Quickshell.iconPath(root.iconName, "image-loading-symbolic")
    }

    ColorOverlay {
        visible: root.useColor
        anchors.fill: icon
        source: icon
        color: root.color
    }
}
