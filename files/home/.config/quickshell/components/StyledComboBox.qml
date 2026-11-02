import QtQuick
import QtQuick.Controls
import qs
import "../lib/ColorUtils.js" as ColorUtils

ComboBox {
    id: root
    indicator: null
    implicitHeight: 42
    implicitWidth: 168
    padding: 0
    spacing: 0

    property real radius: height / 2
    property bool showBorder: true
    property bool showScrollBar: true
    property bool popupAlignRight: false
    property int horizontalTextAlignment: Text.AlignLeft

    property color colorBg: Theme.colors.gray1
    property color colorBgHovered: Theme.colors.bgElevated
    property color colorBgPressed: Theme.colors.bgSurface
    property color colorBgPopup: Theme.colors.gray1
    property color colorHighlitedPopup: Theme.colors.bgOverlay
    property color colorBorderOpen: Theme.colors.borderMid
    property color colorBorderClosed: ColorUtils.transparentize(Theme.colors.borderMid, 0.6)
    property color colorText: Theme.colors.white
    property color colorTextSecondary: Theme.colors.textSecondary
    property color colorArrow: Theme.colors.textPrimary

    property int popupWidth: width

    property string iconMode: "icon" // "icon"
    property int iconSize: 24

    function entryText(entry) {
        return (entry !== null && typeof entry === "object") ? (entry.text ?? "") : (entry ?? "");
    }

    function entryIcon(entry) {
        return (entry !== null && typeof entry === "object") ? (entry.icon ?? "") : "";
    }

    displayText: entryText(currentValue)
    focusPolicy: Qt.NoFocus

    background: StyledRectangle {
        baseRadius: root.radius
        color: ColorUtils.transparentize(root.enabled ? (root.pressed ? root.colorBgPressed : root.hovered ? root.colorBgHovered : root.colorBg) : root.colorBg, 0.5)
        border.color: root.popup.visible ? root.colorBorderOpen : root.colorBorderClosed
        border.width: root.showBorder ? 1 : 0

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
    }

    contentItem: Item {
        implicitHeight: root.implicitHeight
        opacity: root.enabled ? 1 : 0.35

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outCubic
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        Loader {
            id: selectedIconLoader
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            active: root.entryIcon(root.currentValue) !== ""
            sourceComponent: selectedIcon
        }

        Component {
            id: selectedIcon
            MaterialSymbol {
                iconName: root.entryIcon(root.currentValue)
                iconSize: root.iconSize
                color: root.colorText
            }
        }

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: selectedIconLoader.active ? (selectedIconLoader.x + selectedIconLoader.width + 10) : 16
            anchors.right: arrow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayText
            color: root.colorText
            horizontalAlignment: root.horizontalTextAlignment
            font {
                pixelSize: Theme.fontPixelSizes.small
                weight: Font.Medium
            }
        }

        MaterialSymbol {
            id: arrow
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            iconName: "expand_more"
            iconSize: 20
            color: root.colorArrow
            rotation: root.popup.visible ? 180 : 0
            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.animations.duration.standard
                    easing.type: Theme.animations.easing.outCubic
                }
            }
        }
    }

    delegate: ItemDelegate {
        id: delegateItem
        width: root.popup.width - root.popup.leftPadding - root.popup.rightPadding
        height: 48
        highlighted: root.highlightedIndex === index
        padding: 0

        required property var modelData
        required property int index

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

    background: StyledRectangle {
        color: delegateItem.highlighted ? root.colorHighlitedPopup : "transparent"
        baseRadius: root.radius - root.popup.padding
            anchors.fill: parent
            anchors.margins: 2
        }

        contentItem: Item {
            implicitHeight: delegateItem.height

            Loader {
                id: delegateIconLoader
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                active: root.entryIcon(delegateItem.modelData) !== ""
                sourceComponent: delegateIcon
            }

            Component {
                id: delegateIcon
                MaterialSymbol {
                    iconName: root.entryIcon(delegateItem.modelData)
                    iconSize: root.iconSize
                    color: delegateItem.highlighted ? root.colorText : root.colorTextSecondary
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: delegateIconLoader.active ? (delegateIconLoader.x + delegateIconLoader.width + 10) : 16
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                text: root.entryText(delegateItem.modelData)
                color: delegateItem.highlighted ? root.colorText : root.colorTextSecondary
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: root.horizontalTextAlignment
                elide: Text.ElideRight
                font {
                    pixelSize: Theme.fontPixelSizes.small
                    weight: Font.Medium
                }
            }
        }
    }

    popup: Popup {
        y: root.height + 6
        x: root.popupAlignRight ? root.width - width : 0
        width: root.popupWidth
        padding: 4
        clip: true

        enter: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0.0
                to: 1.0
                duration: Theme.animations.duration.standard
                easing.type: Theme.animations.easing.outQuint
            }
        }

        exit: Transition {
            NumberAnimation {
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outCubic
            }
        }

        background: StyledRectangle {
            baseRadius: Theme.rounding.large
            color: root.colorBgPopup
            border.color: root.colorBorderOpen
            border.width: 1
        }

        contentItem: ListView {
            implicitHeight: Math.min(contentHeight, 400)
            model: root.delegateModel
            spacing: 5
            clip: true
            currentIndex: 0
            ScrollIndicator.vertical: ScrollIndicator {
                visible: root.showScrollBar
            }
        }
    }
}
