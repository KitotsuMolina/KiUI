#[allow(dead_code)]
mod contracts;
mod kilivepaper_bridge;
mod kitowall_bridge;
mod runtime;

use cxx_qt::casting::Upcast;
use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QQmlEngine, QUrl};
use std::env;
use std::pin::Pin;

fn main() {
    let runtime = match runtime::RuntimeContext::from_process() {
        Ok(runtime) => runtime,
        Err(error) => {
            eprintln!("kiui:error:{error}");
            return;
        }
    };
    configure_graphics_backend(runtime.mode);
    if runtime.mode == runtime::RuntimeMode::Local {
        eprintln!(
            "kiui:mode:local kitowall={} kilivepaper={} compositor={}",
            runtime.clis.kitowall.display(),
            runtime
                .clis
                .kilivepaper
                .as_ref()
                .map(|path| path.display().to_string())
                .unwrap_or_else(|| "<missing>".into()),
            runtime.clis.compositor.display()
        );
    }
    if let Err(error) = kitowall_bridge::configure(
        runtime.clis.kitowall.clone(),
        runtime.clis.kilivepaper.clone(),
        runtime.clis.compositor.clone(),
        runtime.mode == runtime::RuntimeMode::Local,
    ) {
        eprintln!("kiui:error:{error}");
        return;
    }
    if let Some(binary) = runtime.clis.kilivepaper.clone() {
        if let Err(error) = kilivepaper_bridge::configure(binary, runtime.clis.compositor.clone()) {
            eprintln!("kiui:error:{error}");
            return;
        }
    }

    let mut app = QGuiApplication::new();
    cxx_qt::init_qml_module!("dev.kitotsu.kiui");
    let mut engine = QQmlApplicationEngine::new();

    if let Some(engine) = engine.as_mut() {
        let mut engine = engine;
        engine
            .as_mut()
            .on_object_creation_failed(|_, _| {
                eprintln!("kiui:error:qml-object-creation-failed");
            })
            .release();
        let mut qml_engine: Pin<&mut QQmlEngine> = engine.as_mut().upcast_pin();
        qml_engine
            .as_mut()
            .set_output_warnings_to_standard_error(true);
        qml_engine.on_quit(|_| {}).release();
        engine.load(&QUrl::from("qrc:/qt/qml/dev/kitotsu/kiui/qml/main.qml"));
    }

    if let Some(app) = app.as_mut() {
        app.exec();
    }
}

fn configure_graphics_backend(mode: runtime::RuntimeMode) {
    let wayland = env::var_os("WAYLAND_DISPLAY").is_some();
    let explicitly_configured =
        env::var_os("QT_QUICK_BACKEND").is_some() || env::var_os("QSG_RHI_BACKEND").is_some();
    if should_use_software_backend(mode, wayland, explicitly_configured) {
        env::set_var("QT_QUICK_BACKEND", "software");
        eprintln!("kiui:graphics:software reason=local-wayland");
    }
}

fn should_use_software_backend(
    mode: runtime::RuntimeMode,
    wayland: bool,
    explicitly_configured: bool,
) -> bool {
    mode == runtime::RuntimeMode::Local && wayland && !explicitly_configured
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn local_wayland_defaults_to_software_rendering() {
        assert!(should_use_software_backend(
            runtime::RuntimeMode::Local,
            true,
            false
        ));
    }

    #[test]
    fn explicit_or_installed_graphics_configuration_is_preserved() {
        assert!(!should_use_software_backend(
            runtime::RuntimeMode::Local,
            true,
            true
        ));
        assert!(!should_use_software_backend(
            runtime::RuntimeMode::Installed,
            true,
            false
        ));
    }
}
