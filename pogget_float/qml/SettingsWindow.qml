import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

ApplicationWindow {
    id: settingsWindow
    width: 760
    height: 720
    minimumWidth: 640
    minimumHeight: 520
    visible: true
    title: "FlowWidget 设置"
    minimizeVisible: false
    maximizeVisible: false

    Component.onCompleted: {
        Theme.setTheme(appSettings.themeMode)
        Theme.setThemeColor(appSettings.accentColor)
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: settingsWindow.titleBarHeight + 12
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        anchors.bottomMargin: 18

        Connections {
            target: appSettings
            function onLayoutModeChanged() { layoutCombo.currentIndex = layoutCombo.values.indexOf(appSettings.layoutMode) }
            function onTemperatureUnitChanged() { unitCombo.currentIndex = unitCombo.values.indexOf(appSettings.temperatureUnit) }
            function onBackdropEffectChanged() { backdropCombo.currentIndex = backdropCombo.values.indexOf(appSettings.backdropEffect); Theme.setBackdropEffect(appSettings.backdropEffect) }
            function onThemeModeChanged() { themeCombo.currentIndex = themeCombo.values.indexOf(appSettings.themeMode); Theme.setTheme(appSettings.themeMode) }
            function onAccentColorChanged() { accentCombo.currentIndex = Math.max(0, accentCombo.values.indexOf(appSettings.accentColor)); Theme.setThemeColor(appSettings.accentColor) }
            function onWeatherCityChanged() { cityField.text = appSettings.weatherCity }
            function onCountdownTitleChanged() { countdownTitleField.text = appSettings.countdownTitle }
            function onCountdownTargetDateChanged() { countdownDatePicker.setDate(appSettings.countdownTargetDate) }
            function onCountdownTargetHourChanged() { countdownHourSpin.value = appSettings.countdownTargetHour }
            function onCardOpacityChanged() { opacitySlider.value = appSettings.cardOpacity }
            function onCompactLayoutChanged() { compactSwitch.checked = appSettings.compactLayout }
            function onShowGreetingChanged() { greetingSwitch.checked = appSettings.showGreeting }
            function onWeatherEnabledChanged() { weatherSwitch.checked = appSettings.weatherEnabled }
            function onCalendarEnabledChanged() { calendarSwitch.checked = appSettings.calendarEnabled }
            function onCountdownEnabledChanged() { countdownSwitch.checked = appSettings.countdownEnabled }
            function onShowWeekdayChanged() { weekdaySwitch.checked = appSettings.showWeekday }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text {
                        text: "设置"
                        font.pixelSize: 27
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                    }
                    Text {
                        text: "集中控制小组件、布局与个性化"
                        color: Theme.currentTheme.colors.textSecondaryColor
                    }
                }

                Button {
                    text: "恢复默认"
                    icon.name: "ic_fluent_arrow_reset_20_regular"
                    hoverable: false
                    onClicked: appSettings.resetDefaults()
                }
            }

            Flickable {
                id: settingsScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight

                ScrollBar.vertical: ScrollBar {}

                ColumnLayout {
                    id: settingsColumn
                    width: settingsScroll.width - 10
                    spacing: 8

                    Text {
                        text: "外观与布局"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                        Layout.topMargin: 4
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "应用主题"
                        description: "跟随系统、浅色或深色"
                        icon.name: "ic_fluent_dark_theme_20_regular"

                        ComboBox {
                            id: themeCombo
                            objectName: "themeCombo"
                            property var values: ["Auto", "Light", "Dark"]
                            property bool ready: false
                            model: ["跟随系统", "浅色", "深色"]
                            implicitWidth: 140
                            Component.onCompleted: {
                                currentIndex = values.indexOf(appSettings.themeMode)
                                ready = true
                            }
                            onUserActivated: function(index) { if (index >= 0) appSettings.themeMode = values[index] }
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "强调色"
                        description: "按钮、开关和高亮元素使用的颜色"
                        icon.name: "ic_fluent_color_20_regular"

                        ComboBox {
                            id: accentCombo
                            objectName: "accentCombo"
                            property var values: ["#605ed2", "#0067c0", "#107c10", "#c239b3", "#d83b01"]
                            property bool ready: false
                            model: ["紫罗兰", "Windows 蓝", "森林绿", "洋红", "暖橙"]
                            implicitWidth: 140
                            Component.onCompleted: {
                                currentIndex = Math.max(0, values.indexOf(appSettings.accentColor))
                                ready = true
                            }
                            onUserActivated: function(index) { if (index >= 0) appSettings.accentColor = values[index] }
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "卡片透明度"
                        description: "调整小组件卡片与 Mica 背景的融合程度"
                        icon.name: "ic_fluent_square_multiple_20_regular"

                        Slider {
                            id: opacitySlider
                            objectName: "opacitySlider"
                            property bool ready: false
                            from: 0.55
                            to: 1.0
                            stepSize: 0.01
                            value: appSettings.cardOpacity
                            implicitWidth: 150
                            Component.onCompleted: ready = true
                            onValueChanged: if (ready) appSettings.cardOpacity = value
                        }
                        Text {
                            text: Math.round(appSettings.cardOpacity * 100) + "%"
                            color: Theme.currentTheme.colors.textSecondaryColor
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "窗口背景材质"
                        description: "亚克力提供模糊透明背景，失焦时保持同样的材质，不会变灰"
                        icon.name: "ic_fluent_square_hint_sparkles_20_regular"

                        ComboBox {
                            id: backdropCombo
                            objectName: "backdropCombo"
                            property var values: ["acrylic", "mica", "tabbed", "none"]
                            property bool ready: false
                            model: ["亚克力（推荐）", "Mica", "Tabbed", "不使用材质"]
                            implicitWidth: 150
                            Component.onCompleted: {
                                currentIndex = values.indexOf(appSettings.backdropEffect)
                                ready = true
                            }
                            onUserActivated: function(index) { if (index >= 0) appSettings.backdropEffect = values[index] }
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "排列方式"
                        description: "控制小组件面板使用一列、两列或自动排列"
                        icon.name: "ic_fluent_grid_20_regular"

                        ComboBox {
                            id: layoutCombo
                            objectName: "layoutCombo"
                            property var values: ["auto", "single", "double"]
                            property bool ready: false
                            model: ["自动", "固定一列", "固定两列"]
                            implicitWidth: 140
                            Component.onCompleted: {
                                currentIndex = values.indexOf(appSettings.layoutMode)
                                ready = true
                            }
                            onUserActivated: function(index) { if (index >= 0) appSettings.layoutMode = values[index] }
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "紧凑布局"
                        description: "缩小卡片之间的间距"
                        icon.name: "ic_fluent_contract_down_left_20_regular"
                        Switch {
                            id: compactSwitch
                            objectName: "compactSwitch"
                            property bool ready: false
                            checked: appSettings.compactLayout
                            Component.onCompleted: ready = true
                            onCheckedChanged: if (ready) appSettings.compactLayout = checked
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "显示问候语"
                        description: "在面板顶部显示上午好、下午好或晚上好"
                        icon.name: "ic_fluent_text_20_regular"
                        Switch {
                            id: greetingSwitch
                            property bool ready: false
                            checked: appSettings.showGreeting
                            Component.onCompleted: ready = true
                            onCheckedChanged: if (ready) appSettings.showGreeting = checked
                        }
                    }

                    Text {
                        text: "小组件开关"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                        Layout.topMargin: 12
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "天气"
                        description: "在小组件面板显示天气卡片"
                        icon.name: "ic_fluent_weather_cloudy_20_regular"
                        Switch {
                            id: weatherSwitch
                            property bool ready: false
                            checked: appSettings.weatherEnabled
                            Component.onCompleted: ready = true
                            onCheckedChanged: if (ready) appSettings.weatherEnabled = checked
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "日历"
                        description: "在小组件面板显示日历卡片"
                        icon.name: "ic_fluent_calendar_ltr_20_regular"
                        Switch {
                            id: calendarSwitch
                            property bool ready: false
                            checked: appSettings.calendarEnabled
                            Component.onCompleted: ready = true
                            onCheckedChanged: if (ready) appSettings.calendarEnabled = checked
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "倒计时"
                        description: "在小组件面板显示倒计时卡片"
                        icon.name: "ic_fluent_timer_20_regular"
                        Switch {
                            id: countdownSwitch
                            property bool ready: false
                            checked: appSettings.countdownEnabled
                            Component.onCompleted: ready = true
                            onCheckedChanged: if (ready) appSettings.countdownEnabled = checked
                        }
                    }

                    Text {
                        text: "天气设置"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                        Layout.topMargin: 12
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "城市"
                        description: "天气卡片显示的位置"
                        icon.name: "ic_fluent_location_20_regular"
                        TextField {
                            id: cityField
                            text: appSettings.weatherCity
                            placeholderText: "输入城市名称"
                            implicitWidth: 180
                            onEditingFinished: {
                                appSettings.weatherCity = text
                                weatherBackend.refresh()
                            }
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "天气数据"
                        description: weatherBackend.loading
                            ? "正在连接 Open-Meteo 获取真实天气"
                            : weatherBackend.errorMessage.length > 0
                                ? weatherBackend.errorMessage
                                : "已更新 " + (weatherBackend.updatedText || "刚刚")
                        icon.name: weatherBackend.errorMessage.length > 0
                            ? "ic_fluent_error_circle_20_regular"
                            : "ic_fluent_arrow_clockwise_20_regular"
                        Button {
                            text: weatherBackend.loading ? "刷新中" : "立即刷新"
                            enabled: !weatherBackend.loading
                            hoverable: false
                            onClicked: weatherBackend.refresh()
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "温度单位"
                        description: "摄氏度或华氏度"
                        icon.name: "ic_fluent_temperature_20_regular"
                        ComboBox {
                            id: unitCombo
                            property var values: ["C", "F"]
                            property bool ready: false
                            model: ["摄氏度（°C）", "华氏度（°F）"]
                            implicitWidth: 150
                            Component.onCompleted: {
                                currentIndex = values.indexOf(appSettings.temperatureUnit)
                                ready = true
                            }
                            onUserActivated: function(index) { if (index >= 0) appSettings.temperatureUnit = values[index] }
                        }
                    }

                    Text {
                        text: "日历与倒计时"
                        font.pixelSize: 15
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                        Layout.topMargin: 12
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "显示星期"
                        description: "在日期下方显示今天是星期几"
                        icon.name: "ic_fluent_calendar_week_numbers_20_regular"
                        Switch {
                            id: weekdaySwitch
                            property bool ready: false
                            checked: appSettings.showWeekday
                            Component.onCompleted: ready = true
                            onCheckedChanged: if (ready) appSettings.showWeekday = checked
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "倒计时名称"
                        description: "显示在倒计时数字上方"
                        icon.name: "ic_fluent_edit_20_regular"
                        TextField {
                            id: countdownTitleField
                            text: appSettings.countdownTitle
                            placeholderText: "输入目标名称"
                            implicitWidth: 200
                            onEditingFinished: appSettings.countdownTitle = text
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "目标日期"
                        description: "倒计时会根据这个日期实时计算剩余时间"
                        icon.name: "ic_fluent_calendar_clock_20_regular"
                        DatePicker {
                            id: countdownDatePicker
                            startYear: new Date().getFullYear()
                            endYear: new Date().getFullYear() + 30
                            Component.onCompleted: setDate(appSettings.countdownTargetDate)
                            onDateChanged: {
                                if (date.length > 0 && date !== appSettings.countdownTargetDate)
                                    appSettings.countdownTargetDate = date
                            }
                        }
                    }

                    SettingCard {
                        Layout.fillWidth: true
                        title: "目标时间"
                        description: "目标日期当天的小时，使用 24 小时制"
                        icon.name: "ic_fluent_clock_20_regular"
                        SpinBox {
                            id: countdownHourSpin
                            from: 0
                            to: 23
                            value: appSettings.countdownTargetHour
                            editable: true
                            textFromValue: function(value, locale) {
                                return (value < 10 ? "0" : "") + value + ":00"
                            }
                            valueFromText: function(text, locale) {
                                return Math.max(0, Math.min(23, parseInt(text)))
                            }
                            onValueModified: appSettings.countdownTargetHour = value
                        }
                    }

                    Item { Layout.preferredHeight: 10 }
                }
            }
        }
    }
}
