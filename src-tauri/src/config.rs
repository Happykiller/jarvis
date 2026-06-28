//! Loads and models `jarvis.config.json` - the single source of truth shared
//! with the legacy PowerShell scripts. Only the fields Jarvis needs are typed;
//! unknown fields are ignored so the schema can evolve without breaking here.

use std::path::PathBuf;

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Config {
    pub version: String,
    pub project_root: String,
    #[serde(default)]
    pub project_share: Option<String>,
    #[serde(default)]
    pub git_pull: Option<GitPull>,
    #[serde(default)]
    pub docker_phases: Vec<DockerPhase>,
    #[serde(default)]
    pub services: Vec<ServiceDef>,
    #[serde(default)]
    pub chrome: Option<ChromeConfig>,
    #[serde(default)]
    pub terminal_tabs: Vec<TerminalTab>,
    #[serde(default)]
    pub paths: Option<Paths>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ChromeConfig {
    pub user_data_dir: String,
    #[serde(default)]
    pub profile_dir: Option<String>,
    #[serde(default)]
    pub debug_port: Option<u16>,
    #[serde(default)]
    pub extra_urls: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TerminalTab {
    pub title: String,
    pub command: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Paths {
    #[serde(default)]
    pub compass: Option<String>,
    #[serde(default)]
    pub vscode: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GitPull {
    pub enabled: bool,
    pub repos: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct DockerPhase {
    pub name: String,
    pub parallel: bool,
    #[serde(default)]
    pub wait_healthy: Vec<String>,
    #[serde(default)]
    pub health_timeout_seconds: Option<u64>,
    pub services: Vec<PhaseService>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PhaseService {
    pub name: String,
    pub path: String,
    pub command: String,
    #[serde(default)]
    pub network: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ServiceDef {
    pub name: String,
    pub port: u16,
    #[serde(default)]
    pub url: Option<String>,
    #[serde(default)]
    pub health_url: Option<String>,
    /// Name of the `dockerPhases` service backing this one, enabling restart.
    #[serde(default)]
    pub docker_service: Option<String>,
}

/// Locates a repo-root file by probing the obvious locations. In `tauri dev` the
/// working dir is `src-tauri`, so files sit one level up; in a bundled build
/// they live next to the exe (or one level up).
pub fn locate(filename: &str) -> Option<PathBuf> {
    let mut candidates: Vec<PathBuf> = Vec::new();

    if let Ok(cwd) = std::env::current_dir() {
        candidates.push(cwd.join(filename));
        candidates.push(cwd.join("..").join(filename));
    }
    if let Ok(exe) = std::env::current_exe() {
        if let Some(dir) = exe.parent() {
            candidates.push(dir.join(filename));
            candidates.push(dir.join("..").join(filename));
        }
    }

    candidates.into_iter().find(|p| p.exists())
}

/// Locates `jarvis.config.json`, honoring the `JARVIS_CONFIG` override.
pub fn locate_config() -> Option<PathBuf> {
    if let Ok(explicit) = std::env::var("JARVIS_CONFIG") {
        let p = PathBuf::from(explicit);
        if p.exists() {
            return Some(p);
        }
    }
    locate("jarvis.config.json")
}

/// Expands Windows-style `%VAR%` references using the process environment.
/// Unknown variables are left untouched.
pub fn expand_env(input: &str) -> String {
    let mut out = String::with_capacity(input.len());
    let mut rest = input;
    while let Some(start) = rest.find('%') {
        out.push_str(&rest[..start]);
        let after = &rest[start + 1..];
        if let Some(end) = after.find('%') {
            let name = &after[..end];
            match std::env::var(name) {
                Ok(val) => out.push_str(&val),
                Err(_) => {
                    out.push('%');
                    out.push_str(name);
                    out.push('%');
                }
            }
            rest = &after[end + 1..];
        } else {
            out.push_str(&rest[start..]);
            rest = "";
            break;
        }
    }
    out.push_str(rest);
    out
}

/// Reads and parses the config. Returns a human-readable error string suitable
/// for surfacing straight to the UI.
pub fn load() -> Result<Config, String> {
    let path = locate_config().ok_or_else(|| "jarvis.config.json not found".to_string())?;
    let raw = std::fs::read_to_string(&path)
        .map_err(|e| format!("failed to read {}: {e}", path.display()))?;
    serde_json::from_str(&raw).map_err(|e| format!("invalid jarvis.config.json: {e}"))
}
