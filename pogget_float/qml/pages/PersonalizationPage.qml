import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "个性化"
    horizontalPadding: width < 700 ? 24 : 42
    wrapperWidth: 820
    spacing: 20

    function themeText() {
        if (appSettings.themeMode === "Auto") return "跟随系统"
        if (appSettings.themeMode === "Dark") return "深色"
        return "浅色"
    }
    function layoutText() {
        if (appSettings.layoutMode === "single") return "一列"
        if (appSettings.layoutMode === "double") return "两列"
        return "自动"
    }

    Text { Layout.fillWidth: true; text: "这里仅显示当前配置。点击下方按钮进入完整设置界面。"; color: Theme.currentTheme.colors.textSecondaryColor; wrapMode: Text.WordWrap }

    ColumnLayout {
        Layout.fillWidth: true; spacing: 10
        Repeater {
            model: [
                { title: "主题", value: page.themeText(), icon: "ic_fluent_dark_theme_20_regular" },
                { title: "组件布局", value: page.layoutText(), icon: "ic_fluent_grid_20_regular" },
                { title: "天气位置", value: appSettings.weatherCity, icon: "ic_fluent_location_20_regular" }
            ]
            delegate: Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 78; radius: 13; color: Theme.currentTheme.colors.cardSecondaryColor
                RowLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 16
                    Icon { name: modelData.icon; size: 24; color: Theme.currentTheme.colors.primaryColor }
                    Text { Layout.fillWidth: true; text: modelData.title; font.pixelSize: 16; font.bold: true; color: Theme.currentTheme.colors.textColor; elide: Text.ElideRight }
                    Text { text: modelData.value; color: Theme.currentTheme.colors.textSecondaryColor }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true; Layout.preferredHeight: 132; radius: 16
        color: Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.12)
        RowLayout {
            anchors.fill: parent; anchors.margins: 22; spacing: 18
            ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text { Layout.fillWidth: true; text: "完整设置"; font.pixelSize: 19; font.bold: true; color: Theme.currentTheme.colors.textColor }
                Text { Layout.fillWidth: true; text: "调整主题色、亚克力效果、透明度、天气和倒计时。"; color: Theme.currentTheme.colors.textSecondaryColor; wrapMode: Text.WordWrap }
            }
            Button { text: "打开设置"; icon.name: "ic_fluent_settings_20_regular"; hoverable: false; onClicked: settingsWindowBackend.show() }
        }
    }
}
