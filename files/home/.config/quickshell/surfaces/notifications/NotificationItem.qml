pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Notifications
import qs
import qs.services
import qs.components
import "../../lib/ColorUtils.js" as ColorUtils

StyledRectangle {
    id: root
    required property var notification

    shadow: true
    property int revealedGroups: 0
    property bool hovered: false

    readonly property var actionGroups: {
        const actions = root.notification?.actions ?? [];
        const groups = [];
        for (let i = 0; i < actions.length; i += 2)
            groups.push(actions.slice(i, i + 2));
        return groups;
    }

    readonly property int inlineReplyHeight: 40
    readonly property int replyToActionsGap: 6
    readonly property int actionRowHeight: 40
    readonly property int actionGroupsHeight: revealedGroups * actionRowHeight

    readonly property bool showReply: notification ? notification.hasInlineReply : false

    readonly property bool hasIcon: resolvedIcon !== ""

    readonly property string resolvedIcon: {
        if (!notification)
            return "";
        const img = notification.image ?? "";
        if (img !== "")
            return img;
        const icon = notification.appIcon ?? "";
        return icon !== "" ? Quickshell.iconPath(icon, "dialog-information") : "";
    }

    readonly property int effectiveExpireTimeout: (notification?.expireTimeout ?? 0) > 0 ? notification.expireTimeout : 5000
    property string relativeTime: ""

    clip: true
    implicitWidth: Theme.sizes.notificationPopupWidth
    implicitHeight: Theme.sizes.notificationPopupHeight + (showReply ? inlineReplyHeight + replyToActionsGap : 0) + actionGroupsHeight

    color: GlobalSettings.transparentize && !GlobalSettings.isPowerSaverEnabled ? ColorUtils.transparentize(Theme.colors.bgBase, 0.72) : Theme.colors.bgBase
    baseRadius: Theme.rounding.large
    border.color: notification.urgency === NotificationUrgency.Critical ? Theme.colors.error : Theme.colors.borderFrameMid
    border.width: 1

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Theme.animations.duration.slower
            easing.type: Theme.animations.easing.outBack
        }
    }

    // Helpers
    function computeRelativeTime(): string {
        if (!notification)
            return "";
        const ts = GlobalCache.notificationTimestamps[notification.id];
        if (!ts)
            return "";
        const delta = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
        if (delta < 60)
            return "just now";
        const mins = Math.floor(delta / 60);
        return mins < 60 ? mins + " min" : Math.floor(mins / 60) + " hour";
    }

    function nextUpdateInterval(): int {
        if (!notification)
            return 60000;
        const ts = GlobalCache.notificationTimestamps[notification.id];
        if (!ts)
            return 60000;
        const delta = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
        return delta < 60 ? (60 - delta) * 1000 : (60 - (delta % 60)) * 1000;
    }

    function dismiss() {
        NotificationService.requestDismiss(notification?.id);
        GlobalStates.isNotificationActionsMenuOpenVisible = false;
    }

    function refreshTime() {
        relativeTime = computeRelativeTime();
        timeRefreshTimer.interval = nextUpdateInterval();
        timeRefreshTimer.restart();
    }

    // Lifecycle
    Component.onCompleted: refreshTime()

    onNotificationChanged: {
        if (!notification)
            NotificationService.updateActiveNotificationsList();
        else
            refreshTime();
    }

    // Locks & Timers
    RetainableLock {
        object: root.notification
        locked: true
    }

    // Auto-expire
    Timer {
        id: expireTimer
        interval: root.effectiveExpireTimeout
        running: root.notification && root.notification.urgency !== NotificationUrgency.Critical
        repeat: false
        onTriggered: NotificationService.requestExpire(root.notification?.id)
    }

    // Periodic relative elapsed time refresher
    Timer {
        id: timeRefreshTimer
        repeat: true
        running: false
        onTriggered: root.refreshTime()
    }

    // Input handlers
    HoverHandler {
        onHoveredChanged: {
            root.hovered = hovered;
            if (hovered) {
                if (root.notification?.actions?.length > 0)
                    root.revealedGroups = 1;
                expireTimer.stop();
            } else {
                root.revealedGroups = 0;
                if (root.notification && root.notification.urgency !== NotificationUrgency.Critical)
                    expireTimer.restart();
            }
        }
    }

    TapHandler {
        acceptedButtons: Qt.LeftButton
        onTapped: root.dismiss()
    }

    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: {
            const content = (root.notification?.summary ?? "") + "\n" + (root.notification?.body ?? "");
            Quickshell.clipboardText = content.trim();
            copyToast.show();
        }
    }

    // Main content
    Item {
        id: mainContent
        height: Theme.sizes.notificationPopupHeight
        clip: true

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            leftMargin: 8
            rightMargin: 8
        }

        RowLayout {
            spacing: 8

            anchors {
                left: parent.left
                right: parent.right
                leftMargin: 2
                verticalCenter: parent.verticalCenter
            }

            // App icon + badge
            Item {
                implicitWidth: 52
                implicitHeight: 52
                visible: root.hasIcon

                StyledClippingRectangle {
                    id: notificationIconRectangle
                    anchors.centerIn: parent
                    width: 52
                    height: 52
                    baseRadius: width / 4
                    color: "transparent"

                    IconImage {
                        anchors.fill: parent
                        source: root.resolvedIcon
                        smooth: true
                        mipmap: true
                    }
                }

                // Small badge overlaid on icon corner
                IconImage {
                    anchors {
                        bottom: notificationIconRectangle.bottom
                        right: notificationIconRectangle.right
                        bottomMargin: -4
                        rightMargin: -4
                    }
                    width: 20
                    height: 20
                    source: Quickshell.iconPath(root.notification?.appIcon ?? "")
                    visible: root.notification?.image !== "" && (root.notification?.appIcon ?? "") !== ""
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowBlur: 0.4
                    }
                }
            }

            // Summary + body
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 2

                StyledText {
                    Layout.fillWidth: true
                    text: root.notification?.summary ?? ""
                    font.bold: true
                    font.pixelSize: Theme.fontPixelSizes.small
                    horizontalAlignment: Text.AlignLeft
                    elide: Text.ElideRight
                    maximumLineCount: 1
                    wrapMode: Text.NoWrap
                }

                StyledText {
                    Layout.fillWidth: true
                    text: root.notification?.body ?? ""
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WordWrap
                    font.pixelSize: Theme.fontPixelSizes.small
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    visible: (root.notification?.body ?? "") !== ""
                }
            }
        }

        // Relative timestamp
        StyledText {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.rightMargin: 8
            text: root.relativeTime
            font.pixelSize: Theme.fontPixelSizes.smaller
            color: Theme.colors.textSecondary
        }
    }

    // Inline reply field
    StyledRectangle {
        id: replyBackground
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.replyToActionsGap
        anchors.rightMargin: root.replyToActionsGap
        opacity: root.showReply ? 1 : 0
        implicitHeight: root.inlineReplyHeight
        y: Theme.sizes.notificationPopupHeight

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outExpo
            }
        }

        color: ColorUtils.transparentize(Theme.colors.bgBase, 0.25)
        baseRadius: Theme.rounding.large
        border.width: 1
        border.color: replyField.activeFocus ? ColorUtils.transparentize(Theme.colors.borderMid, 0.5) : ColorUtils.transparentize(Theme.colors.borderMid, 0.25)
        Behavior on border.color {
            ColorAnimation {
                duration: Theme.animations.duration.slower
                easing.type: Theme.animations.easing.outExpo
            }
        }

        StyledTextField {
            id: replyField
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: Text.AlignVCenter

            placeholderText: root.notification?.inlineReplyPlaceholder || "Type something..."
            placeholderTextColor: Theme.colors.textMuted
            color: Theme.colors.white
            selectionColor: Theme.colors.white
            selectedTextColor: Theme.colors.bgBase

            font {
                family: Theme.fontFamilies.main
                pixelSize: Theme.fontPixelSizes.small
                weight: Font.Medium
            }

            onAccepted: {
                if (root.notification.hasInlineReply) {
                    root.notification.sendInlineReply(text);
                    root.dismiss();
                }
            }
        }
    }

    // Copy toast
    StyledToast {
        id: copyToast
        text: "Copied notification"
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 8
    }

    // Dot indicators
    Row {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: 12
        anchors.leftMargin: 12
        spacing: 4
        visible: root.actionGroups.length > 0
        opacity: root.revealedGroups > 0 ? 0 : 1
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.animations.duration.slower
                easing.type: Theme.animations.easing.outExpo
            }
        }

        Repeater {
            model: root.actionGroups.length
            delegate: StyledRectangle {
                required property int index
                width: 3
                height: 3
                baseRadius: 2
                color: Theme.colors.textSecondary
                opacity: index === 0 ? 1 : 0.3
            }
        }
    }

    // Action rows
    Repeater {
        model: root.actionGroups

        delegate: Item {
            id: groupRow
            required property var modelData
            required property int index
            readonly property bool isSingle: modelData.length === 1
            readonly property bool isRevealed: root.revealedGroups > index
            readonly property bool showExpand: !isSingle && index < root.actionGroups.length - 1 && root.revealedGroups === index + 1

            anchors.left: root.left
            anchors.right: root.right
            anchors.leftMargin: 8
            anchors.rightMargin: 8

            y: Theme.sizes.notificationPopupHeight + (root.showReply ? root.inlineReplyHeight + root.replyToActionsGap : 0) + (index * root.actionRowHeight)
            height: root.actionRowHeight
            opacity: isRevealed ? 1 : 0

            Behavior on opacity {
                SequentialAnimation {
                    PauseAnimation {
                        duration: groupRow.opacity === 0 ? Theme.animations.duration.fast : Theme.animations.duration.instant
                    }
                    NumberAnimation {
                        duration: groupRow.opacity === 0 ? Theme.animations.duration.normal : Theme.animations.duration.instant
                        easing.type: Theme.animations.easing.outExpo
                    }
                }
            }

            // Full-width pill for single actions
            ActionPill {
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                }
                visible: groupRow.isSingle
                label: groupRow.modelData[0]?.text || "Action"
                onActivated: groupRow.modelData[0]?.invoke()
            }

            // Left pill (first of two)
            ActionPill {
                anchors {
                    left: parent.left
                    top: parent.top
                }
                visible: !groupRow.isSingle
                width: (parent.width - 6) / 2
                label: groupRow.modelData[0]?.text || "Action"
                onActivated: groupRow.modelData[0]?.invoke()
            }

            // Right pill (second of two)
            ActionPill {
                id: secondPill
                anchors {
                    right: expandBtn.left
                    rightMargin: groupRow.showExpand ? 6 : 0
                    top: parent.top
                }
                visible: !groupRow.isSingle
                width: (parent.width - 6) / 2 - (groupRow.showExpand ? 38 : 0)
                label: groupRow.modelData[1]?.text || "Action"
                onActivated: groupRow.modelData[1]?.invoke()

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outExpo
                    }
                }
                Behavior on anchors.rightMargin {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outExpo
                    }
                }
            }

            // Expand button
            StyledRectangle {
                id: expandBtn
                anchors.right: parent.right
                anchors.verticalCenter: secondPill.verticalCenter
                height: root.actionRowHeight - 8
                width: groupRow.showExpand ? height : 0
                baseRadius: height / 2
                visible: !groupRow.isSingle && width > 0
                clip: true
                color: expandHover.containsMouse ? ColorUtils.transparentize(Theme.colors.white, 0.15) : ColorUtils.transparentize(Theme.colors.bgOverlay, 0.40)
                border.width: groupRow.showExpand ? 0.5 : 0
                border.color: ColorUtils.transparentize(Theme.colors.borderMid, 0.50)

                Behavior on width {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outExpo
                    }
                }
                Behavior on color {
                    ColorAnimation {
                        duration: Theme.animations.duration.fast
                        easing.type: Theme.animations.easing.outExpo
                    }
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    iconName: "expand_more"
                    iconSize: Theme.fontPixelSizes.normal
                    color: Theme.colors.textSecondary
                }

                MouseArea {
                    id: expandHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.revealedGroups = groupRow.index + 2
                }
            }
        }
    }

    // Reusable pill button
    component ActionPill: StyledRectangle {
        id: pill

        property string label: ""
        signal activated

        height: root.actionRowHeight - 8
        baseRadius: height / 2
        color: pillHover.containsMouse ? ColorUtils.transparentize(Theme.colors.white, 0.15) : ColorUtils.transparentize(Theme.colors.bgOverlay, 0.40)
        border.width: 1
        border.color: ColorUtils.transparentize(Theme.colors.borderMid, 0.50)

        Behavior on color {
            ColorAnimation {
                duration: Theme.animations.duration.normal
                easing.type: Theme.animations.easing.outQuad
            }
        }

        StyledText {
            anchors.centerIn: parent
            width: parent.width - 16
            text: pill.label
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            wrapMode: Text.NoWrap
            font.pixelSize: Theme.fontPixelSizes.small
            font.weight: Font.DemiBold
        }

        MouseArea {
            id: pillHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                pill.activated();
                root.dismiss();
            }
        }
    }
}
