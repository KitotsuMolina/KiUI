import QtQuick

Item {
    id: root

    property var wallpaperModel
    property int currentIndex: 0
    property int columns: width > 900 ? 5 : width > 620 ? 4 : 3
    property real tileGap: 10
    property real horizontalPadding: 18
    property real verticalPadding: 28
    property color accent: "#ad3cf3"
    property color accentBright: "#d16cff"
    readonly property int itemCount: wallpaperModel ? wallpaperModel.count : 0
    readonly property int rowCount: Math.ceil(itemCount / columns)
    readonly property real staggerWidth: rowCount > 1 ? 0.5 : 0
    readonly property real gridWidthInTiles: columns + staggerWidth
    readonly property real availableWidth: Math.max(0, width - horizontalPadding * 2)
    readonly property real tileWidth: Math.max(92,
        (availableWidth - (columns - 1 + staggerWidth) * tileGap)
            / gridWidthInTiles)
    readonly property real tileHeight: tileWidth * 1.095
    readonly property real horizontalPitch: tileWidth + tileGap
    readonly property real verticalPitch: tileHeight * 0.75 + tileGap
    readonly property real contentWidth: columns * tileWidth
        + (columns - 1) * tileGap + staggerWidth * horizontalPitch
    readonly property real gridContentHeight: itemCount > 0 ? tileHeight
        + Math.max(0, rowCount - 1) * verticalPitch
        : 0
    readonly property real originX: Math.max(horizontalPadding,
        (width - contentWidth) * 0.5)
    readonly property real originY: gridContentHeight + verticalPadding * 2 <= height
        ? Math.max(verticalPadding, (height - gridContentHeight) * 0.5)
        : verticalPadding
    readonly property bool canScrollUp: viewport.contentY > 2
    readonly property bool canScrollDown: viewport.contentHeight > viewport.height
        && viewport.contentY < viewport.contentHeight - viewport.height - 2
    signal selected(int itemIndex)
    signal applyRequested(int itemIndex)

    focus: true
    clip: true

    Flickable {
        id: viewport

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: Math.max(height,
            root.gridContentHeight + root.verticalPadding * 2)
        boundsBehavior: Flickable.DragOverBounds
        flickableDirection: Flickable.VerticalFlick
        maximumFlickVelocity: 2600
        flickDeceleration: 3200

        Repeater {
            model: root.wallpaperModel

            delegate: HexTile {
                required property int index
                required property string title
                required property string provider
                required property string colorA
                required property string colorB
                required property bool favorite
                required property bool live
                required property string duration
                required property string previewSource
                required property int sourceWidth
                required property int sourceHeight
                readonly property int rowIndex: Math.floor(index / root.columns)
                readonly property int columnIndex: index % root.columns

                itemIndex: index
                wallpaperTitle: title
                wallpaperProvider: provider
                primaryColor: colorA
                secondaryColor: colorB
                isFavorite: favorite
                isLive: live
                mediaDuration: duration
                mediaSource: previewSource
                mediaWidth: sourceWidth
                mediaHeight: sourceHeight
                accent: root.accent
                accentBright: root.accentBright
                width: root.tileWidth
                height: root.tileHeight
                x: root.originX + columnIndex * root.horizontalPitch
                    + (rowIndex % 2) * root.horizontalPitch * 0.5
                y: root.originY + rowIndex * root.verticalPitch
                selected: index === root.currentIndex
                onActivated: function(itemIndex) {
                    root.currentIndex = itemIndex
                    root.selected(itemIndex)
                    root.ensureVisible(itemIndex)
                    root.forceActiveFocus()
                }
            }
        }
    }

    EdgeScrollGlow {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        active: root.canScrollUp
        topEdge: true
        accent: root.accent
        accentBright: root.accentBright
        z: 10
    }

    EdgeScrollGlow {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        active: root.canScrollDown
        topEdge: false
        accent: root.accent
        accentBright: root.accentBright
        z: 10
    }

    function ensureVisible(candidate) {
        if (candidate < 0 || candidate >= itemCount)
            return
        var row = Math.floor(candidate / columns)
        var itemTop = originY + row * verticalPitch
        var itemBottom = itemTop + tileHeight
        var safeTop = viewport.contentY + 38
        var safeBottom = viewport.contentY + viewport.height - 38
        if (itemTop < safeTop)
            viewport.contentY = Math.max(0, itemTop - 38)
        else if (itemBottom > safeBottom)
            viewport.contentY = Math.min(
                viewport.contentHeight - viewport.height,
                itemBottom - viewport.height + 38)
    }

    function select(candidate) {
        if (candidate < 0 || candidate >= wallpaperModel.count)
            return
        currentIndex = candidate
        selected(candidate)
        ensureVisible(candidate)
    }

    onCurrentIndexChanged: Qt.callLater(function() {
        root.ensureVisible(root.currentIndex)
    })

    Keys.onLeftPressed: select(currentIndex - 1)
    Keys.onRightPressed: select(currentIndex + 1)
    Keys.onUpPressed: select(currentIndex - columns)
    Keys.onDownPressed: select(currentIndex + columns)
    Keys.onReturnPressed: applyRequested(currentIndex)
    Keys.onEnterPressed: applyRequested(currentIndex)
}
