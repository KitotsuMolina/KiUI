import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control

    property string label: ""
    property var options: []
    property string bits: "000"
    property string placeholderText: "Selecciona opciones"
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"

    spacing: 7
    Layout.fillWidth: true

    function normalizedBits() {
        return /^[01]+$/.test(bits) && bits.length === options.length
            ? bits : "0".repeat(options.length)
    }

    function selected(index) {
        return normalizedBits().charAt(index) === "1"
    }

    function toggle(index) {
        var current = normalizedBits().split("")
        current[index] = current[index] === "1" ? "0" : "1"
        bits = current.join("")
    }

    Text {
        text: control.label
        color: "#aeb3c3"
        font.family: control.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Button {
        id: trigger

        Layout.fillWidth: true
        Layout.preferredHeight: 44
        onClicked: optionsPopup.opened ? optionsPopup.close() : optionsPopup.open()
        background: Rectangle {
            radius: 10
            color: trigger.hovered ? "#151826" : "#10131f"
            border.width: 1
            border.color: optionsPopup.opened ? "#9b3fd1" : "#2d3142"
        }
        contentItem: RowLayout {
            spacing: 7

            Flow {
                Layout.fillWidth: true
                spacing: 5

                Repeater {
                    model: control.options
                    delegate: Rectangle {
                        required property int index
                        required property string modelData

                        visible: control.selected(index)
                        width: chipLabel.implicitWidth + 16
                        height: 24
                        radius: 8
                        color: "#35144e"
                        border.color: "#69308a"

                        Text {
                            id: chipLabel
                            anchors.centerIn: parent
                            text: modelData
                            color: "#dcb5f4"
                            font.family: control.fontFamily
                            font.pixelSize: 9
                        }
                    }
                }

                Text {
                    visible: control.normalizedBits().indexOf("1") < 0
                    text: control.placeholderText
                    color: "#666c80"
                    font.family: control.fontFamily
                    font.pixelSize: 10
                    topPadding: 5
                }
            }

            Rectangle {
                Layout.preferredWidth: 42
                Layout.preferredHeight: 24
                radius: 8
                color: "#19132a"
                border.color: "#433052"
                Text {
                    anchors.centerIn: parent
                    text: control.normalizedBits()
                    color: "#c78fe7"
                    font.family: control.fontFamily
                    font.pixelSize: 9
                }
            }

            KiIcon {
                Layout.preferredWidth: 18
                name: optionsPopup.opened ? "keyboard_arrow_up" : "keyboard_arrow_down"
                color: "#858ba0"
                iconSize: 17
            }
        }
    }

    Popup {
        id: optionsPopup

        parent: control
        x: 0
        y: trigger.y + trigger.height + 6
        width: control.width
        padding: 6
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle {
            radius: 12
            color: "#151824"
            border.color: "#343849"
        }
        contentItem: ColumnLayout {
            spacing: 4

            Repeater {
                model: control.options
                delegate: Button {
                    required property int index
                    required property string modelData

                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    onClicked: control.toggle(index)
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? "#2b163d" : "transparent"
                    }
                    contentItem: RowLayout {
                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: "#d5d2dd"
                            font.family: control.fontFamily
                            font.pixelSize: 10
                        }
                        Rectangle {
                            width: 36
                            height: 22
                            radius: 8
                            color: control.selected(index) ? "#17412b" : "#351b24"
                            Text {
                                anchors.centerIn: parent
                                text: control.selected(index) ? "on" : "off"
                                color: control.selected(index) ? "#75df9b" : "#e58b98"
                                font.family: control.fontFamily
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }
        }
    }
}
