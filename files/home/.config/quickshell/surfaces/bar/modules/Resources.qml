pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils

BarModule {
    id: root
    name: "resources"
    baseWidth: 210
    expandedWidth: 870
    expandedHeight: 467
    enableClickToExpand: !isExpanded

    property int gap: 8

    component ResourceItem: Item {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignCenter

        property string text: ""

        StyledText {
            anchors.fill: parent
            text: parent.text
            font.weight: Font.Medium
            font.family: Theme.fontFamilies.main
            font.pixelSize: Theme.fontPixelSizes.small + 1
            font.letterSpacing: -0.05
        }
    }

    component Separator: StyledRectangle {
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        opacity: 0.15
        baseRadius: width / 2
    }

    component StyledContainer: StyledClippingRectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: ColorUtils.transparentize(Theme.colors.bgSurface, 0.45)
        baseRadius: root.radius - root.gap
        border.width: 1
        border.color: Theme.colors.borderFrameDim
    }

    // Reusable circular gauge panel (CPU, GPU, RAM, Swap)
    component GaugePanel: Item {
        id: gaugePanel
        Layout.fillWidth: true
        Layout.fillHeight: true

        property string label: ""
        property real value: 0
        property string topText: ""
        property string mainText: ""
        property string bottomText: ""
        property bool stackedMain: false

        ColumnLayout {
            anchors.fill: parent

            StyledText {
                text: gaugePanel.label
                font.family: Theme.fontFamilies.main
                font.pixelSize: Theme.fontPixelSizes.large
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                Layout.topMargin: 10
            }

            CircularProgress {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.bottomMargin: 8
                value: gaugePanel.value
                enableAnimation: false
                primaryColor: value < 0.75 ? Theme.colors.color10 : value < 0.9 ? Theme.colors.warning : Theme.colors.error
                secondaryColor: ColorUtils.transparentize(value < 0.75 ? Theme.colors.textPrimary : value < 0.9 ? Theme.colors.warning : Theme.colors.error, 0.10)
                lineWidth: 7
                gapAngle: 10

                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: gaugePanel.stackedMain ? -2 : 0

                    StyledText {
                        text: gaugePanel.topText
                        font.pixelSize: Theme.fontPixelSizes.small
                        font.family: Theme.fontFamilies.main
                        color: Theme.colors.textSecondary
                        visible: !gaugePanel.stackedMain && gaugePanel.topText !== ""
                        Layout.alignment: Qt.AlignCenter
                    }

                    StyledText {
                        text: gaugePanel.mainText
                        font.pixelSize: gaugePanel.stackedMain ? Theme.fontPixelSizes.large : Theme.fontPixelSizes.hugeass
                        font.family: Theme.fontFamilies.main
                        font.weight: Font.DemiBold
                        Layout.alignment: Qt.AlignCenter
                    }

                    Separator {
                        opacity: 0.15
                        Layout.fillWidth: true
                        Layout.preferredHeight: 2
                        visible: gaugePanel.stackedMain
                    }

                    StyledText {
                        text: gaugePanel.bottomText
                        font.pixelSize: gaugePanel.stackedMain ? Theme.fontPixelSizes.large : Theme.fontPixelSizes.small
                        font.family: Theme.fontFamilies.main
                        font.weight: gaugePanel.stackedMain ? Font.DemiBold : Font.Medium
                        color: gaugePanel.stackedMain ? Theme.colors.textBright : Theme.colors.textSecondary
                        Layout.alignment: Qt.AlignCenter
                    }
                }
            }
        }
    }

    // Two-panel container (CPU+GPU or RAM+Swap)
    component DualGaugeContainer: StyledContainer {
        id: dualGaugeContainer
        property alias firstPanel: firstSlot.data
        property alias secondPanel: secondSlot.data
        property bool secondVisible: true

        RowLayout {
            anchors.fill: parent

            Item {
                id: firstSlot
                Layout.fillWidth: true
                Layout.fillHeight: true
            }

            Separator {
                opacity: 0.05
            }

            Item {
                id: secondSlot
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: dualGaugeContainer.secondVisible
            }
        }
    }

    initialContent: Item {
        RowLayout {
            anchors.fill: parent
            anchors.margins: 1
            anchors.leftMargin: 4
            anchors.rightMargin: 4

            ResourceItem {
                text: Math.floor(ResourcesService.cpuUsage * 100) + " %"
            }
            Separator {
                Layout.preferredWidth: 3
            }
            ResourceItem {
                text: Math.floor(ResourcesService.cpuTempC) + " °C"
            }
            Separator {
                Layout.preferredWidth: 3
            }
            ResourceItem {
                text: ResourcesService.ramUsedGiB.toFixed(1) + " GiB"
            }
        }
    }

    expandedContent: Item {
        id: expandedContentItem

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = false
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: root.gap
            spacing: root.gap

            // Row 1: CPU + GPU  |  RAM + Swap
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height / 2
                spacing: root.gap

                StyledContainer {
                    RowLayout {
                        anchors.fill: parent

                        GaugePanel {
                            label: "CPU"
                            value: ResourcesService.cpuUsage
                            topText: Math.floor(ResourcesService.cpuTempC) + " °C"
                            mainText: Math.floor(ResourcesService.cpuUsage * 100) + " %"
                            bottomText: ResourcesService.cpuFreqGHz + " GHz"
                        }

                        Separator {
                            opacity: 0.05
                        }

                        GaugePanel {
                            label: "GPU"
                            value: ResourcesService.gpuUsage
                            topText: Math.floor(ResourcesService.gpuTempC) + " °C"
                            mainText: Math.floor(ResourcesService.gpuUsage * 100) + " %"
                            bottomText: ResourcesService.gpuMemUsedGiB + " GiB"
                        }
                    }
                }

                StyledContainer {
                    RowLayout {
                        anchors.fill: parent

                        GaugePanel {
                            label: "Memory"
                            value: ResourcesService.ramUsedPercent
                            mainText: ResourcesService.ramUsedGiB + " GiB"
                            bottomText: ResourcesService.ramTotalGiB + " GiB"
                            stackedMain: true
                        }

                        Separator {
                            opacity: 0.05
                        }

                        GaugePanel {
                            label: "Swap"
                            value: ResourcesService.swapUsedPercent
                            mainText: ResourcesService.swapUsedGiB + " GiB"
                            bottomText: ResourcesService.swapTotalGiB + " GiB"
                            stackedMain: true
                            visible: ResourcesService.swapActive
                        }
                    }
                }
            }

            // Row 2: Disks  |  Network
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height / 2
                spacing: root.gap

                StyledContainer {
                    ColumnLayout {
                        anchors.fill: parent
                        clip: true

                        StyledText {
                            text: "Disks"
                            font.pixelSize: Theme.fontPixelSizes.large
                            font.family: Theme.fontFamilies.main
                            font.weight: Font.DemiBold
                            Layout.topMargin: 10
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                        }

                        StyledListView {
                            id: disksList
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 4
                            model: ResourcesService.partitions
                            showScrollBar: false
                            spacing: 8

                            delegate: Column {
                                id: disk
                                required property var modelData
                                required property int index
                                width: disksList.width
                                padding: 6
                                spacing: 8

                                ColumnLayout {
                                    width: parent.width - 12
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: 4

                                    RowLayout {
                                        Layout.fillWidth: true

                                        StyledText {
                                            Layout.alignment: Qt.AlignLeft
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignLeft
                                            elide: Text.ElideMiddle
                                            text: disk.modelData.path
                                            font.weight: Font.Medium
                                            font.family: Theme.fontFamilies.main
                                            font.pixelSize: Theme.fontPixelSizes.small + 1
                                        }

                                        StyledText {
                                            Layout.alignment: Qt.AlignRight
                                            text: disk.modelData.usedGiB + " / " + disk.modelData.totalGiB + " GiB"
                                            color: Theme.colors.textSecondary
                                            font.family: Theme.fontFamilies.main
                                            font.pixelSize: Theme.fontPixelSizes.small
                                            font.weight: Font.Medium
                                        }
                                    }

                                    LinearProgressBar {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 12
                                        value: disk.modelData.usedPercent
                                        enableBorder: false
                                        enableAnimation: false
                                        fillColor: value < 0.85 ? Theme.colors.color10 : value < 0.9 ? Theme.colors.warning : Theme.colors.error
                                        backgroundColor: ColorUtils.transparentize(value < 0.85 ? Theme.colors.textPrimary : value < 0.9 ? Theme.colors.warning : Theme.colors.error, 0.10)
                                    }
                                }

                                StyledRectangle {
                                    width: parent.width
                                    anchors.horizontalCenter: disk.horizontalCenter
                                    color: Theme.colors.textMuted
                                    height: 1
                                    opacity: 1
                                    baseRadius: 1
                                    visible: disk.index < disksList.count - 1
                                }
                            }
                        }
                    }
                }

                StyledContainer {
                    ColumnLayout {
                        anchors.fill: parent
                        clip: true

                        StyledText {
                            text: "Network"
                            font.family: Theme.fontFamilies.main
                            font.pixelSize: Theme.fontPixelSizes.large
                            font.weight: Font.DemiBold
                            Layout.topMargin: 10
                            Layout.alignment: Qt.AlignHCenter | Qt.AlignTop
                        }

                        MultiChart {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Layout.margins: 4
                            seriesIconSize: 16
                            smooth: true
                            showDots: false
                            lineWidth: 1
                            scaleStep: 1024
                            series: [NetworkService.downloadSpeedHistory, NetworkService.uploadSpeedHistory]
                            autoScale: true
                            scaleUnits: ["KB/s", "MB/s", "GB/s"]
                            seriesNames: ["Download", "Upload"]
                            colorPalette: [Theme.colors.color14, Theme.colors.color6]
                        }
                    }
                }
            }
        }
    }
}
