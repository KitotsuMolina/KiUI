import QtQuick
import QtQuick.Controls

Button {
    id: control

    property string tone: "secondary"
    property string iconName: ""
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"

    implicitWidth: Math.max(88, label.implicitWidth + (iconName.length > 0 ? 48 : 30))
    implicitHeight: 36
    leftPadding: 14
    rightPadding: 14
    topPadding: 0
    bottomPadding: 0

    function backgroundColor() {
        if (!enabled)
            return "#10121a"
        if (tone === "primary")
            return down ? "#7113b9" : (hovered ? "#a526df" : "#8d1dce")
        if (tone === "danger")
            return down ? "#32141e" : (hovered ? "#391824" : "#28151d")
        return down ? "#181b28" : (hovered ? "#1d202f" : "#131620")
    }

    function borderColor() {
        if (activeFocus)
            return tone === "danger" ? "#d15b76" : "#ad3cf3"
        if (tone === "primary")
            return "#b94dec"
        if (tone === "danger")
            return hovered ? "#8a3b50" : "#56303d"
        return hovered ? "#454a5e" : "#303445"
    }

    background: Rectangle {
        radius: 9
        color: control.backgroundColor()
        border.width: 1
        border.color: control.borderColor()
        opacity: control.enabled ? 1 : 0.55

        Behavior on color {
            ColorAnimation { duration: 100 }
        }
    }

    contentItem: Item {
        implicitWidth: actionRow.implicitWidth
        implicitHeight: actionRow.implicitHeight

        Row {
            id: actionRow
            anchors.centerIn: parent
            spacing: 7

            KiIcon {
                visible: control.iconName.length > 0
                width: visible ? 17 : 0
                height: 17
                anchors.verticalCenter: parent.verticalCenter
                name: control.iconName
                color: control.tone === "danger" ? "#e38ba0" : "#c9ccd8"
                iconSize: 16
            }

            Text {
                id: label
                anchors.verticalCenter: parent.verticalCenter
                text: control.text
                color: !control.enabled
                    ? "#686d7e"
                    : (control.tone === "primary"
                        ? "white"
                        : (control.tone === "danger" ? "#e5a2b1" : "#c9ccd8"))
                font.family: control.fontFamily
                font.pixelSize: 10
                font.weight: Font.Medium
            }
        }
    }
}
