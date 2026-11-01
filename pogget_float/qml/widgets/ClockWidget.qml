import QtQuick
import QtQuick.Layouts
import RinUI

Item {
    id: clock
    property date currentTime: new Date()

    function weekday(value) {
        return ["周日", "周一", "周二", "周三", "周四", "周五", "周六"][value.getDay()]
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.currentTime = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: Qt.formatTime(clock.currentTime, "HH:mm")
                font.pixelSize: 46
                font.bold: true
                color: Theme.currentTheme.colors.textColor
                renderType: Text.NativeRendering
            }

            ColumnLayout {
                Layout.alignment: Qt.AlignBottom
                spacing: 1
                Text {
                    text: Qt.formatTime(clock.currentTime, "ss")
                    font.pixelSize: 18
                    font.bold: true
                    color: Theme.currentTheme.colors.primaryColor
                }
                Text {
                    text: "秒"
                    font.pixelSize: 11
                    color: Theme.currentTheme.colors.textSecondaryColor
                }
            }

            Item { Layout.fillWidth: true }

            Rectangle {
                Layout.preferredWidth: 54
                Layout.preferredHeight: 30
                radius: 8
                color: Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.14)
                Text {
                    anchors.centerIn: parent
                    text: "实时"
                    font.pixelSize: 12
                    color: Theme.currentTheme.colors.primaryColor
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.currentTheme.colors.cardBorderColor
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Icon {
                name: "ic_fluent_calendar_ltr_20_regular"
                size: 16
                color: Theme.currentTheme.colors.primaryColor
            }
            Text {
                Layout.fillWidth: true
                text: Qt.formatDate(clock.currentTime, "yyyy年M月d日") + " · " + clock.weekday(clock.currentTime)
                font.pixelSize: 13
                color: Theme.currentTheme.colors.textSecondaryColor
            }
        }
    }
}
