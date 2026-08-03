use std::env;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum RuntimeMode {
    Installed,
    Local,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CliPaths {
    pub kitowall: Option<PathBuf>,
    pub compositor: PathBuf,
    pub kitsune: Option<PathBuf>,
    pub kilivepaper: Option<PathBuf>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RuntimeContext {
    pub mode: RuntimeMode,
    pub clis: CliPaths,
}

impl RuntimeContext {
    pub fn from_process() -> Result<Self, String> {
        let local =
            cfg!(debug_assertions) || env::args().skip(1).any(|argument| argument == "--lc");
        if !local {
            let compositor = installed_binary("KIUI_COMPOSITOR_BIN", "kitsune-compositor")
                .ok_or_else(|| {
                    "kitsune-compositor is not installed or is not available in PATH".to_owned()
                })?;
            return Ok(Self {
                mode: RuntimeMode::Installed,
                clis: CliPaths {
                    kitowall: optional_installed_binary(
                        "KIUI_DISABLE_KITOWALL",
                        "KIUI_KITOWALL_BIN",
                        "kitowall",
                    ),
                    compositor,
                    kitsune: installed_binary("KIUI_KITSUNE_BIN", "kitsune"),
                    kilivepaper: optional_installed_binary(
                        "KIUI_DISABLE_KILIVEPAPER",
                        "KIUI_KILIVEPAPER_BIN",
                        "kilivepaper",
                    ),
                },
            });
        }

        let root = env::current_dir()
            .ok()
            .and_then(|path| find_refactor_root(&path))
            .or_else(|| {
                env::current_exe()
                    .ok()
                    .and_then(|path| find_refactor_root(&path))
            })
            .ok_or_else(|| "could not locate the local refactor workspace".to_owned())?;
        let preferred = active_profile();
        let compositor = local_binary(&root, "compositor", "kitsune-compositor", &preferred)
            .ok_or_else(|| local_build_hint("compositor", "kitsune-compositor"))?;

        Ok(Self {
            mode: RuntimeMode::Local,
            clis: CliPaths {
                kitowall: (!module_disabled("KIUI_DISABLE_KITOWALL"))
                    .then(|| local_binary(&root, "kitowall", "kitowall", &preferred))
                    .flatten(),
                compositor,
                kitsune: local_binary(&root, "kitsune", "kitsune", &preferred),
                kilivepaper: (!module_disabled("KIUI_DISABLE_KILIVEPAPER"))
                    .then(|| local_kilivepaper_binary(&root, &preferred))
                    .flatten(),
            },
        })
    }
}

fn optional_installed_binary(
    disable_variable: &str,
    path_variable: &str,
    binary: &str,
) -> Option<PathBuf> {
    (!module_disabled(disable_variable))
        .then(|| installed_binary(path_variable, binary))
        .flatten()
}

fn module_disabled(variable: &str) -> bool {
    env::var(variable).is_ok_and(|value| {
        matches!(
            value.trim().to_ascii_lowercase().as_str(),
            "1" | "true" | "yes" | "on"
        )
    })
}

fn installed_binary(variable: &str, binary: &str) -> Option<PathBuf> {
    if let Some(path) = env::var_os(variable).map(PathBuf::from) {
        return path.is_file().then_some(path);
    }
    env::var_os("PATH").and_then(|paths| {
        env::split_paths(&paths)
            .map(|directory| directory.join(binary))
            .find(|candidate| candidate.is_file())
    })
}

fn active_profile() -> String {
    env::current_exe()
        .ok()
        .and_then(|path| path.parent().map(Path::to_path_buf))
        .and_then(|path| path.file_name().map(|name| name.to_owned()))
        .and_then(|name| name.to_str().map(str::to_owned))
        .filter(|profile| matches!(profile.as_str(), "debug" | "release"))
        .unwrap_or_else(|| "debug".into())
}

fn local_binary(root: &Path, project: &str, binary: &str, preferred: &str) -> Option<PathBuf> {
    [preferred, "debug", "release"]
        .into_iter()
        .map(|profile| root.join(project).join("target").join(profile).join(binary))
        .find(|candidate| candidate.is_file())
}

fn local_kilivepaper_binary(root: &Path, preferred: &str) -> Option<PathBuf> {
    local_binary(root, "kilivepaper", "kilivepaper", preferred)
}

fn find_refactor_root(start: &Path) -> Option<PathBuf> {
    start.ancestors().find_map(|candidate| {
        (candidate.join("compositor/Cargo.toml").is_file()
            && candidate.join("kiui/Cargo.toml").is_file())
        .then(|| candidate.to_path_buf())
    })
}

fn local_build_hint(project: &str, binary: &str) -> String {
    format!(
        "local binary {binary} is missing; build it with `cargo build --manifest-path refactor/{project}/Cargo.toml`"
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    fn fixture() -> PathBuf {
        let nonce = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        let root = env::temp_dir().join(format!("kiui-local-runtime-{nonce}"));
        for project in ["kitowall", "compositor", "kiui"] {
            fs::create_dir_all(root.join(project)).unwrap();
            fs::write(root.join(project).join("Cargo.toml"), "[workspace]\n").unwrap();
        }
        root
    }

    #[test]
    fn finds_the_refactor_root_from_a_nested_target() {
        let root = fixture();
        let nested = root.join("kitowall/target/debug");
        fs::create_dir_all(&nested).unwrap();
        assert_eq!(find_refactor_root(&nested), Some(root.clone()));
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn prefers_the_requested_profile_and_falls_back_to_debug() {
        let root = fixture();
        let debug = root.join("compositor/target/debug/kitsune-compositor");
        fs::create_dir_all(debug.parent().unwrap()).unwrap();
        fs::write(&debug, "").unwrap();
        assert_eq!(
            local_binary(&root, "compositor", "kitsune-compositor", "release"),
            Some(debug)
        );
        fs::remove_dir_all(root).unwrap();
    }

    #[test]
    fn local_modules_are_optional_but_compositor_is_not() {
        let root = fixture();
        let compositor = root.join("compositor/target/debug/kitsune-compositor");
        fs::create_dir_all(compositor.parent().unwrap()).unwrap();
        fs::write(&compositor, "").unwrap();

        assert!(local_binary(&root, "kitowall", "kitowall", "debug").is_none());
        assert_eq!(
            local_binary(&root, "compositor", "kitsune-compositor", "debug"),
            Some(compositor)
        );
        fs::remove_dir_all(root).unwrap();
    }
}
