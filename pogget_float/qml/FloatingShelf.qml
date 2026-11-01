import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

TileWindow {
    id: shelf
    width: 300
    height: expandedHeight
    Behavior on height {
    NumberAnimation {
        duration: 220
        easing.type: Easing.InOutQuad
    }
}
    minimumWidth: 220
    maximumWidth: 720
    minimumHeight: collapsedHeight
    maximumHeight: 620
    visible: true
    title: shelfSettings.windowTitle
    tileTransparency: appSettings.tileTransparency
    backdropEnabled: appSettings.backdropEffect !== "none"
    keepBackdropActive: true
    minimizeVisible: false
    maximizeVisible: false
    property bool expanded: true
    readonly property int columns: shelfSettings.columns
    readonly property int expandedHeight: 240
    readonly property int collapsedHeight: 38

    onExpandedChanged: height = expanded ? expandedHeight : collapsedHeight

    Component.onCompleted: {
        Theme.setTheme(appSettings.themeMode)
        Theme.setThemeColor(appSettings.accentColor)
    }

    Item {
        id: popupHost
        anchors.fill: parent
        z: 100

        Connections {
            target: appSettings
            function onThemeModeChanged() { Theme.setTheme(appSettings.themeMode) }
            function onAccentColorChanged() { Theme.setThemeColor(appSettings.accentColor) }
            function onBackdropEffectChanged() { Theme.setBackdropEffect(appSettings.backdropEffect) }
            function onTileTransparencyChanged() { Theme.setBackdropEffect(appSettings.backdropEffect) }
        }

        Dialog {
            id: renameDialog
            title: "修改窗口名称"
            modal: true
            standardButtons: Dialog.Ok | Dialog.Cancel

            TextField {
                id: titleInput
                Layout.fillWidth: true
                placeholderText: "输入新名称"
                onAccepted: renameDialog.accept()
            }

            onOpened: {
                titleInput.text = shelf.title
                titleInput.selectAll()
                titleInput.forceActiveFocus()
            }
            onAccepted: shelfSettings.setWindowTitle(titleInput.text)
        }

        Menu {
            id: backgroundMenu

            MenuItem {
                text: "修改窗口名称"
                icon.name: "ic_fluent_edit_20_regular"
                onTriggered: renameDialog.open()
            }
            MenuItem {
                text: "打开小组件面板"
                icon.name: "ic_fluent_apps_20_regular"
                onTriggered: widgetBoardBackend.show()
            }
            MenuItem {
                text: "打开设置"
                icon.name: "ic_fluent_settings_20_regular"
                onTriggered: settingsWindowBackend.show()
            }
            MenuSeparator {}
            MenuItem {
                text: "大图标（每行 4 个）"
                checkable: true
                checked: shelf.columns === 4
                onTriggered: shelfSettings.setColumns(4)
            }
            MenuItem {
                text: "小图标（每行 8 个）"
                checkable: true
                checked: shelf.columns === 8
                onTriggered: shelfSettings.setColumns(8)
            }
        }

        Menu {
            id: shortcutMenu
            property string targetPath: ""
            property bool canRestore: false

            MenuItem {
                text: "打开"
                icon.name: "ic_fluent_open_20_regular"
                onTriggered: shortcutBackend.openPath(shortcutMenu.targetPath)
            }
            MenuItem {
                text: "恢复快捷方式到桌面"
                icon.name: "ic_fluent_arrow_undo_20_regular"
                enabled: shortcutMenu.canRestore
                onTriggered: shortcutBackend.restorePath(shortcutMenu.targetPath)
            }
            MenuSeparator {}
            MenuItem {
                text: "从收纳盒删除"
                icon.name: "ic_fluent_delete_20_regular"
                onTriggered: shortcutBackend.removePath(shortcutMenu.targetPath)
            }
        }
    }

    titleBarArea: Item {
        id: collapseControl
        objectName: "collapseControl"
        anchors.right: parent.right
        anchors.rightMargin: -43
        width: 40
        height: parent ? parent.height : shelf.titleBarHeight

        Component.onCompleted: {
            // RinUI's content slot is clipped by default. Allow only this
            // title-bar action to extend into the hidden caption-button slot.
            parent.clip = false
        }

        Icon {
            anchors.centerIn: parent
            size: 16
            name: shelf.expanded
                ? "ic_fluent_chevron_up_20_regular"
                : "ic_fluent_chevron_down_20_regular"
            color: Theme.currentTheme.colors.textColor
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton
            onClicked: shelf.expanded = !shelf.expanded
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 8
        visible: shelf.expanded
        color: "transparent"
        

        DropArea {
            id: dropArea
            anchors.fill: parent
            onDropped: function(drop) {
                const urls = []
                for (const url of drop.urls) urls.push(url.toString())
                shortcutBackend.addUrls(urls)
                drop.acceptProposedAction()
            }

            Rectangle {
                id: dropSurface
                anchors.fill: parent
                color: "transparent"
                radius: 10

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0.2, 0.5, 0.9, 0.08)
                    visible: dropArea.containsDrag
                }

                GridView {
                    id: grid
                    anchors.fill: parent
                    anchors.margins: 8
                    model: shortcutModel
                    cellWidth: width / shelf.columns
                    cellHeight: shelf.columns === 4 ? 92 : 58
                    clip: true

                    delegate: Item {
                        property string shortcutPath: path
                        property string shortcutRestorePath: restorePath
                        width: grid.cellWidth
                        height: grid.cellHeight
                        clip: true

                        Column {
                            anchors.centerIn: parent
                            width: Math.max(0, parent.width - 10)
                            spacing: shelf.columns === 4 ? 4 : 2
                            Image {
                                width: shelf.columns === 4 ? 52 : 28
                                height: width
                                anchors.horizontalCenter: parent.horizontalCenter
                                source: iconSource
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                            Text {
                                width: parent.width
                                height: shelf.columns === 4 ? 18 : 14
                                text: name
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.NoWrap
                                elide: Text.ElideMiddle
                                maximumLineCount: 1
                                clip: true
                                font.pixelSize: shelf.columns === 4 ? 12 : 9
                                color: Theme.currentTheme.colors.textColor
                            }
                        }
                    }

                    TapHandler {
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        gesturePolicy: TapHandler.ReleaseWithinBounds

                        onTapped: function(eventPoint, button) {
                            const item = grid.itemAt(
                                eventPoint.position.x + grid.contentX,
                                eventPoint.position.y + grid.contentY
                            )
                            if (item && button === Qt.LeftButton) {
                                shortcutBackend.openPath(item.shortcutPath)
                            } else if (item && button === Qt.RightButton) {
                                shortcutMenu.targetPath = item.shortcutPath
                                shortcutMenu.canRestore = item.shortcutRestorePath.length > 0
                                shortcutMenu.popup(eventPoint.scenePosition)
                            } else if (button === Qt.RightButton) {
                                backgroundMenu.popup(eventPoint.scenePosition)
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: grid.count === 0
                        text: "将快捷方式拖入这里"
                        color: Theme.currentTheme.colors.textSecondaryColor
                    }
                }
            }
        }
    }
}
