import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: field

    property alias label: labelItem.text
    property alias text: input.text
    property alias placeholderText: input.placeholderText
    property alias echoMode: input.echoMode
    property string helperText: ""
    property bool readOnly: false
    property int inputMethodHints: Qt.ImhNone
    property color textColor: "#f3f1f8"
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"

    spacing: 7
    Layout.fillWidth: true

    Text {
        id: labelItem
        color: "#aeb3c3"
        font.family: field.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    TextField {
        id: input
        Layout.fillWidth: true
        Layout.preferredHeight: 42
        readOnly: field.readOnly
        inputMethodHints: field.inputMethodHints
        color: field.textColor
        placeholderTextColor: "#666c80"
        selectionColor: "#7d2bc2"
        selectedTextColor: "white"
        font.family: field.fontFamily
        font.pixelSize: 11
        leftPadding: 13
        rightPadding: 13
        background: Rectangle {
            radius: 10
            color: input.readOnly ? "#0c0e17" : "#10131f"
            border.width: 1
            border.color: input.activeFocus ? "#9b3fd1" : "#2d3142"
        }
    }

    Text {
        visible: field.helperText.length > 0
        Layout.fillWidth: true
        text: field.helperText
        color: "#6f758a"
        wrapMode: Text.WordWrap
        font.family: field.fontFamily
        font.pixelSize: 9
    }
}
