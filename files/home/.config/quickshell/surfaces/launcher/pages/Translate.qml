pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils

BasePage {
    id: root

    placeHolder: "Type to translate..."
    currentItemPrimaryActionName: "Copy Translation"
    pageIcon: "translate"
    pageIconType: "symbol"
    pageName: "Translate"
    isLoading: (TranslateService.serverActive && !TranslateService.serverReady) || TranslateService.busy
    showSearchbar: false
    enableSearchbar: false
    showSearchbarOverlay: false
    loadingBarColor: !TranslateService.serverActive ? Theme.colors.error : (TranslateService.serverReady ? Theme.colors.color12 : Theme.colors.warning)

    property string inputText: ""
    property string outputText: ""

    readonly property var sourceModel: [
        {
            code: "auto",
            text: "Auto Detect"
        },
        ...TranslateService.availableLanguages.map(l => ({
                    code: l.code,
                    text: l.name
                }))]

    readonly property var targetModel: TranslateService.availableLanguages.map(l => ({
                code: l.code,
                text: l.name
            }))

    function getIndex(model, code) {
        return model.findIndex(m => m.code === code);
    }

    function translate() {
        if (root.inputText.trim() !== "")
            TranslateService.translate(root.inputText);
        else
            root.outputText = "";
    }

    function secondaryAction() {
        if (root.outputText) {
            Quickshell.clipboardText = root.outputText;
            GlobalIpc.popup.showInfo("Copied to clipboard", "", 1000);
            GlobalStates.showLauncher = false;
        }
    }

    Timer {
        id: debounceTimer
        interval: 400
        onTriggered: root.translate()
    }

    Timer {
        id: focusTimer
        interval: 100
        running: true
        onTriggered: inputArea.forceActiveFocus()
    }

    Connections {
        target: TranslateService
        function onTranslationReady(res) {
            if (res?.translatedText)
                root.outputText = res.translatedText;
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 0

        // Left Side: Source
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            StyledComboBox {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 300
                model: root.sourceModel
                currentIndex: root.getIndex(model, TranslateService.sourceLang)
                colorBg: ColorUtils.transparentize(Theme.colors.bgElevated, 0.65)
                enabled: model.length > 0
                horizontalTextAlignment: Text.AlignHCenter
                onActivated: index => {
                    TranslateService.sourceLang = model[index].code;
                    root.translate();
                }
            }
            StyledRectangle {

                Layout.fillWidth: true
                Layout.fillHeight: true
                baseRadius: Theme.rounding.normal
                border.width: 1
                color: ColorUtils.transparentize(Theme.colors.bgElevated, 0.35)
                border.color: ColorUtils.transparentize(Theme.colors.white, 0.15)

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 12

                    StyledTextArea {
                        id: inputArea
                        width: parent.width
                        focus: true
                        wrapMode: Text.Wrap
                        placeholderText: root.placeHolder
                        font.pixelSize: Theme.fontPixelSizes.large
                        onTextChanged: {
                            root.inputText = text;
                            debounceTimer.restart();
                        }
                    }
                }

                StyledIconButton {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 8
                    iconName: "close"
                    iconSize: 22
                    visible: root.inputText !== ""
                    onClicked: {
                        inputArea.clear();
                        root.outputText = "";
                        inputArea.forceActiveFocus();
                    }
                }
            }
        }

        StyledIconButton {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignTop
            Layout.topMargin: 4
            iconName: "swap_horiz"
            enabled: TranslateService.canTranslate(TranslateService.targetLang, TranslateService.sourceLang)
            onClicked: {
                TranslateService.swapLanguages();
                root.translate();
            }
        }

        // Right Side: Target
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            StyledComboBox {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 300
                model: root.targetModel
                currentIndex: root.getIndex(model, TranslateService.targetLang)
                colorBg: ColorUtils.transparentize(Theme.colors.bgElevated, 0.65)
                enabled: model.length > 0
                horizontalTextAlignment: Text.AlignHCenter
                onActivated: index => {
                    TranslateService.targetLang = model[index].code;
                    root.translate();
                }
            }
            StyledRectangle {

                Layout.fillWidth: true
                Layout.fillHeight: true
                baseRadius: Theme.rounding.normal
                border.width: 1
                color: ColorUtils.transparentize(Theme.colors.white, 0.075)
                border.color: ColorUtils.transparentize(Theme.colors.color16, 0.20)

                ScrollView {
                    anchors.fill: parent
                    anchors.margins: 12
                    StyledTextArea {
                        id: outputArea
                        width: parent.width
                        readOnly: true
                        wrapMode: Text.Wrap
                        text: root.outputText
                        placeholderText: "Translation"
                        font.pixelSize: Theme.fontPixelSizes.large
                    }
                }

                StyledIconButton {
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 8
                    iconName: "content_copy"
                    iconSize: 18
                    visible: root.outputText !== ""
                    onClicked: {
                        if (root.outputText) {
                            Quickshell.clipboardText = root.outputText;
                            GlobalIpc.popup.showInfo("Copied to clipboard", "", 1000);
                        }
                    }
                }
            }
        }
    }
}
