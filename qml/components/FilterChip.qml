import QtQuick
import QtQuick.Controls

Control {
    id: root

    property string label: ""
    property string count: ""
    property string iconName: ""
    property bool selected: false
    signal activated()

    implicitWidth: 20 + iconItem.width + labelText.implicitWidth
        + countText.implicitWidth + contentRow.spacing * 2
    implicitHeight: 42
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: label

    background: Rectangle {
        radius: 14
        color: root.selected ? "#331056" : root.hovered ? "#161827" : "#10121d"
        border.width: 1
        border.color: root.selected ? "#a93bf4" : root.activeFocus ? "#8d48bd" : "#272a39"

        Rectangle {
            visible: root.selected
            anchors.fill: parent
            anchors.margins: -5
            radius: 18
            color: "transparent"
            border.width: 1
            border.color: "#47205f"
            opacity: 0.75
        }
    }

    contentItem: Row {
        id: contentRow

        spacing: 6
        leftPadding: 10
        rightPadding: 10

        KiIcon {
            id: iconItem

            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter
            name: root.iconName
            iconSize: 16
            color: root.selected ? "#c15bff" : "#6e7488"
        }

        Text {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: "#eef0f8"
            font.family: "CaskaydiaCove Nerd Font Propo"
            font.pixelSize: 12
        }

        Text {
            id: countText

            anchors.verticalCenter: parent.verticalCenter
            text: root.count
            color: "#7e8497"
            font.family: "CaskaydiaCove Nerd Font Propo"
            font.pixelSize: 10
        }
    }

    TapHandler {
        onTapped: root.activated()
    }

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
}
