pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import Quickshell
import qs

Singleton {
    id: root
    readonly property alias instance: root
    property alias trackedNotifications: notificationServer.trackedNotifications

    property var activeNotifications: ({})
    property var trackedNotificationsList: unique([...root.trackedNotifications.values].filter(n => n && n.appName && !n.transient)).reverse()
    property var activeNotificationsList: unique(Object.values(activeNotifications))
    readonly property string materialSymbol: GlobalSettings.doNotDisturb ? "notifications_off" : GlobalCache.unreadNotificationsIds.length === 0 ? "notifications" : "notifications_active"

    signal focusChangeRequested(bool hasInlineReply)

    // Helper function to get unique notifications by ID
    function unique(notifications) {
        const seen = new Set();
        return notifications.filter(n => {
            if (!n || !n.id || seen.has(n.id))
                return false;
            seen.add(n.id);
            return true;
        });
    }

    NotificationServer {
        id: notificationServer
        imageSupported: true
        actionsSupported: true
        actionIconsSupported: true
        keepOnReload: true
        inlineReplySupported: true
        persistenceSupported: true
        onNotification: notification => {
            notification.tracked = true;
            if (!GlobalSettings.doNotDisturb)
                root.createNotificationItem(notification);
            if (!notification.lastGeneration)
                GlobalCache.notificationTimestamps = Object.assign({}, GlobalCache.notificationTimestamps, {
                    [notification.id]: new Date()
                });
            if (GlobalStates.expandedBarModule.toLowerCase() === "controlcenter" && GlobalStates.showNotificationHistory)
                root.expireAll();
        }
    }

    function requestDismiss(notificationId) {
        if (activeNotifications[notificationId]) {
            delete activeNotifications[notificationId];
            updateActiveNotificationsList();

            let t = Object.assign({}, GlobalCache.notificationTimestamps);
            delete t[notificationId];
            GlobalCache.notificationTimestamps = t;
        }
        notificationServer.trackedNotifications.values.find(n => n.id === notificationId)?.dismiss();
    }

    function requestExpire(notificationId) {
        if (activeNotifications[notificationId]) {
            const notification = activeNotifications[notificationId];
            if (!GlobalStates.showNotificationHistory)
                GlobalCache.unreadNotificationsIds = [...GlobalCache.unreadNotificationsIds, notification.id];
            delete activeNotifications[notificationId];
            updateActiveNotificationsList();
        }
    }

    function dismissAll() {
        for (let notification of [...root.trackedNotifications.values].reverse()) {
            requestDismiss(notification.id);
        }
    }

    function expireAll() {
        const ids = Object.keys(activeNotifications);
        for (let id of ids) {
            requestExpire(id);
        }
    }

    function updateActiveNotificationsList() {
        activeNotificationsList = Object.values(activeNotifications).filter(n => Object.keys(n).length > 0);
    }

    function createNotificationItem(notification) {
        focusChangeRequested(notification.hasInlineReply);
        const wasInLastGeneration = notification.lastGeneration;
        if (wasInLastGeneration) {
            return;
        }

        activeNotifications[notification.id] = notification;
        updateActiveNotificationsList();
    }

    function notifySend(...content) {
        Quickshell.execDetached(["notify-send", ...content]);
    }
}
