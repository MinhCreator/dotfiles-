pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.components
import "../../lib/ColorUtils.js" as ColorUtils

PanelWindow {
    id: root

    property real timerDuration: 1000
    property int _nextUid: 0

    WlrLayershell.namespace: "quickshell:reloadpopup"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Normal
    implicitWidth: 400
    color: "transparent"
    visible: stackCol.opacity !== 0

    anchors {
        top: true
        bottom: true
        left: true
    }

    mask: Region {
        item: stackCol
    }

    // Public API, same signatures as before, now enqueued instead of overwritten
    function showError(title, message, duration) {
        _enqueue("error", title ?? "Error", message ?? "", duration);
    }

    function showInfo(title, message, duration) {
        _enqueue("info", title ?? "Info", message ?? "", duration);
    }

    function showWarning(title, message, duration) {
        _enqueue("warning", title ?? "Warning", message ?? "", duration);
    }

    function showSuccess(title, message, duration) {
        _enqueue("success", title ?? "Success", message ?? "", duration);
    }

    function _enqueue(type, title, message, duration) {
        const requested = duration ?? root.timerDuration;
        const locked = (requested < 0);
        const computed = locked ? 0 : Math.min(15000, Math.max(requested, (message ?? "").length * 80));
        const uid = root._nextUid++;
        popupModel.insert(0, {
            "uid": uid,
            "title": title,
            "message": message ?? "",
            "type": type,
            "duration": computed,
            "locked": locked,
            "manual": false,
            "progress": 0,
            "restartToken": 0
        });
        return uid;
    }

    // Manual progress popup: sticky, bar driven via setProgress, no countdown.
    // Returns a uid handle for setProgress/completeProgress.
    function showProgress(title, message) {
        const uid = root._nextUid++;
        popupModel.insert(0, {
            "uid": uid,
            "title": title ?? "Working",
            "message": message ?? "",
            "type": "info",
            "duration": 0,
            "locked": true,
            "manual": true,
            "progress": 0,
            "restartToken": 0
        });
        return uid;
    }

    function setProgress(uid, value) {
        const i = indexOfUid(uid);
        if (i === -1)
            return;
        popupModel.setProperty(i, "progress", Math.min(1, Math.max(0, value)));
    }

    // Morphs a manual progress popup into a timed success/error toast.
    // Falls back to a plain toast if the card was already dismissed.
    function completeProgress(uid, ok, title, message, duration) {
        const i = indexOfUid(uid);
        const type = ok ? "success" : "error";
        if (i === -1) {
            _enqueue(type, title ?? (ok ? "Success" : "Error"), message ?? "", duration);
            return;
        }
        const current = popupModel.get(i);
        const msg = message ?? current.message;
        const requested = duration ?? root.timerDuration;
        popupModel.set(i, {
            "title": title ?? current.title,
            "message": msg,
            "type": type,
            "duration": Math.min(15000, Math.max(requested, msg.length * 80)),
            "locked": false,
            "manual": false,
            "restartToken": current.restartToken + 1
        });
    }

    function indexOfUid(uid) {
        for (let i = 0; i < popupModel.count; i++) {
            if (popupModel.get(i).uid === uid)
                return i;
        }
        return -1;
    }

    function dismiss(uid) {
        const i = indexOfUid(uid);
        if (i !== -1)
            popupModel.remove(i);
    }

    function dismissAll() {
        popupModel.clear();
    }

    // Quickshell reload hooks
    Connections {
        target: Quickshell
        function onReloadFailed(error) {
            root.showError("Reload Failed", error, 0);
        }

        function onReloadCompleted() {
            root.showSuccess("Reloaded");
        }
    }

    ListModel {
        id: popupModel
    }

    Column {
        id: stackCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 16
        anchors.leftMargin: 16
        spacing: 8
        opacity: (popupModel.count === 0 || GlobalCache.loadLockScreen) ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outCubic
            }
        }

        Repeater {
            model: popupModel
            delegate: PopupCard {}
        }
    }

    component PopupCard: StyledRectangle {
        id: card

        required property string title
        required property string message
        required property string type
        required property real duration
        required property bool locked
        required property bool manual
        required property real progress
        required property int restartToken
        required property int uid
        required property int index

        property real timerProgress: 0
        property bool appeared: false
        property bool closing: false

        width: 340
        height: contentCol.implicitHeight + 32 - ((card.locked && !card.manual) ? 16 : 0)
        shadow: true
        baseRadius: Theme.rounding.normal
        color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase
        border.color: Theme.colors.borderFrameMid
        border.width: 1
        visible: opacity >= 0.18
        opacity: (card.closing || !card.appeared) ? 0 : 1
        scale: (card.closing || !card.appeared) ? 0.92 : 1
        transformOrigin: Item.Top

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.standard
                easing.type: Theme.animations.easing.inQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.animations.duration.standard
                easing.type: Theme.animations.easing.inQuad
            }
        }

        Component.onCompleted: {
            card.appeared = true;
            card.startTimer();
        }

        // Fired by completeProgress morphing a manual card into a timed toast
        onRestartTokenChanged: {
            closeTimer.stop();
            card.closing = false;
            card.appeared = true;
            progressAnim.stop();
            card.timerProgress = 0;
            card.startTimer();
        }

        function startTimer() {
            if (card.locked || card.manual) {
                dismissTimer.stop();
                progressAnim.stop();
                card.timerProgress = 0;
                return;
            }
            progressAnim.duration = card.duration;
            progressAnim.restart();
            dismissTimer.interval = card.duration;
            dismissTimer.restart();
        }

        function closeCard() {
            if (card.closing)
                return;
            card.closing = true;
            dismissTimer.stop();
            progressAnim.stop();
            closeTimer.restart();
        }

        function pauseTimer() {
            dismissTimer.stop();
            progressAnim.stop();
        }

        function resumeTimer() {
            if (card.locked || card.manual || card.closing)
                return;
            card.startTimer();
        }

        Timer {
            id: dismissTimer
            onTriggered: card.closeCard()
        }

        Timer {
            id: closeTimer
            interval: Theme.animations.duration.standard
            onTriggered: root.dismiss(card.uid)
        }

        NumberAnimation {
            id: progressAnim
            target: card
            property: "timerProgress"
            from: 0
            to: 1
            easing.type: Easing.Linear
        }

        HoverHandler {
            id: cardHover
            onHoveredChanged: {
                if (card.locked || card.closing)
                    return;
                if (cardHover.hovered)
                    card.pauseTimer();
                else
                    card.resumeTimer();
            }
        }

        ColumnLayout {
            id: contentCol
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 14
            }
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialSymbol {
                    iconName: {
                        if (card.type === "error")
                            return "error";
                        if (card.type === "info")
                            return "lightbulb_2";
                        if (card.type === "warning")
                            return "warning";
                        return "check_circle";
                    }
                    color: {
                        if (card.type === "error")
                            return Theme.colors.error;
                        if (card.type === "info")
                            return Theme.colors.info;
                        if (card.type === "warning")
                            return Theme.colors.warning;
                        return Theme.colors.success;
                    }
                    Layout.alignment: Qt.AlignVCenter
                    iconSize: 22
                    filled: true
                }

                StyledText {
                    text: card.title
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontPixelSizes.small
                    color: Theme.colors.textPrimary
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideNone
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledToast {
                    id: copiedPopup
                    text: "Copied!"
                    Layout.alignment: Qt.AlignVCenter
                }

                StyledIconButton {
                    iconName: "content_copy"
                    iconSize: width * 0.60
                    visible: card.message !== ""
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 28
                    onClicked: {
                        Quickshell.clipboardText = card.message;
                        copiedPopup.show();
                    }
                }

                StyledIconButton {
                    iconName: "close"
                    iconSize: width * 0.75
                    Layout.preferredHeight: 28
                    Layout.preferredWidth: 28
                    Layout.alignment: Qt.AlignVCenter
                    radius: width / 2
                    onClicked: card.closeCard()
                }
            }

            StyledText {
                visible: card.message !== ""
                text: card.message
                font.pixelSize: Theme.fontPixelSizes.smaller
                color: Theme.colors.textSecondary
                horizontalAlignment: Text.AlignLeft
                elide: Text.ElideNone
                wrapMode: Text.WordWrap
                maximumLineCount: 0
                Layout.fillWidth: true
            }

            LinearProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 3
                radius: height / 2
                value: card.manual ? card.progress : card.timerProgress
                enableAnimation: false
                enableBorder: false
                fillColor: {
                    if (card.type === "error")
                        return Theme.colors.error;
                    if (card.type === "info")
                        return Theme.colors.info;
                    if (card.type === "warning")
                        return Theme.colors.warning;
                    return Theme.colors.success;
                }
                backgroundColor: ColorUtils.transparentize(Theme.colors.white, 0.15)
                opacity: card.manual ? 1 : ((cardHover.hovered || card.locked) ? 0 : 1)

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                    }
                }
            }
        }
    }
}
