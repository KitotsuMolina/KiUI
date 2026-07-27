import QtQuick

Text {
    id: root

    property string name: ""
    property int iconSize: 20

    text: name
    color: "#aeb3c3"
    font.family: iconFont.name.length > 0
        ? iconFont.name : "Material Symbols Rounded"
    font.pixelSize: iconSize
    font.preferShaping: true
    font.features: { "liga": 1, "rlig": 1 }
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter

    FontLoader {
        id: iconFont
        source: "../assets/MaterialSymbolsRounded-KiUI.ttf"
    }
}
