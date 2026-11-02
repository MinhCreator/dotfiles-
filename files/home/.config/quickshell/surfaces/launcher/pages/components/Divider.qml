pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

Rectangle {
    id: root

    property bool vertical: true

    Layout.fillWidth: !vertical
    Layout.fillHeight: vertical
    implicitWidth: vertical ? 1 : 0
    implicitHeight: vertical ? 0 : 1
    color: Theme.colors.textMuted
    opacity: 0.15
}
