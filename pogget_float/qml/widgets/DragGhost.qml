import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import RinUI

Window {
    id: ghost
    property string widgetId: ""
    property string widgetTitle: ""
    property string iconName: "ic_fluent_apps_20_regular"
    property bool overDesktop: false
    property bool snapped: false
    property bool magnetic: false
    property string direction: ""
    property string placementMessage: ""

    flags: Qt.Tool
        | Qt.FramelessWindowHint
        | Qt.WindowStaysOnTopHint
        | Qt.WindowDoesNotAcceptFocus
        | Qt.WindowTransparentForInput
    color: "transparent"
    width: 300
    height: 104
    visible: false

    function showAt(gx, gy) {
        x = Math.round(gx - 72)
        y = Math.round(gy - 28)
        snapped = false
        magnetic = false
        direction = ""
        placementMessage = ""
        visible = true
        body.opacity = 0
        body.scale = 0.84
        popIn.start()
    }

    function moveTo(gx, gy) {
        x = Math.round(gx - 72)
        y = Math.round(gy - 28)
    }

    function setPlacementState(isSnapped, isMagnetic, directionName, message) {
        const justSnapped = !!isSnapped && (!snapped || direction !== (directionName || ""))
        snapped = !!isSnapped
        magnetic = !!isMagnetic
        direction = directionName || ""
        placementMessage = message || ""
        if (justSnapped)
            playSnapFeedback()
    }

    function hideGhost() {
        popOut.start()
    }

    onVisibleChanged: if (!visible) {
        body.opacity = 0
        body.scale = 0.84
        overDesktop = false
        snapped = false
        magnetic = false
        direction = ""
        placementMessage = ""
    }

    Item {
        id: body
        anchors.fill: parent
        transformOrigin: Item.Center
        scale: 1
        opacity: 1

        Rectangle {
            anchors.fill: parent
            radius: 16
            color: Theme.currentTheme.isDark
                ? Qt.rgba(0.12, 0.13, 0.16, 0.92)
                : Qt.rgba(1, 1, 1, 0.94)
            border.width: ghost.overDesktop && ghost.snapped ? 2 : 1
            border.color: ghost.overDesktop
                ? Theme.currentTheme.colors.primaryColor
                : Theme.currentTheme.colors.cardBorderColor

            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 44
                Layout.preferredHeight: 44
                radius: 12
                color: Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.16)

                Rectangle {
                    id: snapHalo
                    anchors.centerIn: parent
                    width: 44
                    height: 44
                    radius: 22
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.currentTheme.colors.primaryColor
                    opacity: 0
                    scale: 0.72
                }

                Icon {
                    anchors.centerIn: parent
                    name: ghost.iconName
                    size: 22
                    color: Theme.currentTheme.colors.primaryColor
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: ghost.widgetTitle
                    font.pixelSize: 16
                    font.bold: true
                    color: Theme.currentTheme.colors.textColor
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: ghost.overDesktop
                        ? (ghost.placementMessage.length > 0 ? ghost.placementMessage : "靠近边缘自动吸附")
                        : "拖到窗口外放到桌面"
                    font.pixelSize: 12
                    color: ghost.overDesktop
                        ? Theme.currentTheme.colors.primaryColor
                        : Theme.currentTheme.colors.textSecondaryColor
                }
            }
        }
    }

    function playSnapFeedback() {
        snapPulse.restart()
    }

    SequentialAnimation {
        id: snapPulse
        ParallelAnimation {
            NumberAnimation {
                target: snapHalo
                property: "opacity"
                from: 0.46
                to: 0
                duration: 240
            }
            NumberAnimation {
                target: snapHalo
                property: "scale"
                from: 0.72
                to: 1.34
                duration: 240
                easing.type: Easing.OutCubic
            }
        }
    }

    ParallelAnimation {
        id: popIn
        NumberAnimation { target: body; property: "opacity"; to: 1; duration: 140; easing.type: Easing.OutCubic }
        NumberAnimation { target: body; property: "scale"; to: 1; duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }

    ParallelAnimation {
        id: popOut
        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 140; easing.type: Easing.InCubic }
        NumberAnimation { target: body; property: "scale"; to: 0.88; duration: 140; easing.type: Easing.InCubic }
        onFinished: ghost.visible = false
    }
}
