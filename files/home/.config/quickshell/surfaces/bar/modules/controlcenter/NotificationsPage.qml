pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import qs
import qs.components
import qs.services
import qs.surfaces.bar.modules.controlcenter.components
import "../../../../lib/ColorUtils.js" as ColorUtils

ControlCenterPage {
    id: root

    Component.onDestruction: GlobalStates.showNotificationHistory = false

    Connections {
        target: root
        function onIsCurrentItemChanged() {
            if (root.isCurrentItem) {
                NotificationService.expireAll();
                GlobalCache.unreadNotificationsIds = [];
                GlobalStates.showNotificationHistory = true;
            }
        }
    }

    // Empty State
    ControlCenterEmptyState {
        anchors.fill: parent
        shown: NotificationService.trackedNotificationsList.length === 0
        iconName: GlobalSettings.doNotDisturb ? "notifications_off" : "notifications"
        text: "Your notification history is empty"
        textPixelSize: Theme.fontPixelSizes.normal
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            spacing: 8

            StyledText {
                text: "Notifications"
                font.pixelSize: Theme.fontPixelSizes.larger
                font.weight: Font.Bold
                horizontalAlignment: Text.AlignLeft
                Layout.fillWidth: true
            }

            StyledIconButton {
                iconName: "delete_sweep"
                iconSize: 28
                visible: NotificationService.trackedNotificationsList.length > 0
                onClicked: NotificationService.dismissAll()
            }

            RowLayout {
                spacing: 8
                StyledText {
                    text: "DND"
                    font.pixelSize: Theme.fontPixelSizes.small
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignLeft
                    opacity: 0.4
                }

                StyledSwitch {
                    implicitWidth: 64
                    implicitHeight: 28
                    checked: GlobalSettings.doNotDisturb
                    onClicked: GlobalSettings.doNotDisturb = !GlobalSettings.doNotDisturb
                }
            }
        }

        // Content
        StyledListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: NotificationService.trackedNotificationsList.length > 0
            scrollBarWidth: 6
            showScrollBar: false
            spacing: 12
            clip: true
            cacheBuffer: 400
            displayMarginBeginning: 0
            displayMarginEnd: 0
            reuseItems: true
            model: ScriptModel {
                values: NotificationService.trackedNotificationsList
                objectProp: "id"
                comparisonMode: ObjectComparison.Identity
            }

            delegate: StyledRectangle {
                id: notificationDelegate
                required property var modelData
                width: listView.width
                implicitHeight: mainLayout.implicitHeight + 24

                readonly property string timeAgo: {
                    const ts = GlobalCache.notificationTimestamps[notificationDelegate.modelData.id];
                    if (!ts)
                        return "";
                    const delta = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
                    if (delta < 60)
                        return "just now";
                    const mins = Math.floor(delta / 60);
                    if (mins < 60)
                        return mins + "m ago";
                    const hours = Math.floor(mins / 60);
                    if (hours < 24)
                        return hours + "h ago";
                    return Math.floor(hours / 24) + "d ago";
                }

                ListView.onReused: {
                    replyInput.text = "";
                }

                baseRadius: Theme.rounding.large
                color: ColorUtils.transparentize(Theme.colors.white, 0.050)
                border.color: modelData.urgency === NotificationUrgency.Critical ? ColorUtils.transparentize(Theme.colors.error, 0.5) : ColorUtils.transparentize(Theme.colors.white, 0.15)
                border.width: 1

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton) {
                            NotificationService.requestDismiss(notificationDelegate.modelData.id);
                        } else {
                            const content = (notificationDelegate.modelData.summary ?? "") + "\n" + (notificationDelegate.modelData.body ?? "");
                            Quickshell.clipboardText = content.trim();
                            copyToast.show();
                        }
                    }
                }

                StyledToast {
                    id: copyToast
                    text: "Copied notification"
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.topMargin: 8
                }

                ColumnLayout {
                    id: mainLayout
                    anchors.fill: parent
                    anchors.margins: 6
                    anchors.topMargin: 8
                    spacing: 4

                    // Top row: App info, timestamp, and close
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        spacing: 8

                        IconImage {
                            Layout.preferredWidth: 16
                            Layout.preferredHeight: 16
                            source: Quickshell.iconPath(notificationDelegate.modelData.appIcon, "dialog-information")
                            asynchronous: true
                            visible: notificationDelegate.modelData.appIcon !== ""
                        }

                        StyledText {
                            text: notificationDelegate.modelData.appName || "Notification"
                            font.pixelSize: Theme.fontPixelSizes.smaller
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignLeft
                            color: Theme.colors.textSecondary
                            Layout.fillWidth: true
                        }

                        StyledText {
                            text: notificationDelegate.timeAgo
                            font.pixelSize: Theme.fontPixelSizes.smaller
                            horizontalAlignment: Text.AlignLeft
                            color: Theme.colors.textMuted
                        }

                        StyledIconButton {
                            iconName: "close"
                            iconSize: 14
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            onClicked: NotificationService.requestDismiss(notificationDelegate.modelData.id)
                        }
                    }

                    // Content Row: Optional Image + Text
                    RowLayout {
                        Layout.topMargin: -4 * 0
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Layout.alignment: Qt.AlignTop
                        spacing: 12

                        // Image if present
                        StyledClippingRectangle {
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            Layout.alignment: Qt.AlignVCenter
                            baseRadius: width / 4
                            color: "transparent"
                            visible: notificationDelegate.modelData.image !== ""

                            IconImage {
                                anchors.fill: parent
                                source: notificationDelegate.modelData.image
                                asynchronous: true
                                backer.fillMode: Image.PreserveAspectCrop
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 4

                            StyledText {
                                Layout.fillWidth: true
                                text: notificationDelegate.modelData.summary || ""
                                font.weight: Font.Bold
                                font.pixelSize: Theme.fontPixelSizes.normal
                                wrapMode: Text.WordWrap
                                horizontalAlignment: Text.AlignLeft
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: notificationDelegate.modelData.body.substring(0, 300) || ""
                                horizontalAlignment: Text.AlignLeft
                                color: Theme.colors.textPrimary
                                visible: text !== ""
                                wrapMode: Text.WordWrap
                                maximumLineCount: 4
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Item {
                        visible: actionsFlow.visible
                        Layout.fillHeight: true
                    }

                    // Actions Row
                    Flow {
                        id: actionsFlow
                        Layout.fillWidth: true
                        visible: notificationDelegate.modelData.actions && notificationDelegate.modelData.actions.length > 0
                        spacing: 6

                        Repeater {
                            model: notificationDelegate.modelData.actions
                            delegate: StyledRectangle {
                                required property var modelData
                                implicitWidth: actionLabel.implicitWidth + 24
                                implicitHeight: 34
                                baseRadius: height / 2
                                color: actionMouse.containsMouse ? ColorUtils.transparentize(Theme.colors.white, 0.025) : ColorUtils.transparentize(Theme.colors.white, 0.045)
                                border.color: ColorUtils.transparentize(Theme.colors.borderMid, 0.65)
                                border.width: 1

                                Behavior on color {
                                    ColorAnimation {
                                        duration: Theme.animations.duration.fast
                                    }
                                }

                                StyledText {
                                    id: actionLabel
                                    anchors.centerIn: parent
                                    text: parent.modelData.text || "Action"
                                    horizontalAlignment: Text.AlignLeft
                                    font.pixelSize: Theme.fontPixelSizes.smaller
                                    font.weight: Font.Medium
                                }

                                MouseArea {
                                    id: actionMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: parent.modelData.invoke()
                                }
                            }
                        }
                    }

                    Item {
                        visible: inputBackground.visible
                        Layout.fillHeight: true
                    }

                    // Inline Reply
                    StyledRectangle {
                        id: inputBackground
                        visible: notificationDelegate.modelData.hasInlineReply
                        Layout.fillWidth: true
                        Layout.preferredHeight: replyInput.implicitHeight + 16
                        Layout.alignment: Qt.AlignBottom
                        color: ColorUtils.transparentize(Theme.colors.bgBase, 0.50)
                        baseRadius: notificationDelegate.baseRadius - mainLayout.anchors.margins
                        border.color: ColorUtils.transparentize(replyInput.focus ? Theme.colors.gray7 : Theme.colors.gray3, 0.50)
                        border.width: 1

                        Behavior on border.color {
                            ColorAnimation {
                                duration: Theme.animations.duration.slow
                                easing.type: Theme.animations.easing.outQuad
                            }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 5
                            spacing: 8

                            StyledTextField {
                                id: replyInput
                                Layout.fillWidth: true
                                horizontalAlignment: Text.AlignLeft
                                placeholderText: notificationDelegate.modelData.inlineReplyPlaceholder || "Reply..."
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        notificationDelegate.modelData.sendInlineReply(text);
                                        replyInput.text = "";
                                    }
                                }
                            }

                            StyledIconButton {
                                iconName: "send"
                                enabled: replyInput.text !== ""
                                opacity: enabled ? 1 : 0
                                Layout.preferredHeight: 36
                                Layout.preferredWidth: 36
                                onClicked: {
                                    notificationDelegate.modelData.sendInlineReply(replyInput.text);
                                    replyInput.text = "";
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.animations.duration.normal
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
