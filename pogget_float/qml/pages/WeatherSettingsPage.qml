import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "天气"
    wrapperWidth: 820
    horizontalPadding: width < 700 ? 24 : 38
    contentSpacing: 10

    function navigation() {
        var item = page
        while (item) {
            if (item.objectName === "MainNavigationView") return item
            item = item.parent
        }
        return null
    }

    RowLayout {
        Layout.fillWidth: true
        ToolButton { icon.name: "ic_fluent_arrow_left_20_regular"; onClicked: { var nav = page.navigation(); if (nav) nav.pop() } }
        Text { text: "返回设置"; color: Theme.currentTheme.colors.textSecondaryColor }
        Item { Layout.fillWidth: true }
    }

    Text {
        Layout.fillWidth: true
        text: "天气数据来自 Open-Meteo。更改城市后会立即重新获取。"
        color: Theme.currentTheme.colors.textSecondaryColor
        wrapMode: Text.WordWrap
    }

    Text { text: "位置与单位"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor; Layout.topMargin: 8 }

    SettingCard {
        Layout.fillWidth: true
        title: "城市"
        description: "天气卡片显示的位置"
        icon.name: "ic_fluent_location_20_regular"
        TextField {
            id: cityField
            text: appSettings.weatherCity
            placeholderText: "输入城市名称"
            implicitWidth: 200
            onEditingFinished: {
                appSettings.weatherCity = text.trim()
                weatherBackend.refresh()
            }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "温度单位"
        description: "选择摄氏度或华氏度"
        icon.name: "ic_fluent_temperature_20_regular"
        ComboBox {
            property var values: ["C", "F"]
            model: ["摄氏度（°C）", "华氏度（°F）"]
            implicitWidth: 160
            Component.onCompleted: currentIndex = values.indexOf(appSettings.temperatureUnit)
            onUserActivated: function(index) { if (index >= 0) appSettings.temperatureUnit = values[index] }
        }
    }

    Text { text: "数据状态"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor; Layout.topMargin: 8 }

    SettingCard {
        Layout.fillWidth: true
        title: "天气数据"
        description: weatherBackend.loading
            ? "正在连接 Open-Meteo 获取天气"
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
}
