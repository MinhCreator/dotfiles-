pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

Scope {
    id: root

    Loader {
        active: GlobalStates.showLauncher && GlobalStates.currentLauncherPage === "Monitors" && !GlobalCache.loadLockScreen
        sourceComponent: Variants {
            model: Quickshell.screens
            delegate: PanelWindow {
                id: window
                required property var modelData
                readonly property bool isMain: modelData.name === GlobalSettings.mainMonitor
                screen: modelData

                anchors {
                    top: true
                    left: true
                    right: true
                    bottom: true
                }

                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                mask: Region {}

                WlrLayershell.namespace: "quickshell:monitorlabels"
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

                StyledRectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.margins: 4
                    width: contentRow.implicitWidth + 32
                    height: 64
                    color: Theme.colors.bgBase
                    border.color: Theme.colors.borderMid
                    border.width: 1
                    baseRadius: Theme.rounding.large
                    shadow: true

                    RowLayout {
                        id: contentRow
                        anchors.centerIn: parent
                        spacing: 8

                        MaterialSymbol {
                            iconName: "star"
                            iconSize: 32
                            filled: true
                            visible: window.isMain
                        }

                        StyledText {
                            text: window.modelData.name
                            font.pixelSize: Theme.fontPixelSizes.normal
                            font.weight: Font.DemiBold
                            color: Theme.colors.textBright
                        }
                    }
                }
            }
        }
    }
}
