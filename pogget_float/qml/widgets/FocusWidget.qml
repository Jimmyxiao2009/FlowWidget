import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

Item {
    id: focus
    property int totalSeconds: 25 * 60
    property int remainingSeconds: totalSeconds
    property bool running: false

    function formatTime(value) {
        const minutes = Math.floor(value / 60)
        const seconds = value % 60
        return (minutes < 10 ? "0" : "") + minutes + ":" + (seconds < 10 ? "0" : "") + seconds
    }

    function resetTimer() {
        running = false
        remainingSeconds = totalSeconds
    }

    Timer {
        interval: 1000
        running: focus.running
        repeat: true
        onTriggered: {
            if (focus.remainingSeconds > 0) {
                focus.remainingSeconds -= 1
            } else {
                focus.running = false
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 42
                radius: 12
                color: Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.14)
                Icon {
                    anchors.centerIn: parent
                    name: "ic_fluent_target_20_regular"
                    size: 22
                    color: Theme.currentTheme.colors.primaryColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text {
                    text: focus.running ? "专注进行中" : "准备开始专注"
                    font.pixelSize: 14
                    font.bold: true
                    color: Theme.currentTheme.colors.textColor
                }
                Text {
                    text: focus.running ? "保持当前窗口，专心完成一件事" : "25 分钟专注 · 5 分钟休息"
                    font.pixelSize: 11
                    color: Theme.currentTheme.colors.textSecondaryColor
                    elide: Text.ElideRight
                }
            }

            Text {
                text: focus.formatTime(focus.remainingSeconds)
                font.pixelSize: 22
                font.bold: true
                color: Theme.currentTheme.colors.primaryColor
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 6
            radius: 3
            color: Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.12)

            Rectangle {
                width: parent.width * (1 - focus.remainingSeconds / focus.totalSeconds)
                height: parent.height
                radius: 3
                color: Theme.currentTheme.colors.primaryColor
                Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                Layout.fillWidth: true
                text: focus.running ? "暂停" : "开始"
                icon.name: focus.running ? "ic_fluent_pause_20_filled" : "ic_fluent_play_20_filled"
                flat: true
                hoverable: false
                onClicked: focus.running = !focus.running
            }

            ToolButton {
                icon.name: "ic_fluent_arrow_reset_20_regular"
                size: 18
                flat: true
                hoverable: false
                onClicked: focus.resetTimer()
            }
        }
    }
}
