pragma ComponentBehavior: Bound
import QtQuick
import qs
import qs.components

DashedRectangle {
    id: selection

    required property var window
    required property var screenshot

    visible: false
    color: "transparent"
    borderColor: Theme.colors.color15
    borderWidth: 1

    property bool isMoving: false
    property bool isResizing: false
    property string resizeEdge: ""
    property int resizeCursor: Qt.SizeFDiagCursor
    property real resizeStartX: 0
    property real resizeStartY: 0
    property real resizeStartWidth: 0
    property real resizeStartHeight: 0

    readonly property int handleSize: 12

    function getEdgeAt(px: real, py: real): string {
        if (!visible || width === 0 || height === 0)
            return "";

        const left = px >= x - handleSize && px <= x + handleSize;
        const right = px >= x + width - handleSize && px <= x + width + handleSize;
        const top = py >= y - handleSize && py <= y + handleSize;
        const bottom = py >= y + height - handleSize && py <= y + height + handleSize;
        const hCenter = px >= x + handleSize && px <= x + width - handleSize;
        const vCenter = py >= y + handleSize && py <= y + height - handleSize;

        if (top && left)
            return "tl";
        if (top && right)
            return "tr";
        if (bottom && left)
            return "bl";
        if (bottom && right)
            return "br";
        if (top && hCenter)
            return "t";
        if (bottom && hCenter)
            return "b";
        if (left && vCenter)
            return "l";
        if (right && vCenter)
            return "r";

        return "";
    }

    function getCursorForEdge(edge: string): int {
        switch (edge) {
        case "tl":
        case "br":
            return Qt.SizeFDiagCursor;
        case "tr":
        case "bl":
            return Qt.SizeBDiagCursor;
        case "t":
        case "b":
            return Qt.SizeVerCursor;
        case "l":
        case "r":
            return Qt.SizeHorCursor;
        default:
            return Qt.CrossCursor;
        }
    }

    function contains(px: real, py: real): bool {
        return px >= x + handleSize && px <= x + width - handleSize && py >= y + handleSize && py <= y + height - handleSize;
    }

    function reset() {
        x = y = width = height = 0;
        visible = false;
        isMoving = false;
        isResizing = false;
        resizeEdge = "";
    }

    function startSelection(startX: real, startY: real) {
        x = startX;
        y = startY;
        width = height = 0;
        visible = true;
        isMoving = false;
        isResizing = false;
    }

    function updateGeometry(newX: real, newY: real, newWidth: real, newHeight: real) {
        x = newX;
        y = newY;
        width = newWidth;
        height = newHeight;
    }

    function moveSelection(deltaX: real, deltaY: real) {
        const newX = x + deltaX;
        const newY = y + deltaY;

        x = Math.max(0, Math.min(newX, parent.width - width));
        y = Math.max(0, Math.min(newY, parent.height - height));
    }

    function startResize(edge: string, mouseX: real, mouseY: real) {
        isResizing = true;
        resizeEdge = edge;
        resizeCursor = getCursorForEdge(edge);
        resizeStartX = x;
        resizeStartY = y;
        resizeStartWidth = width;
        resizeStartHeight = height;
    }

    function resizeSelection(mouseX: real, mouseY: real) {
        const minSize = 10;
        let newX = x;
        let newY = y;
        let newWidth = width;
        let newHeight = height;

        switch (resizeEdge) {
        case "tl":
            newX = Math.min(mouseX, resizeStartX + resizeStartWidth - minSize);
            newY = Math.min(mouseY, resizeStartY + resizeStartHeight - minSize);
            newWidth = resizeStartX + resizeStartWidth - newX;
            newHeight = resizeStartY + resizeStartHeight - newY;
            break;
        case "tr":
            newY = Math.min(mouseY, resizeStartY + resizeStartHeight - minSize);
            newWidth = Math.max(mouseX - x, minSize);
            newHeight = resizeStartY + resizeStartHeight - newY;
            break;
        case "bl":
            newX = Math.min(mouseX, resizeStartX + resizeStartWidth - minSize);
            newWidth = resizeStartX + resizeStartWidth - newX;
            newHeight = Math.max(mouseY - y, minSize);
            break;
        case "br":
            newWidth = Math.max(mouseX - x, minSize);
            newHeight = Math.max(mouseY - y, minSize);
            break;
        case "t":
            newY = Math.min(mouseY, resizeStartY + resizeStartHeight - minSize);
            newHeight = resizeStartY + resizeStartHeight - newY;
            break;
        case "b":
            newHeight = Math.max(mouseY - y, minSize);
            break;
        case "l":
            newX = Math.min(mouseX, resizeStartX + resizeStartWidth - minSize);
            newWidth = resizeStartX + resizeStartWidth - newX;
            break;
        case "r":
            newWidth = Math.max(mouseX - x, minSize);
            break;
        }

        // Constrain to screen bounds
        newX = Math.max(0, Math.min(newX, parent.width - minSize));
        newY = Math.max(0, Math.min(newY, parent.height - minSize));
        newWidth = Math.min(newWidth, parent.width - newX);
        newHeight = Math.min(newHeight, parent.height - newY);

        x = newX;
        y = newY;
        width = newWidth;
        height = newHeight;
    }

    function captureSelection() {
        const cropX = Math.floor(x);
        const cropY = Math.floor(y);
        const cropW = Math.ceil(width);
        const cropH = Math.ceil(height);
        const finalPath = window.getFinalPath();

        window.startCrop(cropX, cropY, cropW, cropH, finalPath);
    }

    Item {
        anchors.fill: parent
        anchors.margins: selection.borderWidth
        clip: true

        Image {
            source: selection.screenshot.source
            width: selection.screenshot.width
            height: selection.screenshot.height
            fillMode: Image.Pad
            cache: false
            asynchronous: true
            x: -(selection.x + selection.borderWidth)
            y: -(selection.y + selection.borderWidth)
        }
    }

    InfoLabel {
        property int gap: height + 4
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: (selection.y > gap) ? -gap : selection.height - height - 4
        anchors.leftMargin: (selection.y > gap) ? 0 : selection.width - width - 4
        text: selection.width > 0 && selection.height > 0 ? `${Math.floor(selection.x)}, ${Math.floor(selection.y)} • ${Math.ceil(selection.width)} × ${Math.ceil(selection.height)}` : ""
        opacity: !selection.isMoving && !selection.isResizing ? 1 : 0.35
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.fast
            }
        }
    }
}
