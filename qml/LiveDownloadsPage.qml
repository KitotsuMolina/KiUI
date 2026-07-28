import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.kitotsu.kiui 1.0
import "components"

Item {
    id: root

    signal libraryChanged()

    property var outputModel
    property string selectedOutput: ""
    property int pageNumber: 1
    property int pageLimit: 20
    property var rawItems: []
    property int selectedIndex: -1
    readonly property var selectedItem: selectedIndex >= 0
        && selectedIndex < rawItems.length ? rawItems[selectedIndex] : ({})
    readonly property color accent: "#ad3cf3"
    readonly property color accentBright: "#d16cff"
    readonly property color panel: "#d90b0d18"
    readonly property color border: "#2a2d3d"
    readonly property color textPrimary: "#f3f1f8"
    readonly property color textSecondary: "#9196aa"
    readonly property string uiFont: "CaskaydiaCove Nerd Font Propo"

    function parseJson(input, fallback) {
        try {
            return JSON.parse(input)
        } catch (error) {
            return fallback
        }
    }

    function providerColor(provider) {
        return provider === "motionbgs"
            ? ["#155f78", "#10152c"] : ["#7a245d", "#151126"]
    }

    function currentProvider() {
        return ["all", "moewalls", "motionbgs"][providerSelect.currentIndex]
    }

    function currentQuality() {
        return qualitySelect.currentIndex === 1 ? "4k" : "all"
    }

    function requestCatalog(resetPage) {
        if (resetPage)
            pageNumber = 1
        kilivepaper.requestCatalog(
            searchField.text.trim(),
            currentProvider(),
            currentQuality(),
            pageNumber,
            pageLimit)
    }

    function loadCatalog() {
        var response = parseJson(kilivepaper.catalogJson, {})
        var items = response.items || []
        rawItems = items
        catalogModel.clear()
        for (var index = 0; index < items.length; ++index) {
            var item = items[index]
            var preview = item.media_preview || {}
            var colors = providerColor(String(item.provider || ""))
            var previewPath = String(preview.local_path || "")
            catalogModel.append({
                "title": String(item.title || item.slug || "Live wallpaper"),
                "provider": String(item.provider || ""),
                "colorA": colors[0],
                "colorB": colors[1],
                "favorite": false,
                "live": true,
                "duration": "",
                "previewSource": previewPath.length > 0
                    ? (previewPath.indexOf("file:") === 0
                        ? previewPath : "file://" + previewPath)
                    : String(item.thumb_remote || preview.remote_url || ""),
                "sourceWidth": Number(preview.width || 0),
                "sourceHeight": Number(preview.height || 0)
            })
        }
        selectedIndex = catalogModel.count > 0 ? 0 : -1
        hexGrid.currentIndex = Math.max(0, selectedIndex)
    }

    function selectedQuality() {
        if (qualitySelect.currentIndex === 1 && selectedItem.has_4k === true)
            return "4k"
        return selectedItem.has_hd === true ? "hd" : "auto"
    }

    function downloadSelected(apply) {
        if (selectedIndex < 0 || kilivepaper.busy)
            return
        kilivepaper.download(
            String(selectedItem.page_url || ""),
            selectedQuality(),
            root.selectedOutput,
            apply && root.selectedOutput.length > 0)
    }

    ListModel { id: catalogModel }

    Timer {
        id: searchDebounce
        interval: 450
        repeat: false
        onTriggered: root.requestCatalog(true)
    }

    KilivepaperBridge {
        id: kilivepaper
        onCatalogJsonChanged: root.loadCatalog()
        onLastMessageChanged: {
            if (lastMessage.indexOf("Live wallpaper descargado") === 0)
                root.libraryChanged()
        }
    }

    Component.onCompleted: requestCatalog(false)

    Row {
        id: toolbar
        anchors.left: parent.left
        anchors.right: detailPanel.left
        anchors.top: parent.top
        anchors.rightMargin: 18
        height: 48
        spacing: 12

        TextField {
            id: searchField
            width: Math.max(260, parent.width - 520)
            height: 46
            placeholderText: "Buscar wallpapers, temas o tags..."
            color: root.textPrimary
            placeholderTextColor: "#747a8d"
            font.family: root.uiFont
            font.pixelSize: 11
            leftPadding: 43
            rightPadding: 16
            onTextChanged: searchDebounce.restart()
            background: Rectangle {
                radius: 14
                color: "#a90d0f1a"
                border.width: parent.activeFocus ? 1 : 1
                border.color: parent.activeFocus ? root.accent : root.border
            }

            KiIcon {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: "search"
                color: "#9ba1b4"
                iconSize: 19
            }
        }

        ComboBox {
            id: providerSelect
            width: 210
            height: 46
            model: ["Todos los proveedores", "Moewalls", "MotionBGs"]
            onActivated: root.requestCatalog(true)
            contentItem: Text {
                leftPadding: 15
                rightPadding: 34
                text: "Proveedor: " + providerSelect.displayText
                color: root.textPrimary
                font.family: root.uiFont
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                radius: 13
                color: "#c40d0f1a"
                border.color: root.border
            }
        }

        ComboBox {
            id: qualitySelect
            width: 142
            height: 46
            model: ["Todas", "4K"]
            onActivated: root.requestCatalog(true)
            contentItem: Text {
                leftPadding: 15
                rightPadding: 32
                text: "Calidad: " + qualitySelect.displayText
                color: root.textPrimary
                font.family: root.uiFont
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 13
                color: "#c40d0f1a"
                border.color: root.border
            }
        }

        ComboBox {
            id: monitorSelect
            width: 132
            height: 46
            model: root.outputModel
            textRole: "outputName"
            onActivated: {
                if (currentIndex >= 0)
                    root.selectedOutput = currentText
            }
            contentItem: Row {
                leftPadding: 14
                spacing: 8

                KiIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "desktop_windows"
                    color: "#d0d3dc"
                    iconSize: 17
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedOutput.length > 0
                        ? root.selectedOutput : "Monitor"
                    color: root.textPrimary
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
            }
            background: Rectangle {
                radius: 13
                color: "#c40d0f1a"
                border.color: root.border
            }
        }
    }

    Rectangle {
        id: catalogPanel
        anchors.left: parent.left
        anchors.right: detailPanel.left
        anchors.top: toolbar.bottom
        anchors.bottom: pagination.top
        anchors.topMargin: 14
        anchors.rightMargin: 18
        anchors.bottomMargin: 10
        radius: 18
        color: "#300a0c16"
        border.width: 1
        border.color: "#171a28"
        clip: true

        HexGrid {
            id: hexGrid
            anchors.fill: parent
            anchors.margins: 8
            wallpaperModel: catalogModel
            currentIndex: Math.max(0, root.selectedIndex)
            columns: width > 980 ? 5 : width > 730 ? 4 : 3
            horizontalPadding: 22
            verticalPadding: 18
            tileGap: 11
            onSelected: function(itemIndex) {
                root.selectedIndex = itemIndex
            }
        }

        Column {
            visible: catalogModel.count === 0
            anchors.centerIn: parent
            width: Math.min(430, parent.width - 80)
            spacing: 10

            KiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: kilivepaper.busy ? "cloud_sync" : "search_off"
                color: root.accentBright
                iconSize: 34
            }

            Text {
                width: parent.width
                text: kilivepaper.busy
                    ? "Consultando proveedores..."
                    : "No se encontraron live wallpapers"
                color: root.textPrimary
                horizontalAlignment: Text.AlignHCenter
                font.family: root.uiFont
                font.pixelSize: 14
            }

            Text {
                visible: kilivepaper.lastError.length > 0
                width: parent.width
                text: kilivepaper.lastError
                color: "#e77989"
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                font.family: root.uiFont
                font.pixelSize: 10
            }
        }

        ProgressBar {
            visible: kilivepaper.busy
            indeterminate: true
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 3
        }
    }

    Row {
        id: pagination
        anchors.left: parent.left
        anchors.right: detailPanel.left
        anchors.bottom: parent.bottom
        anchors.rightMargin: 18
        height: 48
        spacing: 10

        Text {
            width: Math.max(190, parent.width - 500)
            anchors.verticalCenter: parent.verticalCenter
            text: catalogModel.count > 0
                ? "Pagina " + root.pageNumber + "  ·  "
                    + catalogModel.count + " resultados"
                : "Sin resultados"
            color: root.textSecondary
            font.family: root.uiFont
            font.pixelSize: 10
        }

        Button {
            width: 104
            height: 38
            anchors.verticalCenter: parent.verticalCenter
            enabled: root.pageNumber > 1 && !kilivepaper.busy
            text: "Anterior"
            onClicked: {
                root.pageNumber--
                root.requestCatalog(false)
            }
            background: Rectangle {
                radius: 10
                color: parent.hovered ? "#191c2a" : "#10131f"
                border.color: root.border
            }
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? root.textPrimary : "#555b6d"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.uiFont
                font.pixelSize: 10
            }
        }

        Rectangle {
            width: 38
            height: 38
            radius: 10
            anchors.verticalCenter: parent.verticalCenter
            gradient: Gradient {
                GradientStop { position: 0; color: "#b832ed" }
                GradientStop { position: 1; color: "#6818c5" }
            }
            Text {
                anchors.centerIn: parent
                text: root.pageNumber
                color: "white"
                font.family: root.uiFont
                font.pixelSize: 11
                font.bold: true
            }
        }

        Button {
            width: 104
            height: 38
            anchors.verticalCenter: parent.verticalCenter
            enabled: catalogModel.count >= root.pageLimit && !kilivepaper.busy
            text: "Siguiente"
            onClicked: {
                root.pageNumber++
                root.requestCatalog(false)
            }
            background: Rectangle {
                radius: 10
                color: parent.hovered ? "#21152c" : "#15111e"
                border.color: parent.enabled ? "#4c2863" : root.border
            }
            contentItem: Text {
                text: parent.text
                color: parent.enabled ? "#d89aef" : "#555b6d"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.family: root.uiFont
                font.pixelSize: 10
            }
        }

        Item { width: 18; height: 1 }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Limite"
            color: root.textSecondary
            font.family: root.uiFont
            font.pixelSize: 10
        }

        ComboBox {
            id: limitSelect
            width: 78
            height: 38
            anchors.verticalCenter: parent.verticalCenter
            model: [10, 20, 30, 50]
            currentIndex: 1
            onActivated: {
                root.pageLimit = Number(currentText)
                root.requestCatalog(true)
            }
            background: Rectangle {
                radius: 10
                color: "#10131f"
                border.color: root.border
            }
        }
    }

    Rectangle {
        id: detailPanel
        width: 304
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        radius: 19
        color: root.panel
        border.width: 1
        border.color: root.border

        Column {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            Rectangle {
                width: parent.width
                height: 188
                radius: 13
                color: "#121523"
                clip: true

                Image {
                    anchors.fill: parent
                    property string localPreview: String(
                        (root.selectedItem.media_preview || {}).local_path || "")
                    source: localPreview.length > 0
                        ? (localPreview.indexOf("file:") === 0
                            ? localPreview : "file://" + localPreview)
                        : String(root.selectedItem.thumb_remote
                            || (root.selectedItem.media_preview || {}).remote_url || "")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }

                Rectangle {
                    visible: root.selectedItem.has_4k === true
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 10
                    width: 36
                    height: 24
                    radius: 8
                    color: "#c0791ade"
                    Text {
                        anchors.centerIn: parent
                        text: "4K"
                        color: "white"
                        font.family: root.uiFont
                        font.pixelSize: 10
                        font.bold: true
                    }
                }
            }

            Text {
                width: parent.width
                text: String(root.selectedItem.title || "Selecciona un live wallpaper")
                color: root.textPrimary
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: root.uiFont
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: root.selectedIndex >= 0
                    ? "por " + String(root.selectedItem.provider || "desconocido")
                    : ""
                color: root.textSecondary
                font.family: root.uiFont
                font.pixelSize: 10
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.border
            }

            Text {
                text: "INFORMACION"
                color: "#676d81"
                font.family: root.uiFont
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            GridLayout {
                width: parent.width
                columns: 2
                columnSpacing: 12
                rowSpacing: 9

                Text { text: "Proveedor"; color: root.textSecondary; font.family: root.uiFont; font.pixelSize: 10 }
                Text {
                    Layout.fillWidth: true
                    text: String(root.selectedItem.provider || "No disponible")
                    color: root.textPrimary
                    horizontalAlignment: Text.AlignRight
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
                Text { text: "Calidad"; color: root.textSecondary; font.family: root.uiFont; font.pixelSize: 10 }
                Text {
                    Layout.fillWidth: true
                    text: root.selectedItem.has_4k === true ? "HD, 4K"
                        : root.selectedItem.has_hd === true ? "HD" : "No disponible"
                    color: root.textPrimary
                    horizontalAlignment: Text.AlignRight
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
                Text { text: "Duracion"; color: root.textSecondary; font.family: root.uiFont; font.pixelSize: 10 }
                Text {
                    Layout.fillWidth: true
                    text: "No disponible"
                    color: root.textPrimary
                    horizontalAlignment: Text.AlignRight
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
            }

            Text {
                text: "ETIQUETAS"
                color: "#676d81"
                font.family: root.uiFont
                font.pixelSize: 9
                font.letterSpacing: 1
            }

            Rectangle {
                width: parent.width
                height: 38
                radius: 10
                color: "#141724"

                Text {
                    anchors.centerIn: parent
                    text: (root.selectedItem.tags || []).length > 0
                        ? root.selectedItem.tags.join("  ·  ")
                        : "Disponibles al resolver el contenido"
                    color: root.textSecondary
                    font.family: root.uiFont
                    font.pixelSize: 9
                    elide: Text.ElideRight
                    width: parent.width - 18
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Item { width: 1; height: Math.max(0, parent.height - 610) }

            Text {
                visible: kilivepaper.lastMessage.length > 0 || kilivepaper.lastError.length > 0
                width: parent.width
                text: kilivepaper.lastError.length > 0
                    ? kilivepaper.lastError : kilivepaper.lastMessage
                color: kilivepaper.lastError.length > 0 ? "#e77989" : "#74dc9a"
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                font.family: root.uiFont
                font.pixelSize: 9
            }

            Button {
                width: parent.width
                height: 44
                enabled: root.selectedIndex >= 0 && !kilivepaper.busy
                text: root.selectedItem.has_4k === true
                    ? "Descargar 4K" : "Descargar HD"
                onClicked: root.downloadSelected(false)
                background: Rectangle {
                    radius: 11
                    gradient: Gradient {
                        GradientStop { position: 0; color: parent.enabled ? "#bd2bea" : "#292b37" }
                        GradientStop { position: 1; color: parent.enabled ? "#7416d1" : "#20222d" }
                    }
                }
                contentItem: Text {
                    text: kilivepaper.busy ? "Procesando..." : parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.uiFont
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            Button {
                width: parent.width
                height: 42
                enabled: root.selectedIndex >= 0
                    && root.selectedOutput.length > 0
                    && !kilivepaper.busy
                text: "Descargar y aplicar en "
                    + (root.selectedOutput.length > 0 ? root.selectedOutput : "monitor")
                onClicked: root.downloadSelected(true)
                background: Rectangle {
                    radius: 11
                    color: parent.hovered ? "#1b1e2c" : "#131620"
                    border.color: root.border
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? root.textPrimary : "#5f6474"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
            }
        }
    }
}
