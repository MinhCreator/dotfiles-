pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.components
import qs.surfaces.launcher.pages.components

RowLayout {
    id: root

    default property alias detailData: detailPane.data
    property real listRatio: 0.40

    readonly property alias listView: list
    readonly property alias dividerVisible: divider.visible
    readonly property var currentModelData: list.currentItem ? list.currentItem?.modelData : null

    property alias model: list.model
    property alias delegate: list.delegate
    property alias currentIndex: list.currentIndex
    property Component headerComponent: null
    property string sectionProperty: ""
    property Component sectionDelegate: null

    property bool isEmpty: false
    property bool showEmptyState: false
    property bool animationsEnabled: false
    property bool highlightMoveEnabled: true
    property string emptyIcon: ""
    property string emptyText: ""
    property int emptyIconSize: 64

    anchors.fill: parent
    spacing: 12

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
        Qt.callLater(() => {
            if (list.count > 0)
                list.contentY = list.originY;
        });
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
        Layout.preferredWidth: parent.width * root.listRatio
        Layout.fillHeight: true
        spacing: 6
        showScrollBar: false
        visible: count > 0
        header: (count > 0 && !root.isEmpty) ? root.headerComponent : null
        section.property: root.sectionProperty
        section.delegate: root.sectionDelegate
        animationsEnabled: root.animationsEnabled
        highlightMoveEnabled: root.highlightMoveEnabled
    }

    Divider {
        id: divider
        vertical: true
        visible: list.count > 0
    }

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ColumnLayout {
            id: detailPane
            anchors.fill: parent
            spacing: 0
        }

        EmptyState {
            id: emptyState
            anchors.fill: parent
            visible: root.showEmptyState && root.isEmpty
            iconName: root.emptyIcon
            text: root.emptyText
            iconSize: root.emptyIconSize
        }
    }
}
