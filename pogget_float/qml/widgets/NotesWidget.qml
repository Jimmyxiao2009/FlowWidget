import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import RinUI

Item {
    id: notes
    property string noteText: ""

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        TextArea {
            id: editor
            Layout.fillWidth: true
            Layout.fillHeight: true
            text: notes.noteText
            placeholderText: "写下此刻要记住的事…"
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            font.pixelSize: 13
            color: Theme.currentTheme.colors.textColor
            placeholderTextColor: Theme.currentTheme.colors.textSecondaryColor
            leftPadding: 12
            rightPadding: 12
            topPadding: 10
            bottomPadding: 10
            background: Rectangle {
                radius: 10
                color: Theme.currentTheme.isDark
                    ? Qt.rgba(1, 1, 1, 0.045)
                    : Qt.rgba(1, 1, 1, 0.48)
                border.width: 1
                border.color: editor.activeFocus
                    ? Theme.currentTheme.colors.primaryColor
                    : Theme.currentTheme.colors.cardBorderColor
                Behavior on border.color { ColorAnimation { duration: 120 } }
            }
            onTextChanged: notes.noteText = text
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Icon {
                name: "ic_fluent_edit_20_regular"
                size: 14
                color: Theme.currentTheme.colors.textSecondaryColor
            }
            Text {
                Layout.fillWidth: true
                text: "临时便签"
                font.pixelSize: 11
                color: Theme.currentTheme.colors.textSecondaryColor
            }
            Text {
                text: editor.length + "/200"
                font.pixelSize: 11
                color: Theme.currentTheme.colors.textSecondaryColor
            }
        }
    }
}
