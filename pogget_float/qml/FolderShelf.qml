import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

TileWindow {
    id: shelf
    width: 520
    height: expandedHeight
    minimumWidth: 360
    maximumWidth: 1400
    minimumHeight: collapsedHeight
    maximumHeight: 900
    visible: true
    title: shelfSettings.windowTitle
    tileTransparency: appSettings.tileTransparency
    backdropEnabled: appSettings.backdropEffect !== "none"
    keepBackdropActive: true
    minimizeVisible: false
    maximizeVisible: false

    property bool expanded: true
    readonly property int expandedHeight: 320
    readonly property int collapsedHeight: 38
    readonly property int overviewColumns: 6

    onExpandedChanged: height = expanded ? expandedHeight : collapsedHeight

    Behavior on height {
        NumberAnimation { duration: 220; easing.type: Easing.InOutQuad }
    }

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

        Connections {
            target: folderModel
            function onLastErrorChanged() {
                if (folderModel.lastError.length > 0)
                    errorTimer.restart()
            }
        }

        Timer {
            id: errorTimer
            interval: 4500
            onTriggered: folderBackend.clearError()
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

        Dialog {
            id: deleteDialog
            property string targetPath: ""
            property bool removesStoredData: false
            title: "从收纳箱删除"
            modal: true
            standardButtons: Dialog.Ok | Dialog.Cancel

            Text {
                width: 360
                wrapMode: Text.WordWrap
                color: Theme.currentTheme.colors.textColor
                text: deleteDialog.removesStoredData
                    ? "这个项目由 FlowWidget 保管。继续后会删除收纳的文件夹或压缩包，且无法恢复。若要放回桌面，请选择“恢复到原位置”。"
                    : "只会从收纳箱移除记录，不会删除原位置的文件夹或压缩包。"
            }

            onAccepted: folderBackend.removePath(targetPath)
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
        }

        Menu {
            id: itemMenu
            property string targetPath: ""
            property bool targetIsDirectory: false
            property bool targetIsRoot: false
            property bool canRestore: false

            MenuItem {
                text: itemMenu.targetIsDirectory ? "在收纳箱中打开" : "打开"
                icon.name: "ic_fluent_open_20_regular"
                onTriggered: folderBackend.activatePath(itemMenu.targetPath, itemMenu.targetIsDirectory)
            }
            MenuItem {
                text: "在资源管理器中显示"
                icon.name: "ic_fluent_folder_open_20_regular"
                onTriggered: folderBackend.showInExplorer(itemMenu.targetPath)
            }
            MenuSeparator { visible: itemMenu.targetIsRoot }
            MenuItem {
                visible: itemMenu.targetIsRoot
                text: "恢复到原位置"
                icon.name: "ic_fluent_arrow_undo_20_regular"
                enabled: itemMenu.canRestore
                onTriggered: folderBackend.restorePath(itemMenu.targetPath)
            }
            MenuItem {
                visible: itemMenu.targetIsRoot
                text: "从收纳箱删除"
                icon.name: "ic_fluent_delete_20_regular"
                onTriggered: {
                    deleteDialog.targetPath = itemMenu.targetPath
                    deleteDialog.removesStoredData = itemMenu.canRestore
                    deleteDialog.open()
                }
            }
        }
    }

    titleBarLeadingArea: Item {
        width: 0
        height: parent ? parent.height : shelf.titleBarHeight
        visible: false
    }

    titleBarArea: Item {
        anchors.right: parent.right
        anchors.rightMargin: -43
        width: folderModel.browsing ? 120 : 40
        height: parent ? parent.height : shelf.titleBarHeight

        Row {
            anchors.fill: parent
            spacing: 0

            Item {
                width: folderModel.browsing ? 40 : 0
                height: parent.height
                visible: folderModel.browsing
                Icon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    name: "ic_fluent_arrow_left_20_regular"
                    size: 16
                    color: Theme.currentTheme.colors.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false
                    onClicked: folderBackend.goBack()
                }
            }

            Item {
                width: folderModel.browsing ? 40 : 0
                height: parent.height
                visible: folderModel.browsing
                Icon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    name: "ic_fluent_folder_open_20_regular"
                    size: 16
                    color: Theme.currentTheme.colors.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false
                    onClicked: folderBackend.openInExplorer()
                }
            }

            Item {
                width: 40
                height: parent.height
                Icon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 2
                    size: 16
                    name: shelf.expanded
                        ? "ic_fluent_chevron_up_20_regular"
                        : "ic_fluent_chevron_down_20_regular"
                    color: Theme.currentTheme.colors.textColor
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false
                    onClicked: shelf.expanded = !shelf.expanded
                }
            }
        }

        Component.onCompleted: parent.clip = false
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
                if (folderModel.browsing)
                    return
                const urls = []
                for (const url of drop.urls) urls.push(url.toString())
                folderBackend.addUrls(urls)
                drop.acceptProposedAction()
            }

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: 10

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: Qt.rgba(0.2, 0.5, 0.9, 0.10)
                    visible: dropArea.containsDrag && !folderModel.browsing
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0

                    GridView {
                        id: grid
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.margins: 8
                        model: folderModel
                        cellWidth: width / (folderModel.browsing ? Math.max(4, Math.floor(width / 82)) : shelf.overviewColumns)
                        cellHeight: 78
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}

                        delegate: Item {
                            id: delegateRoot
                            required property string name
                            required property string path
                            required property string iconSource
                            required property string restorePath
                            required property bool isDirectory
                            required property bool isArchive
                            width: grid.cellWidth
                            height: grid.cellHeight

                            Column {
                                anchors.centerIn: parent
                                width: Math.max(0, parent.width - 8)
                                spacing: 3
                                Image {
                                    width: 50
                                    height: width
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    source: delegateRoot.iconSource
                                    fillMode: Image.PreserveAspectFit
                                    smooth: true
                                    asynchronous: true
                                }
                                Text {
                                    width: parent.width
                                    height: 16
                                    text: delegateRoot.name
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.NoWrap
                                    elide: Text.ElideMiddle
                                    maximumLineCount: 1
                                    clip: true
                                    font.pixelSize: 10
                                    color: Theme.currentTheme.colors.textColor
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.RightButton
                                hoverEnabled: false
                                onClicked: function(mouse) {
                                    itemMenu.targetPath = delegateRoot.path
                                    itemMenu.targetIsDirectory = delegateRoot.isDirectory
                                    itemMenu.targetIsRoot = !folderModel.browsing
                                    itemMenu.canRestore = delegateRoot.restorePath.length > 0
                                    const point = delegateRoot.mapToItem(popupHost, mouse.x, mouse.y)
                                    itemMenu.popup(point.x, point.y)
                                }
                            }

                            TapHandler {
                                acceptedButtons: Qt.LeftButton
                                gesturePolicy: TapHandler.ReleaseWithinBounds
                                onTapped: function(eventPoint) {
                                    if (delegateRoot.isDirectory)
                                        folderBackend.enterFolder(delegateRoot.path)
                                    else
                                        folderBackend.openPath(delegateRoot.path)
                                }
                            }
                        }

                        TapHandler {
                            acceptedButtons: Qt.RightButton
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: function(eventPoint) {
                                const item = grid.itemAt(
                                    eventPoint.position.x + grid.contentX,
                                    eventPoint.position.y + grid.contentY
                                )
                                if (!item)
                                    backgroundMenu.popup(eventPoint.scenePosition)
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: grid.count === 0
                            text: folderModel.browsing
                                ? "这个文件夹是空的"
                                : "将文件夹或压缩包拖入这里"
                            color: Theme.currentTheme.colors.textSecondaryColor
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: folderModel.browsing ? 30 : 0
                        visible: folderModel.browsing
                        color: Theme.currentTheme.colors.controlAltSecondaryColor

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 7
                            Icon {
                                name: "ic_fluent_folder_20_regular"
                                size: 14
                                color: Theme.currentTheme.colors.textSecondaryColor
                            }
                            Text {
                                Layout.fillWidth: true
                                text: folderModel.currentPath
                                elide: Text.ElideMiddle
                                font.pixelSize: 11
                                color: Theme.currentTheme.colors.textSecondaryColor
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 8
            height: 38
            visible: folderModel.lastError.length > 0
            radius: 6
            color: Theme.currentTheme.colors.systemCautionBackgroundColor
            border.width: 1
            border.color: Qt.alpha(Theme.currentTheme.colors.systemCautionColor, 0.35)
            z: 20

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8
                Icon {
                    name: "ic_fluent_warning_20_regular"
                    size: 16
                    color: Theme.currentTheme.colors.systemCautionColor
                }
                Text {
                    Layout.fillWidth: true
                    text: folderModel.lastError
                    elide: Text.ElideRight
                    color: Theme.currentTheme.colors.textColor
                }
                ToolButton {
                    width: 28
                    height: 28
                    icon.name: "ic_fluent_dismiss_20_regular"
                    onClicked: folderBackend.clearError()
                }
            }
        }
    }
}
