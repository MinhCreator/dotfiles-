pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components
import "../../../../lib/AppUtils.js" as AppUtils
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    component SectionDelegate: Item {
        required property string section
        property bool isFirst: AudioService.unifiedList.findIndex(item => item.section === section) === 0
        width: ListView.view.width
        height: isFirst ? 20 : 34

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: 4
            text: parent.section
            font.pixelSize: Theme.fontPixelSizes.small
            font.weight: Font.Bold
            opacity: 0.5
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignBottom
            bottomPadding: 4
        }
    }

    component AudioItemDelegate: StyledRectangle {
        id: delegate
        required property var modelData
        property var node: modelData.node
        property string type: modelData.type
        property bool isInput: modelData.isInput

        width: ListView.view.width
        height: childrenRect.height + 20
        color: ColorUtils.transparentize(Theme.colors.white, 0.045)
        baseRadius: Theme.rounding.large
        border.width: 1
        border.color: ColorUtils.transparentize(Theme.colors.white, 0.15)

        ColumnLayout {
            width: parent.width
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Loader {
                    active: true
                    sourceComponent: delegate.type === "stream" ? appIcon : iconComponent
                }

                Component {
                    id: iconComponent
                    StyledIconButton {
                        iconName: {
                            if (delegate.isInput)
                                return AudioService.getSourceMaterialSymbol(delegate.node);
                            return AudioService.getSinkMaterialSymbol(delegate.node);
                        }
                        inactiveOpacity: 0.5
                        onClicked: delegate.node.audio.muted = delegate.node.audio.muted ? false : true
                    }
                }
                Component {
                    id: appIcon
                    StyledIcon {
                        iconName: AppUtils.getAppIcon(delegate.modelData.clientName, [...new Set(DesktopEntries.applications.values)])
                        iconSize: 24
                        useIconTheme: true
                        placeHolder: "applications-system"
                    }
                }

                StyledText {
                    text: delegate.modelData.clientName
                    font.pixelSize: Theme.fontPixelSizes.normal
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledIconButton {
                    property bool isDefault: delegate.type === "device" && (delegate.isInput ? AudioService.source === delegate.node : AudioService.sink === delegate.node)
                    visible: delegate.type === "device"
                    iconName: isDefault ? "radio_button_checked" : "radio_button_unchecked"
                    inactiveOpacity: isDefault ? 1 : 0.35
                    enabled: !isDefault
                    iconFilled: isDefault
                    iconSize: 20
                    onClicked: {
                        if (delegate.isInput)
                            AudioService.setDefaultSource(delegate.node);
                        else
                            AudioService.setDefaultSink(delegate.node);
                    }
                }
            }

            StyledSlider {
                id: slider
                Layout.leftMargin: -5
                Layout.bottomMargin: 2
                implicitWidth: parent.width
                implicitHeight: 28
                showIcon: false
                leftBorder: false
                value: delegate.node.audio.volume
                onMoved: delegate.node.audio.volume = value
                animationEnabled: false
                from: 0
                to: 1
                showValue: true
                valueText: Math.round(delegate.node.audio.volume * 100) + "%"

                Timer {
                    interval: 200
                    running: true
                    repeat: false
                    onTriggered: parent.animationEnabled = true
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            spacing: 12

            StyledText {
                text: "Audio"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }
            StyledIconButton {
                iconName: "tune"
                onClicked: {
                    Quickshell.execDetached(["sh", "-c", "XDG_CURRENT_DESKTOP=GNOME gnome-control-center sound"]);
                    GlobalStates.expandedBarModule = "";
                }
            }
        }

        StyledListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: AudioService.unifiedList
            showScrollBar: false
            section.property: "section"
            section.delegate: SectionDelegate {}
            delegate: AudioItemDelegate {}
            spacing: 10
        }
    }
}
