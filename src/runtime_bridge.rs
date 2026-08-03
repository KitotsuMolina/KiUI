use std::sync::OnceLock;

#[derive(Debug, Clone, Copy, Default)]
struct RuntimeCapabilities {
    has_kitowall: bool,
    has_kilivepaper: bool,
    has_kitsune: bool,
}

static CAPABILITIES: OnceLock<RuntimeCapabilities> = OnceLock::new();

pub fn configure(
    has_kitowall: bool,
    has_kilivepaper: bool,
    has_kitsune: bool,
) -> Result<(), String> {
    CAPABILITIES
        .set(RuntimeCapabilities {
            has_kitowall,
            has_kilivepaper,
            has_kitsune,
        })
        .map_err(|_| "KiUI runtime capabilities were already configured".to_owned())
}

pub struct RuntimeBridgeRust {
    has_kitowall: bool,
    has_kilivepaper: bool,
    has_kitsune: bool,
}

impl Default for RuntimeBridgeRust {
    fn default() -> Self {
        let capabilities = CAPABILITIES.get().copied().unwrap_or_default();
        Self {
            has_kitowall: capabilities.has_kitowall,
            has_kilivepaper: capabilities.has_kilivepaper,
            has_kitsune: capabilities.has_kitsune,
        }
    }
}

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(bool, has_kitowall, cxx_name = "hasKitowall")]
        #[qproperty(bool, has_kilivepaper, cxx_name = "hasKilivepaper")]
        #[qproperty(bool, has_kitsune, cxx_name = "hasKitsune")]
        type RuntimeBridge = super::RuntimeBridgeRust;
    }
}
