pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.services
import qs.surfaces.bar.modules.controlcenter.components
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    property var selectedPackages: []

    Connections {
        target: UpdateService
        function onFileUpdated() {
            listView.model = UpdateService.updatesList;
        }
    }

    ControlCenterEmptyState {
        anchors.fill: parent
        shown: UpdateService.updateCount === 0 || UpdateService.checking
        iconName: UpdateService.checking ? "autoplay" : UpdateService.updateCount === 0 ? "check_circle" : ""
        text: UpdateService.checking ? "Checking for updates…" : UpdateService.updateCount === 0 ? "System is up to date" : ""
        useActivityIndicator: UpdateService.checking
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            Layout.preferredHeight: 32
            spacing: 8

            StyledText {
                text: "Software Updates"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
            }

            StyledIconButton {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 32
                iconName: "lock"
                visible: UpdateService.dbLock
                onClicked: UpdateService.removeDbLock()
            }

            StyledIconButton {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 32
                iconName: UpdateService.updateCount > 0 && root.selectedPackages.length === UpdateService.updateCount ? "radio_button_checked" : "radio_button_unchecked"
                iconSize: 24
                enabled: !UpdateService.checking && UpdateService.updateCount > 0
                opacity: enabled ? 1 : 0.50
                onClicked: {
                    if (root.selectedPackages.length === UpdateService.updateCount)
                        root.selectedPackages = [];
                    else
                        root.selectedPackages = UpdateService.updatesList.map(p => p.name);
                }

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                    }
                }
            }

            StyledIconButton {
                Layout.preferredHeight: 32
                Layout.preferredWidth: 32
                enabled: !UpdateService.checking
                opacity: enabled ? 1 : 0.50
                iconSize: 28
                iconName: "sync"
                onClicked: UpdateService.refresh(false)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                    }
                }
            }
        }

        StyledListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            opacity: UpdateService.updateCount > 0 && !UpdateService.checking ? 1 : 0
            visible: opacity !== 0
            model: UpdateService.updatesList
            showScrollBar: false
            spacing: 8

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                }
            }

            delegate: StyledRectangle {
                id: updateDelegate
                required property var modelData
                required property int index

                readonly property bool selected: root.selectedPackages.indexOf(modelData.name) !== -1

                height: 54
                width: listView.width
                baseRadius: Theme.rounding.normal
                color: selected ? ColorUtils.transparentize(Theme.colors.white, 0.10) : "transparent"
                border.color: ColorUtils.transparentize(Theme.colors.white, 0.20)
                border.width: selected ? 1 : 0

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    StyledCheckBox {
                        checked: updateDelegate.selected
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            text: updateDelegate.modelData.name
                            font.weight: Font.DemiBold
                            font.pixelSize: Theme.fontPixelSizes.small
                            horizontalAlignment: Text.AlignLeft
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: updateDelegate.modelData.currentVersion ? `${updateDelegate.modelData.currentVersion} → ${updateDelegate.modelData.newVersion}` : updateDelegate.modelData.newVersion
                            font.pixelSize: Theme.fontPixelSizes.smaller
                            color: Theme.colors.textSecondary
                            horizontalAlignment: Text.AlignLeft
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (updateDelegate.selected)
                            root.selectedPackages = root.selectedPackages.filter(p => p !== updateDelegate.modelData.name);
                        else
                            root.selectedPackages = [...root.selectedPackages, updateDelegate.modelData.name];
                    }
                }
            }
        }

        StyledButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            opacity: UpdateService.updateCount > 0 && !UpdateService.checking ? 1 : 0
            visible: opacity !== 0
            iconName: "download"
            backgroundColor: ColorUtils.transparentize(Theme.colors.gray6, 0.75)
            border.color: ColorUtils.transparentize(Theme.colors.white, 0.215)
            text: root.selectedPackages.length > 0 ? `Update Selected (${root.selectedPackages.length})` : `Update All (${UpdateService.updatesList.length})`
            onClicked: {
                GlobalStates.expandedBarModule = "";
                if (root.selectedPackages.length > 0)
                    UpdateService.updateSelected(root.selectedPackages);
                else
                    UpdateService.updateAll();
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.animations.duration.normal
                }
            }
        }
    }
}
