import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import dev.kitotsu.kiui 1.0
import "components"

ApplicationWindow {
    id: root

    width: 1380
    height: 860
    minimumWidth: 880
    minimumHeight: 640
    visible: true
    title: "KiUI"
    color: "#070812"

    property int selectedIndex: 0
    property int activeSource: 0
    property int activeFilter: 0
    property string activeView: "library"
    property string favoriteCount: "N/D"
    property string selectedOutput: ""
    property string applyMessage: ""
    property string selectedPack: ""
    property string selectedColor: ""
    property bool dashboardHasActiveJobs: false
    property bool rotationEnabled: false
    property int rotationIntervalSeconds: 1800
    property string transitionType: "center"
    property real transitionDuration: 2
    property bool dynamicColorsEnabled: false
    property string dynamicColorsOutput: ""
    readonly property var transitionTypes: [
        "simple", "fade", "left", "right", "top", "bottom", "wipe",
        "wave", "grow", "center", "outer", "any", "random"
    ]
    property int minimumFilterWidth: 0
    property int minimumFilterHeight: 0
    property bool colorFiltersExpanded: false
    property bool resolutionFiltersExpanded: false
    property var catalogItems: []
    property var kitowallCatalogItems: []
    property var liveLibraryItems: []
    property var kitowallCatalogSummary: ({})
    property var historyEntries: []
    property bool compactSidebar: width < 1040
    property bool showDetails: width >= 1180
    readonly property var appearanceState: parseJson(
        kitowallBridge.appearanceJson, {})
    readonly property var appearancePalette: appearanceState.palette || ({})
    readonly property bool dynamicThemeAvailable: dynamicColorsEnabled
        && Boolean(appearanceState.active)
        && String(appearancePalette.accent_mid || "").length > 0
    property color accent: dynamicThemeAvailable
        ? String(appearancePalette.accent_mid) : "#ad3cf3"
    property color accentBright: dynamicThemeAvailable
        ? String(appearancePalette.accent_light) : "#d16cff"
    property color accentDark: dynamicThemeAvailable
        ? String(appearancePalette.accent_dark) : "#7113b9"
    property color accentForeground: dynamicThemeAvailable
        ? String(appearancePalette.foreground) : "#ffffff"
    readonly property color accentSurface: Qt.rgba(
        accent.r, accent.g, accent.b, 0.22)
    readonly property color panel: "#d90b0d18"
    readonly property color panelSolid: "#10121d"
    readonly property color border: "#2a2d3d"
    readonly property color textPrimary: "#f3f1f8"
    readonly property color textSecondary: "#9196aa"
    readonly property string uiFont: "CaskaydiaCove Nerd Font Propo"

    Behavior on accent { ColorAnimation { duration: 260 } }
    Behavior on accentBright { ColorAnimation { duration: 260 } }
    Behavior on accentDark { ColorAnimation { duration: 260 } }

    onActiveViewChanged: {
        if (activeView === "library" && !kilivepaperBridge.busy)
            kilivepaperBridge.refreshLibrary()
    }

    function selected(role) {
        if (selectedIndex < 0 || selectedIndex >= wallpapers.count)
            return ""
        var item = wallpapers.get(selectedIndex)
        return item && item[role] !== undefined ? item[role] : ""
    }

    function parseJson(input, fallback) {
        try {
            return JSON.parse(input)
        } catch (error) {
            return fallback
        }
    }

    function mediaSource(item) {
        var preview = item.preview || {}
        var thumbnail = preview.thumbnail || {}
        var path = thumbnail.local_path || preview.local_path || item.local_path || ""
        if (path.length > 0)
            return path.indexOf("file:") === 0 ? path : "file://" + path
        return thumbnail.remote_url || preview.remote_url || item.remote_url || ""
    }

    function wallpaperTitle(item) {
        if (String(item.title || "").length > 0)
            return String(item.title)
        var candidate = item.local_path || item.remote_url || item.id || "Wallpaper"
        var clean = String(candidate).split("?")[0]
        var parts = clean.split("/")
        var name = parts[parts.length - 1] || String(item.id).slice(0, 12)
        try {
            name = decodeURIComponent(name)
        } catch (error) {
        }
        return name.replace(/\.[^.]+$/, "").replace(/[-_]+/g, " ")
    }

    function providerColors(provider) {
        switch (String(provider).toLowerCase()) {
        case "wallhaven": return ["#7d2bc2", "#132047"]
        case "reddit": return ["#8d174e", "#171126"]
        case "unsplash": return ["#23799a", "#121a38"]
        case "local": return ["#59647d", "#151726"]
        case "static_url": return ["#b36b1f", "#17151b"]
        case "moewalls": return ["#8d275f", "#171126"]
        case "motionbgs": return ["#176b86", "#11182e"]
        default: return ["#663399", "#111342"]
        }
    }

    function formatBytes(value) {
        var bytes = Number(value || 0)
        if (bytes <= 0)
            return ""
        if (bytes >= 1024 * 1024)
            return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return Math.round(bytes / 1024) + " KB"
    }

    function formatDuration(value) {
        var totalSeconds = Math.floor(Number(value || 0) / 1000)
        if (totalSeconds <= 0)
            return ""
        var minutes = Math.floor(totalSeconds / 60)
        var seconds = String(totalSeconds % 60).padStart(2, "0")
        return String(minutes).padStart(2, "0") + ":" + seconds
    }

    function countText(value) {
        var count = Number(value)
        return isNaN(count) ? "N/D" : count.toLocaleString(Qt.locale(), "f", 0)
    }

    function updateCatalogCounts() {
        var catalog = kitowallCatalogSummary || {}
        var facets = catalog.facets || {}
        var providers = facets.by_provider || {}
        var liveProviders = {"moewalls": 0, "motionbgs": 0}
        var liveFavorites = 0
        for (var index = 0; index < liveLibraryItems.length; ++index) {
            var liveItem = liveLibraryItems[index]
            var provider = String(liveItem.provider || "").toLowerCase()
            if (liveProviders[provider] !== undefined)
                liveProviders[provider] += 1
            if (liveItem.favorite === true)
                liveFavorites += 1
        }
        var staticTotal = Number(catalog.total || kitowallCatalogItems.length)
        var total = staticTotal + liveLibraryItems.length
        sourceModel.setProperty(0, "count", countText(total))
        sourceModel.setProperty(1, "count", countText(providers.local || 0))
        sourceModel.setProperty(2, "count", countText(providers.wallhaven || 0))
        sourceModel.setProperty(3, "count", countText(providers.unsplash || 0))
        sourceModel.setProperty(4, "count", countText(providers.reddit || 0))
        sourceModel.setProperty(5, "count", countText(liveProviders.moewalls))
        sourceModel.setProperty(6, "count", countText(liveProviders.motionbgs))
        filterModel.setProperty(0, "modelCount", countText(total))
        filterModel.setProperty(1, "modelCount", countText(facets.images || 0))
        filterModel.setProperty(2, "modelCount",
            countText(Number(facets.videos || 0) + liveLibraryItems.length))
        filterModel.setProperty(3, "modelCount",
            countText(Number(facets.favorites || 0) + liveFavorites))
        filterModel.setProperty(5, "modelCount",
            countText(Number(facets.hydrated || 0) + liveLibraryItems.length))
        favoriteCount = countText(Number(facets.favorites || 0) + liveFavorites)
    }

    function loadPacks() {
        var response = parseJson(kitowallBridge.packsJson, {})
        var packs = response.packs || {}
        var names = Object.keys(packs).sort()
        var previous = selectedPack
        packsFilterModel.clear()
        packsFilterModel.append({
            "packName": "",
            "displayName": "Todos los packs"
        })
        var selected = 0
        for (var index = 0; index < names.length; ++index) {
            packsFilterModel.append({
                "packName": names[index],
                "displayName": names[index]
            })
            if (names[index] === previous)
                selected = packsFilterModel.count - 1
        }
        if (selected === 0 && previous.length > 0)
            selectedPack = ""
        packSelect.currentIndex = selected
    }

    function loadHistoryCount() {
        var history = parseJson(kitowallBridge.historyJson, {})
        historyEntries = history.entries || []
        filterModel.setProperty(4, "modelCount", countText(historyEntries.length))
        rebuildWallpapers()
    }

    function loadDashboardJobs() {
        var response = parseJson(kitowallBridge.jobsJson, {})
        var jobs = response.jobs || []
        dashboardHasActiveJobs = false
        for (var index = 0; index < jobs.length; ++index) {
            var status = String(jobs[index].status || "")
            if (["queued", "running", "cancel_requested"].indexOf(status) >= 0) {
                dashboardHasActiveJobs = true
                break
            }
        }
    }

    function providerForSource(index) {
        switch (index) {
        case 1: return "local"
        case 2: return "wallhaven"
        case 3: return "unsplash"
        case 4: return "reddit"
        case 5: return "moewalls"
        case 6: return "motionbgs"
        default: return ""
        }
    }

    function recentRank(path) {
        for (var index = 0; index < historyEntries.length; ++index) {
            if (String(historyEntries[index].path || "") === path)
                return index
        }
        return -1
    }

    function matchesLibraryFilters(item) {
        var preview = item.preview || {}
        if (selectedPack.length > 0 && String(item.pack || "") !== selectedPack)
            return false
        var provider = providerForSource(activeSource)
        if (provider.length > 0
                && String(item.provider || "").toLowerCase() !== provider)
            return false
        if (activeFilter === 1 && preview.kind === "video")
            return false
        if (activeFilter === 2 && preview.kind !== "video")
            return false
        if (activeFilter === 3 && item.favorite !== true)
            return false
        var path = String(item.local_path || "")
        if (activeFilter === 4 && recentRank(path) < 0)
            return false
        if (activeFilter === 5 && item.hydrated !== true
                && item.downloaded !== true)
            return false
        if (minimumFilterWidth > 0
                && (Number(item.width || preview.width || 0) < minimumFilterWidth
                    || Number(item.height || preview.height || 0) < minimumFilterHeight))
            return false
        if (selectedColor.length > 0) {
            var colors = Array.isArray(item.colors) ? item.colors : []
            var normalized = colors.map(function(color) {
                return String(color).replace("#", "").toLowerCase()
            })
            if (normalized.indexOf(selectedColor.toLowerCase()) < 0)
                return false
        }
        var query = searchField.text.trim().toLowerCase()
        if (query.length > 0) {
            var searchable = [
                wallpaperTitle(item),
                item.pack || "",
                item.provider || "",
                Array.isArray(item.tags) ? item.tags.join(" ") : ""
            ].join(" ").toLowerCase()
            if (searchable.indexOf(query) < 0)
                return false
        }
        return true
    }

    function wallpaperEntry(item) {
        var preview = item.preview || {}
        var colors = providerColors(item.provider)
        var width = Number(item.width || preview.width || 0)
        var height = Number(item.height || preview.height || 0)
        var sourceWidth = Number(preview.source_width || width)
        var sourceHeight = Number(preview.source_height || height)
        return {
            "title": wallpaperTitle(item),
            "provider": String(item.provider || ""),
            "colorA": colors[0],
            "colorB": colors[1],
            "favorite": item.favorite === true,
            "favoriteKey": String(item.favorite_key || item.local_path || ""),
            "live": preview.kind === "video",
            "duration": formatDuration(preview.duration_ms),
            "resolution": width > 0 && height > 0 ? width + " x " + height : "",
            "size": formatBytes(preview.size_bytes),
            "tags": Array.isArray(item.tags) ? item.tags.join("  ") : "",
            "wallpaperId": String(item.id || ""),
            "product": String(item.product || "kitowall"),
            "pack": String(item.pack || ""),
            "previewSource": mediaSource(item),
            "sourceWidth": sourceWidth,
            "sourceHeight": sourceHeight,
            "hydrated": item.hydrated === true,
            "localPath": String(item.local_path || "")
        }
    }

    function wallpaperIndexById(id, start) {
        for (var index = Math.max(0, start || 0);
                index < wallpapers.count; ++index) {
            if (String(wallpapers.get(index).wallpaperId) === id)
                return index
        }
        return -1
    }

    function rebuildWallpapers() {
        var previousId = selected("wallpaperId")
        var filtered = []
        for (var index = 0; index < catalogItems.length; ++index) {
            if (matchesLibraryFilters(catalogItems[index]))
                filtered.push(catalogItems[index])
        }
        if (activeFilter === 4) {
            filtered.sort(function(left, right) {
                return recentRank(String(left.local_path || ""))
                    - recentRank(String(right.local_path || ""))
            })
        }
        var desired = []
        for (var itemIndex = 0; itemIndex < filtered.length; ++itemIndex) {
            desired.push(wallpaperEntry(filtered[itemIndex]))
        }

        for (var desiredIndex = 0; desiredIndex < desired.length; ++desiredIndex) {
            var desiredItem = desired[desiredIndex]
            var currentId = desiredIndex < wallpapers.count
                ? String(wallpapers.get(desiredIndex).wallpaperId) : ""
            if (currentId !== desiredItem.wallpaperId) {
                var existingIndex = wallpaperIndexById(
                    desiredItem.wallpaperId, desiredIndex + 1)
                if (existingIndex >= 0)
                    wallpapers.move(existingIndex, desiredIndex, 1)
                else
                    wallpapers.insert(desiredIndex, desiredItem)
            }
            wallpapers.set(desiredIndex, desiredItem)
        }
        if (wallpapers.count > desired.length)
            wallpapers.remove(desired.length, wallpapers.count - desired.length)

        var nextSelection = previousId.length > 0
            ? wallpaperIndexById(previousId, 0) : -1
        if (nextSelection >= 0)
            selectedIndex = nextSelection
        else if (wallpapers.count > 0)
            selectedIndex = Math.min(Math.max(0, selectedIndex), wallpapers.count - 1)
        else
            selectedIndex = -1
    }

    function selectPack(index) {
        if (index < 0 || index >= packsFilterModel.count)
            return
        selectedPack = packsFilterModel.get(index).packName
        kitowallBridge.refreshDashboard(selectedPack, true)
    }

    function hasLibraryFilters() {
        return selectedPack.length > 0
            || activeSource > 0
            || activeFilter > 0
            || selectedColor.length > 0
            || minimumFilterWidth > 0
            || searchField.text.trim().length > 0
    }

    function loadOutputs() {
        var response = parseJson(kitowallBridge.outputsJson, {})
        var outputs = response.outputs || []
        var previous = selectedOutput
        var selected = -1
        outputsModel.clear()
        for (var index = 0; index < outputs.length; ++index) {
            var name = String(outputs[index] || "")
            if (name.length === 0)
                continue
            outputsModel.append({ "outputName": name })
            if (name === previous)
                selected = outputsModel.count - 1
        }
        if (selected < 0 && outputsModel.count > 0)
            selected = 0
        outputSelect.currentIndex = selected
        selectedOutput = selected >= 0 ? outputsModel.get(selected).outputName : ""
    }

    function applyToSelectedOutput() {
        if (selectedOutput.length === 0 || wallpapers.count === 0)
            return
        if (String(selected("product")) === "kilivepaper") {
            kilivepaperBridge.applyItem(
                String(selected("wallpaperId")), selectedOutput)
            return
        }
        kitowallBridge.applyWallpaper(
            String(selected("pack")),
            String(selected("wallpaperId")),
            selectedOutput)
    }

    function applyToAllOutputs() {
        if (outputsModel.count === 0 || wallpapers.count === 0)
            return
        if (String(selected("product")) === "kilivepaper") {
            var outputs = []
            for (var index = 0; index < outputsModel.count; ++index)
                outputs.push(outputsModel.get(index).outputName)
            kilivepaperBridge.applyItemAll(
                String(selected("wallpaperId")), JSON.stringify(outputs))
            return
        }
        kitowallBridge.applyWallpaperAll(
            String(selected("pack")),
            String(selected("wallpaperId")))
    }

    function rotateNow() {
        if (kitowallBridge.busy)
            return
        kitowallBridge.rotateNow(selectedPack)
    }

    function loadCatalog() {
        var catalog = parseJson(kitowallBridge.catalogJson, {})
        kitowallCatalogSummary = catalog
        kitowallCatalogItems = catalog.items || []
        mergeCatalogs()
    }

    function normalizeLiveItem(item) {
        var preview = item.media_preview || {}
        var resolution = item.resolution || {}
        var videoWidth = Number(preview.width || resolution.w || 0)
        var videoHeight = Number(preview.height || resolution.h || 0)
        var thumbnailWidth = 480
        var thumbnailHeight = videoWidth > 0 && videoHeight > 0
            ? Math.max(1, Math.round(thumbnailWidth * videoHeight / videoWidth))
            : 270
        return {
            "product": "kilivepaper",
            "id": String(item.id || ""),
            "title": String(item.title || item.slug || "Live wallpaper"),
            "provider": String(item.provider || ""),
            "pack": "",
            "favorite": item.favorite === true,
            "favorite_key": String(item.id || ""),
            "hydrated": true,
            "downloaded": true,
            "local_path": String(item.file_path || preview.local_path || ""),
            "width": videoWidth,
            "height": videoHeight,
            "tags": Array.isArray(item.tags) ? item.tags : [],
            "last_applied_at": Number(item.last_applied_at || 0),
            "preview": {
                "kind": "video",
                "local_path": String(preview.local_path || item.file_path || ""),
                "width": videoWidth,
                "height": videoHeight,
                "source_width": thumbnailWidth,
                "source_height": thumbnailHeight,
                "size_bytes": Number(preview.size_bytes || item.size_bytes || 0),
                "duration_ms": Number(preview.duration_ms || 0),
                "thumbnail": preview.thumbnail || {
                    "local_path": String(item.thumb_path || "")
                }
            }
        }
    }

    function loadLiveLibrary() {
        var response = parseJson(kilivepaperBridge.libraryJson, {})
        var items = response.items || []
        var normalized = []
        for (var index = 0; index < items.length; ++index)
            normalized.push(normalizeLiveItem(items[index]))
        liveLibraryItems = normalized
        mergeCatalogs()
    }

    function mergeCatalogs() {
        catalogItems = kitowallCatalogItems.concat(liveLibraryItems)
        updateCatalogCounts()
        rebuildWallpapers()
    }

    function loadRuntimeSettings() {
        var settings = parseJson(kitowallBridge.settingsJson, {})
        rotationEnabled = settings.mode === "rotate"
        rotationIntervalSeconds = Number(
            settings.rotation_interval_seconds || 1800)
        var transition = settings.transition || {}
        transitionType = String(transition.type || "center")
        transitionDuration = Number(transition.duration || 0)
    }

    function loadAppearancePolicy() {
        var policy = parseJson(kitowallBridge.appearancePolicyJson, {})
        dynamicColorsEnabled = Boolean(policy.enabled)
        dynamicColorsOutput = String(policy.source_output || "")
    }

    function toggleDynamicColors() {
        if (kitowallBridge.busy)
            return
        kitowallBridge.setAppearancePolicyEnabled(
            !dynamicColorsEnabled, selectedOutput)
    }

    function toggleRotation() {
        if (!kitowallBridge.busy)
            kitowallBridge.setRotationEnabled(!rotationEnabled)
    }

    function rotationIntervalLabel() {
        switch (rotationIntervalSeconds) {
        case 300: return "5 min"
        case 900: return "15 min"
        case 1800: return "30 min"
        case 3600: return "1 hora"
        default: return Math.round(rotationIntervalSeconds / 60) + " min"
        }
    }

    function cycleRotationInterval() {
        if (kitowallBridge.busy)
            return
        var intervals = [300, 900, 1800, 3600]
        var current = intervals.indexOf(rotationIntervalSeconds)
        var next = intervals[(current + 1) % intervals.length]
        kitowallBridge.setRotationInterval(next)
    }

    function cycleTransitionType() {
        if (kitowallBridge.busy)
            return
        var current = transitionTypes.indexOf(transitionType)
        var next = transitionTypes[(current + 1) % transitionTypes.length]
        kitowallBridge.setTransitionType(next)
    }

    function transitionDurationLabel() {
        return Number.isInteger(transitionDuration)
            ? transitionDuration.toFixed(0) + " seg"
            : transitionDuration.toFixed(1) + " seg"
    }

    function cycleTransitionDuration() {
        if (kitowallBridge.busy)
            return
        var durations = [1, 2, 3, 4, 5]
        var current = durations.indexOf(transitionDuration)
        var next = durations[(current + 1) % durations.length]
        kitowallBridge.setTransitionDuration(next)
    }

    function toggleSelectedFavorite() {
        var favoriteKey = String(selected("favoriteKey"))
        if (favoriteKey.length === 0)
            return
        if (String(selected("product")) === "kilivepaper") {
            if (!kilivepaperBridge.busy)
                kilivepaperBridge.setFavorite(
                    String(selected("wallpaperId")),
                    !Boolean(selected("favorite")))
            return
        }
        if (kitowallBridge.busy)
            return
        kitowallBridge.setFavorite(
            favoriteKey,
            !Boolean(selected("favorite")),
            selectedPack)
    }

    KitowallBridge {
        id: kitowallBridge
        onCatalogJsonChanged: root.loadCatalog()
        onSettingsJsonChanged: root.loadRuntimeSettings()
        onHistoryJsonChanged: root.loadHistoryCount()
        onJobsJsonChanged: root.loadDashboardJobs()
        onOutputsJsonChanged: root.loadOutputs()
        onAppearancePolicyJsonChanged: root.loadAppearancePolicy()
        onPacksJsonChanged: root.loadPacks()
        onLastMessageChanged: {
            if (lastMessage.indexOf("Wallpaper aplicado") === 0
                    || lastMessage.indexOf("Wallpaper cambiado") === 0
                    || lastMessage.indexOf("Rotacion automatica") === 0
                    || lastMessage.indexOf("Intervalo de rotacion") === 0
                    || lastMessage.indexOf("Transicion actualizada") === 0
                    || lastMessage.indexOf("Duracion de transicion") === 0
                    || lastMessage.indexOf("Colores dinamicos") === 0
                    || lastMessage.indexOf("Wallpaper agregado a favoritos") === 0
                    || lastMessage.indexOf("Wallpaper eliminado de favoritos") === 0) {
                kitowallBridge.refreshDashboard(root.selectedPack, true)
                root.applyMessage = lastMessage
                applyToast.restart()
            }
        }
        onLastErrorChanged: {
            if (lastError.length > 0) {
                root.applyMessage = lastError
                applyToast.restart()
            }
        }
    }

    KilivepaperBridge {
        id: kilivepaperBridge
        onLibraryJsonChanged: root.loadLiveLibrary()
        onLastMessageChanged: {
            if (lastMessage.length > 0) {
                root.applyMessage = lastMessage
                applyToast.restart()
            }
        }
        onLastErrorChanged: {
            if (lastError.length > 0) {
                root.applyMessage = lastError
                applyToast.restart()
            }
        }
    }

    ListModel { id: wallpapers }
    ListModel { id: outputsModel }
    ListModel {
        id: packsFilterModel
        ListElement { packName: ""; displayName: "Todos los packs" }
    }
    ListModel {
        id: colorFilterModel
        ListElement { colorValue: ""; colorLabel: "Todos" }
        ListElement { colorValue: "cc0000"; colorLabel: "Rojo" }
        ListElement { colorValue: "e7d40a"; colorLabel: "Amarillo" }
        ListElement { colorValue: "00aa44"; colorLabel: "Verde" }
        ListElement { colorValue: "0099cc"; colorLabel: "Azul" }
        ListElement { colorValue: "663399"; colorLabel: "Violeta" }
        ListElement { colorValue: "ffffff"; colorLabel: "Blanco" }
        ListElement { colorValue: "000000"; colorLabel: "Negro" }
    }
    ListModel {
        id: resolutionFilterModel
        ListElement { label: "Todas"; minWidth: 0; minHeight: 0 }
        ListElement { label: "Full HD+"; minWidth: 1920; minHeight: 1080 }
        ListElement { label: "QHD+"; minWidth: 2560; minHeight: 1440 }
        ListElement { label: "4K+"; minWidth: 3840; minHeight: 2160 }
    }

    ListModel {
        id: sourceModel
        ListElement { label: "Todos"; count: "N/D"; iconName: "apps" }
        ListElement { label: "Locales"; count: "N/D"; iconName: "folder" }
        ListElement { label: "Wallhaven"; count: "N/D"; iconName: "language" }
        ListElement { label: "Unsplash"; count: "N/D"; iconName: "photo_library" }
        ListElement { label: "Reddit"; count: "N/D"; iconName: "forum" }
        ListElement { label: "Moewalls"; count: "N/D"; iconName: "animated_images" }
        ListElement { label: "MotionBGs"; count: "N/D"; iconName: "movie" }
    }

    ListModel {
        id: filterModel
        ListElement { modelLabel: "Todos"; modelCount: "N/D"; modelIcon: "apps" }
        ListElement { modelLabel: "Estaticos"; modelCount: "N/D"; modelIcon: "image" }
        ListElement { modelLabel: "Videos"; modelCount: "N/D"; modelIcon: "videocam" }
        ListElement { modelLabel: "Favoritos"; modelCount: "N/D"; modelIcon: "favorite" }
        ListElement { modelLabel: "Recientes"; modelCount: "N/D"; modelIcon: "history" }
        ListElement { modelLabel: "Descargados"; modelCount: "N/D"; modelIcon: "download_done" }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#080914" }
            GradientStop { position: 0.48; color: "#0c0d18" }
            GradientStop { position: 1; color: "#060710" }
        }
    }

    Rectangle {
        width: parent.width * 0.62
        height: width
        radius: width / 2
        x: parent.width * 0.18
        y: -height * 0.58
        color: "#221328"
        opacity: 0.52
    }

    Rectangle {
        id: sidebar
        visible: root.activeView !== "settings"
        width: root.compactSidebar ? 78 : 214
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 12
        radius: 20
        color: root.panel
        border.width: 1
        border.color: root.border

        Column {
            anchors.fill: parent
            anchors.margins: root.compactSidebar ? 10 : 14
            spacing: 7

            Row {
                height: 78
                width: parent.width
                spacing: 11

                Rectangle {
                    width: 38
                    height: 38
                    radius: 12
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.accentBright }
                        GradientStop { position: 1; color: root.accentDark }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: "Ki"
                        color: root.accentForeground
                        font.family: root.uiFont
                        font.pixelSize: 14
                        font.bold: true
                    }
                }

                Text {
                    visible: !root.compactSidebar
                    anchors.verticalCenter: parent.verticalCenter
                    text: "KiUI"
                    color: root.textPrimary
                    font.family: root.uiFont
                    font.pixelSize: 20
                    font.weight: Font.DemiBold
                }
            }

            Text {
                visible: !root.compactSidebar
                text: "FUENTES"
                color: "#63697e"
                font.family: root.uiFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
                leftPadding: 9
                topPadding: 4
                bottomPadding: 5
            }

            Repeater {
                model: sourceModel
                delegate: NavItem {
                    required property int index
                    required property string label
                    required property string count
                    required property string iconName
                    width: parent.width
                    displayLabel: label
                    displayCount: count
                    displayIcon: iconName
                    compact: root.compactSidebar
                    accent: root.accent
                    accentBright: root.accentBright
                    selected: root.activeSource === index
                    onActivated: {
                        root.activeView = "library"
                        root.activeSource = index
                        root.rebuildWallpapers()
                    }
                }
            }

            Item { width: 1; height: 10 }

            Text {
                visible: !root.compactSidebar
                text: "FILTROS"
                color: "#63697e"
                font.family: root.uiFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
                leftPadding: 9
            }

            NavItem {
                id: favoritesFilterItem
                width: parent.width
                displayLabel: "Favoritos"
                displayIcon: "favorite"
                displayCount: root.favoriteCount
                compact: root.compactSidebar
                accent: root.accent
                accentBright: root.accentBright
                selected: root.activeFilter === 3
                onActivated: {
                    root.activeFilter = root.activeFilter === 3 ? 0 : 3
                    root.rebuildWallpapers()
                }
            }
            NavItem {
                id: colorsFilterItem
                width: parent.width
                displayLabel: "Colores"
                displayIcon: "palette"
                displayCount: root.selectedColor.length > 0
                    ? "#" + root.selectedColor.toUpperCase() : ""
                trailingIcon: root.colorFiltersExpanded
                    ? "keyboard_arrow_up" : "keyboard_arrow_down"
                compact: root.compactSidebar
                accent: root.accent
                accentBright: root.accentBright
                selected: root.selectedColor.length > 0
                onActivated: {
                    root.colorFiltersExpanded = !root.colorFiltersExpanded
                    root.resolutionFiltersExpanded = false
                }
            }
            Flow {
                visible: !root.compactSidebar && root.colorFiltersExpanded
                x: 7
                width: parent.width - 14
                spacing: 6

                Repeater {
                    model: colorFilterModel

                    delegate: Button {
                        required property string colorValue
                        required property string colorLabel
                        width: 27
                        height: 27
                        padding: 0
                        onClicked: {
                            root.selectedColor = colorValue
                            root.rebuildWallpapers()
                        }
                        ToolTip.visible: hovered
                        ToolTip.text: colorLabel
                        background: Rectangle {
                            radius: 8
                            color: colorValue.length > 0 ? "#" + colorValue : "#151824"
                            border.width: root.selectedColor === colorValue ? 2 : 1
                            border.color: root.selectedColor === colorValue
                                ? root.accentBright : "#3a3e50"
                        }
                        contentItem: KiIcon {
                            visible: colorValue.length === 0
                            name: "format_color_reset"
                            color: "#8f95a8"
                            iconSize: 15
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: "Paleta disponible tras refrescar el indice"
                    color: "#646a7e"
                    wrapMode: Text.WordWrap
                    font.family: root.uiFont
                    font.pixelSize: 8
                }
            }
            NavItem {
                id: resolutionFilterItem
                width: parent.width
                displayLabel: "Resolucion"
                displayIcon: "aspect_ratio"
                displayCount: root.minimumFilterWidth > 0
                    ? root.minimumFilterWidth + "x" + root.minimumFilterHeight : ""
                trailingIcon: root.resolutionFiltersExpanded
                    ? "keyboard_arrow_up" : "keyboard_arrow_down"
                compact: root.compactSidebar
                accent: root.accent
                accentBright: root.accentBright
                selected: root.minimumFilterWidth > 0
                onActivated: {
                    root.resolutionFiltersExpanded = !root.resolutionFiltersExpanded
                    root.colorFiltersExpanded = false
                }
            }
            Column {
                visible: !root.compactSidebar && root.resolutionFiltersExpanded
                width: parent.width
                spacing: 5

                Repeater {
                    model: resolutionFilterModel

                    delegate: Button {
                        required property string label
                        required property int minWidth
                        required property int minHeight
                        width: parent.width
                        height: 30
                        text: label
                        onClicked: {
                            root.minimumFilterWidth = minWidth
                            root.minimumFilterHeight = minHeight
                            root.rebuildWallpapers()
                        }
                        background: Rectangle {
                            radius: 8
                            color: root.minimumFilterWidth === minWidth
                                ? root.accentSurface
                                : (parent.hovered ? "#171a27" : "transparent")
                            border.color: root.minimumFilterWidth === minWidth
                                ? root.accent : "#272b39"
                        }
                        contentItem: Text {
                            text: parent.text
                            color: root.minimumFilterWidth === minWidth
                                ? "#e1b9f7" : "#9da3b5"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.family: root.uiFont
                            font.pixelSize: 9
                        }
                    }
                }
            }

            Item { width: 1; height: 10 }

            Text {
                visible: !root.compactSidebar
                text: "LIVE WALLPAPERS"
                color: "#63697e"
                font.family: root.uiFont
                font.pixelSize: 10
                font.letterSpacing: 1.1
                leftPadding: 9
            }

            NavItem {
                width: parent.width
                displayLabel: "Descargas live"
                displayIcon: "cloud_download"
                compact: root.compactSidebar
                accent: root.accent
                accentBright: root.accentBright
                selected: root.activeView === "liveDownloads"
                onActivated: {
                    root.activeView = "liveDownloads"
                    root.colorFiltersExpanded = false
                    root.resolutionFiltersExpanded = false
                }
            }
        }

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 26
            columns: root.compactSidebar ? 1 : 3
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: ["settings", "history", "power_settings_new"]
                delegate: Button {
                    required property string modelData
                    width: 48
                    height: 38
                    onClicked: {
                        if (modelData === "settings")
                            root.activeView = "settings"
                    }
                    Accessible.name: modelData
                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? "#1b1d2a" : "transparent"
                        border.color: "#262938"
                    }
                    contentItem: KiIcon {
                        name: modelData
                        color: "#8f95a8"
                        iconSize: 19
                    }
                }
            }
        }
    }

    Rectangle {
        id: detailPanel
        visible: root.activeView === "library" && root.showDetails && wallpapers.count > 0
        width: 302
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 18
        radius: 20
        color: root.panel
        border.width: 1
        border.color: root.border

        Column {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 12

            Rectangle {
                id: detailPreview

                width: parent.width
                height: 245
                radius: 13
                clip: true
                gradient: Gradient {
                    GradientStop { position: 0; color: root.selected("colorA") }
                    GradientStop { position: 0.7; color: root.selected("colorB") }
                    GradientStop { position: 1; color: "#080b17" }
                }

                Image {
                    id: detailImage

                    anchors.fill: parent
                    source: root.selected("previewSource")
                    sourceSize.width: detailPreview.width * 2
                    sourceSize.height: detailPreview.height * 2
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    autoTransform: true
                    mipmap: true
                }

                Column {
                    visible: detailImage.status === Image.Null
                        || detailImage.status === Image.Error
                    anchors.centerIn: parent
                    spacing: 7

                    KiIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 30
                        height: 30
                        name: "broken_image"
                        color: "#a2a7b8"
                        iconSize: 27
                    }

                    Text {
                        text: detailImage.status === Image.Error
                            ? "Preview no disponible" : "Sin preview"
                        color: "#a2a7b8"
                        font.family: root.uiFont
                        font.pixelSize: 10
                    }
                }

                BusyIndicator {
                    visible: detailImage.status === Image.Loading
                    running: visible
                    anchors.centerIn: parent
                    width: 34
                    height: 34
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 56
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#99070812" }
                        GradientStop { position: 1; color: "#00070812" }
                    }
                }

                Button {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 8
                    width: 38
                    height: 38
                    enabled: !kitowallBridge.busy
                        && String(root.selected("favoriteKey")).length > 0
                    hoverEnabled: true
                    onClicked: root.toggleSelectedFavorite()

                    background: Rectangle {
                        radius: 19
                        color: parent.pressed
                            ? "#b82b3040"
                            : (parent.hovered ? "#a9282b3a" : "#78070812")
                        border.width: parent.activeFocus ? 1 : 0
                        border.color: "#f3b0c8"
                    }

                    contentItem: KiIcon {
                        name: root.selected("favorite")
                            ? "favorite" : "favorite_border"
                        color: root.selected("favorite") ? "#ff719f" : "white"
                        iconSize: 22
                    }

                    ToolTip.visible: hovered
                    ToolTip.text: root.selected("favorite")
                        ? "Quitar de favoritos" : "Agregar a favoritos"
                }
            }

            Row {
                spacing: 10
                Text {
                    width: 174
                    text: root.selected("title")
                    color: root.textPrimary
                    font.family: root.uiFont
                    font.pixelSize: 17
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: root.selected("live") ? 48 : 54
                    height: 22
                    radius: 11
                    color: "#2f1744"
                    Text {
                        anchors.centerIn: parent
                        text: root.selected("live") ? "Live" : "Estatico"
                        color: "#d799ff"
                        font.family: root.uiFont
                        font.pixelSize: 9
                    }
                }
            }

            Text {
                text: "por " + root.selected("provider")
                color: root.textSecondary
                font.family: root.uiFont
                font.pixelSize: 11
            }

            Rectangle { width: parent.width; height: 1; color: "#232635" }

            Grid {
                width: parent.width
                columns: 2
                rowSpacing: 11
                columnSpacing: 12

                Text { text: "Resolucion"; color: root.textSecondary; font.family: root.uiFont; font.pixelSize: 11 }
                Text { width: 116; text: root.selected("resolution"); color: "#c6cada"; font.family: root.uiFont; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                Text { text: "Relacion"; color: root.textSecondary; font.family: root.uiFont; font.pixelSize: 11 }
                Text { width: 116; text: "16:9"; color: "#c6cada"; font.family: root.uiFont; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
                Text { text: "Tamano"; color: root.textSecondary; font.family: root.uiFont; font.pixelSize: 11 }
                Text { width: 116; text: root.selected("size"); color: "#c6cada"; font.family: root.uiFont; font.pixelSize: 11; horizontalAlignment: Text.AlignRight }
            }

            Text {
                text: "Etiquetas"
                color: root.textSecondary
                font.family: root.uiFont
                font.pixelSize: 11
                topPadding: 5
            }

            Rectangle {
                width: parent.width
                height: 32
                radius: 9
                color: "#151724"
                Text {
                    anchors.centerIn: parent
                    text: root.selected("tags")
                    color: "#aeb3c3"
                    font.family: root.uiFont
                    font.pixelSize: 10
                }
            }

            Item { width: 1; height: Math.max(0, parent.height - 640) }

            Button {
                width: parent.width
                height: 44
                enabled: root.selectedOutput.length > 0
                    && wallpapers.count > 0
                    && !kitowallBridge.busy
                text: root.selectedOutput.length > 0
                    ? "Aplicar en " + root.selectedOutput
                    : "Sin monitor disponible"
                onClicked: root.applyToSelectedOutput()
                background: Rectangle {
                    radius: 10
                    opacity: parent.enabled ? 1 : 0.45
                    gradient: Gradient {
                        GradientStop { position: 0; color: root.accentBright }
                        GradientStop { position: 1; color: root.accentDark }
                    }
                }
                contentItem: Text {
                    text: parent.text
                    color: root.accentForeground
                    font.family: root.uiFont
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                width: parent.width
                height: 40
                enabled: outputsModel.count > 0
                    && wallpapers.count > 0
                    && !kitowallBridge.busy
                text: "Aplicar en todos"
                onClicked: root.applyToAllOutputs()
                background: Rectangle { radius: 10; color: parent.hovered ? "#222432" : "#191b28"; border.color: "#292c3b" }
                contentItem: Text { text: parent.text; color: parent.enabled ? "#c7cad5" : "#666a7a"; font.family: root.uiFont; font.pixelSize: 11; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }

    Item {
        id: content
        visible: root.activeView === "library"
        anchors.left: sidebar.right
        anchors.right: detailPanel.visible ? detailPanel.left : parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 22
        anchors.rightMargin: detailPanel.visible ? 22 : 28
        anchors.topMargin: 22
        anchors.bottomMargin: 18

        Row {
            id: header
            width: parent.width
            height: 54
            spacing: 12

            TextField {
                id: searchField
                width: Math.min(470, parent.width - 190)
                height: 48
                placeholderText: "Buscar wallpapers..."
                color: root.textPrimary
                placeholderTextColor: "#777c90"
                font.family: root.uiFont
                font.pixelSize: 12
                leftPadding: 46
                onTextChanged: root.rebuildWallpapers()
                background: Rectangle {
                    radius: 24
                    color: "#b50f111e"
                    border.color: parent.activeFocus ? "#694084" : "#323545"
                }

                KiIcon {
                    width: 20
                    height: 20
                    anchors.left: parent.left
                    anchors.leftMargin: 17
                    anchors.verticalCenter: parent.verticalCenter
                    name: "search"
                    color: "#a4a8b8"
                    iconSize: 19
                }
            }

            Item { width: Math.max(0, parent.width - 650); height: 1 }

            ComboBox {
                id: outputSelect
                width: 136
                height: 44
                model: outputsModel
                textRole: "outputName"
                enabled: outputsModel.count > 0
                displayText: currentIndex >= 0 && currentIndex < outputsModel.count
                    ? outputsModel.get(currentIndex).outputName
                    : "Sin monitores"
                onActivated: function(index) {
                    root.selectedOutput = outputsModel.get(index).outputName
                }
                background: Rectangle {
                    radius: 13
                    color: "#11131f"
                    border.color: outputSelect.activeFocus ? root.accent : "#313443"
                    opacity: outputSelect.enabled ? 1 : 0.65
                }
                contentItem: Item {
                    KiIcon {
                        id: outputIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18
                        height: 18
                        name: "monitor"
                        color: "#d7d9e3"
                        iconSize: 17
                    }

                    Text {
                        anchors.left: outputIcon.right
                        anchors.right: parent.right
                        anchors.leftMargin: 7
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: outputSelect.displayText
                        color: "#d7d9e3"
                        elide: Text.ElideRight
                        font.family: root.uiFont
                        font.pixelSize: 11
                    }
                }
                indicator: KiIcon {
                    x: outputSelect.width - width - 10
                    y: (outputSelect.height - height) / 2
                    width: 16
                    height: 16
                    name: "keyboard_arrow_down"
                    color: "#8e94a7"
                    iconSize: 16
                }
                delegate: ItemDelegate {
                    required property int index
                    required property string outputName
                    width: outputSelect.width
                    height: 38
                    text: outputName
                    highlighted: outputSelect.highlightedIndex === index
                    contentItem: Text {
                        text: parent.text
                        color: "#d7d9e3"
                        font.family: root.uiFont
                        font.pixelSize: 11
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: parent.highlighted ? root.accentSurface : "#11131f"
                    }
                }
                popup: Popup {
                    y: outputSelect.height + 5
                    width: outputSelect.width
                    implicitHeight: Math.min(contentItem.implicitHeight + 8, 220)
                    padding: 4
                    closePolicy: Popup.CloseOnEscape
                        | Popup.CloseOnPressOutsideParent
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: outputSelect.popup.visible ? outputSelect.delegateModel : null
                        currentIndex: outputSelect.highlightedIndex
                    }
                    background: Rectangle {
                        radius: 10
                        color: "#10121d"
                        border.color: "#313443"
                    }
                }
            }
        }

        Item {
            id: filters
            anchors.top: header.bottom
            anchors.topMargin: 16
            width: parent.width
            height: 44

            Flickable {
                anchors.left: parent.left
                anchors.right: packSelect.left
                anchors.rightMargin: 12
                height: parent.height
                contentWidth: filterChipRow.width
                contentHeight: height
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.HorizontalFlick

                Row {
                    id: filterChipRow
                    height: parent.height
                    spacing: 10

                    Repeater {
                        model: filterModel
                        delegate: FilterChip {
                            required property int index
                            required property string modelLabel
                            required property string modelCount
                            required property string modelIcon
                            label: modelLabel
                            count: modelCount
                            iconName: modelIcon
                            accent: root.accent
                            accentBright: root.accentBright
                            selected: root.activeFilter === index
                            onActivated: {
                                root.activeFilter = root.activeFilter === index
                                    && index === 3 ? 0 : index
                                root.rebuildWallpapers()
                            }
                        }
                    }
                }
            }

            ComboBox {
                id: packSelect
                width: 174
                height: 40
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                model: packsFilterModel
                textRole: "displayName"
                displayText: currentIndex >= 0 && currentIndex < packsFilterModel.count
                    ? packsFilterModel.get(currentIndex).displayName
                    : "Todos los packs"
                onActivated: function(index) {
                    root.selectPack(index)
                }
                background: Rectangle {
                    radius: 11
                    color: "#11131f"
                    border.color: packSelect.activeFocus ? root.accent : "#313443"
                }
                contentItem: Item {
                    KiIcon {
                        id: packIcon
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: 17
                        height: 17
                        name: "folder"
                        color: root.selectedPack.length > 0 ? root.accentBright : "#9298aa"
                        iconSize: 16
                    }
                    Text {
                        anchors.left: packIcon.right
                        anchors.right: parent.right
                        anchors.leftMargin: 7
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: packSelect.displayText
                        color: "#d7d9e3"
                        elide: Text.ElideRight
                        font.family: root.uiFont
                        font.pixelSize: 10
                    }
                }
                indicator: KiIcon {
                    x: packSelect.width - width - 9
                    y: (packSelect.height - height) / 2
                    width: 16
                    height: 16
                    name: "keyboard_arrow_down"
                    color: "#8e94a7"
                    iconSize: 15
                }
                delegate: ItemDelegate {
                    required property int index
                    required property string packName
                    required property string displayName
                    width: packSelect.width
                    height: 36
                    text: displayName
                    highlighted: packSelect.highlightedIndex === index
                    contentItem: Text {
                        text: parent.text
                        color: "#d7d9e3"
                        font.family: root.uiFont
                        font.pixelSize: 10
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                    background: Rectangle {
                        color: parent.highlighted ? root.accentSurface : "#11131f"
                    }
                }
                popup: Popup {
                    y: packSelect.height + 5
                    width: packSelect.width
                    implicitHeight: Math.min(contentItem.implicitHeight + 8, 240)
                    padding: 4
                    contentItem: ListView {
                        clip: true
                        implicitHeight: contentHeight
                        model: packSelect.popup.visible ? packSelect.delegateModel : null
                        currentIndex: packSelect.highlightedIndex
                    }
                    background: Rectangle {
                        radius: 10
                        color: "#10121d"
                        border.color: "#313443"
                    }
                }
            }
        }

        HexGrid {
            id: hexGrid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: filters.bottom
            anchors.bottom: rotationDock.top
            anchors.topMargin: 18
            anchors.bottomMargin: 14
            wallpaperModel: wallpapers
            currentIndex: root.selectedIndex
            accent: root.accent
            accentBright: root.accentBright
            onSelected: function(itemIndex) {
                root.selectedIndex = itemIndex
            }
            onApplyRequested: function(itemIndex) {
                root.selectedIndex = itemIndex
                root.applyToSelectedOutput()
            }
        }

        Column {
            visible: wallpapers.count === 0
            anchors.centerIn: hexGrid
            spacing: 8

            KiIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 34
                height: 34
                name: kitowallBridge.busy ? "sync" : "image_search"
                color: "#777d92"
                iconSize: 30
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: kitowallBridge.busy
                    ? "Cargando catalogo..."
                    : (root.hasLibraryFilters()
                        ? "Ningun wallpaper coincide con los filtros"
                        : "No hay wallpapers indexados")
                color: "#aeb3c3"
                font.family: root.uiFont
                font.pixelSize: 13
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: kitowallBridge.lastError.length > 0
                    ? kitowallBridge.lastError
                    : (root.hasLibraryFilters()
                        ? "Cambia o limpia alguno de los filtros activos."
                        : "Refresca un pack remoto o agrega una carpeta local.")
                color: kitowallBridge.lastError.length > 0 ? "#d88992" : "#676d81"
                font.family: root.uiFont
                font.pixelSize: 9
            }
        }

        Rectangle {
            id: rotationDock
            width: Math.min(815, parent.width - 24)
            height: 74
            radius: 20
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: footer.top
            anchors.bottomMargin: 9
            color: "#e510121e"
            border.color: "#343747"

            Row {
                anchors.centerIn: parent
                spacing: 0

                Repeater {
                    model: [
                        {
                            "title": "Rotacion",
                            "value": root.rotationEnabled ? "Activada" : "Desactivada",
                            "accent": root.rotationEnabled,
                            "icon": root.rotationEnabled ? "sync" : "sync_disabled"
                        },
                        {
                            "title": "Intervalo",
                            "value": root.rotationIntervalLabel(),
                            "accent": false,
                            "icon": "schedule"
                        },
                        { "title": "Cambiar", "value": "Ahora", "accent": true, "icon": "shuffle" },
                        {
                            "title": "Transicion",
                            "value": root.transitionType,
                            "accent": false,
                            "icon": "animation"
                        },
                        {
                            "title": "Duracion",
                            "value": root.transitionDurationLabel(),
                            "accent": false,
                            "icon": "timer"
                        },
                        {
                            "title": "Colores",
                            "value": root.dynamicColorsEnabled
                                ? "Activados" : "Desactivados",
                            "accent": root.dynamicColorsEnabled,
                            "icon": "palette"
                        }
                    ]
                    delegate: Item {
                        required property var modelData
                        width: Math.floor((rotationDock.width - 12) / 6)
                        height: 52

                        Button {
                            visible: modelData.title === "Cambiar"
                            width: 62
                            height: 62
                            anchors.centerIn: parent
                            enabled: !kitowallBridge.busy
                            hoverEnabled: true
                            onClicked: root.rotateNow()

                            background: Rectangle {
                                radius: 31
                                color: parent.pressed
                                    ? root.accentDark
                                    : root.accentSurface
                                border.width: 2
                                border.color: parent.activeFocus
                                    ? root.accentBright : root.accent
                                opacity: parent.enabled ? 1 : 0.48
                            }

                            contentItem: KiIcon {
                                name: kitowallBridge.busy ? "sync" : modelData.icon
                                color: root.accentBright
                                iconSize: 26
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: "Cambiar wallpaper ahora"
                        }

                        Button {
                            visible: modelData.title === "Rotacion"
                            anchors.fill: parent
                            enabled: !kitowallBridge.busy
                            hoverEnabled: true
                            onClicked: root.toggleRotation()

                            background: Rectangle {
                                radius: 13
                                color: parent.pressed
                                    ? "#271335"
                                    : (parent.hovered ? "#191526" : "transparent")
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentBright
                                opacity: parent.enabled ? 1 : 0.5
                            }

                            contentItem: Row {
                                spacing: 9

                                KiIcon {
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    color: modelData.accent ? "#67dd80" : "#9297aa"
                                    iconSize: 21
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text { text: modelData.title; color: "#d4d6e0"; font.family: root.uiFont; font.pixelSize: 11 }
                                    Text { text: modelData.value; color: modelData.accent ? "#67dd80" : "#9297aa"; font.family: root.uiFont; font.pixelSize: 10 }
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: root.rotationEnabled
                                ? "Desactivar rotacion automatica"
                                : "Activar rotacion automatica"
                        }

                        Button {
                            visible: modelData.title === "Intervalo"
                            anchors.fill: parent
                            enabled: !kitowallBridge.busy
                            hoverEnabled: true
                            onClicked: root.cycleRotationInterval()

                            background: Rectangle {
                                radius: 13
                                color: parent.pressed
                                    ? "#21192d"
                                    : (parent.hovered ? "#171724" : "transparent")
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentBright
                                opacity: parent.enabled ? 1 : 0.5
                            }

                            contentItem: Row {
                                spacing: 9

                                KiIcon {
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    color: "#9ca1b3"
                                    iconSize: 21
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text { text: modelData.title; color: "#d4d6e0"; font.family: root.uiFont; font.pixelSize: 11 }
                                    Text { text: modelData.value; color: "#959bad"; font.family: root.uiFont; font.pixelSize: 10 }
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: "Cambiar intervalo de rotacion"
                        }

                        Button {
                            visible: modelData.title === "Transicion"
                            anchors.fill: parent
                            enabled: !kitowallBridge.busy
                            hoverEnabled: true
                            onClicked: root.cycleTransitionType()

                            background: Rectangle {
                                radius: 13
                                color: parent.pressed
                                    ? "#21192d"
                                    : (parent.hovered ? "#171724" : "transparent")
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentBright
                                opacity: parent.enabled ? 1 : 0.5
                            }

                            contentItem: Row {
                                spacing: 9

                                KiIcon {
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    color: "#9ca1b3"
                                    iconSize: 21
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text { text: modelData.title; color: "#d4d6e0"; font.family: root.uiFont; font.pixelSize: 11 }
                                    Text { text: modelData.value; color: "#959bad"; font.family: root.uiFont; font.pixelSize: 10 }
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: "Cambiar tipo de transicion"
                        }

                        Button {
                            visible: modelData.title === "Duracion"
                            anchors.fill: parent
                            enabled: !kitowallBridge.busy
                            hoverEnabled: true
                            onClicked: root.cycleTransitionDuration()

                            background: Rectangle {
                                radius: 13
                                color: parent.pressed
                                    ? "#21192d"
                                    : (parent.hovered ? "#171724" : "transparent")
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentBright
                                opacity: parent.enabled ? 1 : 0.5
                            }

                            contentItem: Row {
                                spacing: 9

                                KiIcon {
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    color: "#9ca1b3"
                                    iconSize: 21
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text { text: modelData.title; color: "#d4d6e0"; font.family: root.uiFont; font.pixelSize: 11 }
                                    Text { text: modelData.value; color: "#959bad"; font.family: root.uiFont; font.pixelSize: 10 }
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: "Cambiar duracion de la animacion"
                        }

                        Button {
                            visible: modelData.title === "Colores"
                            anchors.fill: parent
                            enabled: !kitowallBridge.busy
                                && root.selectedOutput.length > 0
                            hoverEnabled: true
                            onClicked: root.toggleDynamicColors()

                            background: Rectangle {
                                radius: 13
                                color: parent.pressed
                                    ? "#271335"
                                    : (parent.hovered ? "#191526" : "transparent")
                                border.width: parent.activeFocus ? 1 : 0
                                border.color: root.accentBright
                                opacity: parent.enabled ? 1 : 0.5
                            }

                            contentItem: Row {
                                spacing: 9

                                KiIcon {
                                    width: 24
                                    height: 24
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: modelData.icon
                                    color: modelData.accent ? "#67dd80" : "#9297aa"
                                    iconSize: 21
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3
                                    Text { text: modelData.title; color: "#d4d6e0"; font.family: root.uiFont; font.pixelSize: 11 }
                                    Text { text: modelData.value; color: modelData.accent ? "#67dd80" : "#9297aa"; font.family: root.uiFont; font.pixelSize: 10 }
                                }
                            }

                            ToolTip.visible: hovered
                            ToolTip.text: root.dynamicColorsEnabled
                                ? "Desactivar sincronizacion de colores"
                                : "Usar " + root.selectedOutput
                                    + " como fuente de colores"
                        }

                        Row {
                            visible: modelData.title !== "Cambiar"
                                && modelData.title !== "Rotacion"
                                && modelData.title !== "Intervalo"
                                && modelData.title !== "Transicion"
                                && modelData.title !== "Duracion"
                                && modelData.title !== "Colores"
                            anchors.centerIn: parent
                            spacing: 9

                            KiIcon {
                                width: 24
                                height: 24
                                anchors.verticalCenter: parent.verticalCenter
                                name: modelData.icon
                                color: modelData.accent ? "#67dd80" : "#9ca1b3"
                                iconSize: 21
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text { text: modelData.title; color: "#d4d6e0"; font.family: root.uiFont; font.pixelSize: 11 }
                                Text { text: modelData.value; color: modelData.accent ? "#67dd80" : "#959bad"; font.family: root.uiFont; font.pixelSize: 10 }
                            }
                        }
                    }
                }
            }
        }

        Text {
            id: footer
            height: 20
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Flechas  Navegar        Enter  Aplicar        Esc  Cerrar"
            color: "#656b7e"
            font.family: root.uiFont
            font.pixelSize: 10
        }
    }

    LiveDownloadsPage {
        id: liveDownloadsView
        visible: root.activeView === "liveDownloads"
        anchors.left: sidebar.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 26
        anchors.rightMargin: 28
        anchors.topMargin: 26
        anchors.bottomMargin: 24
        outputModel: outputsModel
        selectedOutput: root.selectedOutput
        accent: root.accent
        accentBright: root.accentBright
        accentDark: root.accentDark
        accentForeground: root.accentForeground
        onLibraryChanged: {
            if (!kilivepaperBridge.busy)
                kilivepaperBridge.refreshLibrary()
        }
    }

    Loader {
        id: settingsLoader

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 18
        anchors.topMargin: 12
        anchors.bottomMargin: 12
        visible: root.activeView === "settings"
        active: visible
        source: "SettingsPage.qml"
        onLoaded: {
            item.kitowall = kitowallBridge
            item.kilivepaper = kilivepaperBridge
            item.accent = Qt.binding(function() { return root.accent })
            item.accentBright = Qt.binding(function() { return root.accentBright })
            item.accentDark = Qt.binding(function() { return root.accentDark })
            item.accentForeground = Qt.binding(function() {
                return root.accentForeground
            })
            item.refreshAll()
        }
    }

    Connections {
        target: settingsLoader.item

        function onCloseRequested() {
            root.activeView = "library"
            hexGrid.forceActiveFocus()
        }
    }

    Rectangle {
        id: toast
        width: 240
        height: 42
        radius: 12
        anchors.horizontalCenter: parent.horizontalCenter
        y: applyToast.running ? 24 : -60
        color: "#dd171926"
        border.color: kitowallBridge.lastError.length > 0 ? "#8f3d4b" : "#63407d"
        z: 20

        Text {
            anchors.centerIn: parent
            text: root.applyMessage
            color: kitowallBridge.lastError.length > 0 ? "#f3b2ba" : "#e8e3ed"
            font.family: root.uiFont
            font.pixelSize: 11
        }

        Behavior on y {
            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
        }
    }

    Timer {
        id: applyToast
        interval: 1600
    }

    Timer {
        interval: root.dashboardHasActiveJobs ? 750 : 1200
        repeat: true
        running: true
        onTriggered: kitowallBridge.refreshDashboard(root.selectedPack, false)
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: kitowallBridge.refreshDashboard(root.selectedPack, true)
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.activeView === "library"
        onTriggered: {
            if (!kilivepaperBridge.busy)
                kilivepaperBridge.refreshLibrary()
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: root.close()
    }

    Component.onCompleted: {
        kitowallBridge.refresh()
        kitowallBridge.refreshOutputs()
        kitowallBridge.refreshAppearancePolicy()
        kitowallBridge.refreshAppearance()
        kitowallBridge.refreshDashboard("", true)
        kilivepaperBridge.refreshLibrary()
        hexGrid.forceActiveFocus()
    }
}
