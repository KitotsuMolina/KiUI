use std::path::PathBuf;
use std::process::Command;

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use serde::Deserialize;
use serde_json::Value;

use crate::contracts::ContractEnvelope;

#[derive(Debug, Clone)]
struct BridgeRuntime {
    binary: PathBuf,
    compositor: PathBuf,
}

static RUNTIME: std::sync::OnceLock<BridgeRuntime> = std::sync::OnceLock::new();

pub fn configure(binary: PathBuf, compositor: PathBuf) -> Result<(), String> {
    RUNTIME
        .set(BridgeRuntime { binary, compositor })
        .map_err(|_| "Kilivepaper bridge runtime was already configured".to_owned())
}

#[derive(Default)]
pub struct KilivepaperBridgeRust {
    catalog_json: QString,
    library_json: QString,
    settings_json: QString,
    applications_json: QString,
    status_json: QString,
    last_error: QString,
    last_message: QString,
    busy: bool,
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GeneralSettingsInput {
    video_fps: u32,
    video_speed: f64,
    hwaccel: String,
    quality: String,
    pause_on_steam_game: bool,
    pause_applications: Vec<String>,
    steam_poll_ms: u64,
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
        #[qproperty(QString, catalog_json, cxx_name = "catalogJson")]
        #[qproperty(QString, library_json, cxx_name = "libraryJson")]
        #[qproperty(QString, settings_json, cxx_name = "settingsJson")]
        #[qproperty(QString, applications_json, cxx_name = "applicationsJson")]
        #[qproperty(QString, status_json, cxx_name = "statusJson")]
        #[qproperty(QString, last_error, cxx_name = "lastError")]
        #[qproperty(QString, last_message, cxx_name = "lastMessage")]
        #[qproperty(bool, busy)]
        type KilivepaperBridge = super::KilivepaperBridgeRust;

        #[qinvokable]
        #[cxx_name = "requestCatalog"]
        fn request_catalog(
            self: Pin<&mut KilivepaperBridge>,
            query: &QString,
            provider: &QString,
            quality: &QString,
            page: i32,
            limit: i32,
        );

        #[qinvokable]
        #[cxx_name = "refreshLibrary"]
        fn refresh_library(self: Pin<&mut KilivepaperBridge>);

        #[qinvokable]
        #[cxx_name = "refreshSettings"]
        fn refresh_settings(self: Pin<&mut KilivepaperBridge>);

        #[qinvokable]
        #[cxx_name = "refreshStatus"]
        fn refresh_status(self: Pin<&mut KilivepaperBridge>);

        #[qinvokable]
        #[cxx_name = "saveGeneral"]
        fn save_general(self: Pin<&mut KilivepaperBridge>, payload_json: &QString);

        #[qinvokable]
        #[cxx_name = "serviceAction"]
        fn service_action(self: Pin<&mut KilivepaperBridge>, action: &QString);

        #[qinvokable]
        #[cxx_name = "applyItem"]
        fn apply_item(self: Pin<&mut KilivepaperBridge>, id: &QString, monitor: &QString);

        #[qinvokable]
        #[cxx_name = "applyItemAll"]
        fn apply_item_all(self: Pin<&mut KilivepaperBridge>, id: &QString, monitors_json: &QString);

        #[qinvokable]
        #[cxx_name = "setFavorite"]
        fn set_favorite(self: Pin<&mut KilivepaperBridge>, id: &QString, favorite: bool);

        #[qinvokable]
        #[cxx_name = "download"]
        fn download(
            self: Pin<&mut KilivepaperBridge>,
            page_url: &QString,
            quality: &QString,
            monitor: &QString,
            apply: bool,
        );
    }

    impl cxx_qt::Threading for KilivepaperBridge {}
}

impl ffi::KilivepaperBridge {
    fn request_catalog(
        mut self: core::pin::Pin<&mut Self>,
        query: &QString,
        provider: &QString,
        quality: &QString,
        page: i32,
        limit: i32,
    ) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let query = query.to_string();
        let provider = normalized_provider(&provider.to_string());
        let quality = normalized_browse_quality(&quality.to_string());
        let page = page.max(1);
        let limit = limit.clamp(1, 50);
        let qt_thread = self.qt_thread();

