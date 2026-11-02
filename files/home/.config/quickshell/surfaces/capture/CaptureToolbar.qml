pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import "../../lib/ColorUtils.js" as ColorUtils

StyledRectangle {
    id: root

    property string captureMode: "snapshot"
    property string selectionMode: "selection"
    property bool isInteractionActive: false // replaces (manager.isDragging || selection.isMoving || selection.isResizing)
    property bool isWindowVisible: false
    readonly property bool isPopupVisible: selectionModeCombo.popup.visible

    signal closed
    signal popupClosed

    z: 99
    anchors.top: parent.top
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.topMargin: isWindowVisible ? (Theme.sizes.barHeight + 12) : -height
    implicitWidth: 420
    implicitHeight: 56
    opacity: isInteractionActive ? 0 : 1
    color: Theme.colors.bgBase
    baseRadius: height / 2
    border.color: Theme.colors.borderFrameDim
    border.width: 1
    shadow: true

    Behavior on anchors.topMargin {
        NumberAnimation {
            duration: Theme.animations.duration.slower
            easing.type: Theme.animations.easing.outExpo
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.animations.duration.normal
        }
    }

    RowLayout {
        id: actionButtonGroupRow
        anchors.fill: parent
        anchors.margins: 5
        spacing: 6

        // Capture mode selector
        StyledSelector {
            id: captureModeSelector
            Layout.fillHeight: true
            Layout.preferredWidth: (height + 0) * entries.length
            backgroundColor: selectionModeCombo.colorBg
            showIndicatorBorder: false
            borderColor: "transparent"
            indicatorColor: ColorUtils.transparentize(Theme.colors.color8, 0.60)
            entries: ["camera", "videocam", "image_search", "document_scanner"]

            Binding {
                target: captureModeSelector
                property: "currentIndex"
                value: {
                    switch (root.captureMode) {
                    case "snapshot":
                        return 0;
                    case "recording":
                        return 1;
                    case "ask google":
                        return 2;
                    case "ocr":
                        return 3;
                    default:
                        return 0;
                    }
                }
            }

            onCurrentIndexChanged: {
                let mode = "snapshot";
                switch (currentIndex) {
                case 0:
                    mode = "snapshot";
                    break;
                case 1:
                    mode = "recording";
                    break;
                case 2:
                    mode = "ask google";
                    break;
                case 3:
                    mode = "ocr";
                    break;
                }
                if (root.captureMode !== mode)
                    root.captureMode = mode;
            }

            delegate: Item {
                property var modelData
                property int index

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconName: parent.modelData
                    iconSize: 26
                    filled: parent.index === captureModeSelector.currentIndex
                }
            }
        }

        // Selection mode combobox
        StyledComboBox {
            id: selectionModeCombo
            Layout.fillHeight: true
            Layout.fillWidth: true
            colorBorderClosed: Theme.colors.borderFrameDim
            showBorder: true
            iconSize: 26

            Binding {
                target: selectionModeCombo
                property: "currentIndex"
                value: {
                    switch (root.selectionMode) {
                    case "selection":
                        return 0;
                    case "region":
                        return 1;
                    case "monitor":
                        return 2;
                    case "windows":
                        return 3;
                    default:
                        return 0;
                    }
                }
            }

            model: [
                {
                    text: "Selection",
                    icon: "screenshot_region"
                },
                {
                    text: "Regions",
                    icon: "dashboard"
                },
                {
                    text: "Monitors",
                    icon: "desktop_windows"
                },
                {
                    text: "Windows",
                    icon: "web_asset"
                },
            ]

            onCurrentIndexChanged: {
                let mode = "selection";
                switch (currentIndex) {
                case 0:
                    mode = "selection";
                    break;
                case 1:
                    mode = "region";
                    break;
                case 2:
                    mode = "monitor";
                    break;
                case 3:
                    mode = "windows";
                    break;
                }
                if (root.selectionMode !== mode)
                    root.selectionMode = mode;
            }

            popup.onVisibleChanged: {
                if (!popup.visible)
                    root.popupClosed();
            }
        }

        // Close button
        StyledIconButton {
            Layout.preferredWidth: parent.height
            Layout.fillHeight: true
            iconName: "close"
            iconSize: 22
            onClicked: root.closed()
            enableBorder: true
            alwaysShowBackground: true
            backgroundTransparency: hovered ? 0.10 : 0.03
        }
    }
}
