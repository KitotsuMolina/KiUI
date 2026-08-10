use std::path::PathBuf;
use std::process::Command;

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use serde_json::Value;

use crate::contracts::ContractEnvelope;

struct BridgeRuntime {
    binary: PathBuf,
    compositor: PathBuf,
    kitowall: Option<PathBuf>,
    kilivepaper: Option<PathBuf>,
}

static RUNTIME: std::sync::OnceLock<BridgeRuntime> = std::sync::OnceLock::new();

pub fn configure(
    binary: PathBuf,
    compositor: PathBuf,
    kitowall: Option<PathBuf>,
    kilivepaper: Option<PathBuf>,
) -> Result<(), String> {
    RUNTIME
        .set(BridgeRuntime {
            binary,
            compositor,
            kitowall,
            kilivepaper,
        })
        .map_err(|_| "KiSDDM bridge runtime was already configured".to_owned())
}

#[derive(Default)]
pub struct KiSddmBridgeRust {
    themes_json: QString,
    config_json: QString,
    last_error: QString,
    last_message: QString,
    busy: bool,
}

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, themes_json, cxx_name = "themesJson")]
        #[qproperty(QString, config_json, cxx_name = "configJson")]
        #[qproperty(QString, last_error, cxx_name = "lastError")]
        #[qproperty(QString, last_message, cxx_name = "lastMessage")]
        #[qproperty(bool, busy)]
        type KiSddmBridge = super::KiSddmBridgeRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut KiSddmBridge>);

        #[qinvokable]
        #[cxx_name = "selectTheme"]
        fn select_theme(self: Pin<&mut KiSddmBridge>, id: &QString);

        #[qinvokable]
        #[cxx_name = "setMode"]
        fn set_mode(self: Pin<&mut KiSddmBridge>, mode: &QString);

        #[qinvokable]
        #[cxx_name = "applyToSddm"]
        fn apply_to_sddm(self: Pin<&mut KiSddmBridge>);
    }

    impl cxx_qt::Threading for KiSddmBridge {}
}

impl ffi::KiSddmBridge {
    fn refresh(mut self: core::pin::Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke_json(["theme", "list"])
                .and_then(|themes| invoke_json(["config", "show"]).map(|config| (themes, config)));
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok((themes, config)) => {
                            bridge.as_mut().set_themes_json(QString::from(&themes));
                            bridge.as_mut().set_config_json(QString::from(&config));
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn select_theme(self: core::pin::Pin<&mut Self>, id: &QString) {
        let id = id.to_string();
        if *self.busy() || id.is_empty() {
            return;
        }
        run_mutation(
            self,
            vec!["theme".into(), "select".into(), "--id".into(), id],
            "Tema de KiSDDM actualizado".into(),
        );
    }

    fn set_mode(self: core::pin::Pin<&mut Self>, mode: &QString) {
        let mode = mode.to_string();
        if *self.busy() || !matches!(mode.as_str(), "static" | "random" | "video") {
            return;
        }
        run_mutation(
            self,
            vec!["mode".into(), "set".into(), mode],
            "Modo de fondo actualizado".into(),
        );
    }

    fn apply_to_sddm(mut self: core::pin::Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        self.as_mut().set_last_message(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(["apply", "run", "--confirm", "--authorize"]);
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(_) => bridge
                            .as_mut()
                            .set_last_message(QString::from("Tema aplicado en SDDM correctamente")),
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }
}

fn run_mutation(
    mut bridge: core::pin::Pin<&mut ffi::KiSddmBridge>,
    args: Vec<String>,
    message: String,
) {
    bridge.as_mut().set_busy(true);
    bridge.as_mut().set_last_error(QString::default());
    let qt_thread = bridge.qt_thread();
    std::thread::spawn(move || {
        let result = invoke(args.iter().map(String::as_str)).and_then(|_| {
            let themes = invoke_json(["theme", "list"])?;
            let config = invoke_json(["config", "show"])?;
            Ok((themes, config))
        });
        qt_thread
            .queue(move |mut bridge| {
                match result {
                    Ok((themes, config)) => {
                        bridge.as_mut().set_themes_json(QString::from(&themes));
                        bridge.as_mut().set_config_json(QString::from(&config));
                        bridge.as_mut().set_last_message(QString::from(&message));
                    }
                    Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                }
                bridge.as_mut().set_busy(false);
            })
            .ok();
    });
}

fn invoke<'a>(args: impl IntoIterator<Item = &'a str>) -> Result<Value, String> {
    let runtime = RUNTIME
        .get()
        .ok_or_else(|| "KiSDDM bridge runtime is not configured".to_owned())?;
    let mut command = Command::new(&runtime.binary);
    command.env("KISDDM_COMPOSITOR_BIN", &runtime.compositor);
    if let Some(kitowall) = &runtime.kitowall {
        command.env("KISDDM_KITOWALL_BIN", kitowall);
    }
    if let Some(kilivepaper) = &runtime.kilivepaper {
        command.env("KISDDM_KILIVEPAPER_BIN", kilivepaper);
    }
    let output = command
        .args(args)
        .arg("--contract-v1")
        .output()
        .map_err(|error| format!("No se pudo ejecutar KiSDDM: {error}"))?;
    let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    let envelope = serde_json::from_slice::<ContractEnvelope>(&output.stdout).map_err(|error| {
        if output.stdout.is_empty() && !stderr.is_empty() {
            format!("KiSDDM no pudo completar la operación: {stderr}")
        } else {
            format!("KiSDDM devolvio una respuesta invalida: {error}; {stderr}")
        }
    })?;
    envelope.validate("kisddm")?;
    if !output.status.success() || !envelope.ok {
        return Err(envelope
            .error
            .map(|error| error.message)
            .unwrap_or_else(|| "KiSDDM fallo sin detalle".into()));
    }
    envelope
        .data
        .ok_or_else(|| "KiSDDM no devolvio datos".to_owned())
}

fn invoke_json<'a>(args: impl IntoIterator<Item = &'a str>) -> Result<String, String> {
    invoke(args).and_then(|value| serde_json::to_string(&value).map_err(|error| error.to_string()))
}
