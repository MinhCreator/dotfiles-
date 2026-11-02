import QtQuick
import Quickshell.Widgets
import Quickshell

Item {
    id: root
    required property string iconName
    property string placeHolder: "not_available"
    property bool useIconTheme: false
    property real iconSize: 24
    property var fallbacks: []
    property var replacements: ({})
    property alias backer: icon.backer

    implicitWidth: iconSize
    implicitHeight: iconSize

    function getIcon() {
        const name = replacements[iconName] ?? iconName;

        if (!useIconTheme)
            return Quickshell.shellDir + "/assets/icons/" + name + ".svg";
        if (Quickshell.iconPath(name, true) !== "")
            return name;
        return fallbacks.find(f => Quickshell.iconPath(f, true) !== "") || placeHolder;
    }

    IconImage {
        id: icon
        anchors.fill: parent
        source: Quickshell.iconPath(root.getIcon(), root.placeHolder)
    }
}
