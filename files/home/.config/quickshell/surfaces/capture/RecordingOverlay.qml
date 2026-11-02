pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.components

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "quickshell:recordingOverlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    mask: Region {}

    readonly property var region: GlobalData.recordingRegion
    readonly property bool active: GlobalData.isRecording && region !== null
    readonly property bool isRecordingMonitor: active && region.screen === root.screen.name
    readonly property real rx: region ? region.x - root.screen.x : 0
    readonly property real ry: region ? region.y - root.screen.y : 0
    readonly property real rw: region ? region.width : 0
    readonly property real rh: region ? region.height : 0
    readonly property bool isFullScreen: active && rx <= 0 && ry <= 0 && rw >= root.width - 1 && rh >= root.height - 1
    readonly property color veilColor: "#88000000"
    readonly property real borderWidth: 2

    // Full veil on monitors that do not contain the recorded region
    Rectangle {
        anchors.fill: parent
        color: root.veilColor
        visible: root.active && !root.isFullScreen && !root.isRecordingMonitor
    }

    // Veil with a hole at the recorded region on the recording monitor
    Rectangle {
        x: 0
        y: 0
        width: root.width
        height: root.ry
        color: root.veilColor
        visible: root.isRecordingMonitor && !root.isFullScreen && height > 0
    }
    Rectangle {
        x: 0
        y: root.ry + root.rh
        width: root.width
        height: root.height - (root.ry + root.rh)
        color: root.veilColor
        visible: root.isRecordingMonitor && !root.isFullScreen && height > 0
    }
    Rectangle {
        x: 0
        y: root.ry
        width: root.rx
        height: root.rh
        color: root.veilColor
        visible: root.isRecordingMonitor && !root.isFullScreen && width > 0
    }
    Rectangle {
        x: root.rx + root.rw
        y: root.ry
        width: root.width - (root.rx + root.rw)
        height: root.rh
        color: root.veilColor
        visible: root.isRecordingMonitor && !root.isFullScreen && width > 0
    }

    // Dashed border drawn fully outside the recorded region so it never appears in the capture
    DashedRectangle {
        visible: root.isRecordingMonitor && !root.isFullScreen
        x: root.rx - root.borderWidth
        y: root.ry - root.borderWidth
        width: root.rw + root.borderWidth * 2
        height: root.rh + root.borderWidth * 2
        borderWidth: root.borderWidth
        borderColor: Theme.colors.color16
        dashPattern: [8, 8]
    }
}
