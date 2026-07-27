import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control

    property string ratio: "16x9"
    property string minimumResolution: "1920x1080"
    property string selectedMode: "16:9"
    property string customWidth: ""
    property string customHeight: ""
    property string fontFamily: "CaskaydiaCove Nerd Font Propo"
    readonly property bool customMode: selectedMode === "x:x"

    spacing: 9
    Layout.fillWidth: true

    function ratioForMode(mode) {
        switch (mode) {
        case "ultrawide": return "21x9"
        case "16:9": return "16x9"
        case "16:10": return "16x10"
        case "4:3": return "4x3"
        case "5:4": return "5x4"
        default: return ""
        }
    }

    function modeForRatio(value) {
        var firstRatio = String(value || "").split(",")[0].trim()
        switch (firstRatio) {
        case "21x9": return "ultrawide"
        case "16x9": return "16:9"
        case "16x10": return "16:10"
        case "4x3": return "4:3"
        case "5x4": return "5:4"
        default: return "x:x"
        }
    }

    function resolutionsForMode(mode) {
        switch (mode) {
        case "ultrawide":
            return ["2560x1080", "3440x1440", "3840x1600"]
        case "16:9":
            return ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
        case "16:10":
            return ["1280x800", "1600x1000", "1920x1200", "2560x1600", "3840x2400"]
        case "4:3":
            return ["1280x960", "1600x1200", "1920x1440", "2560x1920", "3840x2880"]
        case "5:4":
            return ["1280x1024", "1600x1280", "1920x1536", "2560x2048", "3840x3072"]
        default:
            return []
        }
    }

    function loadValues(ratios, atleast) {
        selectedMode = modeForRatio(ratios)
        ratio = ratioForMode(selectedMode)
        minimumResolution = String(atleast || "")
        customWidth = ""
        customHeight = ""
        if (customMode && minimumResolution.indexOf("x") > 0) {
            var dimensions = minimumResolution.split("x")
            customWidth = dimensions[0] || ""
            customHeight = dimensions[1] || ""
        }
    }

    function selectMode(mode) {
        selectedMode = mode
        ratio = ratioForMode(mode)
        minimumResolution = ""
        customWidth = ""
        customHeight = ""
        resolutionPopup.close()
        if (!customMode)
            resolutionPopup.open()
    }

    function updateCustomResolution() {
        if (!customMode)
            return
        var width = Number(customWidth)
        var height = Number(customHeight)
        minimumResolution = width > 0 && height > 0
            ? String(Math.floor(width)) + "x" + String(Math.floor(height))
            : ""
    }

    Text {
        text: "Relacion de pantalla"
        color: "#aeb3c3"
        font.family: control.fontFamily
        font.pixelSize: 11
        font.weight: Font.Medium
    }

    Flow {
        Layout.fillWidth: true
        spacing: 7

        Repeater {
            model: ["ultrawide", "16:9", "16:10", "4:3", "5:4", "x:x"]

            delegate: Button {
                required property string modelData

                text: modelData === "ultrawide" ? "Ultrawide" : modelData
                height: 34
                implicitWidth: contentItem.implicitWidth + 24
                onClicked: control.selectMode(modelData)
                background: Rectangle {
                    radius: 9
                    color: control.selectedMode === parent.modelData ? "#35144e" : "#10131f"
                    border.width: 1
                    border.color: control.selectedMode === parent.modelData ? "#ad3cf3" : "#2d3142"
                }
                contentItem: Text {
                    text: parent.text
                    color: control.selectedMode === parent.modelData ? "#f0d4ff" : "#aeb3c3"
                    font.family: control.fontFamily
                    font.pixelSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    RowLayout {
        visible: !control.customMode
        Layout.fillWidth: true
        spacing: 7

        Button {
            id: resolutionTrigger

            Layout.fillWidth: true
            Layout.preferredHeight: 42
            onClicked: resolutionPopup.opened ? resolutionPopup.close() : resolutionPopup.open()
            background: Rectangle {
                radius: 10
                color: resolutionTrigger.hovered ? "#151826" : "#10131f"
                border.width: 1
                border.color: resolutionPopup.opened ? "#9b3fd1" : "#2d3142"
            }
            contentItem: RowLayout {
                Text {
                    Layout.fillWidth: true
                    text: control.minimumResolution.length > 0
                        ? control.minimumResolution : "Selecciona resolucion minima"
                    color: control.minimumResolution.length > 0 ? "#f3f1f8" : "#666c80"
                    font.family: control.fontFamily
                    font.pixelSize: 10
                }
                KiIcon {
                    name: resolutionPopup.opened ? "keyboard_arrow_up" : "keyboard_arrow_down"
                    color: "#858ba0"
                    iconSize: 17
                }
            }
        }

        Button {
            visible: control.minimumResolution.length > 0
            Layout.preferredWidth: 42
            Layout.preferredHeight: 42
            onClicked: control.minimumResolution = ""
            ToolTip.visible: hovered
            ToolTip.text: "Sin resolucion minima"
            background: Rectangle {
                radius: 10
                color: parent.hovered ? "#261827" : "#10131f"
                border.color: "#2d3142"
            }
            contentItem: KiIcon {
                name: "close"
                color: "#c5a6b3"
                iconSize: 17
            }
        }
    }

    RowLayout {
        visible: control.customMode
        Layout.fillWidth: true
        spacing: 9

        TextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            text: control.customWidth
            placeholderText: "Ancho"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 1 }
            onTextEdited: {
                control.customWidth = text
                control.updateCustomResolution()
            }
            color: "#f3f1f8"
            placeholderTextColor: "#666c80"
            font.family: control.fontFamily
            font.pixelSize: 10
            background: Rectangle {
                radius: 10
                color: "#10131f"
                border.color: parent.activeFocus ? "#9b3fd1" : "#2d3142"
            }
        }

        Text {
            text: "x"
            color: "#858ba0"
            font.family: control.fontFamily
            font.pixelSize: 12
        }

        TextField {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            text: control.customHeight
            placeholderText: "Alto"
            inputMethodHints: Qt.ImhDigitsOnly
            validator: IntValidator { bottom: 1 }
            onTextEdited: {
                control.customHeight = text
                control.updateCustomResolution()
            }
            color: "#f3f1f8"
            placeholderTextColor: "#666c80"
            font.family: control.fontFamily
            font.pixelSize: 10
            background: Rectangle {
                radius: 10
                color: "#10131f"
                border.color: parent.activeFocus ? "#9b3fd1" : "#2d3142"
            }
        }
    }

    Text {
        Layout.fillWidth: true
        text: control.customMode
            ? (control.minimumResolution.length > 0
                ? "Resolucion personalizada: " + control.minimumResolution
                : "Introduce ancho y alto positivos")
            : "Solo se muestran resoluciones compatibles con " + control.selectedMode
        color: control.customMode && control.minimumResolution.length === 0 ? "#c98a98" : "#6f758a"
        font.family: control.fontFamily
        font.pixelSize: 9
    }

    Popup {
        id: resolutionPopup

        y: resolutionTrigger.y + resolutionTrigger.height + 6
        width: control.width
        padding: 10
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        background: Rectangle {
            radius: 12
            color: "#151824"
            border.color: "#343849"
        }
        contentItem: ColumnLayout {
            spacing: 8

            Text {
                text: "Resolucion minima para " + control.selectedMode
                color: "#d5d2dd"
                font.family: control.fontFamily
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: control.resolutionsForMode(control.selectedMode)

                    delegate: Button {
                        required property string modelData

                        text: modelData
                        height: 34
                        implicitWidth: contentItem.implicitWidth + 20
                        onClicked: {
                            control.minimumResolution = modelData
                            resolutionPopup.close()
                        }
                        background: Rectangle {
                            radius: 8
                            color: control.minimumResolution === parent.modelData
                                ? "#35144e" : (parent.hovered ? "#202333" : "#10131f")
                            border.color: control.minimumResolution === parent.modelData
                                ? "#ad3cf3" : "#2d3142"
                        }
                        contentItem: Text {
                            text: parent.text
                            color: control.minimumResolution === parent.modelData ? "#f0d4ff" : "#c3c7d4"
                            font.family: control.fontFamily
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
    }
}
