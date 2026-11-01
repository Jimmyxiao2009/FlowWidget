import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "外观与布局"
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
        ToolButton {
            icon.name: "ic_fluent_arrow_left_20_regular"
            onClicked: { var nav = page.navigation(); if (nav) nav.pop() }
        }
        Text { text: "返回设置"; color: Theme.currentTheme.colors.textSecondaryColor }
        Item { Layout.fillWidth: true }
    }

    Text { text: "应用外观"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor }

    SettingCard {
        Layout.fillWidth: true
        title: "应用主题"
        description: "跟随系统、浅色或深色"
        icon.name: "ic_fluent_dark_theme_20_regular"
        ComboBox {
            property var values: ["Auto", "Light", "Dark"]
            model: ["跟随系统", "浅色", "深色"]
            implicitWidth: 150
            Component.onCompleted: currentIndex = values.indexOf(appSettings.themeMode)
            onUserActivated: function(index) { if (index >= 0) appSettings.themeMode = values[index] }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "强调色"
        description: "按钮、开关与高亮元素使用的颜色"
        icon.name: "ic_fluent_color_20_regular"
        ComboBox {
            property var values: ["#605ed2", "#0067c0", "#107c10", "#c239b3", "#d83b01"]
            model: ["紫罗兰", "Windows 蓝", "森林绿", "洋红", "暖橙"]
            implicitWidth: 150
            Component.onCompleted: currentIndex = Math.max(0, values.indexOf(appSettings.accentColor))
            onUserActivated: function(index) { if (index >= 0) appSettings.accentColor = values[index] }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "窗口背景材质"
        description: "亚克力提供模糊透明背景，失焦时保持同样的材质，不会变灰"
        icon.name: "ic_fluent_square_hint_sparkles_20_regular"
        ComboBox {
            property var values: ["acrylic", "mica", "tabbed", "none"]
            model: ["亚克力（推荐）", "Mica", "Tabbed", "不使用材质"]
            implicitWidth: 160
            Component.onCompleted: currentIndex = values.indexOf(appSettings.backdropEffect)
            onUserActivated: function(index) { if (index >= 0) appSettings.backdropEffect = values[index] }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "浮窗透明度"
        description: "调整应用收纳箱与文件夹收纳箱的亚克力透明程度"
        icon.name: "ic_fluent_transparency_square_20_regular"
        RowLayout {
            Layout.preferredWidth: 235
            Slider {
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: appSettings.tileTransparency
                onMoved: appSettings.tileTransparency = value
            }
            Text {
                text: Math.round(appSettings.tileTransparency * 100) + "%"
                color: Theme.currentTheme.colors.textSecondaryColor
            }
        }
    }

    Text { text: "组件布局"; font.pixelSize: 17; font.bold: true; color: Theme.currentTheme.colors.textColor; Layout.topMargin: 8 }

    SettingCard {
        Layout.fillWidth: true
        title: "卡片透明度"
        description: "调整小组件卡片与窗口背景的融合程度"
        icon.name: "ic_fluent_transparency_square_20_regular"
        RowLayout {
            Layout.preferredWidth: 235
            Slider {
                Layout.fillWidth: true
                from: 0.55
                to: 1.0
                stepSize: 0.01
                value: appSettings.cardOpacity
                onMoved: appSettings.cardOpacity = value
            }
            Text { text: Math.round(appSettings.cardOpacity * 100) + "%"; color: Theme.currentTheme.colors.textSecondaryColor }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "排列方式"
        description: "小组件面板使用一列、两列或自动排列"
        icon.name: "ic_fluent_grid_20_regular"
        ComboBox {
            property var values: ["auto", "single", "double"]
            model: ["自动", "固定一列", "固定两列"]
            implicitWidth: 150
            Component.onCompleted: currentIndex = values.indexOf(appSettings.layoutMode)
            onUserActivated: function(index) { if (index >= 0) appSettings.layoutMode = values[index] }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "紧凑布局"
        description: "缩小组件卡片之间的间距"
        icon.name: "ic_fluent_contract_down_left_20_regular"
        Switch {
            checked: appSettings.compactLayout
            onClicked: appSettings.compactLayout = checked
        }
    }
}
