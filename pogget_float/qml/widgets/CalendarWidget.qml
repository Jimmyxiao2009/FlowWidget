import QtQuick
import QtQuick.Layouts
import RinUI

Item {
    id: calendar

    property var now: new Date()

    function weekdayName(day) {
        return ["日", "一", "二", "三", "四", "五", "六"][day]
    }

    function weekDate(index) {
        const date = new Date(now)
        date.setDate(now.getDate() - now.getDay() + index)
        return date
    }

    function isToday(date) {
        return date.getDate() === now.getDate()
            && date.getMonth() === now.getMonth()
            && date.getFullYear() === now.getFullYear()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: calendar.now = new Date()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Text {
            text: (calendar.now.getMonth() + 1) + "月"
            font.pixelSize: 13
            color: Theme.currentTheme.colors.primaryColor
        }
        Text {
            text: calendar.now.getDate()
            font.pixelSize: 42
            font.bold: true
            color: Theme.currentTheme.colors.textColor
        }
        Text {
            visible: appSettings.showWeekday
            text: "星期" + calendar.weekdayName(calendar.now.getDay())
            font.pixelSize: 16
            color: Theme.currentTheme.colors.textColor
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: 7
                delegate: Column {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: calendar.weekdayName(index)
                        font.pixelSize: 11
                        color: Theme.currentTheme.colors.textSecondaryColor
                    }
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: calendar.isToday(calendar.weekDate(index))
                            ? Theme.currentTheme.colors.primaryColor
                            : "transparent"
                        Text {
                            anchors.centerIn: parent
                            text: calendar.weekDate(index).getDate()
                            font.pixelSize: 12
                            font.bold: calendar.isToday(calendar.weekDate(index))
                            color: calendar.isToday(calendar.weekDate(index))
                                ? "#ffffff"
                                : Theme.currentTheme.colors.textColor
                        }
                    }
                }
            }
        }
    }
}
