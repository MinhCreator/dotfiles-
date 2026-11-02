pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs
import "../lib/ColorUtils.js" as ColorUtils

Rectangle {
    id: root
    color: "transparent"

    implicitHeight: 36

    property var entries: []
    property int currentIndex: 0

    property bool showIcon: true
    property bool showText: true

    property string iconMode: "icon" // "icon"

    property var iconName: entry => ""
    property var entryText: entry => String(entry)

    property color activeColor: ColorUtils.transparentize(Theme.colors.color16, 0.20)
    property color hoveredColor: ColorUtils.transparentize(Theme.colors.color16, 0.07)
    property color inactiveColor: "transparent"
    property color textColor: Theme.colors.white
    property color iconColor: Theme.colors.white
    property int spacing: 4
    property int iconSize: 22
    property int fontSize: 13

    signal clicked(int index)

    Row {
        anchors.centerIn: parent
        spacing: root.spacing

        Repeater {
            model: root.entries

            delegate: StyledRectangle {
                id: tabItem
                required property var modelData
                required property int index
                property bool hovered: false

                readonly property bool isActive: index === root.currentIndex
                readonly property string resolvedIconName: root.showIcon ? root.iconName(modelData) : ""

                color: isActive ? root.activeColor : hovered ? root.hoveredColor : root.inactiveColor
                border.color: ColorUtils.transparentize(Theme.colors.white, isActive ? 0.25 : hovered ? 0.10 : 0)
                border.width: 1

                height: root.height
                baseRadius: height / 2
                clip: true

                width: {
                    if (!root.showText || !isActive)
                        return height;
                    const iconW = root.showIcon ? iconLoader.width : 0;
                    const gap = root.showIcon ? contentRow.spacing : 0;
                    return contentRow.anchors.leftMargin + iconW + gap + labelText.implicitWidth + 14;
                }

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animations.duration.slow
                        easing.type: Theme.animations.easing.outExpo
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outCubic
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.currentIndex = tabItem.index;
                        root.clicked(tabItem.index);
                    }
                    onContainsMouseChanged: tabItem.hovered = containsMouse
                }

                Row {
                    id: contentRow
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Loader {
                        id: iconLoader
                        visible: root.showIcon
                        anchors.verticalCenter: parent.verticalCenter
                        sourceComponent: root.showIcon ? iconDelegate : null

                        Component {
                            id: iconDelegate
                            MaterialSymbol {
                                iconName: tabItem.resolvedIconName
                                iconSize: root.iconSize
                                color: root.iconColor
                            }
                        }
                    }

                    StyledText {
                        id: labelText
                        visible: root.showText
                        text: root.entryText(tabItem.modelData)
                        color: root.textColor
                        font.pixelSize: root.fontSize
                        font.family: Theme.fontFamilies.main
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: tabItem.isActive ? 1 : 0
                        elide: Text.ElideNone

                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.animations.duration.normal
                                easing.type: Theme.animations.easing.outCubic
                            }
                        }
                    }
                }
            }
        }
    }
}
