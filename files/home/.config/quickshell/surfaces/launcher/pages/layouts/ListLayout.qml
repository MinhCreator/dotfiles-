pragma ComponentBehavior: Bound

import QtQuick
import qs.components
import qs.surfaces.launcher.pages.components

Item {
    id: root

    property bool fillParent: true

    anchors.fill: fillParent ? parent : undefined

    property alias model: list.model
    property alias delegate: list.delegate
    property alias currentIndex: list.currentIndex
    property alias spacing: list.spacing
    property alias reuseItems: list.reuseItems
    property Component headerComponent: null
    property string sectionProperty: ""
    property Component sectionDelegate: null

    property bool isEmpty: false
    property string emptyIcon: ""
    property bool animationsEnabled: false
    property bool highlightMoveEnabled: true
    property string emptyText: ""
    property int emptyIconSize: 86

    readonly property alias listView: list
    readonly property alias emptyState: emptyState
    readonly property var currentModelData: list.currentItem ? list.currentItem.modelData : null

    function moveNext() {
        if (list.count > 0)
            list.incrementCurrentIndex();
    }

    function movePrevious() {
        if (list.count > 0)
            list.decrementCurrentIndex();
    }

    function resetToTopNow() {
        root.highlightMoveEnabled = false;
        list.smoothScrollEnabled = false;
        if (list.count > 0)
            list.currentIndex = 0;
        list.contentY = list.originY;
    }

    function restoreAfterReset() {
        Qt.callLater(() => {
            list.smoothScrollEnabled = true;
            root.highlightMoveEnabled = true;
        });
    }

    function resetToTopInstant() {
        resetToTopNow();
        restoreAfterReset();
    }

    StyledListView {
        id: list
        anchors.fill: parent
        spacing: 6
        showScrollBar: false
        header: root.headerComponent
        section.property: root.sectionProperty
        section.delegate: root.sectionDelegate
        visible: count > 0 && !root.isEmpty
        animationsEnabled: root.animationsEnabled
        highlightMoveEnabled: root.highlightMoveEnabled
    }

    EmptyState {
        id: emptyState
        anchors.fill: parent
        visible: root.isEmpty
        iconName: root.emptyIcon
        text: root.emptyText
        iconSize: root.emptyIconSize
    }
}
