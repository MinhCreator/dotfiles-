import QtQuick
import qs
import qs.surfaces.launcher

Item {
    id: root

    property string pageIcon: ""
    property string pageIconType: ""
    property string pageName: ""
    property string searchText: ""
    property string placeHolder: ""
    property string currentItemPrimaryActionName: ""
    property string currentItemSecondaryActionName: ""
    property bool isLoading: false
    property bool showSearchbar: true
    property bool enableSearchbar: true
    property bool showSearchbarOverlay: true
    property bool catchEscape: false
    property bool ctrlHolded: LauncherService.ctrlHolded
    property int outerMargins: 12
    property var navTarget: null
    property var searchbarActions: []
    property color loadingBarColor: Theme.colors.color12

    function primaryAction() {
    }
    function secondaryAction() {
    }
    function escapeAction() {
    }
    function onShown() {
    }

    function nextItem() {
        if (navTarget)
            navTarget.moveNext();
    }
    function previousItem() {
        if (navTarget)
            navTarget.movePrevious();
    }

    function upItem() {
        previousItem();
    }
    function downItem() {
        nextItem();
    }
    function leftItem() {
    }
    function rightItem() {
    }

    function selectItem() {
    }
}
