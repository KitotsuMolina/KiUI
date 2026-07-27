import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.kitotsu.kiui 1.0
import "components"

Rectangle {
    id: page

    signal closeRequested()

    property var kitowall: null
    color: "transparent"
    property int activeSection: 0
    property string selectedPackName: ""
    property string activeProvider: "wallhaven"
    property var sharedProviderCredentials: ({})
    property string catalogRefreshJobId: ""
    property int serviceTotal: 0
    property int serviceInstalled: 0
    property int serviceEnabled: 0
    property int serviceActive: 0
    property int serviceErrors: 0
    property bool servicesHealthy: false
    readonly property color accent: "#ad3cf3"
    readonly property color accentBright: "#d16cff"
    readonly property color panel: "#d90b0d18"
    readonly property color border: "#2a2d3d"
    readonly property color textPrimary: "#f3f1f8"
    readonly property color textSecondary: "#9196aa"
    readonly property string uiFont: "CaskaydiaCove Nerd Font Propo"
    property var transitionTypes: [
        "simple", "fade", "left", "right", "top", "bottom", "wipe",
        "wave", "grow", "center", "outer", "any", "random"
    ]

    function parseJson(input, fallback) {
        try {
            return JSON.parse(input)
        } catch (error) {
            return fallback
        }
    }

    function value(object, key, fallback) {
        return object && object[key] !== undefined && object[key] !== null
            ? object[key] : fallback
    }

    function textValue(object, key) {
        var result = value(object, key, "")
        return Array.isArray(result) ? result.join(", ") : String(result)
    }

    function boolValue(object, key, fallback) {
        return value(object, key, fallback) === true
    }

    function providerIndex(provider) {
        for (var index = 0; index < providerModel.count; ++index) {
            if (providerModel.get(index).value === provider)
                return index
        }
        return 0
    }

    function loadSettings() {
        var settings = parseJson(kitowall.settingsJson, {})
        if (!settings || Object.keys(settings).length === 0)
            return
        modeSelect.currentIndex = settings.mode === "rotate" ? 1 : 0
        intervalField.text = String(value(settings, "rotation_interval_seconds", 1800))
        backendField.text = String(value(settings, "wallpaper_backend", "auto"))
        var transition = value(settings, "transition", {})
        transitionSelect.currentIndex = Math.max(
            0, transitionTypes.indexOf(String(value(transition, "type", "center"))))
        fpsField.text = String(value(transition, "fps", 60))
        durationField.text = String(value(transition, "duration", 0.7))
        angleField.text = textValue(transition, "angle")
        positionField.text = textValue(transition, "pos")
        var selection = value(settings, "selection", {})
        perOutputField.text = String(value(selection, "perOutputCooldown", 10))
        globalCooldownField.text = String(value(selection, "globalCooldown", 20))
        duplicateSwitch.checked = boolValue(selection, "avoidSameTickDuplicates", true)
        var cache = value(settings, "cache", {})
        cacheDirField.text = textValue(cache, "dir")
        downloadDirField.text = textValue(cache, "downloadDir")
        cacheLimitField.text = String(value(cache, "maxMB", 2048))
        cacheTtlField.text = String(value(cache, "defaultTtlSec", 604800))
    }

    function loadPacks() {
        var response = parseJson(kitowall.packsJson, {})
        var packs = value(response, "packs", {})
        sharedProviderCredentials = value(response, "providerCredentials", {})
        packsModel.clear()
        var names = Object.keys(packs).sort()
        for (var index = 0; index < names.length; ++index) {
            var name = names[index]
            var pack = packs[name]
            packsModel.append({
                "name": name,
                "provider": String(value(pack, "type", "unknown")),
                "configJson": JSON.stringify(pack)
            })
        }
    }

    function providerCredentialConfigured(provider) {
        return boolValue(
            value(sharedProviderCredentials, provider, {}),
            "apiKeyConfigured",
            false)
    }

    function refreshAll() {
        if (!kitowall)
            return
        kitowall.refresh()
        kitowall.refreshServices()
        loadSettings()
        loadPacks()
        loadJobs()
        loadServices()
    }

    function loadJobs() {
        var response = parseJson(kitowall.jobsJson, {})
        var jobs = value(response, "jobs", [])
        jobs.sort(function(left, right) {
            return Number(value(right, "updated_at_unix_ms", 0))
                - Number(value(left, "updated_at_unix_ms", 0))
        })
        jobsModel.clear()
        for (var index = 0; index < jobs.length; ++index) {
            var job = jobs[index]
            var jobId = String(value(job, "id", ""))
            var status = String(value(job, "status", "unknown"))
            jobsModel.append({
                "jobId": jobId,
                "kind": String(value(job, "kind", "")),
                "status": status,
                "pack": String(value(job, "pack", "")),
                "completed": Number(value(job, "completed", 0)),
                "total": Number(value(job, "total", 0)),
                "errorText": String(value(job, "error", ""))
            })
            if (status === "completed" && catalogRefreshJobId !== jobId) {
                catalogRefreshJobId = jobId
                kitowall.refreshCatalog("", 0, 100)
            }
        }
    }

    function serviceStateLabel(state) {
        switch (state) {
        case "active": return "Activo"
        case "enabled": return "Habilitado"
        case "stopped": return "Detenido"
        case "not_installed": return "No instalado"
        case "error": return "Error"
        default: return "Desconocido"
        }
    }

    function serviceStateColor(state) {
        switch (state) {
        case "active": return "#69da8c"
        case "enabled": return "#65c6dc"
        case "stopped": return "#d8ad69"
        case "error": return "#f07983"
        default: return "#8f95a8"
        }
    }

    function serviceStateIcon(state) {
        switch (state) {
        case "active": return "play_circle"
        case "enabled": return "check_circle"
        case "stopped": return "pause_circle"
        case "error": return "error"
        default: return "remove_circle"
        }
    }

    function artifactSummary(artifacts) {
        if (!Array.isArray(artifacts) || artifacts.length === 0)
            return "Sin artefactos registrados"
        var labels = []
        for (var index = 0; index < artifacts.length; ++index) {
            var artifact = artifacts[index]
            var state = artifact.active ? "activo"
                : (artifact.enabled ? "habilitado" : "detenido")
            labels.push(String(value(artifact, "unit_name", value(artifact, "id", "")))
                + " · " + state)
        }
        return labels.join("\n")
    }

    function loadServices() {
        var response = parseJson(kitowall.servicesJson, {})
        var summary = value(response, "summary", {})
        var automations = value(response, "automations", [])
        serviceTotal = Number(value(summary, "total", automations.length))
        serviceInstalled = Number(value(summary, "installed", 0))
        serviceEnabled = Number(value(summary, "enabled", 0))
        serviceActive = Number(value(summary, "active", 0))
        serviceErrors = Number(value(summary, "errors", 0))
        servicesHealthy = value(summary, "healthy", false) === true
        servicesModel.clear()
        for (var index = 0; index < automations.length; ++index) {
            var automation = automations[index]
            var state = String(value(automation, "state", "unknown"))
            servicesModel.append({
                "serviceId": String(value(automation, "id", "")),
                "label": String(value(automation, "label", "")),
                "description": String(value(automation, "description", "")),
                "state": state,
                "stateLabel": serviceStateLabel(state),
                "stateColor": serviceStateColor(state),
                "stateIcon": serviceStateIcon(state),
                "installed": value(automation, "installed", false) === true,
                "enabled": value(automation, "enabled", false) === true,
                "active": value(automation, "active", false) === true,
                "artifactSummary": artifactSummary(value(automation, "artifacts", [])),
                "errorText": String(value(automation, "error", ""))
            })
        }
    }

    function hasActiveJobs() {
        for (var index = 0; index < jobsModel.count; ++index) {
            var status = jobsModel.get(index).status
            if (["queued", "running", "cancel_requested"].indexOf(status) >= 0)
                return true
        }
        return false
    }

    function jobStatusLabel(status) {
        switch (status) {
        case "queued": return "En cola"
        case "running": return "En progreso"
        case "cancel_requested": return "Cancelando"
        case "canceled": return "Cancelado"
        case "completed": return "Completado"
        case "failed": return "Fallido"
        default: return status
        }
    }

    function jobStatusColor(status) {
        if (status === "completed")
            return "#69da8c"
        if (status === "failed")
            return "#f07983"
        if (status === "canceled")
            return "#8f95a8"
        return "#d6a3f5"
    }

    function clearEditor(provider) {
        selectedPackName = ""
        activeProvider = provider || activeProvider
        providerSelect.currentIndex = providerIndex(activeProvider)
        packNameField.text = ""
        localPathsField.text = ""
        keywordField.text = ""
        queryField.text = ""
        subredditsField.text = ""
        endpointField.text = ""
        imagePathField.text = ""
        urlField.text = ""
        urlsField.text = ""
        subthemesField.text = ""
        apiKeyField.text = ""
        apiKeyEnvField.text = ""
        categoriesMask.bits = "111"
        purityMask.bits = "100"
        ratioResolution.loadValues("16x9", "1920x1080")
        colorPicker.loadValue("")
        sortingField.text = "random"
        redditSfw.checked = true
        aiArt.checked = false
        minWidthField.text = "1920"
        minHeightField.text = "1080"
        ratioWField.text = "16"
        ratioHField.text = "9"
        redditSortField.text = "hot"
        redditTimeField.text = "week"
        topicsField.text = ""
        collectionsField.text = ""
        usernameField.text = ""
        orientationField.text = "landscape"
        contentFilterField.text = "high"
        imageWidthField.text = "1920"
        imageHeightField.text = "1080"
        imageFitField.text = "crop"
        imageQualityField.text = "80"
        imagePrefixField.text = ""
        candidateLimitField.text = ""
        postPathField.text = ""
        postPrefixField.text = ""
        authorNamePathField.text = ""
        authorUrlPathField.text = ""
        authorUrlPrefixField.text = ""
        authorNameField.text = ""
        authorUrlField.text = ""
        domainField.text = ""
        postUrlField.text = ""
        differentImages.checked = false
        countField.text = "1"
        ttlField.text = ""
    }

    function editPack(name, configJson) {
        var config = parseJson(configJson, {})
        var provider = String(value(config, "type", "wallhaven"))
        clearEditor(provider)
        selectedPackName = name
        packNameField.text = name
        localPathsField.text = textValue(config, "paths")
        keywordField.text = textValue(config, "keyword")
        queryField.text = textValue(config, "query")
        subredditsField.text = textValue(config, "subreddits")
        endpointField.text = textValue(config, "endpoint")
        imagePathField.text = textValue(config, "imagePath")
        urlField.text = textValue(config, "url")
        urlsField.text = textValue(config, "urls")
        subthemesField.text = textValue(config, "subthemes")
        apiKeyEnvField.text = textValue(config, "apiKeyEnv")
        var categories = textValue(config, "categories")
        categoriesMask.bits = /^[01]{3}$/.test(categories)
            ? categories
            : (boolValue(config, "categoryGeneral", true) ? "1" : "0")
                + (boolValue(config, "categoryAnime", true) ? "1" : "0")
                + (boolValue(config, "categoryPeople", true) ? "1" : "0")
        var purity = textValue(config, "purity")
        purityMask.bits = /^[01]{3}$/.test(purity)
            ? purity
            : (boolValue(config, "allowSfw", true) ? "1" : "0")
                + (boolValue(config, "allowSketchy", false) ? "1" : "0")
                + (boolValue(config, "allowNsfw", false) ? "1" : "0")
        ratioResolution.loadValues(
            textValue(config, "ratios"), textValue(config, "atleast"))
        colorPicker.loadValue(textValue(config, "colors"))
        sortingField.text = textValue(config, "sorting") || "random"
        redditSfw.checked = boolValue(config, "allowSfw", true)
        aiArt.checked = boolValue(config, "aiArt", false)
        minWidthField.text = textValue(config, "minWidth")
        minHeightField.text = textValue(config, "minHeight")
        ratioWField.text = textValue(config, "ratioW")
        ratioHField.text = textValue(config, "ratioH")
        redditSortField.text = textValue(config, "sort")
        redditTimeField.text = textValue(config, "time")
        topicsField.text = textValue(config, "topics")
        collectionsField.text = textValue(config, "collections")
        usernameField.text = textValue(config, "username")
        orientationField.text = textValue(config, "orientation")
        contentFilterField.text = textValue(config, "contentFilter")
        imageWidthField.text = textValue(config, "imageWidth")
        imageHeightField.text = textValue(config, "imageHeight")
        imageFitField.text = textValue(config, "imageFit")
        imageQualityField.text = textValue(config, "imageQuality")
        imagePrefixField.text = textValue(config, "imagePrefix")
        candidateLimitField.text = textValue(config, "candidateLimit")
        postPathField.text = textValue(config, "postPath")
        postPrefixField.text = textValue(config, "postPrefix")
        authorNamePathField.text = textValue(config, "authorNamePath")
        authorUrlPathField.text = textValue(config, "authorUrlPath")
        authorUrlPrefixField.text = textValue(config, "authorUrlPrefix")
        authorNameField.text = textValue(config, "authorName")
        authorUrlField.text = textValue(config, "authorUrl")
        domainField.text = textValue(config, "domain")
        postUrlField.text = textValue(config, "postUrl")
        differentImages.checked = boolValue(config, "differentImages", false)
        countField.text = textValue(config, "count")
        ttlField.text = textValue(config, "ttlSec")
    }

    function packPayload() {
        var payload = {"subthemes": subthemesField.text, "ttlSec": ttlField.text}
        if (activeProvider === "local") {
            payload.paths = localPathsField.text
        } else if (activeProvider === "wallhaven") {
            payload.apiKey = apiKeyField.text
            payload.apiKeyEnv = apiKeyEnvField.text
            payload.keyword = keywordField.text
            payload.categories = categoriesMask.bits
            payload.purity = purityMask.bits
            payload.allowSfw = purityMask.bits.charAt(0) === "1"
            payload.allowSketchy = purityMask.bits.charAt(1) === "1"
            payload.allowNsfw = purityMask.bits.charAt(2) === "1"
            payload.categoryGeneral = categoriesMask.bits.charAt(0) === "1"
            payload.categoryAnime = categoriesMask.bits.charAt(1) === "1"
            payload.categoryPeople = categoriesMask.bits.charAt(2) === "1"
            payload.ratios = ratioResolution.ratio
            payload.colors = colorPicker.selectedColor
            payload.atleast = ratioResolution.minimumResolution
            payload.sorting = sortingField.text
            payload.aiArt = aiArt.checked
        } else if (activeProvider === "reddit") {
            payload.subreddits = subredditsField.text
            payload.allowSfw = redditSfw.checked
            payload.minWidth = minWidthField.text
            payload.minHeight = minHeightField.text
            payload.ratioW = ratioWField.text
            payload.ratioH = ratioHField.text
            payload.sort = redditSortField.text
            payload.time = redditTimeField.text
        } else if (activeProvider === "unsplash") {
            payload.apiKey = apiKeyField.text
            payload.apiKeyEnv = apiKeyEnvField.text
            payload.query = queryField.text
            payload.topics = topicsField.text
            payload.collections = collectionsField.text
            payload.username = usernameField.text
            payload.orientation = orientationField.text
            payload.contentFilter = contentFilterField.text
            payload.imageWidth = imageWidthField.text
            payload.imageHeight = imageHeightField.text
            payload.imageFit = imageFitField.text
            payload.imageQuality = imageQualityField.text
        } else if (activeProvider === "generic_json") {
            payload.endpoint = endpointField.text
            payload.imagePath = imagePathField.text
            payload.imagePrefix = imagePrefixField.text
            payload.candidateLimit = candidateLimitField.text
            payload.postPath = postPathField.text
            payload.postPrefix = postPrefixField.text
            payload.authorNamePath = authorNamePathField.text
            payload.authorUrlPath = authorUrlPathField.text
            payload.authorUrlPrefix = authorUrlPrefixField.text
            payload.domain = domainField.text
        } else if (activeProvider === "static_url") {
            payload.url = urlField.text
            payload.urls = urlsField.text
            payload.authorName = authorNameField.text
            payload.authorUrl = authorUrlField.text
            payload.domain = domainField.text
            payload.postUrl = postUrlField.text
            payload.differentImages = differentImages.checked
            payload.count = countField.text
        }
        return payload
    }

    Connections {
        target: kitowall
        onSettingsJsonChanged: page.loadSettings()
        onPacksJsonChanged: page.loadPacks()
        onJobsJsonChanged: page.loadJobs()
        onServicesJsonChanged: page.loadServices()
    }

    ListModel { id: packsModel }
    ListModel { id: jobsModel }
    ListModel { id: servicesModel }
    ListModel {
        id: providerModel
        ListElement { label: "Wallhaven"; value: "wallhaven" }
        ListElement { label: "Unsplash"; value: "unsplash" }
        ListElement { label: "Reddit"; value: "reddit" }
        ListElement { label: "Generic JSON"; value: "generic_json" }
        ListElement { label: "Static URL"; value: "static_url" }
        ListElement { label: "Local"; value: "local" }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 16

        Rectangle {
            Layout.preferredWidth: 224
            Layout.fillHeight: true
            radius: 18
            color: page.panel
            border.color: page.border

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                anchors.bottomMargin: 16
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 10

                    Button {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        onClicked: page.closeRequested()
                        background: Rectangle {
                            radius: 11
                            color: parent.hovered ? "#202333" : "#121520"
                            border.color: "#303445"
                        }
                        contentItem: KiIcon { name: "arrow_back"; color: "#c7cad6"; iconSize: 19 }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: "Configuracion"
                        color: page.textPrimary
                        font.family: page.uiFont
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.topMargin: 3
                    Layout.bottomMargin: 10
                    color: "#222635"
                }

                Text {
                    text: "KITOWALL"
                    color: "#646a7f"
                    font.family: page.uiFont
                    font.pixelSize: 9
                    font.letterSpacing: 1.2
                    leftPadding: 11
                    bottomPadding: 6
                }

                Repeater {
                    model: [
                        {"label": "General", "icon": "tune"},
                        {"label": "Packs", "icon": "folder"},
                        {"label": "Status", "icon": "monitor_heart"}
                    ]

                    delegate: Button {
                        id: sectionButton

                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        onClicked: page.activeSection = index
                        background: Rectangle {
                            radius: 12
                            color: page.activeSection === index
                                ? "#3a1262"
                                : (sectionButton.hovered ? "#171a27" : "transparent")
                            border.width: 1
                            border.color: page.activeSection === index ? "#8632b9" : "transparent"

                            Rectangle {
                                visible: page.activeSection === index
                                anchors.left: parent.left
                                anchors.leftMargin: 5
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 20
                                radius: 2
                                color: page.accentBright
                            }
                        }

                        contentItem: RowLayout {
                            spacing: 10

                            Item {
                                Layout.preferredWidth: 24
                                Layout.preferredHeight: 24
                                Layout.leftMargin: 11

                                KiIcon {
                                    anchors.centerIn: parent
                                    name: modelData.icon
                                    color: page.activeSection === index
                                        ? page.accentBright : "#8990a5"
                                    iconSize: 18
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                Layout.rightMargin: 12
                                text: modelData.label
                                color: page.activeSection === index
                                    ? "#f1e8f7" : "#adb2c3"
                                font.family: page.uiFont
                                font.pixelSize: 11
                                font.weight: page.activeSection === index
                                    ? Font.DemiBold : Font.Normal
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
                Item { Layout.fillHeight: true }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 62
                    radius: 12
                    color: "#0d1019"
                    border.color: "#25293a"
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        KiIcon {
                            name: kitowall.lastError.length > 0 ? "error" : (kitowall.busy ? "sync" : "check_circle")
                            color: kitowall.lastError.length > 0 ? "#f07983" : (kitowall.busy ? "#d6a3f5" : "#64d686")
                            iconSize: 19
                        }
                        Text {
                            Layout.fillWidth: true
                            text: kitowall.lastError.length > 0 ? kitowall.lastError : (kitowall.busy ? "Procesando..." : (kitowall.lastMessage || "CLI conectado"))
                            color: "#9197aa"
                            wrapMode: Text.WordWrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: page.uiFont
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        text: page.activeSection === 0
                            ? "Comportamiento general"
                            : (page.activeSection === 1
                                ? "Bibliotecas y fuentes"
                                : "Estado de servicios")
                        color: page.textPrimary
                        font.family: page.uiFont
                        font.pixelSize: 24
                        font.weight: Font.DemiBold
                    }
                    Text {
                        text: page.activeSection === 0
                            ? "Rotacion y transiciones del modulo estatico"
                            : (page.activeSection === 1
                                ? "Providers, indices e hidratacion"
                                : "Automatizaciones de wallpapers estaticos")
                        color: page.textSecondary
                        font.family: page.uiFont
                        font.pixelSize: 10
                    }
                }
                Button {
                    visible: page.activeSection === 2 && !page.servicesHealthy
                    Layout.preferredWidth: page.serviceInstalled < page.serviceTotal ? 156 : 174
                    Layout.preferredHeight: 40
                    text: page.serviceInstalled < page.serviceTotal
                        ? "Instalar servicios"
                        : "Reparar y activar"
                    enabled: !kitowall.busy
                    onClicked: installServicesDialog.open()
                    background: Rectangle {
                        radius: 10
                        opacity: parent.enabled ? 1 : 0.5
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#bd37f5" }
                            GradientStop { position: 1; color: "#7113b9" }
                        }
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.family: page.uiFont
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                    }
                }
                Button {
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 40
                    text: "Recargar"
                    enabled: !kitowall.busy
                    onClicked: page.refreshAll()
                    background: Rectangle { radius: 10; color: parent.hovered ? "#1c1f2d" : "#121520"; border.color: "#303445" }
                    contentItem: Text { text: parent.text; color: "#c9ccd8"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: page.uiFont; font.pixelSize: 10 }
                }
            }
            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: page.activeSection

                ScrollView {
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: parent.width
                spacing: 14
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: generalGrid.implicitHeight + 40
                    radius: 17
                    color: page.panel
                    border.color: page.border
                    GridLayout {
                        id: generalGrid
                        anchors.fill: parent
                        anchors.margins: 20
                        columns: width > 760 ? 3 : 2
                        columnSpacing: 15
                        rowSpacing: 14
                        Text { Layout.columnSpan: generalGrid.columns; text: "Rotacion y transicion"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            Text { text: "Modo"; color: "#aeb3c3"; font.family: page.uiFont; font.pixelSize: 11 }
                            ComboBox { id: modeSelect; Layout.fillWidth: true; Layout.preferredHeight: 42; model: ["manual", "rotate"] }
                        }
                        ConfigField { id: intervalField; label: "Intervalo (seg)"; placeholderText: "1800"; inputMethodHints: Qt.ImhDigitsOnly }
                        ConfigField { id: backendField; label: "Backend efectivo"; readOnly: true; helperText: "Solo lectura por ahora" }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 7
                            Text { text: "Tipo de transicion"; color: "#aeb3c3"; font.family: page.uiFont; font.pixelSize: 11 }
                            ComboBox { id: transitionSelect; Layout.fillWidth: true; Layout.preferredHeight: 42; model: page.transitionTypes }
                        }
                        ConfigField { id: fpsField; label: "FPS"; placeholderText: "60"; inputMethodHints: Qt.ImhDigitsOnly }
                        ConfigField { id: durationField; label: "Duracion (seg)"; placeholderText: "0.7" }
                        ConfigField { id: angleField; label: "Angulo opcional"; placeholderText: "45" }
                        ConfigField { id: positionField; label: "Posicion opcional"; placeholderText: "0.5,0.5" }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: policyGrid.implicitHeight + 40
                    radius: 17
                    color: page.panel
                    border.color: page.border
                    GridLayout {
                        id: policyGrid
                        anchors.fill: parent
                        anchors.margins: 20
                        columns: width > 760 ? 3 : 2
                        columnSpacing: 15
                        rowSpacing: 14
                        Text { Layout.columnSpan: policyGrid.columns; text: "Seleccion y almacenamiento"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 14; font.weight: Font.DemiBold }
                        ConfigField { id: perOutputField; label: "Cooldown por monitor"; readOnly: true }
                        ConfigField { id: globalCooldownField; label: "Cooldown global"; readOnly: true }
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Evitar duplicados"; color: "#aeb3c3"; font.family: page.uiFont; font.pixelSize: 11 }
                            Switch { id: duplicateSwitch; enabled: false }
                        }
                        ConfigField { id: cacheDirField; label: "Directorio de cache"; readOnly: true }
                        ConfigField { id: downloadDirField; label: "Directorio de descargas"; readOnly: true }
                        ConfigField { id: cacheLimitField; label: "Limite de cache (MB)"; readOnly: true }
                        ConfigField { id: cacheTtlField; label: "TTL predeterminado"; readOnly: true }
                    }
                }
                Button {
                    Layout.alignment: Qt.AlignRight
                    Layout.preferredWidth: 190
                    Layout.preferredHeight: 44
                    text: "Guardar configuracion"
                    enabled: !kitowall.busy
                    onClicked: kitowall.saveGeneral(JSON.stringify({
                        "mode": modeSelect.currentText,
                        "interval": Number(intervalField.text),
                        "transitionType": transitionSelect.currentText,
                        "fps": Number(fpsField.text),
                        "duration": Number(durationField.text),
                        "angle": angleField.text,
                        "position": positionField.text
                    }))
                    background: Rectangle {
                        radius: 11
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#bd37f5" }
                            GradientStop { position: 1; color: "#7113b9" }
                        }
                    }
                    contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: page.uiFont; font.pixelSize: 11; font.weight: Font.DemiBold }
                }
            }
                }

                RowLayout {
            spacing: 14
            Rectangle {
                Layout.preferredWidth: 270
                Layout.fillHeight: true
                radius: 17
                color: page.panel
                border.color: page.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 10
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Packs configurados"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                        Text { text: String(packsModel.count); color: "#d89cff"; font.family: page.uiFont; font.pixelSize: 10 }
                    }
                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        text: "Nuevo pack"
                        onClicked: page.clearEditor("wallhaven")
                        background: Rectangle { radius: 10; color: parent.hovered ? "#351452" : "#28103f"; border.color: "#6c288f" }
                        contentItem: Text { text: parent.text; color: "#e1b9f7"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: page.uiFont; font.pixelSize: 10 }
                    }
                    ListView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        spacing: 7
                        model: packsModel
                        delegate: Button {
                            required property string name
                            required property string provider
                            required property string configJson
                            width: ListView.view.width
                            height: 58
                            onClicked: page.editPack(name, configJson)
                            background: Rectangle { radius: 11; color: page.selectedPackName === name ? "#32134f" : (parent.hovered ? "#171a27" : "#0e111b"); border.color: page.selectedPackName === name ? "#74309c" : "#252938" }
                            contentItem: RowLayout {
                                Rectangle {
                                    width: 34; height: 34; radius: 10; color: "#251337"
                                    KiIcon { anchors.centerIn: parent; name: provider === "local" ? "folder" : "cloud"; color: "#bf6bf1"; iconSize: 18 }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { Layout.fillWidth: true; text: name; elide: Text.ElideRight; color: "#e2dfe8"; font.family: page.uiFont; font.pixelSize: 10; font.weight: Font.Medium }
                                    Text { text: provider; color: "#777e92"; font.family: page.uiFont; font.pixelSize: 8 }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 17
                color: page.panel
                border.color: page.border
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 12
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: page.selectedPackName.length > 0 ? "Editar " + page.selectedPackName : "Crear pack"; color: page.textPrimary; font.family: page.uiFont; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text { text: "Cada cambio se ejecuta mediante el CLI"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 9 }
                        }
                        KiActionButton {
                            visible: page.selectedPackName.length > 0
                            text: "Eliminar"
                            tone: "danger"
                            iconName: "delete"
                            Layout.preferredWidth: 96
                            Layout.preferredHeight: 34
                            onClicked: deleteDialog.open()
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        ColumnLayout {
                            Layout.fillWidth: true
                            Text { text: "Provider"; color: "#aeb3c3"; font.family: page.uiFont; font.pixelSize: 10 }
                            ComboBox {
                                id: providerSelect
                                Layout.fillWidth: true
                                Layout.preferredHeight: 42
                                model: providerModel
                                textRole: "label"
                                onActivated: page.clearEditor(providerModel.get(currentIndex).value)
                            }
                        }
                        ConfigField { id: packNameField; Layout.fillWidth: true; label: "Nombre del pack"; placeholderText: "sakura-night"; readOnly: page.selectedPackName.length > 0 }
                    }
                    ScrollView {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentWidth: availableWidth
                        GridLayout {
                            width: parent.width
                            columns: width > 650 ? 2 : 1
                            columnSpacing: 14
                            rowSpacing: 12
                            ConfigField { id: localPathsField; visible: page.activeProvider === "local"; label: "Carpetas"; placeholderText: "/home/user/Pictures, /mnt/wallpapers"; helperText: "Separadas por comas" }
                            ConfigField { id: keywordField; visible: page.activeProvider === "wallhaven"; label: "Keyword"; placeholderText: "sakura night" }
                            ConfigField { id: queryField; visible: page.activeProvider === "unsplash"; label: "Query"; placeholderText: "mountains night" }
                            ConfigField { id: subredditsField; visible: page.activeProvider === "reddit"; label: "Subreddits"; placeholderText: "wallpapers, animewallpaper" }
                            ConfigField { id: endpointField; visible: page.activeProvider === "generic_json"; label: "Endpoint"; placeholderText: "https://api.example.com/feed" }
                            ConfigField { id: imagePathField; visible: page.activeProvider === "generic_json"; label: "Ruta JSON de imagen"; placeholderText: "$.items[0].image" }
                            ConfigField { id: urlField; visible: page.activeProvider === "static_url"; label: "URL individual"; placeholderText: "https://example.com/image.jpg" }
                            ConfigField { id: urlsField; visible: page.activeProvider === "static_url"; label: "Lista de URLs"; placeholderText: "https://a.jpg, https://b.jpg" }
                            ConfigField { id: subthemesField; visible: ["wallhaven", "reddit", "unsplash"].indexOf(page.activeProvider) >= 0; label: "Subtemas"; placeholderText: "night, minimal, neon" }
                            ConfigField {
                                id: apiKeyField
                                visible: ["wallhaven", "unsplash"].indexOf(page.activeProvider) >= 0
                                label: page.providerCredentialConfigured(page.activeProvider)
                                    ? "Reemplazar API key (opcional)"
                                    : "API key"
                                placeholderText: page.providerCredentialConfigured(page.activeProvider)
                                    ? "Credencial compartida configurada"
                                    : "Se reutilizara en futuros packs"
                                helperText: page.providerCredentialConfigured(page.activeProvider)
                                    ? "Este pack usara la credencial compartida del provider."
                                    : "Se guardara una sola vez para todos los packs de este provider."
                                echoMode: TextInput.Password
                            }
                            ConfigField {
                                id: apiKeyEnvField
                                visible: ["wallhaven", "unsplash"].indexOf(page.activeProvider) >= 0
                                label: "Variable de entorno compartida"
                                placeholderText: page.activeProvider === "wallhaven"
                                    ? "WALLHAVEN_KEY" : "UNSPLASH_KEY"
                                helperText: "Dejar vacio conserva la configuracion existente."
                            }
                            MaskMultiSelect {
                                id: categoriesMask
                                visible: page.activeProvider === "wallhaven"
                                label: "Categorias"
                                options: ["General", "Anime", "People"]
                                placeholderText: "Selecciona categorias"
                            }
                            MaskMultiSelect {
                                id: purityMask
                                visible: page.activeProvider === "wallhaven"
                                label: "Pureza"
                                options: ["SFW", "Sketchy", "NSFW"]
                                placeholderText: "Selecciona niveles"
                            }
                            RatioResolutionSelector {
                                id: ratioResolution
                                visible: page.activeProvider === "wallhaven"
                                Layout.columnSpan: parent.columns
                            }
                            WallhavenColorPicker {
                                id: colorPicker
                                visible: page.activeProvider === "wallhaven"
                            }
                            ConfigField { id: sortingField; visible: page.activeProvider === "wallhaven"; label: "Orden"; placeholderText: "random" }
                            ConfigField { id: minWidthField; visible: page.activeProvider === "reddit"; label: "Ancho minimo"; placeholderText: "1920" }
                            ConfigField { id: minHeightField; visible: page.activeProvider === "reddit"; label: "Alto minimo"; placeholderText: "1080" }
                            ConfigField { id: ratioWField; visible: page.activeProvider === "reddit"; label: "Relacion, ancho"; placeholderText: "16" }
                            ConfigField { id: ratioHField; visible: page.activeProvider === "reddit"; label: "Relacion, alto"; placeholderText: "9" }
                            ConfigField { id: redditSortField; visible: page.activeProvider === "reddit"; label: "Orden"; placeholderText: "hot" }
                            ConfigField { id: redditTimeField; visible: page.activeProvider === "reddit"; label: "Ventana temporal"; placeholderText: "week" }
                            ConfigField { id: topicsField; visible: page.activeProvider === "unsplash"; label: "Topics"; placeholderText: "nature, architecture" }
                            ConfigField { id: collectionsField; visible: page.activeProvider === "unsplash"; label: "Collections"; placeholderText: "123, 456" }
                            ConfigField { id: usernameField; visible: page.activeProvider === "unsplash"; label: "Usuario"; placeholderText: "photographer" }
                            ConfigField { id: orientationField; visible: page.activeProvider === "unsplash"; label: "Orientacion"; placeholderText: "landscape" }
                            ConfigField { id: contentFilterField; visible: page.activeProvider === "unsplash"; label: "Filtro de contenido"; placeholderText: "high" }
                            ConfigField { id: imageWidthField; visible: page.activeProvider === "unsplash"; label: "Ancho de descarga"; placeholderText: "1920" }
                            ConfigField { id: imageHeightField; visible: page.activeProvider === "unsplash"; label: "Alto de descarga"; placeholderText: "1080" }
                            ConfigField { id: imageFitField; visible: page.activeProvider === "unsplash"; label: "Ajuste"; placeholderText: "crop" }
                            ConfigField { id: imageQualityField; visible: page.activeProvider === "unsplash"; label: "Calidad"; placeholderText: "80" }
                            ConfigField { id: imagePrefixField; visible: page.activeProvider === "generic_json"; label: "Prefijo de imagen"; placeholderText: "https://cdn.example.com" }
                            ConfigField { id: candidateLimitField; visible: page.activeProvider === "generic_json"; label: "Limite de candidatos"; placeholderText: "40" }
                            ConfigField { id: postPathField; visible: page.activeProvider === "generic_json"; label: "Ruta JSON del post"; placeholderText: "$.items[0].url" }
                            ConfigField { id: postPrefixField; visible: page.activeProvider === "generic_json"; label: "Prefijo del post"; placeholderText: "https://example.com" }
                            ConfigField { id: authorNamePathField; visible: page.activeProvider === "generic_json"; label: "Ruta JSON del autor"; placeholderText: "$.author.name" }
                            ConfigField { id: authorUrlPathField; visible: page.activeProvider === "generic_json"; label: "Ruta JSON URL del autor"; placeholderText: "$.author.url" }
                            ConfigField { id: authorUrlPrefixField; visible: page.activeProvider === "generic_json"; label: "Prefijo URL del autor"; placeholderText: "https://example.com/users/" }
                            ConfigField { id: authorNameField; visible: page.activeProvider === "static_url"; label: "Autor"; placeholderText: "Nombre" }
                            ConfigField { id: authorUrlField; visible: page.activeProvider === "static_url"; label: "URL del autor"; placeholderText: "https://author.site" }
                            ConfigField { id: postUrlField; visible: page.activeProvider === "static_url"; label: "URL del post"; placeholderText: "https://source-post" }
                            ConfigField { id: countField; visible: page.activeProvider === "static_url"; label: "Cantidad"; placeholderText: "1" }
                            ConfigField { id: domainField; visible: ["generic_json", "static_url"].indexOf(page.activeProvider) >= 0; label: "Dominio"; placeholderText: "example.com" }
                            ConfigField { id: ttlField; visible: page.activeProvider !== "local"; label: "TTL en segundos"; placeholderText: "Vacio usa el TTL global" }
                            Flow {
                                Layout.columnSpan: parent.columns
                                Layout.fillWidth: true
                                visible: page.activeProvider === "wallhaven"
                                spacing: 12
                                CheckBox { id: aiArt; text: "AI art" }
                            }
                            Flow {
                                Layout.columnSpan: parent.columns
                                Layout.fillWidth: true
                                visible: page.activeProvider === "reddit"
                                spacing: 12
                                CheckBox { id: redditSfw; text: "Solo SFW" }
                            }
                            Flow {
                                Layout.columnSpan: parent.columns
                                Layout.fillWidth: true
                                visible: page.activeProvider === "static_url"
                                CheckBox { id: differentImages; text: "El endpoint entrega imagenes diferentes" }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        visible: page.selectedPackName.length > 0 && page.activeProvider !== "local"
                        Text { Layout.fillWidth: true; text: "Operaciones remotas"; color: page.textSecondary; font.family: page.uiFont; font.pixelSize: 9 }
                        SpinBox { id: hydrateCount; from: 1; to: 100; value: 10 }
                        KiActionButton {
                            text: "Refrescar indice"
                            iconName: "refresh"
                            Layout.preferredWidth: 138
                            Layout.preferredHeight: 36
                            enabled: !kitowall.busy && !page.hasActiveJobs()
                            onClicked: kitowall.startPackJob("refresh", page.selectedPackName, 1)
                        }
                        KiActionButton {
                            text: "Hidratar"
                            tone: "primary"
                            iconName: "download"
                            Layout.preferredWidth: 104
                            Layout.preferredHeight: 36
                            enabled: !kitowall.busy && !page.hasActiveJobs()
                            onClicked: kitowall.startPackJob(
                                "hydrate", page.selectedPackName, hydrateCount.value)
                        }
                    }
                    Rectangle {
                        visible: jobsModel.count > 0
                        Layout.fillWidth: true
                        Layout.preferredHeight: jobsColumn.implicitHeight + 24
                        radius: 13
                        color: "#0d1019"
                        border.color: "#25293a"

                        ColumnLayout {
                            id: jobsColumn

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            spacing: 8

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    Layout.fillWidth: true
                                    text: "Trabajos recientes"
                                    color: page.textPrimary
                                    font.family: page.uiFont
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                }
                                KiActionButton {
                                    text: "Actualizar"
                                    iconName: "refresh"
                                    Layout.preferredWidth: 108
                                    Layout.preferredHeight: 34
                                    onClicked: kitowall.refreshJobs()
                                }
                            }

                            Repeater {
                                model: Math.min(jobsModel.count, 3)

                                delegate: Rectangle {
                                    required property int index
                                    readonly property var jobRecord: jobsModel.get(index)

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: jobContent.implicitHeight + 18
                                    radius: 10
                                    color: "#121520"
                                    border.color: "#292d3d"

                                    ColumnLayout {
                                        id: jobContent

                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 5

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: (jobRecord.kind === "hydrate"
                                                    ? "Hidratacion" : "Refresh")
                                                    + " · " + jobRecord.pack
                                                color: "#d5d7e1"
                                                font.family: page.uiFont
                                                font.pixelSize: 10
                                            }
                                            Text {
                                                text: page.jobStatusLabel(jobRecord.status)
                                                color: page.jobStatusColor(jobRecord.status)
                                                font.family: page.uiFont
                                                font.pixelSize: 9
                                                font.weight: Font.DemiBold
                                            }
                                            Button {
                                                visible: ["queued", "running", "cancel_requested"]
                                                    .indexOf(jobRecord.status) >= 0
                                                Layout.preferredWidth: 76
                                                Layout.preferredHeight: 28
                                                text: "Cancelar"
                                                enabled: jobRecord.status !== "cancel_requested"
                                                onClicked: kitowall.cancelJob(jobRecord.jobId)
                                                background: Rectangle {
                                                    radius: 8
                                                    color: parent.hovered ? "#2b1b27" : "#191b28"
                                                    border.color: "#3a3040"
                                                }
                                                contentItem: Text {
                                                    text: parent.text
                                                    color: "#c9b8c2"
                                                    horizontalAlignment: Text.AlignHCenter
                                                    verticalAlignment: Text.AlignVCenter
                                                    font.family: page.uiFont
                                                    font.pixelSize: 9
                                                }
                                            }
                                        }

                                        ProgressBar {
                                            id: jobProgress

                                            visible: jobRecord.status !== "failed"
                                                && jobRecord.status !== "canceled"
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 8
                                            from: 0
                                            to: Math.max(1, jobRecord.total)
                                            value: jobRecord.completed
                                            background: Rectangle {
                                                implicitHeight: 8
                                                radius: 4
                                                color: "#202331"
                                            }
                                            contentItem: Item {
                                                implicitHeight: 8

                                                Rectangle {
                                                    width: parent.width * jobProgress.visualPosition
                                                    height: parent.height
                                                    radius: 4
                                                    gradient: Gradient {
                                                        GradientStop { position: 0; color: "#7d2bc2" }
                                                        GradientStop { position: 1; color: "#d16cff" }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            visible: jobRecord.errorText.length > 0
                                            Layout.fillWidth: true
                                            text: jobRecord.errorText
                                            color: "#d88992"
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            font.family: page.uiFont
                                            font.pixelSize: 9
                                        }
                                    }
                                }
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Item { Layout.fillWidth: true }
                        Button {
                            text: page.selectedPackName.length > 0 ? "Guardar cambios" : "Crear pack"
                            enabled: !kitowall.busy
                            onClicked: kitowall.savePack(page.activeProvider, packNameField.text, JSON.stringify(page.packPayload()))
                            Layout.preferredWidth: 160
                            Layout.preferredHeight: 42
                            background: Rectangle {
                                radius: 10
                                gradient: Gradient {
                                    GradientStop { position: 0; color: "#bd37f5" }
                                    GradientStop { position: 1; color: "#7113b9" }
                                }
                            }
                            contentItem: Text { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: page.uiFont; font.pixelSize: 10; font.weight: Font.DemiBold }
                        }
                    }
                }
            }
                }

                ScrollView {
                    clip: true
                    contentWidth: availableWidth

                    ColumnLayout {
                        width: parent.width
                        spacing: 14

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 150
                            radius: 17
                            color: page.panel
                            border.color: page.servicesHealthy ? "#28553c" : page.border

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 18
                                spacing: 12

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Rectangle {
                                        Layout.preferredWidth: 42
                                        Layout.preferredHeight: 42
                                        radius: 12
                                        color: page.servicesHealthy ? "#123323" : "#25182d"

                                        KiIcon {
                                            anchors.centerIn: parent
                                            name: page.servicesHealthy ? "verified" : "monitor_heart"
                                            color: page.servicesHealthy ? "#69da8c" : "#d6a3f5"
                                            iconSize: 23
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 3

                                        Text {
                                            text: page.servicesHealthy
                                                ? "Servicios estaticos configurados"
                                                : "Estado parcial de servicios"
                                            color: page.textPrimary
                                            font.family: page.uiFont
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                        }
                                        Text {
                                            text: "Kitowall declara las tareas; Kitsune Compositor materializa y controla sus artefactos."
                                            color: page.textSecondary
                                            font.family: page.uiFont
                                            font.pixelSize: 9
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Repeater {
                                        model: [
                                            {"label": "Instalados", "value": page.serviceInstalled + "/" + page.serviceTotal, "color": "#d6a3f5"},
                                            {"label": "Habilitados", "value": String(page.serviceEnabled), "color": "#65c6dc"},
                                            {"label": "Activos", "value": String(page.serviceActive), "color": "#69da8c"},
                                            {"label": "Errores", "value": String(page.serviceErrors), "color": page.serviceErrors > 0 ? "#f07983" : "#8f95a8"}
                                        ]

                                        delegate: Rectangle {
                                            required property var modelData
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 48
                                            radius: 10
                                            color: "#0f121c"
                                            border.color: "#25293a"

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.margins: 10

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: modelData.label
                                                    color: "#8f95a8"
                                                    font.family: page.uiFont
                                                    font.pixelSize: 9
                                                }
                                                Text {
                                                    text: modelData.value
                                                    color: modelData.color
                                                    font.family: page.uiFont
                                                    font.pixelSize: 12
                                                    font.weight: Font.DemiBold
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Repeater {
                            model: servicesModel

                            delegate: Rectangle {
                                required property string serviceId
                                required property string label
                                required property string description
                                required property string state
                                required property string stateLabel
                                required property color stateColor
                                required property string stateIcon
                                required property string artifactSummary
                                required property string errorText

                                Layout.fillWidth: true
                                Layout.preferredHeight: serviceContent.implicitHeight + 30
                                radius: 15
                                color: page.panel
                                border.color: state === "error" ? "#60313a" : page.border

                                RowLayout {
                                    id: serviceContent
                                    anchors.fill: parent
                                    anchors.margins: 15
                                    spacing: 14

                                    Rectangle {
                                        Layout.preferredWidth: 44
                                        Layout.preferredHeight: 44
                                        Layout.alignment: Qt.AlignTop
                                        radius: 12
                                        color: "#151824"

                                        KiIcon {
                                            anchors.centerIn: parent
                                            name: stateIcon
                                            color: stateColor
                                            iconSize: 23
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 5

                                        RowLayout {
                                            Layout.fillWidth: true

                                            Text {
                                                Layout.fillWidth: true
                                                text: label
                                                color: page.textPrimary
                                                font.family: page.uiFont
                                                font.pixelSize: 12
                                                font.weight: Font.DemiBold
                                            }
                                            Rectangle {
                                                Layout.preferredWidth: statusText.implicitWidth + 18
                                                Layout.preferredHeight: 26
                                                radius: 8
                                                color: Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.12)
                                                border.color: Qt.rgba(stateColor.r, stateColor.g, stateColor.b, 0.45)

                                                Text {
                                                    id: statusText
                                                    anchors.centerIn: parent
                                                    text: stateLabel
                                                    color: stateColor
                                                    font.family: page.uiFont
                                                    font.pixelSize: 9
                                                    font.weight: Font.DemiBold
                                                }
                                            }
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: description
                                            color: page.textSecondary
                                            wrapMode: Text.WordWrap
                                            font.family: page.uiFont
                                            font.pixelSize: 9
                                        }

                                        Text {
                                            Layout.fillWidth: true
                                            text: artifactSummary
                                            color: state === "not_installed" ? "#73798d" : "#aeb3c3"
                                            wrapMode: Text.WordWrap
                                            font.family: page.uiFont
                                            font.pixelSize: 9
                                        }

                                        Text {
                                            visible: state === "error" && errorText.length > 0
                                            Layout.fillWidth: true
                                            text: errorText
                                            color: "#d88992"
                                            wrapMode: Text.WordWrap
                                            font.family: page.uiFont
                                            font.pixelSize: 9
                                        }
                                    }

                                    Text {
                                        Layout.preferredWidth: 180
                                        Layout.alignment: Qt.AlignTop
                                        text: serviceId
                                        color: "#666d81"
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideMiddle
                                        font.family: page.uiFont
                                        font.pixelSize: 9
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: servicesModel.count === 0
                            Layout.fillWidth: true
                            Layout.preferredHeight: 92
                            radius: 15
                            color: page.panel
                            border.color: page.border

                            Text {
                                anchors.centerIn: parent
                                text: kitowall.busy
                                    ? "Consultando servicios..."
                                    : "No se recibio informacion de servicios."
                                color: page.textSecondary
                                font.family: page.uiFont
                                font.pixelSize: 10
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            text: "La hidratacion de packs y la poda de cache son operaciones puntuales; no se muestran como servicios."
                            color: "#686f82"
                            wrapMode: Text.WordWrap
                            font.family: page.uiFont
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: installServicesDialog
        anchors.centerIn: parent
        width: Math.min(520, page.width - 80)
        title: page.serviceInstalled > 0
            ? "Reparar servicios de Kitowall"
            : "Instalar servicios de Kitowall"
        modal: true
        onAccepted: kitowall.installServices()

        contentItem: ColumnLayout {
            width: 450
            spacing: 12

            Text {
                Layout.fillWidth: true
                text: "Se materializaran y habilitaran las automatizaciones de runtime, rotacion, monitores y restauracion de sesion."
                color: "#d2d4de"
                wrapMode: Text.WordWrap
                font.family: page.uiFont
                font.pixelSize: 11
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: warningText.implicitHeight + 20
                radius: 10
                color: "#211823"
                border.color: "#563244"

                Text {
                    id: warningText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: "Esta accion modifica los servicios reales del usuario en ~/.config/systemd/user. La flag --lc no aisla esta ruta."
                    color: "#d8a5b5"
                    wrapMode: Text.WordWrap
                    font.family: page.uiFont
                    font.pixelSize: 9
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 10

                Item { Layout.fillWidth: true }

                KiActionButton {
                    text: "Cancelar"
                    Layout.preferredWidth: 96
                    onClicked: installServicesDialog.reject()
                }

                KiActionButton {
                    text: page.serviceInstalled > 0 ? "Reparar y activar" : "Instalar y activar"
                    tone: "primary"
                    Layout.preferredWidth: 150
                    onClicked: installServicesDialog.accept()
                }
            }
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: parent
        width: Math.min(420, page.width - 80)
        title: "Eliminar pack"
        modal: true
        onAccepted: kitowall.removePack(page.selectedPackName)

        contentItem: ColumnLayout {
            width: 360
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: "Se eliminara " + page.selectedPackName + " y se retirara del pool si estaba referenciado."
                color: "#d2d4de"
                wrapMode: Text.WordWrap
                font.family: page.uiFont
                font.pixelSize: 11
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Item { Layout.fillWidth: true }

                KiActionButton {
                    text: "Cancelar"
                    Layout.preferredWidth: 96
                    onClicked: deleteDialog.reject()
                }

                KiActionButton {
                    text: "Eliminar"
                    tone: "danger"
                    iconName: "delete"
                    Layout.preferredWidth: 106
                    onClicked: deleteDialog.accept()
                }
            }
        }
    }

    Component.onCompleted: {
        clearEditor("wallhaven")
    }

}