        std::thread::spawn(move || {
            let result = request_catalog(&query, &provider, &quality, page, limit)
                .and_then(|value| serde_json::to_string(&value).map_err(|error| error.to_string()));
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(json) => {
                            bridge.as_mut().set_catalog_json(QString::from(&json));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn refresh_library(mut self: core::pin::Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(vec!["list".into()])
                .and_then(|value| serde_json::to_string(&value).map_err(|error| error.to_string()));
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(json) => bridge.as_mut().set_library_json(QString::from(&json)),
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn refresh_settings(mut self: core::pin::Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(vec!["config".into(), "show".into()]).and_then(|settings| {
                let status = invoke(vec!["status".into()])?;
                let applications = invoke_compositor(vec!["applications".into(), "list".into()])?;
                Ok((
                    serde_json::to_string(&settings).map_err(|error| error.to_string())?,
                    serde_json::to_string(&status).map_err(|error| error.to_string())?,
                    serde_json::to_string(&applications).map_err(|error| error.to_string())?,
                ))
            });
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok((settings, status, applications)) => {
                            bridge.as_mut().set_settings_json(QString::from(&settings));
                            bridge.as_mut().set_status_json(QString::from(&status));
                            bridge
                                .as_mut()
                                .set_applications_json(QString::from(&applications));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn refresh_status(mut self: core::pin::Pin<&mut Self>) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke_json(vec!["status".into()]);
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(status) => {
                            bridge.as_mut().set_status_json(QString::from(&status));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn save_general(mut self: core::pin::Pin<&mut Self>, payload_json: &QString) {
        if *self.busy() {
            return;
        }
        let args = match general_settings_args(&payload_json.to_string()) {
            Ok(args) => args,
            Err(error) => {
                self.as_mut().set_last_error(QString::from(&error));
                return;
            }
        };
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(args).and_then(|_| {
                let settings = invoke_json(vec!["config".into(), "show".into()])?;
                let status = invoke_json(vec!["status".into()])?;
                Ok((settings, status))
            });
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok((settings, status)) => {
                            bridge.as_mut().set_settings_json(QString::from(&settings));
                            bridge.as_mut().set_status_json(QString::from(&status));
                            bridge
                                .as_mut()
                                .set_last_message(QString::from("Configuracion live actualizada"));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn service_action(mut self: core::pin::Pin<&mut Self>, action: &QString) {
        if *self.busy() {
            return;
        }
        let action = action.to_string();
        if !valid_service_action(&action) {
            self.as_mut()
                .set_last_error(QString::from("Accion de servicio no permitida"));
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(vec!["service".into(), action.clone()])
                .and_then(|_| invoke_json(vec!["status".into()]));
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(status) => {
                            bridge.as_mut().set_status_json(QString::from(&status));
                            bridge.as_mut().set_last_message(QString::from(format!(
                                "Servicio Kilivepaper: {action}"
                            )));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn apply_item(mut self: core::pin::Pin<&mut Self>, id: &QString, monitor: &QString) {
        if *self.busy() {
            return;
        }
        let id = id.to_string();
        let monitor = monitor.to_string();
        if id.trim().is_empty() || monitor.trim().is_empty() {
            self.as_mut()
                .set_last_error(QString::from("Selecciona un live wallpaper y un monitor"));
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(vec![
                "apply".into(),
                id,
                "--monitor".into(),
                monitor.clone(),
            ]);
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(_) => {
                            bridge.as_mut().set_last_message(QString::from(format!(
                                "Live wallpaper aplicado en {monitor}"
                            )));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn apply_item_all(mut self: core::pin::Pin<&mut Self>, id: &QString, monitors_json: &QString) {
        if *self.busy() {
            return;
        }
        let id = id.to_string();
        let monitors = match parse_monitors(&monitors_json.to_string()) {
            Ok(monitors) if !monitors.is_empty() => monitors,
            Ok(_) => {
                self.as_mut()
                    .set_last_error(QString::from("No hay monitores disponibles"));
                return;
            }
            Err(error) => {
                self.as_mut().set_last_error(QString::from(&error));
                return;
            }
        };
        if id.trim().is_empty() {
            self.as_mut()
                .set_last_error(QString::from("Selecciona un live wallpaper"));
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = monitors.iter().try_for_each(|monitor| {
                invoke(vec![
                    "apply".into(),
                    id.clone(),
                    "--monitor".into(),
                    monitor.clone(),
                ])
                .map(|_| ())
            });
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(()) => {
                            bridge.as_mut().set_last_message(QString::from(
                                "Live wallpaper aplicado en todos los monitores",
                            ));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn set_favorite(mut self: core::pin::Pin<&mut Self>, id: &QString, favorite: bool) {
        if *self.busy() {
            return;
        }
        let id = id.to_string();
        if id.trim().is_empty() {
            self.as_mut()
                .set_last_error(QString::from("Selecciona un live wallpaper"));
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke(vec![
                "favorite".into(),
                id,
                if favorite { "on" } else { "off" }.into(),
            ])
            .and_then(|_| invoke_json(vec!["list".into()]));
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(library) => {
                            bridge.as_mut().set_library_json(QString::from(&library));
                            bridge.as_mut().set_last_message(QString::from(if favorite {
                                "Live wallpaper agregado a favoritos"
                            } else {
                                "Live wallpaper eliminado de favoritos"
                            }));
                            bridge.as_mut().set_last_error(QString::default());
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn download(
        mut self: core::pin::Pin<&mut Self>,
        page_url: &QString,
        quality: &QString,
        monitor: &QString,
        apply: bool,
    ) {
        if *self.busy() {
            return;
        }
        let page_url = page_url.to_string();
        if page_url.trim().is_empty() {
            self.as_mut()
                .set_last_error(QString::from("Selecciona un live wallpaper"));
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        self.as_mut()
            .set_last_message(QString::from("Descarga iniciada"));
        let quality = normalized_download_quality(&quality.to_string());
        let monitor = monitor.to_string();
        let qt_thread = self.qt_thread();

        std::thread::spawn(move || {
            let mut args = vec!["fetch".into(), page_url, "--quality".into(), quality];
            if apply && !monitor.trim().is_empty() {
                args.extend(["--monitor".into(), monitor, "--apply".into()]);
            }
            let result = invoke(args);
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok(_) => {
                            bridge.as_mut().set_last_error(QString::default());
                            bridge.as_mut().set_last_message(QString::from(if apply {
                                "Live wallpaper descargado y aplicado"
                            } else {
                                "Live wallpaper descargado"
                            }));
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }
}

fn request_catalog(
    query: &str,
    provider: &str,
    quality: &str,
    page: i32,
    limit: i32,
) -> Result<Value, String> {
    let mut data = if query.trim().is_empty() {
        invoke(vec![
            "browse".into(),
            "--provider".into(),
            provider.into(),
            "--page".into(),
            page.to_string(),
            "--quality".into(),
            quality.into(),
            "--limit".into(),
            limit.to_string(),
            "--cache-thumbnails".into(),
        ])?
    } else {
        invoke(vec![
            "search".into(),
            query.trim().into(),
            "--provider".into(),
            provider.into(),
            "--page".into(),
            page.to_string(),
            "--limit".into(),
            limit.to_string(),
            "--cache-thumbnails".into(),
        ])?
    };

    let count = if let Some(items) = data.get_mut("items").and_then(Value::as_array_mut) {
        if quality == "4k" {
            items.retain(|item| item.get("has_4k").and_then(Value::as_bool) == Some(true));
        }
        items.truncate(limit as usize);
        Some(items.len() as u64)
    } else {
        None
    };
    if let (Some(object), Some(count)) = (data.as_object_mut(), count) {
        object.insert("count".into(), Value::from(count));
        object.insert("limit".into(), Value::from(limit));
    }
    Ok(data)
}

fn invoke(args: Vec<String>) -> Result<Value, String> {
    let runtime = RUNTIME
        .get()
        .ok_or_else(|| "Kilivepaper bridge runtime is not configured".to_owned())?;
    let output = Command::new(&runtime.binary)
        .env("KILIVEPAPER_COMPOSITOR_BIN", &runtime.compositor)
        .args(&args)
        .output()
        .map_err(|error| format!("No se pudo ejecutar Kilivepaper: {error}"))?;
    let envelope = serde_json::from_slice::<ContractEnvelope>(&output.stdout).map_err(|error| {
        format!(
            "Kilivepaper devolvio una respuesta invalida: {error}; {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )
    })?;
    envelope.validate("kilivepaper")?;
    if !output.status.success() || !envelope.ok {
        return Err(envelope
            .error
            .map(|error| error.message)
            .unwrap_or_else(|| "Kilivepaper fallo sin detalle".into()));
    }
    envelope
        .data
        .ok_or_else(|| "Kilivepaper no devolvio datos".to_owned())
}

fn invoke_json(args: Vec<String>) -> Result<String, String> {
    invoke(args).and_then(|value| serde_json::to_string(&value).map_err(|error| error.to_string()))
}

fn invoke_compositor(args: Vec<String>) -> Result<Value, String> {
    let runtime = RUNTIME
        .get()
        .ok_or_else(|| "Kilivepaper bridge runtime is not configured".to_owned())?;
    let output = Command::new(&runtime.compositor)
        .args(&args)
        .arg("--contract-v1")
        .output()
        .map_err(|error| format!("No se pudo ejecutar Kitsune Compositor: {error}"))?;
    let envelope = serde_json::from_slice::<ContractEnvelope>(&output.stdout).map_err(|error| {
        format!(
            "Kitsune Compositor devolvio una respuesta invalida: {error}; {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )
    })?;
    envelope.validate("kitsune-compositor")?;
    if !output.status.success() || !envelope.ok {
        return Err(envelope
            .error
            .map(|error| error.message)
            .unwrap_or_else(|| "Kitsune Compositor fallo sin detalle".into()));
    }
    envelope
        .data
        .ok_or_else(|| "Kitsune Compositor no devolvio datos".to_owned())
}

fn parse_monitors(monitors_json: &str) -> Result<Vec<String>, String> {
    let monitors = serde_json::from_str::<Vec<String>>(monitors_json)
        .map_err(|error| format!("Lista de monitores invalida: {error}"))?;
    Ok(monitors
        .into_iter()
        .filter(|monitor| !monitor.trim().is_empty())
        .collect())
}

fn general_settings_args(payload_json: &str) -> Result<Vec<String>, String> {
    let input = serde_json::from_str::<GeneralSettingsInput>(payload_json)
        .map_err(|error| format!("Configuracion live invalida: {error}"))?;
    if !(1..=240).contains(&input.video_fps) {
        return Err("Los FPS deben estar entre 1 y 240".into());
    }
    if !(0.1..=4.0).contains(&input.video_speed) || !input.video_speed.is_finite() {
        return Err("La velocidad debe estar entre 0.1 y 4.0".into());
    }
    if !matches!(input.hwaccel.as_str(), "auto" | "nvdec" | "vaapi" | "none") {
        return Err("Aceleracion de video no valida".into());
    }
    if !matches!(input.quality.as_str(), "low" | "medium" | "high" | "ultra") {
        return Err("Calidad de render no valida".into());
    }
    if !(200..=120_000).contains(&input.steam_poll_ms) {
        return Err("El sondeo de Steam debe estar entre 200 y 120000 ms".into());
    }
    Ok(vec![
        "config".into(),
        "apply-defaults".into(),
        "--video-fps".into(),
        input.video_fps.to_string(),
        "--video-speed".into(),
        input.video_speed.to_string(),
        "--hwaccel".into(),
        input.hwaccel,
        "--quality".into(),
        input.quality,
        "--pause-on-steam-game".into(),
        input.pause_on_steam_game.to_string(),
        "--pause-applications-json".into(),
        serde_json::to_string(&input.pause_applications)
            .map_err(|error| format!("Lista de aplicaciones invalida: {error}"))?,
        "--steam-poll-ms".into(),
        input.steam_poll_ms.to_string(),
    ])
}

fn valid_service_action(action: &str) -> bool {
    matches!(
        action,
        "apply" | "start" | "stop" | "restart" | "enable" | "disable"
    )
}

fn normalized_provider(value: &str) -> String {
    match value {
        "moewalls" | "motionbgs" => value.into(),
        _ => "all".into(),
    }
}

fn normalized_browse_quality(value: &str) -> String {
    if value == "4k" { "4k" } else { "all" }.into()
}

fn normalized_download_quality(value: &str) -> String {
    match value {
        "hd" | "4k" => value.into(),
        _ => "auto".into(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn normalizes_catalog_filters() {
        assert_eq!(normalized_provider("moewalls"), "moewalls");
        assert_eq!(normalized_provider("invalid"), "all");
        assert_eq!(normalized_browse_quality("4k"), "4k");
        assert_eq!(normalized_browse_quality("hd"), "all");
        assert_eq!(normalized_download_quality("hd"), "hd");
        assert_eq!(normalized_download_quality("all"), "auto");
    }

    #[test]
    fn builds_general_settings_arguments() {
        let args = general_settings_args(
            r#"{"videoFps":60,"videoSpeed":1.25,"hwaccel":"auto","quality":"high","pauseOnSteamGame":true,"pauseApplications":["org.mozilla.firefox"],"steamPollMs":1000}"#,
        )
        .expect("valid settings");
        assert_eq!(&args[..2], ["config", "apply-defaults"]);
        assert!(args.windows(2).any(|pair| pair == ["--video-fps", "60"]));
        assert!(args.windows(2).any(|pair| pair == ["--quality", "high"]));
        assert!(args
            .windows(2)
            .any(|pair| pair == ["--pause-applications-json", "[\"org.mozilla.firefox\"]"]));
    }

    #[test]
    fn rejects_invalid_general_settings() {
        let error = general_settings_args(
            r#"{"videoFps":0,"videoSpeed":1,"hwaccel":"auto","quality":"high","pauseOnSteamGame":true,"pauseApplications":[],"steamPollMs":1000}"#,
        )
        .expect_err("invalid fps");
        assert!(error.contains("FPS"));
        assert!(valid_service_action("restart"));
        assert!(valid_service_action("apply"));
        assert!(!valid_service_action("install"));
    }

    #[test]
    fn parses_monitor_batches() {
        assert_eq!(
            parse_monitors(r#"["DP-1","HDMI-A-1",""]"#).expect("valid monitors"),
            ["DP-1", "HDMI-A-1"]
        );
        assert!(parse_monitors("{}").is_err());
    }
}
