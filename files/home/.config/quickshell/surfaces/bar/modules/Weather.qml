pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils

BarModule {
    id: root
    name: "weather"

    expandedWidth: 290
    expandedHeight: 470
    baseWidth: Theme.sizes.barModuleBaseHeight + 28
    enableClickToExpand: !isExpanded

    component WeatherText: StyledText {
        font.family: Theme.fontFamilies.main
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideNone
    }

    component Separator: StyledRectangle {
        Layout.preferredWidth: 2
        Layout.preferredHeight: 24
        opacity: 0.15
        baseRadius: width / 2
    }

    component WeatherCard: StyledRectangle {
        property bool isFirst: false
        property bool isLast: false

        property real customTopLeftRadius: -1
        property real customTopRightRadius: -1
        property real customBottomLeftRadius: -1
        property real customBottomRightRadius: -1

        baseTopLeftRadius: customTopLeftRadius !== -1 ? customTopLeftRadius : (isFirst ? Theme.rounding.unsharpen : -1)
        baseTopRightRadius: customTopRightRadius !== -1 ? customTopRightRadius : (isLast ? Theme.rounding.unsharpen : -1)
        baseBottomLeftRadius: customBottomLeftRadius !== -1 ? customBottomLeftRadius : (isFirst ? Theme.rounding.unsharpen : -1)
        baseBottomRightRadius: customBottomRightRadius !== -1 ? customBottomRightRadius : (isLast ? Theme.rounding.unsharpen : -1)

        color: ColorUtils.transparentize(Theme.colors.white, 0.05)
        border.color: ColorUtils.transparentize(Theme.colors.white, 0.12)
        border.width: 1
    }

    initialContent: Item {
        RowLayout {
            anchors.centerIn: parent
            spacing: 3

            WeatherText {
                text: WeatherService.data.current.temperature.toFixed(0) + "°"
                font.pixelSize: Theme.fontPixelSizes.normal
                font.weight: Font.Medium
                font.variableAxes: ({
                        "ROND": 100
                    })
            }

            MaterialSymbol {
                iconName: WeatherService.data.current.weather_material_symbol
                iconSize: 24
            }
        }
    }

    expandedContent: Item {
        id: expandedContentItem

        property date now: new Date()
        property var upcomingHours: WeatherService.data.hourly.filter(e => e.time.slice(0, 13) >= now.toISOString().slice(0, 13)).slice(0, 5)
        property var upcomingDays: WeatherService.data.daily.filter(e => e.time >= now.toISOString().slice(0, 10)).slice(1, 4)

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 6

            // Top Hero Section
            WeatherCard {
                Layout.fillHeight: true
                Layout.fillWidth: true

                customTopLeftRadius: root.radius - parent.anchors.margins
                customTopRightRadius: root.radius - parent.anchors.margins
                customBottomLeftRadius: Theme.rounding.unsharpen
                customBottomRightRadius: Theme.rounding.unsharpen

                ColumnLayout {
                    anchors.fill: parent

                    WeatherText {
                        text: WeatherService.data.current.weather_description
                        font.pixelSize: Theme.fontPixelSizes.normal
                        color: Theme.colors.textSecondary
                        Layout.alignment: Qt.AlignHCenter
                        Layout.topMargin: 2
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Item {
                            Layout.fillWidth: true
                        }

                        StyledIcon {
                            iconSize: 98
                            iconName: `google/${WeatherService.data.current.weather_icon}`
                            Layout.alignment: Qt.AlignHCenter
                        }

                        WeatherText {
                            text: WeatherService.data.current.temperature.toFixed(0) + "°"
                            font.pixelSize: Theme.fontPixelSizes.giant * 0.75
                            font.weight: Font.Medium
                            font.variableAxes: ({
                                    "ROND": 100
                                })
                            Layout.alignment: Qt.AlignHCenter
                        }

                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
            }

            // Middle Metrics Section
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

                    Repeater {
                        id: datasRepeater
                        model: [
                            {
                                icon: WeatherService.data.current.apparent_temperature_material_symbol,
                                value: WeatherService.data.current.apparent_temperature.toFixed(0) + "°",
                                label: "Feels like"
                            },
                            {
                                icon: WeatherService.data.current.wind_speed_material_symbol,
                                value: WeatherService.data.current.wind_speed.toFixed(0) + " km/h",
                                label: "Wind"
                            },
                            {
                                icon: WeatherService.data.current.humidity_material_symbol,
                                value: WeatherService.data.current.humidity + "%",
                                label: "Humidity"
                            },
                            {
                                icon: WeatherService.data.current.precipitation_material_symbol,
                                value: WeatherService.data.current.precipitation.toFixed(1) + " mm",
                                label: "Rain"
                            }
                        ]

                        delegate: WeatherCard {
                            id: metricItem
                            required property var modelData
                            required property int index

                            isFirst: index === 0
                            isLast: index === datasRepeater.count - 1

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16

                                MaterialSymbol {
                                    iconName: metricItem.modelData.icon
                                    iconSize: Theme.fontPixelSizes.hugeass + 2
                                    color: Theme.colors.white
                                    Layout.alignment: Qt.AlignCenter
                                    Layout.fillWidth: true
                                }

                                WeatherText {
                                    text: metricItem.modelData.value
                                    font.pixelSize: Theme.fontPixelSizes.normal
                                    font.weight: Font.Medium
                                    Layout.alignment: Qt.AlignCenter
                                    Layout.fillWidth: true
                                }

                                WeatherText {
                                    text: metricItem.modelData.label
                                    font.pixelSize: Theme.fontPixelSizes.smaller
                                    color: Theme.colors.textSecondary
                                    Layout.alignment: Qt.AlignCenter
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }

            // Bottom Hourly Forecast Section
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: parent.height * 0.35
                Layout.maximumHeight: parent.height * 0.35

                RowLayout {
                    anchors.fill: parent
                    spacing: 6

                    Repeater {
                        id: hourRepeater
                        model: expandedContentItem.upcomingHours
                        delegate: WeatherCard {
                            id: upcomingHourItem
                            required property var modelData
                            required property int index

                            isFirst: index === 0
                            isLast: index === hourRepeater.count - 1

                            customBottomLeftRadius: isFirst ? width / 2 : -1
                            customBottomRightRadius: isLast ? width / 2 : -1

                            Layout.fillHeight: true
                            Layout.fillWidth: true

                            ColumnLayout {
                                anchors.fill: parent

                                Item {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                }

                                WeatherText {
                                    text: (upcomingHourItem.modelData.temperature ?? 0).toFixed(0) + "°"
                                    font.pixelSize: Theme.fontPixelSizes.normal
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignCenter
                                }

                                StyledIcon {
                                    iconName: `google/${upcomingHourItem.modelData.weather_icon ?? "sunny"}`
                                    iconSize: Theme.fontPixelSizes.hugeass
                                    Layout.alignment: Qt.AlignCenter
                                }

                                WeatherText {
                                    text: upcomingHourItem.index === 0 ? "Now" : (upcomingHourItem.modelData.time ?? "").slice(11, 16)
                                    font.pixelSize: Theme.fontPixelSizes.small
                                    font.weight: Font.DemiBold
                                    Layout.alignment: Qt.AlignCenter
                                }

                                Item {
                                    Layout.fillHeight: true
                                    Layout.fillWidth: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
