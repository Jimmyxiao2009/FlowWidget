import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: ""
    horizontalPadding: 0
    wrapperWidth: Math.min(width - 42 * 2, 960)
    spacing: 18

    function pageSurface() {
        return Theme.currentTheme.isDark
            ? Qt.rgba(0.08, 0.12, 0.14, 0.78)
            : Qt.rgba(1, 1, 1, 0.72)
    }

    function bannerColor() {
        return Theme.currentTheme.isDark ? "#12353d" : "#b9e2e8"
    }

    contentHeader: Item {
        width: parent.width
        height: 244

        Rectangle {
            anchors.fill: parent
            color: page.bannerColor()

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 5
                color: Theme.currentTheme.colors.primaryColor
            }

            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 42
                anchors.bottomMargin: 28
                spacing: 5

                Text {
                    text: "FlowWidget"
                    font.pixelSize: 34
                    font.bold: true
                    color: Theme.currentTheme.isDark ? "#f4fbfc" : "#164b57"
                }

                Text {
                    text: "桌面摆件收纳盒"
                    font.pixelSize: 16
                    color: Theme.currentTheme.isDark ? "#c1dfe3" : "#387481"
                }
            }

            // A compact workspace preview gives the banner the same product-first feeling
            // as Class Widgets without turning the page into a promotional card wall.
            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: 36
                anchors.topMargin: 30
                spacing: 10

                Repeater {
                    model: [
                        { label: "天气", value: weatherBackend.loading ? "更新中" : weatherBackend.condition, width: 112 },
                        { label: "软件", value: shortcutModel.count + " 个", width: 96 },
                        { label: "小组件", value: appSettings.layoutMode === "single" ? "一列" : "两列", width: 112 }
                    ]

                    delegate: Rectangle {
                        width: modelData.width
                        height: 72
                        radius: 14
                        color: Theme.currentTheme.isDark ? "#1d454d" : "#eaf7f8"
                        border.width: 1
                        border.color: Theme.currentTheme.isDark ? "#47757c" : "#ffffff"

                        Column {
                            anchors.left: parent.left
                            anchors.bottom: parent.bottom
                            anchors.leftMargin: 13
                            anchors.bottomMargin: 11
                            spacing: 2
                            Text {
                                text: modelData.label
                                font.pixelSize: 12
                                color: Theme.currentTheme.isDark ? "#b8d9dd" : "#5a7f86"
                            }
                            Text {
                                text: modelData.value
                                font.pixelSize: 17
                                font.bold: true
                                color: Theme.currentTheme.isDark ? "#f4fbfc" : "#164b57"
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    InfoBar {
        Layout.fillWidth: true
        severity: Severity.Info
        title: "工作区已准备好"
        text: "把快捷方式拖入收纳盒，小组件会按照你的布局设置显示。"
        closable: false
    }

    Text {
        text: "常用入口"
        font.pixelSize: 17
        font.bold: true
        color: Theme.currentTheme.colors.textColor
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            radius: 10
            color: page.pageSurface()
            border.width: 1
            border.color: Theme.currentTheme.colors.cardBorderColor

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: shelfBackend.show()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8

                Icon {
                    name: "ic_fluent_folder_open_20_regular"
                    size: 28
                    color: Theme.currentTheme.colors.primaryColor
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: "软件收纳"
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.currentTheme.colors.textColor
                }
                Text {
                    Layout.fillWidth: true
                    text: "拖入快捷方式并一键启动"
                    color: Theme.currentTheme.colors.textSecondaryColor
                    elide: Text.ElideRight
                }
            }

            Icon {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14
                anchors.bottomMargin: 13
                name: "ic_fluent_open_20_regular"
                size: 17
                color: Theme.currentTheme.colors.textSecondaryColor
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            radius: 10
            color: page.pageSurface()
            border.width: 1
            border.color: Theme.currentTheme.colors.cardBorderColor

            TapHandler {
                acceptedButtons: Qt.LeftButton
                onTapped: widgetBoardBackend.show()
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 8

                Icon {
                    name: "ic_fluent_grid_20_regular"
                    size: 28
                    color: Theme.currentTheme.colors.primaryColor
                }
                Item { Layout.fillHeight: true }
                Text {
                    Layout.fillWidth: true
                    text: "小组件"
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.currentTheme.colors.textColor
                }
                Text {
                    Layout.fillWidth: true
                    text: "磁贴风格，可拖到桌面锁定"
                    color: Theme.currentTheme.colors.textSecondaryColor
                    elide: Text.ElideRight
                }
            }

            Icon {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: 14
                anchors.bottomMargin: 13
                name: "ic_fluent_open_20_regular"
                size: 17
                color: Theme.currentTheme.colors.textSecondaryColor
            }
        }
    }

    SettingCard {
        Layout.fillWidth: true
        title: "个性化设置"
        description: "主题、亚克力效果、透明度和组件布局"
        icon.name: "ic_fluent_settings_20_regular"
        clickable: true
        hoverable: false
        onClicked: settingsWindowBackend.show()
    }
}
