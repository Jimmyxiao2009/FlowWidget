import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "设置"
    wrapperWidth: 820
    horizontalPadding: width < 700 ? 24 : 38
    contentSpacing: 8

    function navigation() {
        var item = page
        while (item) {
            if (item.objectName === "MainNavigationView") return item
            item = item.parent
        }
        return null
    }

    function openPage(fileName) {
        var nav = navigation()
        if (nav) nav.push(Qt.resolvedUrl(fileName))
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.bottomMargin: 10
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3
            Text {
                text: "集中管理 FlowWidget"
                font.pixelSize: 20
                font.bold: true
                color: Theme.currentTheme.colors.textColor
            }
            Text {
                Layout.fillWidth: true
                text: "每类设置放在独立页面，避免内容堆叠。"
                color: Theme.currentTheme.colors.textSecondaryColor
                wrapMode: Text.WordWrap
            }
        }
        Button {
            text: "恢复默认"
            icon.name: "ic_fluent_arrow_reset_20_regular"
            hoverable: false
            onClicked: appSettings.resetDefaults()
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        Repeater {
            model: [
                { title: "外观与布局", detail: "主题、强调色、窗口材质、卡片透明度和排列方式", icon: "ic_fluent_paint_brush_20_regular", page: "AppearanceSettingsPage.qml" },
                { title: "组件显示", detail: "控制天气、日历、倒计时和问候语是否显示", icon: "ic_fluent_apps_list_detail_20_regular", page: "WidgetDisplaySettingsPage.qml" },
                { title: "天气", detail: "城市、温度单位与天气数据刷新", icon: "ic_fluent_weather_cloudy_20_regular", page: "WeatherSettingsPage.qml" },
                { title: "日历与倒计时", detail: "星期显示、目标名称、日期与时间", icon: "ic_fluent_calendar_clock_20_regular", page: "DateCountdownSettingsPage.qml" }
            ]

            delegate: Frame {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 82
                leftPadding: 14
                rightPadding: 14
                topPadding: 12
                bottomPadding: 12

                RowLayout {
                    anchors.fill: parent
                    spacing: 13

                    Rectangle {
                        width: 42
                        height: 42
                        radius: 8
                        color: Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.12)
                        Icon {
                            anchors.centerIn: parent
                            name: modelData.icon
                            size: 22
                            color: Theme.currentTheme.colors.primaryColor
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            Layout.fillWidth: true
                            text: modelData.title
                            font.pixelSize: 16
                            font.bold: true
                            color: Theme.currentTheme.colors.textColor
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: modelData.detail
                            color: Theme.currentTheme.colors.textSecondaryColor
                            elide: Text.ElideRight
                        }
                    }
                    Icon {
                        name: "ic_fluent_chevron_right_20_regular"
                        size: 18
                        color: Theme.currentTheme.colors.textSecondaryColor
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: false
                    onClicked: page.openPage(modelData.page)
                }
            }
        }
    }
}
