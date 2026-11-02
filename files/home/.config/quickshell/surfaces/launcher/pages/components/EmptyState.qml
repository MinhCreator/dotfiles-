pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components

Item {
    id: root

    property alias iconName: symbol.iconName
    property alias text: label.text
    property int iconSize: 86

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 8

        MaterialSymbol {
            id: symbol
            iconSize: root.iconSize
            opacity: 0.2
            Layout.alignment: Qt.AlignCenter
        }

        StyledText {
            id: label
            font.pixelSize: Theme.fontPixelSizes.normal
            opacity: 0.5
            font.weight: Font.DemiBold
            Layout.alignment: Qt.AlignCenter
        }
    }
}
