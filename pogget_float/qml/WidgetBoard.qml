import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI
import "widgets"

ApplicationWindow {
    id: board
    width: 760
    height: 640
    minimumWidth: 520
    minimumHeight: 420
    visible: true
    title: "小组件"
    minimizeVisible: false
    maximizeVisible: false
    keepBackdropActive: true
    titleBarHeight: Theme.currentTheme.appearance.windowTitleBarHeight

    readonly property int layoutGap: appSettings.compactLayout ? 10 : 14
    property bool weatherVisible: appSettings.weatherEnabled
    property bool calendarVisible: appSettings.calendarEnabled
    property bool countdownVisible: appSettings.countdownEnabled
    property bool clockVisible: appSettings.clockEnabled
    property bool focusVisible: appSettings.focusEnabled
    property bool notesVisible: appSettings.notesEnabled
    property string todayText: ""
    property string greetingText: ""
    property string draggingWidgetId: ""
    property DragGhost dragGhost: DragGhost {}
    property PlacementGuide placementGuide: PlacementGuide {}
    property var currentPlacement: ({})

    function isGlobalInsideBoard(gx, gy) {
        return gx >= board.x && gx <= board.x + board.width
            && gy >= board.y && gy <= board.y + board.height
    }

    function beginWidgetDrag(widgetId, title, iconName, gx, gy) {
        if (desktopWidgetBackend.isLocked(widgetId))
            return false
        draggingWidgetId = widgetId
        dragGhost.widgetId = widgetId
        dragGhost.widgetTitle = title
        dragGhost.iconName = iconName
        dragGhost.overDesktop = !isGlobalInsideBoard(gx, gy)
        dragGhost.showAt(gx, gy)
        if (dragGhost.overDesktop)
            updatePlacement(gx, gy)
        return true
    }

    function updatePlacement(gx, gy) {
        if (draggingWidgetId.length === 0)
            return ({})
        const placement = desktopWidgetBackend.previewPlacement(
            draggingWidgetId, dragGhost.x, dragGhost.y
        )
        currentPlacement = placement
        if (placement && placement.width !== undefined) {
            placementGuide.showPlacement(
                placement.previewX,
                placement.previewY,
                placement.width,
                placement.height,
                placement.snapped,
                placement.magnetized,
                placement.direction,
                placement.message
            )
            dragGhost.setPlacementState(
                placement.snapped, placement.magnetized, placement.direction, placement.message
            )
        }
        return placement
    }

    function updateWidgetDrag(gx, gy) {
        dragGhost.overDesktop = !isGlobalInsideBoard(gx, gy)
        dragGhost.moveTo(gx, gy)
        if (dragGhost.overDesktop)
            updatePlacement(gx, gy)
        else
            placementGuide.hideGuide()
    }

    function endWidgetDrag(gx, gy) {
        const widgetId = draggingWidgetId
        const dropOnDesktop = widgetId.length > 0 && !isGlobalInsideBoard(gx, gy)
        if (dropOnDesktop) {
            dragGhost.moveTo(gx, gy)
            const placement = updatePlacement(gx, gy)
            if (placement && placement.width !== undefined)
                desktopWidgetBackend.pinAt(widgetId, placement.x, placement.y)
            draggingWidgetId = ""
            hideGhostTimer.restart()
        } else {
            draggingWidgetId = ""
            placementGuide.hideGuide()
            dragGhost.hideGhost()
        }
    }

    function updateDate() {
        const now = new Date()
        todayText = (now.getMonth() + 1) + "月" + now.getDate() + "日"
        greetingText = now.getHours() < 12 ? "上午好" : (now.getHours() < 18 ? "下午好" : "晚上好")
    }

    Component.onCompleted: {
        updateDate()
        Theme.setTheme(appSettings.themeMode)
        Theme.setThemeColor(appSettings.accentColor)
    }

    Item {
        anchors.fill: parent
        anchors.topMargin: board.titleBarHeight + 8
        anchors.leftMargin: appSettings.compactLayout ? 12 : 18
        anchors.rightMargin: appSettings.compactLayout ? 12 : 18
        anchors.bottomMargin: appSettings.compactLayout ? 12 : 16

        Connections {
            target: appSettings
            function onThemeModeChanged() { Theme.setTheme(appSettings.themeMode) }
            function onAccentColorChanged() { Theme.setThemeColor(appSettings.accentColor) }
            function onBackdropEffectChanged() { Theme.setBackdropEffect(appSettings.backdropEffect) }
        }

        Timer {
            interval: 60000
            running: true
            repeat: true
            onTriggered: board.updateDate()
        }

        Timer {
            id: hideGhostTimer
            interval: 180
            onTriggered: {
                board.dragGhost.hideGhost()
                board.placementGuide.hideGuide()
            }
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: board.layoutGap

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: board.todayText
                        font.pixelSize: 13
                        color: Theme.currentTheme.colors.textSecondaryColor
                    }
                    Text {
                        visible: appSettings.showGreeting
                        text: board.greetingText
                        font.pixelSize: 26
                        font.bold: true
                        color: Theme.currentTheme.colors.textColor
                    }
                    Text {
                        text: "把磁贴拖到桌面上即可固定，锁定后不会被误移。"
                        color: Theme.currentTheme.colors.textSecondaryColor
                        font.pixelSize: 12
                    }
                }

                Button {
                    text: "添加"
                    icon.name: "ic_fluent_add_20_regular"
                    flat: true
                    hoverable: false
                    onClicked: widgetMenu.open()
                        Menu {
                            id: widgetMenu
                            MenuItem { text: "天气"; enabled: !board.weatherVisible; onTriggered: appSettings.setWidgetVisible("weather", true) }
                            MenuItem { text: "日历"; enabled: !board.calendarVisible; onTriggered: appSettings.setWidgetVisible("calendar", true) }
                            MenuItem { text: "倒计时"; enabled: !board.countdownVisible; onTriggered: appSettings.setWidgetVisible("countdown", true) }
                            MenuSeparator {}
                            MenuItem { text: "时钟"; enabled: !board.clockVisible; onTriggered: appSettings.setWidgetVisible("clock", true) }
                            MenuItem { text: "专注"; enabled: !board.focusVisible; onTriggered: appSettings.setWidgetVisible("focus", true) }
                            MenuItem { text: "便签"; enabled: !board.notesVisible; onTriggered: appSettings.setWidgetVisible("notes", true) }
                        }
                }

                ToolButton {
                    icon.name: "ic_fluent_settings_20_regular"
                    size: 20
                    flat: true
                    hoverable: false
                    onClicked: settingsWindowBackend.show()
                }
            }

            Flickable {
                id: widgetScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: widgetColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: widgetColumn
                    width: widgetScroll.width
                    spacing: board.layoutGap

                    GridLayout {
                        Layout.fillWidth: true
                        columns: appSettings.layoutMode === "single" ? 1 : (width >= 560 ? 2 : 1)
                        columnSpacing: board.layoutGap
                        rowSpacing: board.layoutGap

                        WidgetTile {
                            visible: board.weatherVisible
                            widgetId: "weather"
                            title: "天气"
                            iconName: "ic_fluent_weather_cloudy_20_regular"
                            Layout.fillWidth: true
                            Layout.columnSpan: parent.columns
                            Layout.preferredHeight: appSettings.compactLayout ? 168 : 186
                            WeatherWidget { anchors.fill: parent }
                        }

                        WidgetTile {
                            visible: board.calendarVisible
                            widgetId: "calendar"
                            title: "日历"
                            iconName: "ic_fluent_calendar_ltr_20_regular"
                            Layout.fillWidth: true
                            Layout.preferredHeight: appSettings.compactLayout ? 236 : 258
                            CalendarWidget { anchors.fill: parent }
                        }

                        WidgetTile {
                            visible: board.countdownVisible
                            widgetId: "countdown"
                            title: "倒计时"
                            iconName: "ic_fluent_timer_20_regular"
                            Layout.fillWidth: true
                            Layout.preferredHeight: appSettings.compactLayout ? 188 : 210
                            CountdownWidget { anchors.fill: parent }
                        }

                        WidgetTile {
                            visible: board.clockVisible
                            widgetId: "clock"
                            title: "时钟"
                            iconName: "ic_fluent_clock_20_regular"
                            Layout.fillWidth: true
                            Layout.preferredHeight: appSettings.compactLayout ? 148 : 164
                            ClockWidget { anchors.fill: parent }
                        }

                        WidgetTile {
                            visible: board.focusVisible
                            widgetId: "focus"
                            title: "专注"
                            iconName: "ic_fluent_target_20_regular"
                            Layout.fillWidth: true
                            Layout.preferredHeight: appSettings.compactLayout ? 198 : 220
                            FocusWidget { anchors.fill: parent }
                        }

                        WidgetTile {
                            visible: board.notesVisible
                            widgetId: "notes"
                            title: "便签"
                            iconName: "ic_fluent_note_20_regular"
                            Layout.fillWidth: true
                            Layout.preferredHeight: appSettings.compactLayout ? 202 : 224
                            NotesWidget { anchors.fill: parent }
                        }
                    }

                    Item {
                        visible: !board.weatherVisible && !board.calendarVisible && !board.countdownVisible
                            && !board.clockVisible && !board.focusVisible && !board.notesVisible
                        Layout.fillWidth: true
                        Layout.preferredHeight: 260

                        Column {
                            anchors.centerIn: parent
                            spacing: 10
                            Icon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                name: "ic_fluent_apps_add_in_28_regular"
                                size: 34
                                color: Theme.currentTheme.colors.textSecondaryColor
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "这里还没有小组件"
                                font.pixelSize: 17
                                color: Theme.currentTheme.colors.textColor
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "点击右上角“添加”，再把磁贴拖到桌面"
                                color: Theme.currentTheme.colors.textSecondaryColor
                            }
                        }
                    }
                }
            }
        }
    }
}
