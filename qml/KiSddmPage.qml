import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.kitotsu.kiui 1.0
import "components"

Item {
    id: page

    property color accent: "#ad3cf3"
    property color accentBright: "#d16cff"
    property color accentDark: "#7113b9"
    property color textPrimary: "#f3f1f8"
    property color textSecondary: "#9196aa"
    property string uiFont: "CaskaydiaCove Nerd Font Propo"
    property var themes: []
    property var config: ({})
    readonly property string selectedTheme: String(config.theme_preset || "")
    readonly property string backgroundMode: String((config.background || {}).mode || "static")

    KiSddmBridge { id: kisddm }

    function parse(input, fallback) {
        try { return JSON.parse(input) } catch (error) { return fallback }
    }

    function reload() {
        var themeData = parse(kisddm.themesJson, {})
        var configData = parse(kisddm.configJson, {})
        themes = themeData.presets || []
        config = configData.config || {}
    }

    Component.onCompleted: kisddm.refresh()
    Connections {
        target: kisddm
        function onThemesJsonChanged() { page.reload() }
        function onConfigJsonChanged() { page.reload() }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 18

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            ColumnLayout {
                spacing: 2
                Text { text: "KiSDDM"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 23; font.weight: Font.DemiBold }
                Text { text: "Personaliza tu pantalla de inicio de sesión"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                Layout.preferredWidth: 176
                Layout.preferredHeight: 38
                radius: 19
                color: "#0c0f19"
                border.color: kisddm.lastError.length > 0 ? "#8f3d4b" : "#293142"
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    KiIcon { name: kisddm.lastError.length > 0 ? "error" : "check_circle"; color: kisddm.lastError.length > 0 ? "#ff7b8b" : "#43d991"; iconSize: 17 }
                    Text { text: kisddm.lastError.length > 0 ? "Revisar configuración" : "Configuración válida"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 11 }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 460
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 390
                    radius: 16
                    color: "#b50c0f19"
                    border.color: "#282d3d"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            ColumnLayout {
                                spacing: 1
                                Text { text: "Vista previa de SDDM"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: "Representación del tema y su apariencia"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 10 }
                            }
                            Item { Layout.fillWidth: true }
                            KiIcon { name: "fullscreen"; color: page.textSecondary; iconSize: 18 }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 14
                            clip: true
                            border.color: "#34394b"
                            color: "#080b14"

                            SddmThemePreview {
                                anchors.fill: parent
                                preset: page.selectedTheme || "aurora-glass"
                                accent: page.accent
                                uiFont: page.uiFont
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 168
                    radius: 16
                    color: "#b50c0f19"
                    border.color: "#282d3d"
                    ColumnLayout {
                        anchors.fill: parent; anchors.margins: 14; spacing: 10
                        Text { text: "Temas / Presets"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                        RowLayout {
                            Layout.fillWidth: true; Layout.fillHeight: true; spacing: 10
                            Repeater {
                                model: page.themes
                                delegate: Button {
                                    required property var modelData
                                    Layout.fillWidth: true; Layout.fillHeight: true
                                    onClicked: kisddm.selectTheme(String(modelData.id))
                                    background: Rectangle {
                                        radius: 11
                                        color: page.selectedTheme === String(modelData.id) ? "#251431" : "#10131d"
                                        border.width: page.selectedTheme === String(modelData.id) ? 2 : 1
                                        border.color: page.selectedTheme === String(modelData.id) ? page.accent : "#303545"
                                    }
                                    contentItem: Column {
                                        spacing: 7
                                        Rectangle {
                                            width: parent.width
                                            height: Math.max(28, parent.height - 35)
                                            radius: 7
                                            clip: true
                                            color: "#080b14"
                                            SddmThemePreview {
                                                anchors.fill: parent
                                                preset: String(modelData.id)
                                                accent: page.accent
                                                uiFont: page.uiFont
                                                compact: true
                                            }
                                        }
                                        Text { text: String(modelData.name); color: "white"; font.family: page.uiFont; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight; width: parent.width }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.preferredWidth: Math.min(430, page.width * 0.36)
                Layout.fillHeight: true
                radius: 16
                color: "#b50c0f19"
                border.color: "#282d3d"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 14
                    Text { text: "Tema actual"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 10; color: "#10131e"; border.color: "#292e40"
                        Text { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: page.selectedTheme.replace(/-/g, " "); color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 12; font.capitalization: Font.Capitalize }
                    }
                    Button {
                        id: applySddmButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        enabled: !kisddm.busy && page.selectedTheme.length > 0
                        onClicked: kisddm.applyToSddm()
                        Accessible.name: "Aplicar el tema seleccionado en SDDM"
                        background: Rectangle {
                            radius: 10
                            opacity: applySddmButton.enabled ? 1 : 0.5
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0; color: page.accentDark }
                                GradientStop { position: 1; color: page.accent }
                            }
                            border.color: page.accentBright
                        }
                        contentItem: Row {
                            spacing: 8
                            KiIcon {
                                name: kisddm.busy ? "progress_activity" : "desktop_windows"
                                color: "white"
                                iconSize: 18
                            }
                            Text {
                                text: kisddm.busy ? "Aplicando…" : "Aplicar en SDDM"
                                color: "white"
                                font.family: page.uiFont
                                font.pixelSize: 11
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                    Rectangle { Layout.fillWidth: true; height: 1; color: "#252938" }
                    Text { text: "Fondo"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "¿Cómo quieres mostrar el fondo?"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 10 }
                    RowLayout {
                        Layout.fillWidth: true; spacing: 6
                        Repeater {
                            model: [{id:"static",label:"Imagen fija",icon:"image"},{id:"random",label:"Al iniciar",icon:"autorenew"},{id:"video",label:"Live",icon:"play_circle"}]
                            delegate: Button {
                                required property var modelData
                                Layout.fillWidth: true; Layout.preferredHeight: 43
                                onClicked: kisddm.setMode(modelData.id)
                                background: Rectangle { radius: 9; color: page.backgroundMode === modelData.id ? "#301541" : "#11141f"; border.color: page.backgroundMode === modelData.id ? page.accent : "#2a2f40" }
                                contentItem: Row {
                                    spacing: 6
                                    KiIcon {
                                        name: modelData.icon
                                        color: page.backgroundMode === modelData.id
                                            ? page.accentBright : page.textSecondary
                                        iconSize: 16
                                    }
                                    Text {
                                        text: modelData.label
                                        color: page.textPrimary
                                        font.family: page.uiFont
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 116; radius: 11; color: "#10131e"; border.color: "#292e40"
                        Column { anchors.fill: parent; anchors.margins: 13; spacing: 8
                            Text { text: page.backgroundMode === "video" ? "Live wallpaper" : page.backgroundMode === "random" ? "Rotación de wallpapers" : "Wallpaper actual"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                            Text { width: parent.width; wrapMode: Text.WordWrap; text: page.backgroundMode === "random" ? "Cambia al iniciar SDDM o al cerrar la sesión. Rota packs e imágenes sin usar intervalos." : page.backgroundMode === "video" ? "El vídeo se reproduce en bucle y cambia al volver a SDDM." : "Selecciona una imagen descargada desde Kitowall."; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 10 }
                            Text { text: "La selección de medios se conectará al selector compartido"; color: page.accentBright; font.family: page.uiFont; font.pixelSize: 9 }
                        }
                    }
                    Text { text: "Estado"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 116; radius: 11; color: "#10131e"; border.color: "#292e40"
                        GridLayout { anchors.fill: parent; anchors.margins: 13; columns: 2; rowSpacing: 9
                            Text { text: "Tema"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 10 }
                            Text { text: page.selectedTheme || "—"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 10 }
                            Text { text: "Modo"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 10 }
                            Text { text: page.backgroundMode === "random" ? "Por inicio / cierre" : page.backgroundMode; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 10 }
                            Text { text: "Contrato"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 10 }
                            Text { text: kisddm.busy ? "Actualizando…" : "v1 · conectado"; color: kisddm.busy ? page.textSecondary : "#43d991"; font.family: page.uiFont; font.pixelSize: 10 }
                        }
                    }
                    Text { visible: kisddm.lastError.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: kisddm.lastError; color: "#ff7b8b"; font.family: page.uiFont; font.pixelSize: 9 }
                    Text { visible: kisddm.lastMessage.length > 0; Layout.fillWidth: true; wrapMode: Text.WordWrap; text: kisddm.lastMessage; color: "#43d991"; font.family: page.uiFont; font.pixelSize: 9 }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
