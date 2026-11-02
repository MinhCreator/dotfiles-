pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.components

Column {
    id: root

    // Row schema:
    //   { label, value }              plain string value
    //   { label, value, color }       colored string value
    //   { label, component }          custom Component in the value slot
    property var rows: []

    spacing: 0

    Repeater {
        model: root.rows

        delegate: Item {
            id: metaRow
            required property var modelData
            required property int index

            width: root.width
            height: 28

            StyledRectangle {
                anchors.fill: parent
                color: metaRow.index % 2 === 0 ? "transparent" : Qt.rgba(1, 1, 1, 0.025)
                baseRadius: 3
            }

            StyledText {
                id: metaLabel
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: metaRow.modelData.label ?? ""
                font.pixelSize: Theme.fontPixelSizes.small
                color: Theme.colors.textSecondary
                opacity: 0.55
            }

            Loader {
                id: customValue
                active: !!metaRow.modelData.component
                sourceComponent: metaRow.modelData.component ?? null
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: !customValue.active
                anchors.left: metaLabel.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: metaRow.modelData.value ?? ""
                font.pixelSize: Theme.fontPixelSizes.small
                font.weight: Font.DemiBold
                color: metaRow.modelData.color ?? Theme.colors.white
                elide: Text.ElideMiddle
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
