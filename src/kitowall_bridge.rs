use std::collections::BTreeMap;
use std::path::PathBuf;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Mutex, OnceLock};

use cxx_qt::Threading;
use cxx_qt_lib::QString;
use notify::{RecommendedWatcher, RecursiveMode, Watcher};
use serde::Deserialize;
use serde_json::{Map, Value};

use crate::contracts::ContractEnvelope;

#[derive(Debug, Clone)]
struct BridgeRuntime {
    binary: PathBuf,
    kilivepaper: Option<PathBuf>,
    compositor: PathBuf,
    local: bool,
}

static RUNTIME: OnceLock<BridgeRuntime> = OnceLock::new();
static DASHBOARD_DIRTY: AtomicBool = AtomicBool::new(true);
static APPEARANCE_REFRESH_PENDING: AtomicBool = AtomicBool::new(false);
static DASHBOARD_OBSERVER: OnceLock<Result<Mutex<DashboardObserver>, String>> = OnceLock::new();

struct DashboardObserver {
    watcher: RecommendedWatcher,
    watched: BTreeMap<PathBuf, RecursiveMode>,
}

pub fn configure(
    binary: PathBuf,
    kilivepaper: Option<PathBuf>,
    compositor: PathBuf,
    local: bool,
) -> Result<(), String> {
    RUNTIME
        .set(BridgeRuntime {
            binary,
            kilivepaper,
            compositor,
            local,
        })
        .map_err(|_| "Kitowall bridge runtime was already configured".to_owned())
}

#[derive(Default)]
pub struct KitowallBridgeRust {
    settings_json: QString,
    packs_json: QString,
    jobs_json: QString,
    catalog_json: QString,
    history_json: QString,
    outputs_json: QString,
    services_json: QString,
    appearance_policy_json: QString,
    appearance_json: QString,
    dashboard_revision: QString,
    last_error: QString,
    last_message: QString,
    busy: bool,
}

#[cxx_qt::bridge]
mod ffi {
    #[namespace = ""]
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, settings_json, cxx_name = "settingsJson")]
        #[qproperty(QString, packs_json, cxx_name = "packsJson")]
        #[qproperty(QString, jobs_json, cxx_name = "jobsJson")]
        #[qproperty(QString, catalog_json, cxx_name = "catalogJson")]
        #[qproperty(QString, history_json, cxx_name = "historyJson")]
        #[qproperty(QString, outputs_json, cxx_name = "outputsJson")]
        #[qproperty(QString, services_json, cxx_name = "servicesJson")]
        #[qproperty(QString, appearance_policy_json, cxx_name = "appearancePolicyJson")]
        #[qproperty(QString, appearance_json, cxx_name = "appearanceJson")]
        #[qproperty(QString, dashboard_revision, cxx_name = "dashboardRevision")]
        #[qproperty(QString, last_error, cxx_name = "lastError")]
        #[qproperty(QString, last_message, cxx_name = "lastMessage")]
        #[qproperty(bool, busy)]
        type KitowallBridge = super::KitowallBridgeRust;

        #[qinvokable]
        fn refresh(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "refreshDashboard"]
        fn refresh_dashboard(self: Pin<&mut KitowallBridge>, pack: &QString, force: bool);

        #[qinvokable]
        #[cxx_name = "refreshJobs"]
        fn refresh_jobs(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "refreshCatalog"]
        fn refresh_catalog(self: Pin<&mut KitowallBridge>, pack: &QString, offset: i32, limit: i32);

        #[qinvokable]
        #[cxx_name = "refreshOutputs"]
        fn refresh_outputs(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "refreshServices"]
        fn refresh_services(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "refreshAppearancePolicy"]
        fn refresh_appearance_policy(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "refreshAppearance"]
        fn refresh_appearance(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "setAppearancePolicyEnabled"]
        fn set_appearance_policy_enabled(
            self: Pin<&mut KitowallBridge>,
            enabled: bool,
            output: &QString,
        );

        #[qinvokable]
        #[cxx_name = "repairServices"]
        fn repair_services(self: Pin<&mut KitowallBridge>);

        #[qinvokable]
        #[cxx_name = "applyWallpaper"]
        fn apply_wallpaper(
            self: Pin<&mut KitowallBridge>,
            pack: &QString,
            id: &QString,
            output: &QString,
        );

        #[qinvokable]
        #[cxx_name = "applyWallpaperAll"]
        fn apply_wallpaper_all(self: Pin<&mut KitowallBridge>, pack: &QString, id: &QString);

        #[qinvokable]
        #[cxx_name = "rotateNow"]
        fn rotate_now(self: Pin<&mut KitowallBridge>, pack: &QString);

        #[qinvokable]
        #[cxx_name = "setRotationEnabled"]
        fn set_rotation_enabled(self: Pin<&mut KitowallBridge>, enabled: bool);

        #[qinvokable]
        #[cxx_name = "setRotationInterval"]
        fn set_rotation_interval(self: Pin<&mut KitowallBridge>, seconds: i32);

        #[qinvokable]
        #[cxx_name = "setTransitionType"]
        fn set_transition_type(self: Pin<&mut KitowallBridge>, transition_type: &QString);

        #[qinvokable]
        #[cxx_name = "setTransitionDuration"]
        fn set_transition_duration(self: Pin<&mut KitowallBridge>, seconds: i32);

        #[qinvokable]
        #[cxx_name = "setFavorite"]
        fn set_favorite(
            self: Pin<&mut KitowallBridge>,
            favorite_key: &QString,
            favorite: bool,
            pack: &QString,
        );

        #[qinvokable]
        #[cxx_name = "cancelJob"]
        fn cancel_job(self: Pin<&mut KitowallBridge>, id: &QString);

        #[qinvokable]
        #[cxx_name = "saveGeneral"]
        fn save_general(self: Pin<&mut KitowallBridge>, payload_json: &QString);

        #[qinvokable]
        #[cxx_name = "savePack"]
        fn save_pack(
            self: Pin<&mut KitowallBridge>,
            provider: &QString,
            name: &QString,
            payload_json: &QString,
        );

        #[qinvokable]
        #[cxx_name = "removePack"]
        fn remove_pack(self: Pin<&mut KitowallBridge>, name: &QString);

        #[qinvokable]
        #[cxx_name = "startPackJob"]
        fn start_pack_job(
            self: Pin<&mut KitowallBridge>,
            kind: &QString,
            name: &QString,
            count: i32,
        );
    }

    impl cxx_qt::Threading for KitowallBridge {}
}

