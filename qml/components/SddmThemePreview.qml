import QtQuick
import QtQuick.Layouts

Item {
    id: preview

    property string preset: "aurora-glass"
    property color accent: "#ad3cf3"
    property color foreground: "#ffffff"
    property string uiFont: "CaskaydiaCove Nerd Font Propo"
    property bool compact: false

    FontLoader {
        id: pixelFont
        source: "qrc:/qt/qml/dev/kitotsu/kiui/qml/assets/PixelifySans-Bold.ttf"
    }

    clip: true

    Item {
        id: canvas
        width: 640
        height: 400
        anchors.centerIn: parent
        scale: Math.min(preview.width / width, preview.height / height)

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: preview.preset === "neon-grid" ? "#1a2440" : "#76586d" }
                GradientStop { position: 0.48; color: preview.preset === "ember-focus" ? "#b27767" : "#34415c" }
                GradientStop { position: 1; color: preview.preset === "polar-night" ? "#667080" : "#151b31" }
            }
        }

        // Aurora Glass · panel lateral basado en Sugar Candy.
        Item {
            anchors.fill: parent
            visible: preview.preset === "aurora-glass"

            Rectangle {
                width: 224
                height: parent.height
                color: "#99283a50"
                Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: "#33ffffff" }
            }
            Column {
                x: 34
                y: 24
                width: 156
                spacing: 7
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "¡Bienvenido!"; color: "white"; font.family: preview.uiFont; font.pixelSize: 24 }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(new Date(), "HH:mm"); color: "white"; font.family: preview.uiFont; font.pixelSize: 30; font.weight: Font.Light }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(new Date(), "dddd, d 'de' MMMM"); color: "#ddffffff"; font.family: preview.uiFont; font.pixelSize: 9 }
                Item { width: 1; height: 12 }
                Rectangle {
                    width: parent.width; height: 32; radius: 16; color: "#10ffffff"; border.color: "white"
                    Text { anchors.centerIn: parent; text: "usuario"; color: "white"; font.family: preview.uiFont; font.pixelSize: 10 }
                }
                Rectangle {
                    width: parent.width; height: 32; radius: 16; color: "#10ffffff"; border.color: "white"
                    Text { anchors.centerIn: parent; text: "••••••"; color: "white"; font.pixelSize: 11; font.letterSpacing: 2 }
                }
                Text { text: "□  Mostrar contraseña"; color: "white"; font.family: preview.uiFont; font.pixelSize: 7 }
                Item { width: 1; height: 8 }
                Rectangle {
                    width: parent.width; height: 34; radius: 17; color: preview.accent
                    Text { anchors.centerIn: parent; text: "Iniciar sesión"; color: "white"; font.family: preview.uiFont; font.pixelSize: 10 }
                }
            }
            Text {
                x: 34
                y: 326
                width: 156
                text: "Sesión: Hyprland"
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                font.family: preview.uiFont
                font.pixelSize: 8
            }
            Row {
                x: 30
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                spacing: 10
                Repeater {
                    model: [{s:"◐",t:"Dormir"},{s:"↻",t:"Reiniciar"},{s:"⏻",t:"Apagar"}]
                    delegate: Column {
                        width: 50; spacing: 3
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.s; color: "white"; font.pixelSize: 20 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: "white"; font.family: preview.uiFont; font.pixelSize: 7 }
                    }
                }
            }
        }

        // Neon Grid · Pixel Night City.
        Item {
            anchors.fill: parent
            visible: preview.preset === "neon-grid"
            property color pink: "#ff719a"
            property color teal: "#4bdde8"

            Rectangle { anchors.fill: parent; color: "#45101828" }
            Row {
                x: 28; y: 22; spacing: 8
                Text { text: Qt.formatTime(new Date(), "HH"); color: "white"; font.family: pixelFont.name; font.pixelSize: 52; font.weight: Font.Bold }
                Rectangle { width: 3; height: 44; color: parent.parent.pink; anchors.verticalCenter: parent.verticalCenter }
                Text { text: Qt.formatTime(new Date(), "mm"); color: parent.parent.teal; font.family: pixelFont.name; font.pixelSize: 52; font.weight: Font.Bold }
            }
            Text { x: 30; y: 82; text: Qt.formatDate(new Date(), "dddd, MMMM d").toUpperCase(); color: "#e8e4f0"; font.family: pixelFont.name; font.pixelSize: 8; font.letterSpacing: 4 }
            Row {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24; spacing: 23
                Repeater {
                    model: [{t:"HYPRLAND",c:"#ff719a"},{t:"REBOOT",c:"#4bdde8"},{t:"OFF",c:"#4bdde8"}]
                    Text { text: modelData.t; color: modelData.c; font.family: pixelFont.name; font.pixelSize: 7; font.letterSpacing: 2; font.weight: Font.Bold }
                }
            }
            Column {
                width: 220; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 34; spacing: 14
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "USUARIO"; color: "#e8e4f0"; font.family: pixelFont.name; font.pixelSize: 14; font.letterSpacing: 5; font.weight: Font.Bold }
                Item {
                    width: parent.width; height: 32
                    Text { anchors.centerIn: parent; text: "CONNECTING..."; color: "#664bdde8"; font.family: pixelFont.name; font.pixelSize: 8; font.letterSpacing: 3 }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: "#ff719a" }
                }
            }
        }

        // Ember Focus · Plasma Chili.
        Item {
            anchors.fill: parent
            visible: preview.preset === "ember-focus"
            Rectangle { anchors.fill: parent; color: "#380d0603" }
            Column {
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 24; spacing: 1
                Text { anchors.right: parent.right; text: Qt.formatTime(new Date(), "HH:mm"); color: "white"; font.family: preview.uiFont; font.pixelSize: 24; font.weight: Font.Light }
                Text { anchors.right: parent.right; text: Qt.formatDate(new Date(), "dddd, d 'de' MMMM"); color: "#ddffffff"; font.family: preview.uiFont; font.pixelSize: 9 }
            }
            Column {
                width: 220; anchors.centerIn: parent; spacing: 12
                Rectangle {
                    width: 70; height: 70; radius: 35; anchors.horizontalCenter: parent.horizontalCenter; color: "#cc24150f"; border.color: "#99ffffff"; border.width: 2
                    Text { anchors.centerIn: parent; text: "K"; color: "white"; font.family: preview.uiFont; font.pixelSize: 30; font.weight: Font.Light }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "usuario"; color: "white"; font.family: preview.uiFont; font.pixelSize: 13 }
                Rectangle {
                    width: parent.width; height: 32; radius: 2; color: "#e8e3e0"
                    Text { anchors.left: parent.left; anchors.leftMargin: 9; anchors.verticalCenter: parent.verticalCenter; text: "Contraseña"; color: "#77453630"; font.family: preview.uiFont; font.pixelSize: 9 }
                }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Hyprland"; color: "#ccffffff"; font.family: preview.uiFont; font.pixelSize: 8 }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; spacing: 18
                    Repeater {
                        model: [{s:"◐",t:"Suspender"},{s:"↻",t:"Reiniciar"},{s:"⏻",t:"Apagar"}]
                        delegate: Column {
                            width: 52; spacing: 2
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.s; color: "white"; font.pixelSize: 24 }
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.t; color: "white"; font.family: preview.uiFont; font.pixelSize: 7 }
                        }
                    }
                }
            }
        }

        // Polar Night · Nordic.
        Item {
            anchors.fill: parent
            visible: preview.preset === "polar-night"
            Rectangle { anchors.fill: parent; color: "#70828a99" }
            Rectangle {
                width: 286; height: 248; anchors.centerIn: parent; radius: 6; color: "#d9232833"
                Rectangle {
                    width: 74; height: 74; radius: 37; anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top; anchors.topMargin: -18; color: "#232831"; border.color: "#8fbcbb"; border.width: 3
                    Text { anchors.centerIn: parent; text: "K"; color: "#c3c7d1"; font.family: preview.uiFont; font.pixelSize: 30 }
                }
                Text { anchors.top: parent.top; anchors.topMargin: 67; width: parent.width; text: "usuario"; color: "#c3c7d1"; font.family: preview.uiFont; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter }
                Rectangle { width: 184; height: 28; radius: 14; anchors.horizontalCenter: parent.horizontalCenter; y: 102; color: "#66323a49"; Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: "Contraseña"; color: "#a8c3c7d1"; font.family: preview.uiFont; font.pixelSize: 8 } }
                Rectangle { width: 184; height: 28; radius: 14; anchors.horizontalCenter: parent.horizontalCenter; y: 138; color: "#4d698989"; Text { anchors.centerIn: parent; text: "Iniciar sesión"; color: "#77ffffff"; font.family: preview.uiFont; font.pixelSize: 8 } }
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18; spacing: 10
                    Repeater {
                        model: [{s:"◐",t:"Dormir"},{s:"↻",t:"Reiniciar"},{s:"⏻",t:"Apagar"},{s:"⇥",t:"Otro usuario"}]
                        delegate: Column {
                            width: 54; spacing: 1
                            Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.s; color: "#c3c7d1"; font.pixelSize: 19 }
                            Text { width: parent.width; text: modelData.t; color: "#c3c7d1"; font.family: preview.uiFont; font.pixelSize: 6; horizontalAlignment: Text.AlignHCenter }
                        }
                    }
                }
            }
            Text { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 11; text: "Sesión de escritorio: Hyprland"; color: "#c3c7d1"; font.family: preview.uiFont; font.pixelSize: 7 }
            Text { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 11; text: "▣ 94%   " + Qt.formatDateTime(new Date(), "ddd, d MMM yyyy  HH:mm"); color: "#c3c7d1"; font.family: preview.uiFont; font.pixelSize: 7 }
        }
    }
}
