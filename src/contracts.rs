use std::path::PathBuf;

use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContractMeta {
    pub cli: String,
    pub cli_version: String,
    pub contract_version: String,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ContractError {
    pub code: String,
    pub message: String,
    #[serde(default)]
    pub hint: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct ContractEnvelope {
    pub schema_version: u8,
    pub ok: bool,
    pub command: String,
    #[serde(default)]
    pub data: Option<Value>,
    #[serde(default)]
    pub warnings: Vec<String>,
    #[serde(default)]
    pub error: Option<ContractError>,
    pub meta: ContractMeta,
}

impl ContractEnvelope {
    pub fn validate(&self, expected_cli: &str) -> Result<(), String> {
        if self.schema_version != 1 {
            return Err(format!(
                "unsupported schema version: {}",
                self.schema_version
            ));
        }
        if self.meta.contract_version != "1.0" {
            return Err(format!(
                "unsupported contract version: {}",
                self.meta.contract_version
            ));
        }
        if self.meta.cli != expected_cli {
            return Err(format!(
                "unexpected CLI: expected {expected_cli}, got {}",
                self.meta.cli
            ));
        }
        match (self.ok, self.data.is_some(), self.error.is_some()) {
            (true, true, false) | (false, false, true) => Ok(()),
            _ => Err("invalid success/error envelope shape".into()),
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct InstalledModule {
    pub product: String,
    pub executable: PathBuf,
    pub version: String,
    pub contract_version: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct InstallationManifest {
    #[serde(default)]
    pub modules: Vec<InstalledModule>,
}

impl InstallationManifest {
    pub fn module(&self, product: &str) -> Option<&InstalledModule> {
        self.modules.iter().find(|module| module.product == product)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn success() -> ContractEnvelope {
        ContractEnvelope {
            schema_version: 1,
            ok: true,
            command: "capabilities".into(),
            data: Some(serde_json::json!({"product": "kitowall"})),
            warnings: Vec::new(),
            error: None,
            meta: ContractMeta {
                cli: "kitowall".into(),
                cli_version: "0.1.0".into(),
                contract_version: "1.0".into(),
            },
        }
    }

    #[test]
    fn accepts_a_valid_product_envelope() {
        assert_eq!(success().validate("kitowall"), Ok(()));
    }

    #[test]
    fn rejects_mismatched_products_and_ambiguous_payloads() {
        assert!(success().validate("kilivepaper").is_err());
        let mut envelope = success();
        envelope.error = Some(ContractError {
            code: "INTERNAL".into(),
            message: "ambiguous".into(),
            hint: None,
        });
        assert!(envelope.validate("kitowall").is_err());
    }

    #[test]
    fn finds_only_explicitly_registered_modules() {
        let manifest = InstallationManifest {
            modules: vec![InstalledModule {
                product: "kitowall".into(),
                executable: "/usr/bin/kitowall".into(),
                version: "0.1.0".into(),
                contract_version: "1.0".into(),
            }],
        };
        assert!(manifest.module("kitowall").is_some());
        assert!(manifest.module("kilivepaper").is_none());
    }
}