impl ffi::KitowallBridge {
    fn refresh(mut self: core::pin::Pin<&mut Self>) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = (|| {
            let settings = invoke(&["settings", "get"])?;
            let packs = invoke(&["pack", "list"])?;
            let jobs = invoke(&["job", "list"])?;
            let settings = serde_json::to_string(&settings).map_err(|error| error.to_string())?;
            let packs = serde_json::to_string(&packs).map_err(|error| error.to_string())?;
            let jobs = serde_json::to_string(&jobs).map_err(|error| error.to_string())?;
            self.as_mut().set_settings_json(QString::from(&settings));
            self.as_mut().set_packs_json(QString::from(&packs));
            self.as_mut().set_jobs_json(QString::from(&jobs));
            self.as_mut()
                .set_last_message(QString::from("Configuracion actualizada"));
            Ok::<(), String>(())
        })();
        if let Err(error) = result {
            self.as_mut().set_last_error(QString::from(&error));
        }
        self.as_mut().set_busy(false);
    }

    fn refresh_dashboard(mut self: core::pin::Pin<&mut Self>, pack: &QString, force: bool) {
        if *self.busy() {
            DASHBOARD_DIRTY.store(true, Ordering::Release);
            return;
        }
        if !force && !DASHBOARD_DIRTY.swap(false, Ordering::AcqRel) {
            return;
        }

        let pack = pack.to_string();
        let result = invoke_owned(dashboard_snapshot_args(&pack)).and_then(|snapshot| {
            let mut watch_paths = snapshot
                .get("watchPaths")
                .and_then(Value::as_array)
                .map(|paths| {
                    paths
                        .iter()
                        .filter_map(Value::as_str)
                        .map(PathBuf::from)
                        .collect::<Vec<_>>()
                })
                .unwrap_or_default();
            watch_paths.push(appearance_state_path());
            update_dashboard_watches(&watch_paths)?;
            let appearance = invoke_compositor(&["appearance", "current"])
                .and_then(|value| serde_json::to_string(&value).map_err(|error| error.to_string()))
                .ok();
            Ok((snapshot, appearance))
        });
        match result {
            Ok((snapshot, appearance)) => {
                self.as_mut().set_last_error(QString::default());
                if let Some(appearance) = appearance {
                    self.as_mut()
                        .set_appearance_json(QString::from(&appearance));
                }
                let revision = snapshot
                    .get("revision")
                    .and_then(Value::as_str)
                    .unwrap_or_default();
                if revision != self.dashboard_revision().to_string() {
                    match apply_dashboard_snapshot(self.as_mut(), &snapshot) {
                        Ok(()) => self
                            .as_mut()
                            .set_dashboard_revision(QString::from(revision)),
                        Err(error) => {
                            self.as_mut().set_last_error(QString::from(&error));
                            DASHBOARD_DIRTY.store(true, Ordering::Release);
                        }
                    }
                }
            }
            Err(error) => {
                self.as_mut().set_last_error(QString::from(&error));
                DASHBOARD_DIRTY.store(true, Ordering::Release);
            }
        }
    }

    fn refresh_jobs(mut self: core::pin::Pin<&mut Self>) {
        match invoke(&["job", "list"])
            .and_then(|jobs| serde_json::to_string(&jobs).map_err(|error| error.to_string()))
        {
            Ok(jobs) => self.as_mut().set_jobs_json(QString::from(&jobs)),
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
    }

    fn refresh_catalog(
        mut self: core::pin::Pin<&mut Self>,
        pack: &QString,
        offset: i32,
        limit: i32,
    ) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let pack = pack.to_string();
        let args = catalog_args(&pack, offset, limit);
        match invoke_owned(args)
            .and_then(|catalog| serde_json::to_string(&catalog).map_err(|error| error.to_string()))
        {
            Ok(catalog) => {
                self.as_mut().set_catalog_json(QString::from(&catalog));
                self.as_mut()
                    .set_last_message(QString::from("Catalogo actualizado"));
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        match invoke(&["history", "list"])
            .and_then(|history| serde_json::to_string(&history).map_err(|error| error.to_string()))
        {
            Ok(history) => self.as_mut().set_history_json(QString::from(&history)),
            Err(error) if self.last_error().is_empty() => {
                self.as_mut().set_last_error(QString::from(&error));
            }
            Err(_) => {}
        }
        self.as_mut().set_busy(false);
    }

    fn refresh_outputs(mut self: core::pin::Pin<&mut Self>) {
        self.as_mut().set_last_error(QString::default());
        match invoke(&["outputs"])
            .and_then(|data| output_names(&data))
            .and_then(|outputs| {
                serde_json::to_string(&serde_json::json!({ "outputs": outputs }))
                    .map_err(|error| error.to_string())
            }) {
            Ok(outputs) => self.as_mut().set_outputs_json(QString::from(&outputs)),
            Err(error) => {
                self.as_mut()
                    .set_outputs_json(QString::from(r#"{"outputs":[]}"#));
                self.as_mut().set_last_error(QString::from(&error));
            }
        }
    }

    fn refresh_services(mut self: core::pin::Pin<&mut Self>) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        match invoke(&["service", "status"]).and_then(|services| {
            serde_json::to_string(&services).map_err(|error| error.to_string())
        }) {
            Ok(services) => {
                self.as_mut().set_services_json(QString::from(&services));
                self.as_mut()
                    .set_last_message(QString::from("Estado de servicios actualizado"));
            }
            Err(error) => {
                self.as_mut()
                    .set_services_json(QString::from(r#"{"automations":[]}"#));
                self.as_mut().set_last_error(QString::from(&error));
            }
        }
        self.as_mut().set_busy(false);
    }

    fn refresh_appearance_policy(mut self: core::pin::Pin<&mut Self>) {
        match invoke_compositor(&["appearance", "policy", "show"])
            .and_then(|policy| serde_json::to_string(&policy).map_err(|error| error.to_string()))
        {
            Ok(policy) => self
                .as_mut()
                .set_appearance_policy_json(QString::from(&policy)),
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
    }

    fn refresh_appearance(self: core::pin::Pin<&mut Self>) {
        if APPEARANCE_REFRESH_PENDING
            .compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire)
            .is_err()
        {
            return;
        }
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke_compositor(&["appearance", "current"]).and_then(|appearance| {
                serde_json::to_string(&appearance).map_err(|error| error.to_string())
            });
            let queued = qt_thread.queue(move |mut bridge| {
                if let Ok(appearance) = result {
                    bridge
                        .as_mut()
                        .set_appearance_json(QString::from(&appearance));
                }
                APPEARANCE_REFRESH_PENDING.store(false, Ordering::Release);
            });
            if queued.is_err() {
                APPEARANCE_REFRESH_PENDING.store(false, Ordering::Release);
            }
        });
    }

    fn set_appearance_policy_enabled(
        mut self: core::pin::Pin<&mut Self>,
        enabled: bool,
        output: &QString,
    ) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let output = output.to_string();
        let result = if enabled {
            if output.trim().is_empty() {
                Err("Selecciona un monitor antes de activar los colores dinamicos".into())
            } else {
                invoke_compositor(&[
                    "appearance",
                    "policy",
                    "enable",
                    "--output",
                    &output,
                    "--confirm",
                ])
            }
        } else {
            invoke_compositor(&["appearance", "policy", "disable"])
        }
        .and_then(|_| invoke_compositor(&["appearance", "policy", "show"]));

        match result {
            Ok(policy) => match serde_json::to_string(&policy).map_err(|error| error.to_string()) {
                Ok(policy) => {
                    self.as_mut()
                        .set_appearance_policy_json(QString::from(&policy));
                    let message = if enabled {
                        format!("Colores dinamicos activados para {output}")
                    } else {
                        "Colores dinamicos desactivados".into()
                    };
                    self.as_mut().set_last_message(QString::from(&message));
                }
                Err(error) => self.as_mut().set_last_error(QString::from(&error)),
            },
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn repair_services(mut self: core::pin::Pin<&mut Self>) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = invoke(&["service", "apply"])
            .and_then(|_| invoke(&["service", "enable"]))
            .and_then(|_| invoke(&["service", "restart"]))
            .map(|_| ());

        // Always inspect the resulting state: activation can fail after materialization.
        self.as_mut().refresh_services();
        match result {
            Ok(()) => {
                self.as_mut()
                    .set_last_message(QString::from("Servicios reparados y reiniciados"));
            }
            Err(error) => {
                self.as_mut().set_last_error(QString::from(&format!(
                    "La reparacion de servicios no se completo: {error}"
                )));
            }
        }
        self.as_mut().set_busy(false);
    }

    fn apply_wallpaper(
        mut self: core::pin::Pin<&mut Self>,
        pack: &QString,
        id: &QString,
        output: &QString,
    ) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let output_name = output.to_string();
        let result = wallpaper_apply_args(&pack.to_string(), &id.to_string(), &output_name)
            .and_then(invoke_owned)
            .and_then(|value| {
                release_live_output(&output_name)?;
                Ok(value)
            });
        match result {
            Ok(_) => {
                let empty_pack = QString::default();
                self.as_mut().refresh_catalog(&empty_pack, 0, 100);
                self.as_mut().set_last_message(QString::from(&format!(
                    "Wallpaper aplicado en {output_name}"
                )));
            }
            Err(error) => {
                self.as_mut().set_last_error(QString::from(&error));
                self.as_mut().set_busy(false);
            }
        }
    }

    fn apply_wallpaper_all(mut self: core::pin::Pin<&mut Self>, pack: &QString, id: &QString) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = (|| {
            let outputs = invoke(&["outputs"]).and_then(|data| output_names(&data))?;
            let args = wallpaper_apply_batch_args(&pack.to_string(), &id.to_string(), &outputs)?;
            let output_count = outputs.len();
            invoke_owned(args)?;
            for output in &outputs {
                release_live_output(output)?;
            }
            Ok::<usize, String>(output_count)
        })();
        match result {
            Ok(output_count) => {
                let empty_pack = QString::default();
                self.as_mut().refresh_catalog(&empty_pack, 0, 100);
                self.as_mut().set_last_message(QString::from(&format!(
                    "Wallpaper aplicado en {output_count} monitores"
                )));
            }
            Err(error) => {
                self.as_mut().set_last_error(QString::from(&error));
                self.as_mut().set_busy(false);
            }
        }
    }

    fn rotate_now(mut self: core::pin::Pin<&mut Self>, pack: &QString) {
        if *self.busy() {
            return;
        }
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let pack = pack.to_string();
        let qt_thread = self.qt_thread();
        std::thread::spawn(move || {
            let result = invoke_owned(rotate_now_args(&pack)).and_then(|_| {
                let catalog = invoke_owned(catalog_args(&pack, 0, 200)).and_then(|value| {
                    serde_json::to_string(&value).map_err(|error| error.to_string())
                })?;
                let history = invoke(&["history", "list"]).and_then(|value| {
                    serde_json::to_string(&value).map_err(|error| error.to_string())
                })?;
                Ok((catalog, history))
            });
            qt_thread
                .queue(move |mut bridge| {
                    match result {
                        Ok((catalog, history)) => {
                            bridge.as_mut().set_catalog_json(QString::from(&catalog));
                            bridge.as_mut().set_history_json(QString::from(&history));
                            bridge.as_mut().set_last_message(QString::from(
                                "Wallpaper cambiado correctamente",
                            ));
                            DASHBOARD_DIRTY.store(true, Ordering::Release);
                        }
                        Err(error) => bridge.as_mut().set_last_error(QString::from(&error)),
                    }
                    bridge.as_mut().set_busy(false);
                })
                .ok();
        });
    }

    fn set_rotation_enabled(mut self: core::pin::Pin<&mut Self>, enabled: bool) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result =
            invoke(&rotation_mode_args(enabled)).and_then(|_| invoke(&["settings", "get"]));
        match result {
            Ok(settings) => {
                match serde_json::to_string(&settings).map_err(|error| error.to_string()) {
                    Ok(settings) => {
                        self.as_mut().set_settings_json(QString::from(&settings));
                        self.as_mut().set_last_message(QString::from(if enabled {
                            "Rotacion automatica activada"
                        } else {
                            "Rotacion automatica desactivada"
                        }));
                        DASHBOARD_DIRTY.store(true, Ordering::Release);
                    }
                    Err(error) => self.as_mut().set_last_error(QString::from(&error)),
                }
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn set_rotation_interval(mut self: core::pin::Pin<&mut Self>, seconds: i32) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = update_rotation_interval(seconds);
        match result {
            Ok(settings) => {
                match serde_json::to_string(&settings).map_err(|error| error.to_string()) {
                    Ok(settings) => {
                        self.as_mut().set_settings_json(QString::from(&settings));
                        self.as_mut().set_last_message(QString::from(&format!(
                            "Intervalo de rotacion actualizado a {}",
                            rotation_interval_label(seconds)
                        )));
                        DASHBOARD_DIRTY.store(true, Ordering::Release);
                    }
                    Err(error) => self.as_mut().set_last_error(QString::from(&error)),
                }
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn set_transition_type(mut self: core::pin::Pin<&mut Self>, transition_type: &QString) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let transition_type = transition_type.to_string();
        let result = update_transition_type(&transition_type);
        match result {
            Ok(settings) => {
                match serde_json::to_string(&settings).map_err(|error| error.to_string()) {
                    Ok(settings) => {
                        self.as_mut().set_settings_json(QString::from(&settings));
                        self.as_mut().set_last_message(QString::from(&format!(
                            "Transicion actualizada a {transition_type}"
                        )));
                        DASHBOARD_DIRTY.store(true, Ordering::Release);
                    }
                    Err(error) => self.as_mut().set_last_error(QString::from(&error)),
                }
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn set_transition_duration(mut self: core::pin::Pin<&mut Self>, seconds: i32) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = update_transition_duration(seconds);
        match result {
            Ok(settings) => {
                match serde_json::to_string(&settings).map_err(|error| error.to_string()) {
                    Ok(settings) => {
                        self.as_mut().set_settings_json(QString::from(&settings));
                        self.as_mut().set_last_message(QString::from(&format!(
                            "Duracion de transicion actualizada a {seconds} seg"
                        )));
                        DASHBOARD_DIRTY.store(true, Ordering::Release);
                    }
                    Err(error) => self.as_mut().set_last_error(QString::from(&error)),
                }
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn set_favorite(
        mut self: core::pin::Pin<&mut Self>,
        favorite_key: &QString,
        favorite: bool,
        pack: &QString,
    ) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let favorite_key = favorite_key.to_string();
        let pack = pack.to_string();
        let result = favorite_args(&favorite_key, favorite).and_then(invoke_owned);
        match result {
            Ok(_) => {
                self.as_mut().set_last_message(QString::from(if favorite {
                    "Wallpaper agregado a favoritos"
                } else {
                    "Wallpaper eliminado de favoritos"
                }));
                DASHBOARD_DIRTY.store(true, Ordering::Release);
                self.as_mut().set_busy(false);
                let pack = QString::from(pack.as_str());
                self.as_mut().refresh_dashboard(&pack, true);
                return;
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn cancel_job(mut self: core::pin::Pin<&mut Self>, id: &QString) {
        self.as_mut().set_last_error(QString::default());
        let id = id.to_string();
        match invoke(&["job", "cancel", id.trim()]) {
            Ok(_) => {
                self.as_mut()
                    .set_last_message(QString::from("Cancelacion solicitada"));
                self.as_mut().refresh_jobs();
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
    }

    fn save_general(mut self: core::pin::Pin<&mut Self>, payload_json: &QString) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = serde_json::from_str::<GeneralSettingsInput>(&payload_json.to_string())
            .map_err(|error| format!("Formulario general invalido: {error}"))
            .and_then(save_general_settings);
        match result {
            Ok(()) => {
                self.as_mut()
                    .set_last_message(QString::from("Configuracion general guardada"));
                self.as_mut().refresh();
                return;
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn save_pack(
        mut self: core::pin::Pin<&mut Self>,
        provider: &QString,
        name: &QString,
        payload_json: &QString,
    ) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let result = save_pack_config(
            &provider.to_string(),
            &name.to_string(),
            &payload_json.to_string(),
        );
        match result {
            Ok(()) => {
                self.as_mut()
                    .set_last_message(QString::from("Pack guardado"));
                self.as_mut().refresh();
                return;
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn remove_pack(mut self: core::pin::Pin<&mut Self>, name: &QString) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let name = name.to_string();
        match invoke(&["pack", "remove", &name]) {
            Ok(_) => {
                self.as_mut()
                    .set_last_message(QString::from("Pack eliminado"));
                self.as_mut().refresh();
                return;
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }

    fn start_pack_job(
        mut self: core::pin::Pin<&mut Self>,
        kind: &QString,
        name: &QString,
        count: i32,
    ) {
        self.as_mut().set_busy(true);
        self.as_mut().set_last_error(QString::default());
        let kind = kind.to_string();
        let name = name.to_string();
        let result = if kind == "hydrate" {
            let count = count.clamp(1, 100).to_string();
            invoke(&["job", "start", "hydrate", &name, "--count", &count])
        } else {
            invoke(&["job", "start", "refresh", &name])
        };
        match result {
            Ok(record) => {
                let id = record
                    .get("id")
                    .and_then(Value::as_str)
                    .unwrap_or("sin identificador");
                self.as_mut()
                    .set_last_message(QString::from(&format!("Trabajo iniciado: {id}")));
                self.as_mut().refresh_jobs();
            }
            Err(error) => self.as_mut().set_last_error(QString::from(&error)),
        }
        self.as_mut().set_busy(false);
    }
}

fn catalog_args(pack: &str, offset: i32, limit: i32) -> Vec<String> {
    let mut args = vec![
        "wallpaper".to_owned(),
        "list".to_owned(),
        "--offset".to_owned(),
        offset.max(0).to_string(),
        "--limit".to_owned(),
        limit.clamp(1, 200).to_string(),
    ];
    if !pack.trim().is_empty() {
        args.extend(["--pack".to_owned(), pack.trim().to_owned()]);
    }
    args
}

fn favorite_args(favorite_key: &str, favorite: bool) -> Result<Vec<String>, String> {
    let favorite_key = favorite_key.trim();
    if favorite_key.is_empty() {
        return Err("El wallpaper no tiene una referencia de favorito".into());
    }
    Ok(vec![
        "favorite".into(),
        if favorite { "add" } else { "remove" }.into(),
        favorite_key.into(),
    ])
}

fn dashboard_snapshot_args(pack: &str) -> Vec<String> {
    let mut args = vec!["dashboard".to_owned(), "snapshot".to_owned()];
    if !pack.trim().is_empty() {
        args.extend(["--pack".to_owned(), pack.trim().to_owned()]);
    }
    args
}

fn rotate_now_args(pack: &str) -> Vec<String> {
    let mut args = vec!["rotate-now".to_owned()];
    if !pack.trim().is_empty() {
        args.extend(["--pack".to_owned(), pack.trim().to_owned()]);
    }
    args
}

fn apply_dashboard_snapshot(
    mut bridge: core::pin::Pin<&mut ffi::KitowallBridge>,
    snapshot: &Value,
) -> Result<(), String> {
    let catalog = serde_json::to_string(
        snapshot
            .get("catalog")
            .ok_or_else(|| "El snapshot no contiene catalogo".to_owned())?,
    )
    .map_err(|error| error.to_string())?;
    let packs = serde_json::to_string(&serde_json::json!({
        "packs": snapshot.get("packs").cloned().unwrap_or_default(),
        "providerCredentials": snapshot
            .get("providerCredentials")
            .cloned()
            .unwrap_or_default()
    }))
    .map_err(|error| error.to_string())?;
    let jobs = serde_json::to_string(&serde_json::json!({
        "jobs": snapshot.get("jobs").cloned().unwrap_or_default()
    }))
    .map_err(|error| error.to_string())?;
    let history = serde_json::to_string(&serde_json::json!({
        "entries": snapshot.get("history").cloned().unwrap_or_default()
    }))
    .map_err(|error| error.to_string())?;

    bridge.as_mut().set_catalog_json(QString::from(&catalog));
    bridge.as_mut().set_packs_json(QString::from(&packs));
    bridge.as_mut().set_jobs_json(QString::from(&jobs));
    bridge.as_mut().set_history_json(QString::from(&history));
    Ok(())
}

fn update_dashboard_watches(paths: &[PathBuf]) -> Result<(), String> {
    let observer = DASHBOARD_OBSERVER
        .get_or_init(|| {
            notify::recommended_watcher(|event: notify::Result<notify::Event>| {
                if event.is_ok() {
                    DASHBOARD_DIRTY.store(true, Ordering::Release);
                }
            })
            .map(|watcher| {
                Mutex::new(DashboardObserver {
                    watcher,
                    watched: BTreeMap::new(),
                })
            })
            .map_err(|error| error.to_string())
        })
        .as_ref()
        .map_err(Clone::clone)?;
    let mut observer = observer
        .lock()
        .map_err(|_| "El observador del dashboard quedo bloqueado".to_owned())?;
    let desired = paths
        .iter()
        .filter_map(|path| watch_target(path))
        .collect::<BTreeMap<_, _>>();

    let removed = observer
        .watched
        .keys()
        .filter(|path| !desired.contains_key(*path))
        .cloned()
        .collect::<Vec<_>>();
    for path in removed {
        let _ = observer.watcher.unwatch(&path);
        observer.watched.remove(&path);
    }
    for (path, mode) in desired {
        if observer.watched.get(&path) == Some(&mode) {
            continue;
        }
        observer
            .watcher
            .watch(&path, mode)
            .map_err(|error| format!("No se pudo observar {}: {error}", path.display()))?;
        observer.watched.insert(path, mode);
    }
    Ok(())
}

fn watch_target(path: &PathBuf) -> Option<(PathBuf, RecursiveMode)> {
    if path.is_dir() {
        return Some((path.clone(), RecursiveMode::Recursive));
    }
    let mut candidate = path.as_path();
    while !candidate.is_dir() {
        candidate = candidate.parent()?;
    }
    Some((candidate.to_path_buf(), RecursiveMode::NonRecursive))
}

fn appearance_state_path() -> PathBuf {
    std::env::var("KITSUNE_COMPOSITOR_APPEARANCE_STATE")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            let home = std::env::var("HOME").unwrap_or_else(|_| ".".into());
            std::env::var("XDG_STATE_HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|_| PathBuf::from(home).join(".local/state"))
                .join("kitsune-compositor/appearance.json")
        })
}

fn output_names(data: &Value) -> Result<Vec<String>, String> {
    let outputs = data
        .get("outputs")
        .and_then(Value::as_array)
        .ok_or_else(|| "Kitowall no devolvio la lista de monitores".to_owned())?;
    let names = outputs
        .iter()
        .filter_map(Value::as_str)
        .map(str::trim)
        .filter(|name| !name.is_empty())
        .map(str::to_owned)
        .collect::<Vec<_>>();
    if names.is_empty() {
        return Err("El compositor no detecto monitores disponibles".into());
    }
    Ok(names)
}

fn required_apply_value(label: &str, value: &str) -> Result<String, String> {
    let value = value.trim();
    if value.is_empty() {
        return Err(format!("{label} es obligatorio para aplicar el wallpaper"));
    }
    Ok(value.to_owned())
}

fn wallpaper_apply_args(pack: &str, id: &str, output: &str) -> Result<Vec<String>, String> {
    Ok(vec![
        "wallpaper".into(),
        "apply".into(),
        "--pack".into(),
        required_apply_value("El pack", pack)?,
        "--id".into(),
        required_apply_value("El identificador", id)?,
        "--output".into(),
        required_apply_value("El monitor", output)?,
    ])
}

fn rotation_mode_args(enabled: bool) -> [&'static str; 2] {
    ["mode", if enabled { "rotate" } else { "manual" }]
}

const ROTATION_INTERVALS: [i32; 4] = [300, 900, 1800, 3600];
const TRANSITION_DURATIONS: [i32; 5] = [1, 2, 3, 4, 5];
const TRANSITION_TYPES: [&str; 13] = [
    "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow", "center", "outer",
    "any", "random",
];

fn rotation_interval_label(seconds: i32) -> &'static str {
    match seconds {
        300 => "5 min",
        900 => "15 min",
        1800 => "30 min",
        3600 => "1 hora",
        _ => "intervalo personalizado",
    }
}

fn update_rotation_interval(seconds: i32) -> Result<Value, String> {
    if !ROTATION_INTERVALS.contains(&seconds) {
        return Err("El intervalo debe ser 5, 15, 30 o 60 minutos".into());
    }
    let previous = invoke(&["settings", "get"])?;
    let previous_seconds = previous
        .get("rotation_interval_seconds")
        .and_then(Value::as_i64)
        .unwrap_or(1800)
        .to_string();
    let seconds = seconds.to_string();
    invoke(&["settings", "set", "--rotation-interval-seconds", &seconds])?;
    if let Err(error) = invoke(&["service", "reschedule", "--every-seconds", &seconds]) {
        let _ = invoke(&[
            "settings",
            "set",
            "--rotation-interval-seconds",
            &previous_seconds,
        ]);
        return Err(format!("No se pudo reprogramar la rotacion: {error}"));
    }
    invoke(&["settings", "get"])
}

fn update_transition_type(transition_type: &str) -> Result<Value, String> {
    if !TRANSITION_TYPES.contains(&transition_type) {
        return Err(format!(
            "Tipo de transicion no soportado: {transition_type}"
        ));
    }
    invoke(&["transition", "set", "--type", transition_type])?;
    invoke(&["settings", "get"])
}

fn update_transition_duration(seconds: i32) -> Result<Value, String> {
    if !TRANSITION_DURATIONS.contains(&seconds) {
        return Err("La duracion debe ser 1, 2, 3, 4 o 5 segundos".into());
    }
    let seconds = seconds.to_string();
    invoke(&["transition", "set", "--duration", &seconds])?;
    invoke(&["settings", "get"])
}

fn wallpaper_apply_batch_args(
    pack: &str,
    id: &str,
    outputs: &[String],
) -> Result<Vec<String>, String> {
    let pack = required_apply_value("El pack", pack)?;
    let id = required_apply_value("El identificador", id)?;
    if outputs.is_empty() {
        return Err("No hay monitores disponibles para aplicar el wallpaper".into());
    }
    if id.contains([',', ':']) {
        return Err("El identificador del wallpaper contiene separadores no soportados".into());
    }
    let mut targets = Vec::with_capacity(outputs.len());
    for output in outputs {
        let output = required_apply_value("El monitor", output)?;
        if output.contains([',', ':']) {
            return Err(format!(
                "El monitor {output} contiene separadores no soportados"
            ));
        }
        targets.push(format!("{output}:{id}"));
    }
    Ok(vec![
        "wallpaper".into(),
        "apply-batch".into(),
        "--pack".into(),
        pack,
        "--map".into(),
        targets.join(","),
    ])
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct GeneralSettingsInput {
    mode: String,
    interval: i32,
    transition_type: String,
    fps: i32,
    duration: f64,
    angle: String,
    position: String,
}

fn save_general_settings(input: GeneralSettingsInput) -> Result<(), String> {
    if !matches!(input.mode.as_str(), "manual" | "rotate") {
        return Err("El modo debe ser manual o rotate".into());
    }
    if input.interval <= 0 {
        return Err("El intervalo debe ser mayor que cero".into());
    }
    if !(1..=240).contains(&input.fps) {
        return Err("Los FPS deben estar entre 1 y 240".into());
    }
    if !input.duration.is_finite() || !(0.0..=60.0).contains(&input.duration) {
        return Err("La duracion debe estar entre 0 y 60 segundos".into());
    }

    invoke(&["mode", &input.mode])?;
    let interval = input.interval.to_string();
    invoke(&["settings", "set", "--rotation-interval-seconds", &interval])?;

    let fps = input.fps.to_string();
    let duration = input.duration.to_string();
    let mut args = vec![
        "transition".to_owned(),
        "set".to_owned(),
        "--type".to_owned(),
        input.transition_type,
        "--fps".to_owned(),
        fps,
        "--duration".to_owned(),
        duration,
    ];
    if !input.angle.trim().is_empty() {
        args.extend(["--angle".into(), input.angle.trim().into()]);
    }
    if !input.position.trim().is_empty() {
        args.extend(["--pos".into(), input.position.trim().into()]);
    }
    invoke_owned(args)?;
    Ok(())
}

fn save_pack_config(provider: &str, name: &str, payload_json: &str) -> Result<(), String> {
    let provider = provider.trim();
    if !matches!(
        provider,
        "local" | "wallhaven" | "reddit" | "unsplash" | "generic_json" | "static_url"
    ) {
        return Err(format!("Provider no soportado: {provider}"));
    }
    if name.trim().is_empty() {
        return Err("El nombre del pack es obligatorio".into());
    }
    let payload = serde_json::from_str::<Value>(payload_json)
        .map_err(|error| format!("Formulario de pack invalido: {error}"))?;
    let payload = payload
        .as_object()
        .ok_or_else(|| "El formulario del pack debe ser un objeto".to_owned())?;

    let packs = invoke(&["pack", "list"])?;
    let exists = packs
        .get("packs")
        .and_then(Value::as_object)
        .is_some_and(|packs| packs.contains_key(name));
    let mut args = vec![
        "pack".to_owned(),
        if exists { "update" } else { "add" }.to_owned(),
        name.trim().to_owned(),
        "--type".to_owned(),
        provider.to_owned(),
    ];
    append_pack_options(provider, payload, &mut args)?;
    invoke_owned(args)?;
    Ok(())
}

fn append_pack_options(
    provider: &str,
    payload: &Map<String, Value>,
    args: &mut Vec<String>,
) -> Result<(), String> {
    let fields: &[(&str, &str)] = match provider {
        "local" => &[("paths", "--paths")],
        "wallhaven" => &[
            ("apiKey", "--api-key"),
            ("apiKeyEnv", "--api-key-env"),
            ("keyword", "--keyword"),
            ("subthemes", "--subthemes"),
            ("categories", "--categories"),
            ("purity", "--purity"),
            ("allowSfw", "--allow-sfw"),
            ("allowSketchy", "--allow-sketchy"),
            ("allowNsfw", "--allow-nsfw"),
            ("categoryGeneral", "--category-general"),
            ("categoryAnime", "--category-anime"),
            ("categoryPeople", "--category-people"),
            ("ratios", "--ratios"),
            ("colors", "--colors"),
            ("atleast", "--atleast"),
            ("sorting", "--sorting"),
            ("aiArt", "--ai-art"),
            ("ttlSec", "--ttl-sec"),
        ],
        "reddit" => &[
            ("subreddits", "--subreddits"),
            ("subthemes", "--subthemes"),
            ("allowSfw", "--allow-sfw"),
            ("minWidth", "--min-width"),
            ("minHeight", "--min-height"),
            ("ratioW", "--ratio-w"),
            ("ratioH", "--ratio-h"),
            ("sort", "--sort"),
            ("time", "--time"),
            ("ttlSec", "--ttl-sec"),
        ],
        "unsplash" => &[
            ("apiKey", "--api-key"),
            ("apiKeyEnv", "--api-key-env"),
            ("query", "--query"),
            ("subthemes", "--subthemes"),
            ("topics", "--topics"),
            ("collections", "--collections"),
            ("username", "--username"),
            ("orientation", "--orientation"),
            ("contentFilter", "--content-filter"),
            ("imageWidth", "--image-width"),
            ("imageHeight", "--image-height"),
            ("imageFit", "--image-fit"),
            ("imageQuality", "--image-quality"),
            ("ttlSec", "--ttl-sec"),
        ],
        "generic_json" => &[
            ("endpoint", "--endpoint"),
            ("imagePath", "--image-path"),
            ("imagePrefix", "--image-prefix"),
            ("candidateLimit", "--candidate-limit"),
            ("postPath", "--post-path"),
            ("postPrefix", "--post-prefix"),
            ("authorNamePath", "--author-name-path"),
            ("authorUrlPath", "--author-url-path"),
            ("authorUrlPrefix", "--author-url-prefix"),
            ("domain", "--domain"),
            ("ttlSec", "--ttl-sec"),
        ],
        "static_url" => &[
            ("url", "--url"),
            ("urls", "--urls"),
            ("authorName", "--author-name"),
            ("authorUrl", "--author-url"),
            ("domain", "--domain"),
            ("postUrl", "--post-url"),
            ("differentImages", "--different-images"),
            ("count", "--count"),
            ("ttlSec", "--ttl-sec"),
        ],
        _ => return Err(format!("Provider no soportado: {provider}")),
    };

    for (field, option) in fields {
        let Some(value) = payload.get(*field) else {
            continue;
        };
        let Some(value) = option_text(value) else {
            continue;
        };
        args.extend([(*option).to_owned(), value]);
    }
    Ok(())
}

fn option_text(value: &Value) -> Option<String> {
    match value {
        Value::Null => None,
        Value::String(value) => {
            let value = value.trim();
            (!value.is_empty()).then(|| value.to_owned())
        }
        Value::Bool(value) => Some(value.to_string()),
        Value::Number(value) => Some(value.to_string()),
        Value::Array(values) => {
            let values = values
                .iter()
                .filter_map(Value::as_str)
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .collect::<Vec<_>>();
            (!values.is_empty()).then(|| values.join(","))
        }
        Value::Object(_) => None,
    }
}

fn invoke(args: &[&str]) -> Result<Value, String> {
    invoke_owned(args.iter().map(|value| (*value).to_owned()).collect())
}

fn invoke_owned(mut args: Vec<String>) -> Result<Value, String> {
    let runtime = RUNTIME
        .get()
        .ok_or_else(|| "Kitowall bridge runtime is not configured".to_owned())?;
    if runtime.local {
        args.push("--lc".into());
    }
    args.push("--contract-v1".into());
    let output = Command::new(&runtime.binary)
        .args(&args)
        .output()
        .map_err(|error| format!("No se pudo ejecutar Kitowall: {error}"))?;
    let envelope = serde_json::from_slice::<ContractEnvelope>(&output.stdout).map_err(|error| {
        format!(
            "Kitowall devolvio una respuesta invalida: {error}; {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )
    })?;
    envelope.validate("kitowall")?;
    if !output.status.success() || !envelope.ok {
        let error = envelope
            .error
            .map(|error| error.message)
            .unwrap_or_else(|| "Kitowall fallo sin detalle".into());
        return Err(error);
    }
    envelope
        .data
        .ok_or_else(|| "Kitowall no devolvio datos".to_owned())
}

fn invoke_compositor(args: &[&str]) -> Result<Value, String> {
    let runtime = RUNTIME
        .get()
        .ok_or_else(|| "Kitowall bridge runtime is not configured".to_owned())?;
    let mut arguments = args
        .iter()
        .map(|argument| (*argument).to_owned())
        .collect::<Vec<_>>();
    if runtime.local {
        arguments.push("--lc".into());
    }
    arguments.push("--contract-v1".into());
    let output = Command::new(&runtime.compositor)
        .args(&arguments)
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

fn release_live_output(output: &str) -> Result<(), String> {
    let runtime = RUNTIME
        .get()
        .ok_or_else(|| "Kitowall bridge runtime is not configured".to_owned())?;
    let Some(binary) = &runtime.kilivepaper else {
        return Ok(());
    };
    let result = Command::new(binary)
        .env("KILIVEPAPER_COMPOSITOR_BIN", &runtime.compositor)
        .args(["unset", "--monitor", output])
        .output()
        .map_err(|error| format!("No se pudo liberar Kilivepaper en {output}: {error}"))?;
    let envelope = serde_json::from_slice::<ContractEnvelope>(&result.stdout).map_err(|error| {
        format!(
            "Kilivepaper devolvio una respuesta invalida al liberar {output}: {error}; {}",
            String::from_utf8_lossy(&result.stderr).trim()
        )
    })?;
    envelope.validate("kilivepaper")?;
    if result.status.success() && envelope.ok {
        Ok(())
    } else {
        Err(envelope
            .error
            .map(|error| error.message)
            .unwrap_or_else(|| format!("Kilivepaper no pudo liberar el monitor {output}")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn converts_pack_values_to_cli_text() {
        assert_eq!(option_text(&serde_json::json!(true)), Some("true".into()));
        assert_eq!(
            option_text(&serde_json::json!(["one", "two"])),
            Some("one,two".into())
        );
        assert_eq!(option_text(&serde_json::json!("  ")), None);
    }

    #[test]
    fn maps_wallhaven_fields_to_current_cli_options() {
        let payload = serde_json::json!({
            "keyword": "sakura",
            "allowNsfw": false,
            "ratios": ["16x9"]
        });
        let mut args = Vec::new();
        append_pack_options("wallhaven", payload.as_object().unwrap(), &mut args).unwrap();
        assert_eq!(
            args,
            [
                "--keyword",
                "sakura",
                "--allow-nsfw",
                "false",
                "--ratios",
                "16x9"
            ]
        );
    }

    #[test]
    fn blank_credential_fields_do_not_clear_shared_provider_credentials() {
        let payload = serde_json::json!({
            "apiKey": "",
            "apiKeyEnv": "",
            "keyword": "landscape"
        });
        let mut args = Vec::new();
        append_pack_options("wallhaven", payload.as_object().unwrap(), &mut args).unwrap();

        assert_eq!(args, ["--keyword", "landscape"]);
    }

    #[test]
    fn builds_bounded_catalog_arguments_with_an_optional_pack() {
        assert_eq!(
            catalog_args(" sao ", -5, 500),
            [
                "wallpaper",
                "list",
                "--offset",
                "0",
                "--limit",
                "200",
                "--pack",
                "sao"
            ]
        );
        assert_eq!(
            catalog_args("", 20, 0),
            ["wallpaper", "list", "--offset", "20", "--limit", "1"]
        );
    }

    #[test]
    fn builds_rotate_now_arguments_with_an_optional_pack() {
        assert_eq!(rotate_now_args(" sao "), ["rotate-now", "--pack", "sao"]);
        assert_eq!(rotate_now_args(""), ["rotate-now"]);
    }

    #[test]
    fn maps_rotation_switch_to_the_public_mode_contract() {
        assert_eq!(rotation_mode_args(true), ["mode", "rotate"]);
        assert_eq!(rotation_mode_args(false), ["mode", "manual"]);
    }

    #[test]
    fn exposes_only_the_supported_rotation_intervals() {
        assert_eq!(ROTATION_INTERVALS, [300, 900, 1800, 3600]);
        assert_eq!(rotation_interval_label(300), "5 min");
        assert_eq!(rotation_interval_label(3600), "1 hora");
    }

    #[test]
    fn transition_selector_matches_the_kitowall_contract() {
        assert_eq!(
            TRANSITION_TYPES,
            [
                "simple", "fade", "left", "right", "top", "bottom", "wipe", "wave", "grow",
                "center", "outer", "any", "random"
            ]
        );
    }

    #[test]
    fn exposes_only_the_quick_transition_durations() {
        assert_eq!(TRANSITION_DURATIONS, [1, 2, 3, 4, 5]);
    }

    #[test]
    fn favorite_toggle_uses_the_catalog_reference() {
        assert_eq!(
            favorite_args("/walls/sao.jpg", true).unwrap(),
            ["favorite", "add", "/walls/sao.jpg"]
        );
        assert_eq!(
            favorite_args("/walls/sao.jpg", false).unwrap(),
            ["favorite", "remove", "/walls/sao.jpg"]
        );
        assert!(favorite_args(" ", true).is_err());
    }

    #[test]
    fn builds_dashboard_snapshot_arguments_with_an_optional_pack() {
        assert_eq!(
            dashboard_snapshot_args(" sao "),
            ["dashboard", "snapshot", "--pack", "sao"]
        );
        assert_eq!(dashboard_snapshot_args(""), ["dashboard", "snapshot"]);
    }

    #[test]
    fn watcher_uses_existing_directories_and_the_nearest_parent() {
        let root = std::env::temp_dir().join(format!("kiui-watch-target-{}", std::process::id()));
        std::fs::create_dir_all(&root).unwrap();
        assert_eq!(
            watch_target(&root),
            Some((root.clone(), RecursiveMode::Recursive))
        );
        assert_eq!(
            watch_target(&root.join("future/nested")),
            Some((root.clone(), RecursiveMode::NonRecursive))
        );
        std::fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn reads_normalized_monitor_names_from_the_outputs_contract() {
        assert_eq!(
            output_names(&serde_json::json!({"outputs": ["DP-1", "HDMI-A-1"]})).unwrap(),
            ["DP-1", "HDMI-A-1"]
        );
        assert!(output_names(&serde_json::json!({"outputs": []})).is_err());
    }

    #[test]
    fn builds_single_and_batch_wallpaper_application_arguments() {
        assert_eq!(
            wallpaper_apply_args("sao", "wall-1", "DP-1").unwrap(),
            [
                "wallpaper",
                "apply",
                "--pack",
                "sao",
                "--id",
                "wall-1",
                "--output",
                "DP-1"
            ]
        );
        assert_eq!(
            wallpaper_apply_batch_args("sao", "wall-1", &["DP-1".into(), "HDMI-A-1".into()])
                .unwrap(),
            [
                "wallpaper",
                "apply-batch",
                "--pack",
                "sao",
                "--map",
                "DP-1:wall-1,HDMI-A-1:wall-1"
            ]
        );
    }
}
