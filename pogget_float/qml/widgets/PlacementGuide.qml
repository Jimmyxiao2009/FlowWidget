import QtQuick
import QtQuick.Window
import RinUI

Window {
    id: guide
    property bool snapped: false
    property bool magnetic: false
    property string direction: ""
    property string statusText: ""
    property int targetWidth: 336
    property int targetHeight: 196

    flags: Qt.Tool
        | Qt.FramelessWindowHint
        | Qt.WindowStaysOnTopHint
        | Qt.WindowDoesNotAcceptFocus
        | Qt.WindowTransparentForInput
    color: "transparent"
    width: targetWidth
    height: targetHeight
    visible: false

    function showPlacement(px, py, pw, ph, isSnapped, isMagnetic, directionName, message) {
        const nextDirection = directionName || ""
        const justSnapped = isSnapped && (!snapped || direction !== nextDirection)
        hideAnimation.stop()
        appearAnimation.stop()
        targetWidth = Math.max(120, Math.round(pw))
        targetHeight = Math.max(100, Math.round(ph))
        snapped = !!isSnapped
        magnetic = !!isMagnetic
        direction = nextDirection
        statusText = message || ""
        x = Math.round(px)
        y = Math.round(py)
        if (!visible) {
            body.opacity = 0
            visible = true
        }
        if (justSnapped)
            snapPulse.restart()
        appearAnimation.start()
    }

    function hideGuide() {
        if (!visible)
            return
        hideAnimation.start()
    }

    Rectangle {
        id: body
        anchors.fill: parent
        transformOrigin: Item.Center
        radius: 16
        color: guide.snapped
            ? Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.12)
            : Qt.alpha(Theme.currentTheme.colors.primaryColor, 0.05)
        border.width: guide.snapped ? 2 : 1
        border.color: Qt.alpha(Theme.currentTheme.colors.primaryColor, guide.snapped ? 0.86 : 0.42)

        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }
    }

    Behavior on x {
        NumberAnimation {
            duration: guide.snapped ? 160 : (guide.magnetic ? 90 : 55)
            easing.type: guide.snapped ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: guide.snapped ? 0.8 : 0
        }
    }
    Behavior on y {
        NumberAnimation {
            duration: guide.snapped ? 160 : (guide.magnetic ? 90 : 55)
            easing.type: guide.snapped ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: guide.snapped ? 0.8 : 0
        }
    }

    Rectangle {
        id: magnetMarker
        visible: guide.magnetic
        x: guide.direction === "right"
            ? parent.width - width
            : (guide.direction === "left" ? 0 : (parent.width - width) / 2)
        y: guide.direction === "below"
            ? parent.height - height
            : (guide.direction === "above" ? 0 : (parent.height - height) / 2)
        width: guide.direction === "left" || guide.direction === "right" ? 38 : 4
        height: guide.direction === "above" || guide.direction === "below" ? 38 : 4
        radius: 2
        color: Theme.currentTheme.colors.primaryColor
        opacity: guide.snapped ? 0.9 : 0.52
        transformOrigin: Item.Center

        Rectangle {
            anchors.centerIn: parent
            width: guide.direction === "left" || guide.direction === "right" ? 8 : 18
            height: guide.direction === "above" || guide.direction === "below" ? 18 : 8
            radius: 4
            color: Theme.currentTheme.colors.primaryColor
            opacity: 0.42
        }
    }

    Rectangle {
        visible: guide.statusText.length > 0
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 12
        radius: 8
        color: Qt.alpha(
            Theme.currentTheme.colors.primaryColor,
            guide.snapped ? 0.18 : (guide.magnetic ? 0.14 : 0.12)
        )
        width: statusLabel.implicitWidth + 20
        height: 28

        Text {
            id: statusLabel
            anchors.centerIn: parent
            text: guide.statusText
            font.pixelSize: 12
            font.bold: guide.snapped
            color: Theme.currentTheme.colors.primaryColor
        }
    }

    SequentialAnimation {
        id: snapPulse
        NumberAnimation {
            target: body
            property: "scale"
            to: 0.97
            duration: 70
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: body
            property: "scale"
            to: 1.02
            duration: 120
            easing.type: Easing.OutBack
            easing.overshoot: 0.7
        }
        NumberAnimation {
            target: body
            property: "scale"
            to: 1
            duration: 90
            easing.type: Easing.InOutCubic
        }
    }

    SequentialAnimation {
        id: magnetPulse
        NumberAnimation {
            target: magnetMarker
            property: "scale"
            from: 0.82
            to: 1.12
            duration: 100
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: magnetMarker
            property: "scale"
            to: 1
            duration: 150
            easing.type: Easing.OutBack
            easing.overshoot: 0.55
        }
    }

    onMagneticChanged: if (magnetic) magnetPulse.restart()
    onDirectionChanged: if (magnetic) magnetPulse.restart()

    NumberAnimation {
        id: appearAnimation
        target: body
        property: "opacity"
        to: 1
        duration: 120
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: hideAnimation
        target: body
        property: "opacity"
        to: 0
        duration: 100
        easing.type: Easing.InCubic
        onFinished: guide.visible = false
    }
}
