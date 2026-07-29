import QtQuick
import QtQuick.Controls

Control {
    id: root

    property string displayLabel: ""
    property string displayCount: ""
    property string displayIcon: ""
    property string trailingIcon: ""
    property bool selected: false
    property bool compact: false
    property color accent: "#ad3cf3"
    property color accentBright: "#d16cff"
    readonly property color accentSurface: Qt.rgba(
        accent.r, accent.g, accent.b, 0.22)
    signal activated()

    implicitHeight: 40
    hoverEnabled: true
    focusPolicy: Qt.StrongFocus
    Accessible.role: Accessible.Button
    Accessible.name: displayLabel

    background: Rectangle {
        radius: 10
        color: root.selected ? root.accentSurface
            : root.hovered ? "#151827" : "transparent"
        border.width: root.activeFocus ? 1 : 0
        border.color: root.accent
    }

    contentItem: Row {
        spacing: root.compact ? 0 : 11
        leftPadding: root.compact ? (root.width - 20) * 0.5 : 12
        rightPadding: root.compact ? (root.width - 20) * 0.5 : 10

        KiIcon {
            width: 20
            height: 20
            anchors.verticalCenter: parent.verticalCenter
            name: root.displayIcon
            color: root.selected ? root.accentBright : "#9ba1b7"
            iconSize: 18
        }

        Text {
            visible: !root.compact
            width: Math.max(0, root.width - 98)
            anchors.verticalCenter: parent.verticalCenter
            text: root.displayLabel
            color: root.selected ? "#ffffff" : "#c3c7d5"
            font.family: "CaskaydiaCove Nerd Font Propo"
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        Item {
            visible: !root.compact
            width: 34
            height: parent.height

            Text {
                visible: root.trailingIcon.length === 0
                anchors.centerIn: parent
                text: root.displayCount
                color: root.selected ? "#ddc4ee" : "#757b8f"
                font.family: "CaskaydiaCove Nerd Font Propo"
                font.pixelSize: 11
            }

            KiIcon {
                visible: root.trailingIcon.length > 0
                width: 18
                height: 18
                anchors.centerIn: parent
                name: root.trailingIcon
                color: root.selected ? "#ddc4ee" : "#757b8f"
                iconSize: 17
            }
        }
    }

    TapHandler {
        onTapped: root.activated()
    }

    Keys.onReturnPressed: root.activated()
    Keys.onEnterPressed: root.activated()
}
