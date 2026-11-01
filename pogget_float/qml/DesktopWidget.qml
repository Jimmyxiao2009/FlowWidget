import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

TileWindow {
    id: widget
    width: 336
    height: widgetId === "calendar" ? 292 : 196
    minimumWidth: 260
    maximumWidth: 520
    minimumHeight: 150
    maximumHeight: 420
    visible: true
    title: desktopWidgetBackend.titleFor(widgetId)
    tileTransparency: appSettings.tileTransparency
    backdropEnabled: appSettings.backdropEffect !== "none"
    keepBackdropActive: true
    nativeWindowFrame: false
    minimizeVisible: false
    maximizeVisible: false
    closeVisible: false
    titleBarHeight: 36
    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnBottomHint
    property bool appearAnimated: true
    property bool allowClose: false
    property bool stayOnTop: false
    property bool placementAdjusting: false
    opacity: appearAnimated ? 0 : 1

    onClosing: function(close) {
        if (!allowClose)
            close.accepted = false
    }

    onActiveChanged: {
        if (!widget.active && !widget.stayOnTop && !widgetMenu.visible)
            desktopWidgetBackend.ensureLayer(widgetId)
    }

    onXChanged: if (visible && !locked) {
        geometryTimer.restart()
        if (!placementAdjusting)
            settlePlacementTimer.restart()
    }
    onYChanged: if (visible && !locked) {
        geometryTimer.restart()
        if (!placementAdjusting)
            settlePlacementTimer.restart()
    }
    onWidthChanged: if (visible && !locked) geometryTimer.restart()
    onHeightChanged: if (visible && !locked) geometryTimer.restart()

    Component.onCompleted: {
        Theme.setTheme(appSettings.themeMode)
        Theme.setThemeColor(appSettings.accentColor)
        widget.locked = desktopWidgetBackend.isLocked(widgetId)
        widget.stayOnTop = desktopWidgetBackend.isStayOnTop(widgetId)
        if (appearAnimated)
            appearAnim.start()
    }

    titleBarArea: Item {
        anchors.right: parent.right
        width: 36
        height: parent ? parent.height : widget.titleBarHeight

        Icon {
            anchors.centerIn: parent
            size: 15
            name: widget.locked
                ? "ic_fluent_lock_closed_20_filled"
                : "ic_fluent_lock_open_20_regular"
            color: widget.locked
                ? Theme.currentTheme.colors.primaryColor
                : Theme.currentTheme.colors.textColor
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            hoverEnabled: false
            onClicked: desktopWidgetBackend.setLocked(widgetId, !widget.locked)
        }
    }

    Item {
        anchors.fill: parent

        NumberAnimation {
            id: appearAnim
            target: widget
            property: "opacity"
            from: 0
            to: 1
            duration: 240
            easing.type: Easing.OutCubic
        }

        Timer {
            id: geometryTimer
            interval: 280
            onTriggered: desktopWidgetBackend.saveGeometry(
                widgetId, Math.round(widget.x), Math.round(widget.y),
                Math.round(widget.width), Math.round(widget.height)
            )
        }

        Timer {
            id: settlePlacementTimer
            interval: 180
            onTriggered: {
                if (widget.placementAdjusting || widget.locked)
                    return
                const placement = desktopWidgetBackend.previewPlacement(
                    widgetId, Math.round(widget.x), Math.round(widget.y)
                )
                if (!placement || placement.x === undefined)
                    return
                if (Math.round(placement.x) === Math.round(widget.x)
                        && Math.round(placement.y) === Math.round(widget.y))
                    return
                settleX.to = Math.round(placement.x)
                settleY.to = Math.round(placement.y)
                widget.placementAdjusting = true
                settleAnimation.restart()
            }
        }

        ParallelAnimation {
            id: settleAnimation
            onFinished: widget.placementAdjusting = false

            NumberAnimation {
                id: settleX
                target: widget
                property: "x"
                duration: 190
                easing.type: Easing.OutBack
                easing.overshoot: 0.75
            }
            NumberAnimation {
                id: settleY
                target: widget
                property: "y"
                duration: 190
                easing.type: Easing.OutBack
                easing.overshoot: 0.75
            }
        }

        Connections {
            target: appSettings
            function onThemeModeChanged() { Theme.setTheme(appSettings.themeMode) }
            function onAccentColorChanged() { Theme.setThemeColor(appSettings.accentColor) }
            function onBackdropEffectChanged() { Theme.setBackdropEffect(appSettings.backdropEffect) }
            function onTileTransparencyChanged() { Theme.setBackdropEffect(appSettings.backdropEffect) }
            function onCountdownTitleChanged() {
                if (widgetId === "countdown")
                    widget.title = desktopWidgetBackend.titleFor(widgetId)
            }
        }

        Connections {
            target: desktopWidgetBackend
            function onLockChanged() { widget.locked = desktopWidgetBackend.isLocked(widgetId) }
            function onStayOnTopChanged() { widget.stayOnTop = desktopWidgetBackend.isStayOnTop(widgetId) }
        }

        TapHandler {
            acceptedButtons: Qt.RightButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: widgetMenu.popup()
        }

        Menu {
            id: widgetMenu
            position: Position.None
            popupType: Popup.Window
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnReleaseOutside
            onClosed: {
                if (!widget.stayOnTop)
                    desktopWidgetBackend.ensureLayer(widgetId)
            }
            MenuItem {
                text: widget.locked ? "解锁位置" : "锁定位置"
                icon.name: widget.locked
                    ? "ic_fluent_lock_open_20_regular"
                    : "ic_fluent_lock_closed_20_regular"
                onTriggered: desktopWidgetBackend.setLocked(widgetId, !widget.locked)
            }
            MenuItem {
                text: widget.stayOnTop ? "取消置顶" : "一直置顶"
                icon.name: widget.stayOnTop
                    ? "ic_fluent_pin_off_20_regular"
                    : "ic_fluent_pin_20_regular"
                onTriggered: desktopWidgetBackend.setStayOnTop(widgetId, !widget.stayOnTop)
            }
            MenuItem {
                text: "从桌面移除"
                icon.name: "ic_fluent_delete_20_regular"
                onTriggered: desktopWidgetBackend.unpin(widgetId)
            }
        }

        Loader {
            anchors.fill: parent
            anchors.margins: 12
            source: {
                if (widgetId === "weather")
                    return Qt.resolvedUrl("widgets/WeatherWidget.qml")
                if (widgetId === "calendar")
                    return Qt.resolvedUrl("widgets/CalendarWidget.qml")
                if (widgetId === "countdown")
                    return Qt.resolvedUrl("widgets/CountdownWidget.qml")
                if (widgetId === "clock")
                    return Qt.resolvedUrl("widgets/ClockWidget.qml")
                if (widgetId === "focus")
                    return Qt.resolvedUrl("widgets/FocusWidget.qml")
                if (widgetId === "notes")
                    return Qt.resolvedUrl("widgets/NotesWidget.qml")
                return ""
            }
        }
    }
}
