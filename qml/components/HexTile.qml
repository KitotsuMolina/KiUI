import QtQuick
import QtQuick.Controls

Item {
    id: root

    property int itemIndex: -1
    property string wallpaperTitle: ""
    property string wallpaperProvider: ""
    property string primaryColor: "#6d28d9"
    property string secondaryColor: "#0f172a"
    property bool isFavorite: false
    property bool isLive: false
    property string mediaDuration: ""
    property string mediaSource: ""
    property int mediaWidth: 0
    property int mediaHeight: 0
    property bool selected: false
    signal activated(int itemIndex)

    width: 146
    height: 160
    scale: selected ? 1.045 : pointer.hovered ? 1.02 : 1
    z: selected ? 4 : pointer.hovered ? 3 : 1
    focus: selected
    Accessible.role: Accessible.Button
    Accessible.name: wallpaperTitle + ", " + wallpaperProvider

    Behavior on scale {
        NumberAnimation {
            duration: 150
            easing.type: Easing.OutCubic
        }
    }

    Image {
        id: mediaLoader

        visible: false
        source: root.mediaSource
        asynchronous: true
        cache: true
        onStatusChanged: canvas.requestPaint()
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        function traceHex(ctx) {
            ctx.beginPath()
            ctx.moveTo(width * 0.5, 2)
            ctx.lineTo(width - 3, height * 0.255)
            ctx.lineTo(width - 3, height * 0.745)
            ctx.lineTo(width * 0.5, height - 2)
            ctx.lineTo(3, height * 0.745)
            ctx.lineTo(3, height * 0.255)
            ctx.closePath()
        }

        onPaint: {
            const ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            traceHex(ctx)
            ctx.save()
            ctx.clip()

            const gradient = ctx.createLinearGradient(0, 0, width, height)
            gradient.addColorStop(0, root.primaryColor)
            gradient.addColorStop(0.54, root.secondaryColor)
            gradient.addColorStop(1, "#070914")
            ctx.fillStyle = gradient
            ctx.fillRect(0, 0, width, height)

            if (mediaLoader.status === Image.Ready) {
                const loadedWidth = root.mediaWidth > 0
                    ? root.mediaWidth : mediaLoader.sourceSize.width
                const loadedHeight = root.mediaHeight > 0
                    ? root.mediaHeight : mediaLoader.sourceSize.height
                if (loadedWidth > 0 && loadedHeight > 0) {
                    const sourceRatio = loadedWidth / loadedHeight
                    const targetRatio = width / height
                    let sourceX = 0
                    let sourceY = 0
                    let sourceWidth = loadedWidth
                    let sourceHeight = loadedHeight
                    if (sourceRatio > targetRatio) {
                        sourceWidth = loadedHeight * targetRatio
                        sourceX = (loadedWidth - sourceWidth) * 0.5
                    } else {
                        sourceHeight = loadedWidth / targetRatio
                        sourceY = (loadedHeight - sourceHeight) * 0.5
                    }
                    ctx.drawImage(
                        mediaLoader,
                        sourceX, sourceY, sourceWidth, sourceHeight,
                        0, 0, width, height)
                } else {
                    ctx.drawImage(mediaLoader, 0, 0, width, height)
                }
            }

            const glow = ctx.createRadialGradient(
                width * 0.35, height * 0.3, 2,
                width * 0.35, height * 0.3, width * 0.62)
            glow.addColorStop(0, "rgba(244, 184, 255, 0.56)")
            glow.addColorStop(0.35, "rgba(124, 58, 237, 0.22)")
            glow.addColorStop(1, "rgba(4, 5, 13, 0)")
            ctx.fillStyle = glow
            ctx.fillRect(0, 0, width, height)

            ctx.strokeStyle = "rgba(255, 255, 255, 0.10)"
            ctx.lineWidth = 1
            for (let line = 0; line < 5; ++line) {
                ctx.beginPath()
                ctx.moveTo(-10, height * (0.55 + line * 0.09))
                ctx.quadraticCurveTo(
                    width * 0.55, height * (0.35 + line * 0.05),
                    width + 10, height * (0.65 + line * 0.06))
                ctx.stroke()
            }

            ctx.fillStyle = "rgba(255, 255, 255, 0.48)"
            for (let star = 0; star < 10; ++star) {
                const x = (star * 37 + root.itemIndex * 17) % width
                const y = (star * 53 + root.itemIndex * 11) % (height * 0.62)
                ctx.beginPath()
                ctx.arc(x, y, star % 3 === 0 ? 1.5 : 0.8, 0, Math.PI * 2)
                ctx.fill()
            }
            ctx.restore()

            traceHex(ctx)
            ctx.strokeStyle = root.selected ? "#cf63ff"
                : pointer.hovered ? "#9f51d1" : "rgba(205, 213, 232, 0.42)"
            ctx.lineWidth = root.selected ? 3 : 1.3
            ctx.stroke()
        }

    }

    onSelectedChanged: canvas.requestPaint()
    onPrimaryColorChanged: canvas.requestPaint()
    onSecondaryColorChanged: canvas.requestPaint()
    onMediaSourceChanged: canvas.requestPaint()

    Rectangle {
        visible: root.isFavorite
        width: Math.max(25, Math.min(34, root.width * 0.18))
        height: width
        radius: width * 0.5
        x: root.width - width - root.width * 0.035
        y: root.height * 0.30 - height * 0.5
        z: 2
        color: "#181423"
        border.color: "#ff719f"

        KiIcon {
            anchors.centerIn: parent
            width: Math.min(22, parent.width * 0.68)
            height: width
            name: "favorite"
            color: "#ff719f"
            iconSize: width
        }
    }

    Rectangle {
        visible: root.isLive
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: root.height * 0.17
        z: 2
        width: 66
        height: 25
        radius: 13
        color: "#ba07100d"
        border.color: "#65386f"

        Row {
            anchors.centerIn: parent
            spacing: 3

            KiIcon {
                width: 13
                height: 13
                name: "play_arrow"
                color: "#ffffff"
                iconSize: 13
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.mediaDuration
                color: "#ffffff"
                font.family: "CaskaydiaCove Nerd Font Propo"
                font.pixelSize: 9
            }
        }
    }

    HoverHandler {
        id: pointer
    }

    TapHandler {
        onTapped: root.activated(root.itemIndex)
    }

    Keys.onReturnPressed: root.activated(root.itemIndex)
    Keys.onEnterPressed: root.activated(root.itemIndex)
}
