pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Item {
    id: root

    property string iconName: ""
    property string text: ""
    property int iconSize: 64
    property int textPixelSize: Theme.fontPixelSizes.large
    property bool shown: false
    property bool useActivityIndicator: false
    property real centerOffset: 0

    readonly property bool active: indicator.opacity > 0 || icon.opacity > 0 || label.opacity > 0
    visible: active

    ColumnLayout {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.centerOffset
        spacing: 12

        ActivityIndicator {
            id: indicator
            Layout.alignment: Qt.AlignHCenter
            visible: root.useActivityIndicator
            size: root.iconSize
            running: visible
            opacity: root.shown ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outCubic
                }
            }
        }

        MaterialSymbol {
            id: icon
            Layout.alignment: Qt.AlignHCenter
            visible: !root.useActivityIndicator
            iconSize: root.iconSize
            iconName: root.iconName
            opacity: root.shown ? 0.5 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outCubic
                }
            }
        }

        StyledText {
            id: label
            Layout.alignment: Qt.AlignHCenter
            text: root.text
            font.pixelSize: root.textPixelSize
            font.weight: Font.Bold
            opacity: root.shown ? 0.5 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                    easing.type: Theme.animations.easing.outCubic
                }
            }
        }
    }
}
