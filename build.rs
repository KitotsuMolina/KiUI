use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(
        QmlModule::new("dev.kitotsu.kiui")
            .qml_file("qml/main.qml")
            .qml_file("qml/SettingsPage.qml")
            .qml_file("qml/LiveDownloadsPage.qml")
            .qml_file("qml/KiSddmPage.qml")
            .qml_file("qml/components/ConfigField.qml")
            .qml_file("qml/components/MaskMultiSelect.qml")
            .qml_file("qml/components/RatioResolutionSelector.qml")
            .qml_file("qml/components/SddmThemePreview.qml")
            .qml_file("qml/components/WallhavenColorPicker.qml")
            .qml_file("qml/components/HexTile.qml")
            .qml_file("qml/components/HexGrid.qml")
            .qml_file("qml/components/EdgeScrollGlow.qml")
            .qml_file("qml/components/NavItem.qml")
            .qml_file("qml/components/FilterChip.qml")
            .qml_file("qml/components/KiIcon.qml")
            .qml_file("qml/components/KiActionButton.qml"),
    )
    .file("src/kitowall_bridge.rs")
    .file("src/kilivepaper_bridge.rs")
    .file("src/kisddm_bridge.rs")
    .file("src/runtime_bridge.rs")
    .qrc_resources([
        "qml/assets/MaterialSymbolsRounded-KiUI.ttf",
        "qml/assets/PixelifySans-Bold.ttf",
        "qml/assets/kiui-logo.png",
    ])
    .qt_module("Network")
    .qt_module("QuickControls2")
    .build();
}
