import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "日历与倒计时"
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

    Text { text: "日历"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor }

    SettingCard {
        Layout.fillWidth: true
        title: "显示星期"
        description: "在日期下方显示今天是星期几"
        icon.name: "ic_fluent_calendar_week_numbers_20_regular"
        Switch { checked: appSettings.showWeekday; onClicked: appSettings.showWeekday = checked }
    }

    Text { text: "倒计时目标"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor; Layout.topMargin: 8 }

    SettingCard {
        Layout.fillWidth: true
        title: "倒计时名称"
        description: "显示在剩余时间上方"
        icon.name: "ic_fluent_edit_20_regular"
        TextField {
            text: appSettings.countdownTitle
            placeholderText: "输入目标名称"
            implicitWidth: 220
            onEditingFinished: appSettings.countdownTitle = text.trim()
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "目标日期"
        description: "根据这个日期实时计算剩余时间"
        icon.name: "ic_fluent_calendar_clock_20_regular"
        DatePicker {
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
            from: 0
            to: 23
            value: appSettings.countdownTargetHour
            editable: true
            textFromValue: function(value, locale) { return (value < 10 ? "0" : "") + value + ":00" }
            valueFromText: function(text, locale) { return Math.max(0, Math.min(23, parseInt(text))) }
            onValueModified: appSettings.countdownTargetHour = value
        }
    }
}
