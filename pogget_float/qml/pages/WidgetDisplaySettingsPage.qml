import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "组件显示"
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
        Button { text: "打开组件面板"; icon.name: "ic_fluent_open_20_regular"; hoverable: false; onClicked: widgetBoardBackend.show() }
    }

    Text {
        Layout.fillWidth: true
        text: "只保留你真正需要的信息。关闭组件不会删除已有设置。固定到桌面的磁贴可以单独锁定位置。"
        color: Theme.currentTheme.colors.textSecondaryColor
        wrapMode: Text.WordWrap
    }

    Text { text: "面板内容"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor; Layout.topMargin: 8 }

    SettingCard {
        Layout.fillWidth: true
        title: "天气"
        description: "显示当前天气、温度与城市"
        icon.name: "ic_fluent_weather_cloudy_20_regular"
        Switch { checked: appSettings.weatherEnabled; onClicked: appSettings.weatherEnabled = checked }
    }
    SettingCard {
        Layout.fillWidth: true
        title: "日历"
        description: "显示今天的日期与星期"
        icon.name: "ic_fluent_calendar_ltr_20_regular"
        Switch { checked: appSettings.calendarEnabled; onClicked: appSettings.calendarEnabled = checked }
    }
    SettingCard {
        Layout.fillWidth: true
        title: "倒计时"
        description: "显示目标日期的剩余时间"
        icon.name: "ic_fluent_timer_20_regular"
        Switch { checked: appSettings.countdownEnabled; onClicked: appSettings.countdownEnabled = checked }
    }

    Text { text: "页面信息"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor; Layout.topMargin: 8 }

    SettingCard {
        Layout.fillWidth: true
        title: "显示问候语"
        description: "在组件面板顶部显示上午好、下午好或晚上好"
        icon.name: "ic_fluent_text_20_regular"
        Switch { checked: appSettings.showGreeting; onClicked: appSettings.showGreeting = checked }
    }
}
