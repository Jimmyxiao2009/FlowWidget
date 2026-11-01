import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "小组件"
    horizontalPadding: width < 700 ? 24 : 42
    wrapperWidth: 860
    spacing: 20

    function statusText(enabled) { return enabled ? "已启用" : "未启用" }
    property int pinRevision: 0

    Connections {
        target: desktopWidgetBackend
        function onPinnedChanged() { page.pinRevision++ }
        function onLockChanged() { page.pinRevision++ }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true; spacing: 4
            Text { Layout.fillWidth: true; text: "桌面信息，一眼看清"; font.pixelSize: 21; font.bold: true; color: Theme.currentTheme.colors.textColor }
            Text { Layout.fillWidth: true; text: "磁贴风格和 Windows 11 小组件接近。按住标题拖到桌面即可固定，锁定后不会被误移。"; color: Theme.currentTheme.colors.textSecondaryColor; wrapMode: Text.WordWrap }
        }
        Button { text: "打开组件面板"; icon.name: "ic_fluent_open_20_regular"; hoverable: false; onClicked: widgetBoardBackend.show() }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 12
        Repeater {
            model: [
                { id: "weather", title: "天气", description: weatherBackend.loading ? "正在更新天气" : weatherBackend.condition + " · " + weatherBackend.locationName, enabled: appSettings.weatherEnabled, icon: "ic_fluent_weather_cloudy_20_regular" },
                { id: "calendar", title: "日历", description: "显示今天的日期和星期", enabled: appSettings.calendarEnabled, icon: "ic_fluent_calendar_ltr_20_regular" },
                { id: "countdown", title: "倒计时", description: appSettings.countdownEnabled ? appSettings.countdownTitle : "尚未设置倒计时", enabled: appSettings.countdownEnabled, icon: "ic_fluent_timer_20_regular" },
                { id: "clock", title: "时钟", description: "精确显示当前时间和日期", enabled: appSettings.clockEnabled, icon: "ic_fluent_clock_20_regular" },
                { id: "focus", title: "专注", description: "25 分钟专注计时器", enabled: appSettings.focusEnabled, icon: "ic_fluent_target_20_regular" },
                { id: "notes", title: "便签", description: "随手记下当前想法", enabled: appSettings.notesEnabled, icon: "ic_fluent_note_20_regular" }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 92; radius: 14; color: Theme.currentTheme.colors.cardSecondaryColor
                RowLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 16
                    Icon { name: modelData.icon; size: 26; color: Theme.currentTheme.colors.primaryColor }
                    ColumnLayout {
                        Layout.fillWidth: true; spacing: 3
                        Text { Layout.fillWidth: true; text: modelData.title; font.pixelSize: 16; font.bold: true; color: Theme.currentTheme.colors.textColor; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: modelData.description; color: Theme.currentTheme.colors.textSecondaryColor; elide: Text.ElideRight }
                    }
                    Text {
                        text: {
                            page.pinRevision
                            if (desktopWidgetBackend.isPinned(modelData.id))
                                return desktopWidgetBackend.isLocked(modelData.id) ? "桌面已锁定" : "已固定到桌面"
                            return page.statusText(modelData.enabled)
                        }
                        color: {
                            page.pinRevision
                            return (desktopWidgetBackend.isPinned(modelData.id) || modelData.enabled)
                                ? Theme.currentTheme.colors.primaryColor
                                : Theme.currentTheme.colors.textSecondaryColor
                        }
                    }
                }
            }
        }
    }

    Button { text: "管理小组件设置"; icon.name: "ic_fluent_settings_20_regular"; hoverable: false; onClicked: settingsWindowBackend.show() }
}
