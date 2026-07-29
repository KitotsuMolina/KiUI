import QtQuick

Item {
    id: root

    property bool active: false
    property bool topEdge: true
    property color accent: "#ad3cf3"
    property color accentBright: "#d16cff"

    height: 62
    visible: opacity > 0
    enabled: false
    opacity: active ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: root.topEdge ? parent.top : undefined
        anchors.bottom: root.topEdge ? undefined : parent.bottom
        width: parent.width
        height: 1
        color: root.accentBright
        opacity: 0.72
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: parent.height
        rotation: root.topEdge ? 0 : 180
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(
                    root.accent.r, root.accent.g, root.accent.b, 0.30)
            }
            GradientStop {
                position: 0.42
                color: "#162c0e47"
            }
            GradientStop {
                position: 1
                color: "#002c0e47"
            }
        }
    }

    Repeater {
        model: 13

        delegate: Rectangle {
            required property int index

            property real travelStart: root.topEdge ? 3 : root.height - 3
            property real travelEnd: root.topEdge
                ? root.height * (0.58 + (index % 4) * 0.08)
                : root.height * (0.42 - (index % 4) * 0.08)

            x: 12 + ((index * 79) % 937) / 937 * Math.max(0, root.width - 24)
            y: travelStart
            width: index % 4 === 0 ? 3 : 2
            height: width
            radius: width * 0.5
            color: index % 3 === 0 ? root.accentBright : root.accent
            opacity: 0

            SequentialAnimation on y {
                running: root.active
                loops: Animation.Infinite
                PauseAnimation { duration: index * 43 }
                NumberAnimation {
                    from: travelStart
                    to: travelEnd
                    duration: 950 + (index % 5) * 130
                    easing.type: Easing.OutCubic
                }
                PauseAnimation { duration: 260 + (index % 3) * 120 }
            }

            SequentialAnimation on opacity {
                running: root.active
                loops: Animation.Infinite
                PauseAnimation { duration: index * 43 }
                NumberAnimation { from: 0; to: 0.8; duration: 180 }
                NumberAnimation {
                    from: 0.8
                    to: 0
                    duration: 770 + (index % 5) * 130
                }
                PauseAnimation { duration: 260 + (index % 3) * 120 }
            }
        }
    }
}
