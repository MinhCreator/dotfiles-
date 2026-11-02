pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs
import "../../lib/ColorUtils.js" as ColorUtils

FocusScope {
    id: informationPopup
    property string name: "Information"
    property string description: "This is an informational message."
    property string okText: "OK"
    signal okClicked

    StyledRectangle {
        id: root
        anchors.fill: parent
        color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.70) : Theme.colors.bgBase
        border.width: 1
        border.color: Theme.colors.borderFrameMid
        baseRadius: (actionSelector.height / 2) + mainColumn.anchors.margins
        shadow: true
        clip: true

        scale: 0.95
        opacity: 0

        Component.onCompleted: {
            scale = 1;
            opacity = 1;
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outCubic
            }
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10

            StyledText {
                Layout.fillWidth: true
                Layout.maximumHeight: implicitHeight
                Layout.minimumHeight: implicitHeight
                Layout.alignment: Qt.AlignTop
                horizontalAlignment: Text.AlignHCenter
                text: informationPopup.name
                font.pixelSize: Theme.fontPixelSizes.huge
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                Layout.fillWidth: true
                Layout.maximumHeight: implicitHeight
                Layout.minimumHeight: implicitHeight
                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: 12
                horizontalAlignment: Text.AlignHCenter
                text: informationPopup.description
                font.pixelSize: Theme.fontPixelSizes.large
                font.weight: Font.Normal
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 2
            }

            StyledSelector {
                id: actionSelector
                Layout.fillWidth: true
                Layout.preferredHeight: 58
                Layout.maximumHeight: Layout.preferredHeight
                Layout.minimumHeight: Layout.preferredHeight
                Layout.alignment: Qt.AlignBottom
                animationEnableDelay: 0
                backgroundColor: ColorUtils.transparentize(Theme.colors.bgSurface, 0.70)

                entries: [informationPopup.okText]
                currentIndex: 0

                delegate: StyledText {
                    required property var modelData
                    anchors.centerIn: parent
                    text: modelData
                    font.weight: Font.DemiBold
                    font.family: Theme.fontFamilies.main
                    width: parent.width - actionSelector.gap * 4
                    horizontalAlignment: Text.AlignHCenter
                }

                onClicked: {
                    informationPopup.okClicked();
                }

                focus: true
                Keys.onTabPressed: currentIndex = 0
                Keys.onReturnPressed: clicked()
                Keys.onEnterPressed: clicked()
            }
        }
    }

    Component.onCompleted: {
        actionSelector.forceActiveFocus();
    }
}
