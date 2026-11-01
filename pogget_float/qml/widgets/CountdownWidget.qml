import QtQuick
import QtQuick.Layouts
import RinUI

Item {
    id: countdown
    property int remainingSeconds: 0

    function updateRemaining() {
        const parts = appSettings.countdownTargetDate.split("-")
        if (parts.length !== 3) {
            remainingSeconds = 0
            return
        }
        const target = new Date(
            Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]),
            appSettings.countdownTargetHour, 0, 0
        )
        remainingSeconds = Math.max(0, Math.floor((target.getTime() - Date.now()) / 1000))
    }

    function displayText() {
        if (remainingSeconds <= 0)
            return "目标时间已到"
        let seconds = remainingSeconds
        const days = Math.floor(seconds / 86400)
        seconds %= 86400
        const hours = Math.floor(seconds / 3600)
        seconds %= 3600
        const minutes = Math.floor(seconds / 60)
        const remain = seconds % 60
        return days + " 天  "
            + (hours < 10 ? "0" : "") + hours + ":"
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (remain < 10 ? "0" : "") + remain
    }

    function progress() {
        const total = Math.max(1, appSettings.countdownDays * 86400)
        return Math.max(0, Math.min(1, remainingSeconds / total))
    }

    Component.onCompleted: updateRemaining()

    Connections {
        target: appSettings
        function onCountdownTargetDateChanged() { countdown.updateRemaining() }
        function onCountdownTargetHourChanged() { countdown.updateRemaining() }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: countdown.updateRemaining()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Text {
            Layout.fillWidth: true
            text: appSettings.countdownTitle
            font.pixelSize: 15
            color: Theme.currentTheme.colors.textSecondaryColor
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            text: countdown.displayText()
            font.pixelSize: 26
            font.bold: true
            color: Theme.currentTheme.colors.textColor
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 6
            radius: 3
            color: Theme.currentTheme.isDark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)

            Rectangle {
                width: parent.width * countdown.progress()
                height: parent.height
                radius: parent.radius
                color: Theme.currentTheme.colors.primaryColor
            }
        }

        Text {
            text: "目标 " + appSettings.countdownTargetDate + " "
                + (appSettings.countdownTargetHour < 10 ? "0" : "")
                + appSettings.countdownTargetHour + ":00"
            color: Theme.currentTheme.colors.textSecondaryColor
            font.pixelSize: 12
        }
    }
}
