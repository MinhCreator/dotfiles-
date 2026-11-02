pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import "../../lib/ColorUtils.js" as ColorUtils

PanelWindow {
    id: root
    required property var scope
    readonly property bool isMain: scope && screen.name === root.scope.mainMonitorName

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: !GlobalCache.loadLockScreen

    WlrLayershell.namespace: "quickshell:dialog"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: isMain ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region {
        item: root.isMain ? loader.item : null
    }

    Rectangle {
        anchors.fill: parent
        color: ColorUtils.transparentize(Theme.colors.black, 0.20)

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.fast
                easing.type: Theme.animations.easing.outExpo
            }
        }
    }

    Loader {
        id: loader
        anchors.centerIn: parent
        active: root.isMain
        sourceComponent: root.scope && root.scope.kind === "confirm" ? confirmComponent : root.scope && root.scope.kind === "info" ? infoComponent : null

        onLoaded: item => {
            if (item)
                item.forceActiveFocus();
        }
    }

    Component {
        id: confirmComponent

        ConfirmationDialog {
            focus: true
            implicitWidth: 500
            implicitHeight: 220
            name: root.scope.title
            description: root.scope.description
            cancelText: root.scope.cancelText
            proceedText: root.scope.proceedText

            onCancelClicked: {
                root.scope.executeCommand(root.scope.cancelCommand);
                root.scope.close();
            }
            onProceedClicked: {
                root.scope.executeCommand(root.scope.proceedCommand);
                root.scope.close();
            }

            Keys.onEscapePressed: root.scope.close()
        }
    }

    Component {
        id: infoComponent

        InformationDialog {
            focus: true
            implicitWidth: 500
            implicitHeight: 220
            name: root.scope.title
            description: root.scope.description
            okText: root.scope.okText

            onOkClicked: {
                root.scope.executeCommand(root.scope.okCommand);
                root.scope.close();
            }

            Keys.onEscapePressed: root.scope.close()
        }
    }
}
