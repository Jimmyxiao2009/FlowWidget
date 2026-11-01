import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import RinUI

Item {
    id: tile
    property string widgetId: ""
    property string title: ""
    property string iconName: "ic_fluent_apps_20_regular"
    property bool compact: appSettings.compactLayout
    default property alias content: contentSlot.data

    property bool pinned: desktopWidgetBackend.isPinned(widgetId)
    property bool locked: desktopWidgetBackend.isLocked(widgetId)
    property bool stayOnTop: desktopWidgetBackend.isStayOnTop(widgetId)
    property bool dragging: false

    scale: dragging ? 0.97 : (pressHandler.pressed ? 0.985 : (hover.hovered ? 1.016 : 1.0))
    opacity: dragging ? 0.42 : 1
    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 120 } }

    function surfaceColor() {
        const level = Math.max(0, Math.min(1, (appSettings.cardOpacity - 0.55) / 0.45))
        if (Theme.currentTheme.isDark)
            return Qt.rgba(0.14, 0.16, 0.19, 0.42 + level * 0.38)
        return Qt.rgba(1, 1, 1, 0.42 + level * 0.40)
    }

    Connections {
        target: desktopWidgetBackend
        function onPinnedChanged() {
            tile.pinned = desktopWidgetBackend.isPinned(tile.widgetId)
            tile.locked = desktopWidgetBackend.isLocked(tile.widgetId)
            tile.stayOnTop = desktopWidgetBackend.isStayOnTop(tile.widgetId)
        }
        function onLockChanged() {
            tile.locked = desktopWidgetBackend.isLocked(tile.widgetId)
        }
        function onStayOnTopChanged() {
            tile.stayOnTop = desktopWidgetBackend.isStayOnTop(tile.widgetId)
        }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: 16
        color: tile.surfaceColor()
        border.width: 1
        border.color: Theme.currentTheme.colors.cardBorderColor
        clip: true

        Rectangle {
            id: reveal
            width: 168
            height: 168
            radius: 84
            visible: hover.hovered
            x: hover.point.position.x - width / 2
            y: hover.point.position.y - height / 2
            color: Qt.rgba(1, 1, 1, Theme.currentTheme.isDark ? 0.08 : 0.12)
        }
    }

    HoverHandler { id: hover }
    TapHandler {
        id: pressHandler
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: tileMenu.popup()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: tile.compact ? 12 : 16
        spacing: tile.compact ? 6 : 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Icon {
                name: tile.iconName
                size: 16
                color: Theme.currentTheme.colors.primaryColor
            }
            Text {
                Layout.fillWidth: true
                text: tile.title
                font.pixelSize: 13
                font.bold: true
                color: Theme.currentTheme.colors.textSecondaryColor
                elide: Text.ElideRight
            }
            Text {
                visible: tile.pinned
                text: tile.locked ? "已锁定" : "已固定"
                font.pixelSize: 11
                color: Theme.currentTheme.colors.primaryColor
            }
            Item { Layout.preferredWidth: 28 }
        }

        Item {
            id: contentSlot
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
        }
    }

    ToolButton {
        z: 20
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 8
        icon.name: "ic_fluent_more_horizontal_20_regular"
        size: 16
        flat: true
        hoverable: false
        onClicked: tileMenu.popup()
    }

    MouseArea {
        id: dragHandle
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: tile.compact ? 44 : 52
        anchors.rightMargin: 44
        acceptedButtons: Qt.LeftButton
        hoverEnabled: true
        preventStealing: true
        cursorShape: tile.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property real pressX: 0
        property real pressY: 0

        function globalMouse(mouse) {
            return mapToGlobal(mouse.x, mouse.y)
        }

        function host() {
            return tile.Window.window
        }

        onPressed: function(mouse) {
            pressX = mouse.x
            pressY = mouse.y
            tile.dragging = false
        }
        onPositionChanged: function(mouse) {
            if (!pressed)
                return
            const moved = Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY)
            const win = host()
            const globalPos = globalMouse(mouse)
            if (!tile.dragging && moved > 3) {
                if (win && win.beginWidgetDrag && win.beginWidgetDrag(
                    tile.widgetId, tile.title, tile.iconName, globalPos.x, globalPos.y
                )) {
                    tile.dragging = true
                }
            } else if (tile.dragging && win && win.updateWidgetDrag) {
                win.updateWidgetDrag(globalPos.x, globalPos.y)
            }
        }
        onReleased: function(mouse) {
            const wasDragging = tile.dragging
            tile.dragging = false
            if (!wasDragging)
                return
            const win = host()
            const globalPos = globalMouse(mouse)
            if (win && win.endWidgetDrag)
                win.endWidgetDrag(globalPos.x, globalPos.y)
        }
        onCanceled: {
            const win = host()
            if (tile.dragging && win && win.endWidgetDrag)
                win.endWidgetDrag(win.x + win.width / 2, win.y + win.height / 2)
            tile.dragging = false
        }
    }

    Menu {
        id: tileMenu
        position: Position.None
        popupType: Popup.Window
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside | Popup.CloseOnReleaseOutside
        MenuItem {
            text: tile.pinned ? "显示桌面磁贴" : "固定到桌面"
            icon.name: "ic_fluent_pin_20_regular"
            onTriggered: desktopWidgetBackend.pin(tile.widgetId)
        }
        MenuItem {
            visible: tile.pinned
            text: "从桌面取消固定"
            icon.name: "ic_fluent_pin_off_20_regular"
            onTriggered: desktopWidgetBackend.unpin(tile.widgetId)
        }
        MenuItem {
            visible: tile.pinned
            text: tile.locked ? "解锁位置" : "锁定位置"
            icon.name: tile.locked ? "ic_fluent_lock_open_20_regular" : "ic_fluent_lock_closed_20_regular"
            onTriggered: desktopWidgetBackend.setLocked(tile.widgetId, !tile.locked)
        }
        MenuItem {
            visible: tile.pinned
            text: tile.stayOnTop ? "取消置顶" : "一直置顶"
            icon.name: tile.stayOnTop
                ? "ic_fluent_pin_off_20_regular"
                : "ic_fluent_pin_20_regular"
            onTriggered: desktopWidgetBackend.setStayOnTop(tile.widgetId, !tile.stayOnTop)
        }
        MenuSeparator {}
        MenuItem {
            text: "小组件设置"
            icon.name: "ic_fluent_settings_20_regular"
            onTriggered: settingsWindowBackend.show()
        }
        MenuItem {
            text: "从面板移除"
            icon.name: "ic_fluent_delete_20_regular"
            onTriggered: appSettings.setWidgetVisible(tile.widgetId, false)
        }
    }
}
