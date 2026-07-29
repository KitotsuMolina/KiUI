import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control

    property string selectedColor: ""
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    readonly property var themeWindow: ApplicationWindow.window
    readonly property color accentBright: themeWindow
        && themeWindow.accentBright ? themeWindow.accentBright : "#d16cff"
    readonly property var colors: [
        "660000", "990000", "cc0000", "cc3333", "ea4c88", "993399",
        "663399", "333399", "0066cc", "0099cc", "66cccc", "77cc33",
        "669900", "336600", "666600", "999900", "cccc33", "ffff00",
        "ffcc33", "ff9900", "ff6600", "cc6633", "996633", "663300",
        "000000", "999999", "cccccc", "ffffff", "424153", ""
    ]

    spacing: 7
    Layout.fillWidth: true

    function loadValue(value) {
        selectedColor = String(value || "").replace(/^#/, "").toLowerCase()
    }

    Text {
        text: "Color"
        color: "#aeb3c3"
        font.family: control.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Button {
        id: trigger

        Layout.fillWidth: true
        Layout.preferredHeight: 42
        onClicked: colorPopup.opened ? colorPopup.close() : colorPopup.open()
        background: Rectangle {
            radius: 10
            color: trigger.hovered ? "#151826" : "#10131f"
            border.width: 1
            border.color: colorPopup.opened ? "#9b3fd1" : "#2d3142"
        }
        contentItem: RowLayout {
            spacing: 10

            Rectangle {
                Layout.preferredWidth: 24
                Layout.preferredHeight: 24
                radius: 7
                color: control.selectedColor.length > 0
                    ? "#" + control.selectedColor : "#171a26"
                border.width: 1
                border.color: control.selectedColor === "ffffff" ? "#777b8d" : "#3b3f50"

                KiIcon {
                    visible: control.selectedColor.length === 0
                    anchors.centerIn: parent
                    name: "format_color_reset"
                    color: "#858ba0"
                    iconSize: 15
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: control.selectedColor.length > 0
                        ? "#" + control.selectedColor.toUpperCase() : "Sin filtro de color"
                    color: control.selectedColor.length > 0 ? "#f3f1f8" : "#858ba0"
                    font.family: control.fontFamily
                    font.pixelSize: 10
                }
                Text {
                    text: "Paleta compatible con Wallhaven"
                    color: "#60667a"
                    font.family: control.fontFamily
                    font.pixelSize: 8
                }
            }

            KiIcon {
                name: colorPopup.opened ? "keyboard_arrow_up" : "palette"
                color: "#858ba0"
                iconSize: 17
            }
        }
    }

    Popup {
        id: colorPopup

        y: trigger.y + trigger.height + 6
        width: control.width
        padding: 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle {
            radius: 12
            color: "#151824"
            border.color: "#343849"
        }
        contentItem: ColumnLayout {
            spacing: 9

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Selecciona un color"
                    color: "#d5d2dd"
                    font.family: control.fontFamily
                    font.pixelSize: 10
                    font.weight: Font.DemiBold
                }
                Text {
                    text: control.selectedColor.length > 0
                        ? "#" + control.selectedColor.toUpperCase() : "ninguno"
                    color: "#858ba0"
                    font.family: control.fontFamily
                    font.pixelSize: 9
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 7

                Repeater {
                    model: control.colors

                    delegate: Button {
                        required property string modelData

                        width: 34
                        height: 34
                        padding: 0
                        onClicked: {
                            control.selectedColor = modelData
                            colorPopup.close()
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: modelData.length > 0
                            ? "#" + modelData.toUpperCase() : "Sin filtro"
                        background: Rectangle {
                            radius: 9
                            color: parent.modelData.length > 0
                                ? "#" + parent.modelData : "#10131f"
                            border.width: control.selectedColor === parent.modelData ? 3 : 1
                            border.color: control.selectedColor === parent.modelData
                                ? control.accentBright
                                : (parent.modelData === "ffffff" ? "#777b8d" : "#3b3f50")

                            KiIcon {
                                visible: parent.parent.modelData.length === 0
                                anchors.centerIn: parent
                                name: "format_color_reset"
                                color: "#9ba0b3"
                                iconSize: 17
                            }
                        }
                    }
                }
            }
        }
    }
}
