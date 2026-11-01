import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentWindow {
    id: home
    width: 1040
    height: 700
    minimumWidth: 720
    minimumHeight: 540
    visible: true
    title: "FlowWidget"

    navigationView.navExpandWidth: 216
    navigationView.navMinimumExpandWidth: 860
    navigationView.objectName: "MainNavigationView"
    defaultPage: Qt.resolvedUrl("pages/DashboardPage.qml")

    function openSettings() {
        navigationView.push(Qt.resolvedUrl("pages/SettingsHubPage.qml"))
    }

    navigationItems: [
        { title: "主页", page: Qt.resolvedUrl("pages/DashboardPage.qml"), icon: "ic_fluent_home_20_regular", position: Position.Top },
        { title: "软件收纳", page: Qt.resolvedUrl("pages/SoftwarePage.qml"), icon: "ic_fluent_folder_open_20_regular" },
        { title: "小组件", page: Qt.resolvedUrl("pages/WidgetsPage.qml"), icon: "ic_fluent_grid_20_regular" },
        { title: "设置", page: Qt.resolvedUrl("pages/SettingsHubPage.qml"), icon: "ic_fluent_settings_20_regular" }
    ]

    Component.onCompleted: {
        Theme.setTheme(appSettings.themeMode)
        Theme.setThemeColor(appSettings.accentColor)
    }

    Connections {
        target: appSettings
        function onThemeModeChanged() { Theme.setTheme(appSettings.themeMode) }
        function onAccentColorChanged() { Theme.setThemeColor(appSettings.accentColor) }
        function onBackdropEffectChanged() { Theme.setBackdropEffect(appSettings.backdropEffect) }
    }
}
