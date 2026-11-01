import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

FluentPage {
    id: page
    title: "收纳箱"
    horizontalPadding: width < 700 ? 22 : 34
    wrapperWidth: 1180
    spacing: 16

    property var boxes: []
    property bool editing: false
    property string editingId: ""
    property string deletingId: ""

    function refreshBoxes() { boxes = shelfCollectionModel.searchBoxes(searchField.text) }
    function categoryBoxes(category) {
        var result = []
        for (var i = 0; i < boxes.length; i++)
            if (boxes[i].category === category) result.push(boxes[i])
        return result
    }
    function beginCreate() {
        editingId = ""
        nameField.text = ""
        typeCombo.currentIndex = 0
        editorDialog.title = "新建收纳箱"
        editorDialog.open()
    }
    function beginEdit(box) {
        editingId = box.boxId
        nameField.text = box.name
        typeCombo.currentIndex = Math.max(0, typeCombo.values.indexOf(box.category))
        editorDialog.title = "编辑收纳箱"
        editorDialog.open()
    }

    Component.onCompleted: refreshBoxes()
    Connections {
        target: shelfCollectionModel
        function onBoxesChanged() { page.refreshBoxes() }
    }

    Dialog {
        id: editorDialog
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        ColumnLayout {
            width: 360
            spacing: 12
            Text { text: "名称"; font.bold: true; color: Theme.currentTheme.colors.textColor }
            TextField {
                id: nameField
                Layout.fillWidth: true
                placeholderText: "例如：设计软件"
                onAccepted: editorDialog.accept()
            }
            Text { text: "类型"; font.bold: true; color: Theme.currentTheme.colors.textColor }
            ComboBox {
                id: typeCombo
                Layout.fillWidth: true
                property var values: ["软件收纳箱", "文件收纳箱", "文件夹收纳箱"]
                model: values
            }
        }
        onOpened: { nameField.forceActiveFocus(); nameField.selectAll() }
        onAccepted: {
            var cleanName = nameField.text.trim()
            if (cleanName.length === 0) return
            if (page.editingId.length > 0)
                shelfCollectionModel.updateBox(page.editingId, cleanName, typeCombo.values[typeCombo.currentIndex])
            else
                shelfCollectionModel.createBox(cleanName, typeCombo.values[typeCombo.currentIndex])
        }
    }

    Dialog {
        id: deleteDialog
        title: "删除收纳箱"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        Text {
            width: 340
            text: "收纳箱及其中保存的快捷方式记录将被删除。此操作无法撤销。"
            wrapMode: Text.WordWrap
            color: Theme.currentTheme.colors.textColor
        }
        onAccepted: shelfCollectionModel.deleteBox(page.deletingId)
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 10
        Button {
            text: "新建收纳箱"
            icon.name: "ic_fluent_add_20_regular"
            highlighted: true
            Layout.preferredHeight: 36
            onClicked: page.beginCreate()
        }
        Button {
            text: page.editing ? "完成编辑" : "编辑收纳箱"
            icon.name: page.editing ? "ic_fluent_checkmark_20_regular" : "ic_fluent_edit_20_regular"
            Layout.preferredHeight: 36
            onClicked: page.editing = !page.editing
        }
        Item { Layout.fillWidth: true }
        TextField {
            id: searchField
            Layout.preferredWidth: Math.min(260, page.width * 0.34)
            placeholderText: "搜索收纳箱..."
            leftPadding: 36
            onTextChanged: page.refreshBoxes()
            Icon {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: "ic_fluent_search_20_regular"
                size: 17
                color: Theme.currentTheme.colors.textSecondaryColor
            }
        }
    }

    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.currentTheme.colors.dividerBorderColor }

    Repeater {
        model: ["软件收纳箱", "文件收纳箱", "文件夹收纳箱"]
        delegate: ColumnLayout {
            required property string modelData
            property var groupBoxes: page.categoryBoxes(modelData)
            Layout.fillWidth: true
            spacing: 10
            visible: groupBoxes.length > 0

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                Icon {
                    name: modelData === "软件收纳箱" ? "ic_fluent_apps_20_regular"
                        : modelData === "文件收纳箱" ? "ic_fluent_document_20_regular"
                        : "ic_fluent_folder_20_regular"
                    size: 16
                    color: Theme.currentTheme.colors.primaryColor
                }
                Text { text: modelData; font.pixelSize: 15; font.bold: true; color: Theme.currentTheme.colors.textColor }
                Item { Layout.fillWidth: true }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: page.width >= 1050 ? 4 : page.width >= 720 ? 3 : page.width >= 470 ? 2 : 1
                columnSpacing: 14
                rowSpacing: 14
                Repeater {
                    model: groupBoxes
                    delegate: Rectangle {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 150
                        Layout.minimumWidth: 190
                        radius: 14
                        color: Theme.currentTheme.colors.cardColor
                        border.width: 1
                        border.color: Theme.currentTheme.colors.cardBorderColor

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 16
                            spacing: 10
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.pixelSize: 15
                                    font.bold: true
                                    color: Theme.currentTheme.colors.textColor
                                    elide: Text.ElideRight
                                }
                                Row {
                                    visible: page.editing
                                    spacing: 2
                                    ToolButton { width: 30; height: 30; icon.name: "ic_fluent_edit_20_regular"; onClicked: page.beginEdit(modelData) }
                                    ToolButton {
                                        width: 30; height: 30; icon.name: "ic_fluent_delete_20_regular"
                                        onClicked: { page.deletingId = modelData.boxId; deleteDialog.open() }
                                    }
                                }
                                Icon { visible: !page.editing; name: "ic_fluent_open_20_regular"; size: 15; color: Theme.currentTheme.colors.textSecondaryColor }
                            }

                            Row {
                                Layout.fillWidth: true
                                spacing: 8
                                Repeater {
                                    model: modelData.previewIcons
                                    delegate: Rectangle {
                                        required property string modelData
                                        width: 36; height: 36; radius: 8
                                        color: Theme.currentTheme.colors.controlFillSecondaryColor
                                        Image { anchors.centerIn: parent; width: 26; height: 26; source: modelData; fillMode: Image.PreserveAspectFit; smooth: true }
                                    }
                                }
                                Repeater {
                                    model: Math.max(0, 4 - modelData.previewIcons.length)
                                    delegate: Rectangle { width: 36; height: 36; radius: 8; color: Theme.currentTheme.colors.controlFillSecondaryColor }
                                }
                            }

                            Item { Layout.fillHeight: true }
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: modelData.itemCount + (modelData.category === "软件收纳箱" ? " 个软件" : modelData.category === "文件收纳箱" ? " 个文件" : " 个文件夹")
                                    color: Theme.currentTheme.colors.textSecondaryColor
                                }
                                Item { Layout.fillWidth: true }
                                Text { text: "更新于 " + modelData.updatedText; color: Theme.currentTheme.colors.textSecondaryColor; font.pixelSize: 12 }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !page.editing
                            hoverEnabled: false
                            onClicked: shelfBackend.showBox(modelData.boxId)
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: 54
        visible: page.boxes.length === 0
        Icon { Layout.alignment: Qt.AlignHCenter; name: "ic_fluent_box_20_regular"; size: 42; color: Theme.currentTheme.colors.textSecondaryColor }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: searchField.text.length > 0 ? "没有匹配的收纳箱" : "还没有收纳箱"
            font.pixelSize: 17
            color: Theme.currentTheme.colors.textSecondaryColor
        }
    }
}
