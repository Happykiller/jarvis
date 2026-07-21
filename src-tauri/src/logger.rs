//! Persists orchestration events to rotating log files so past boots can be
//! reviewed inside the app (`list_logs` / `read_log` commands). Mirrors the old
//! PowerShell `logs/dev-setup-*.log` behavior: one file per run, newest 30 kept.
//!
//! A single global writer is opened by `start_session` (called at the top of a
//! boot or restart) and appended to by `write`, which is invoked from the
//! orchestrator's `emit` choke point so every streamed event is captured.

use std::fs::{self, File, OpenOptions};
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};

use chrono::Local;
use serde::Serialize;

/// How many log files to retain (older ones are deleted on each new session).
const KEEP: usize = 30;

static LOG_DIR: OnceLock<PathBuf> = OnceLock::new();
static CURRENT: OnceLock<Mutex<Option<File>>> = OnceLock::new();

fn current() -> &'static Mutex<Option<File>> {
    CURRENT.get_or_init(|| Mutex::new(None))
}

/// Metadata for one log file, surfaced to the UI log list.
#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct LogMeta {
    pub name: String,
    /// Last-modified time as epoch milliseconds (for locale formatting in JS).
    pub modified_ms: u64,
    pub size_bytes: u64,
}

/// Sets (once) the directory where log files live and ensures it exists.
pub fn set_dir(dir: PathBuf) {
    let _ = fs::create_dir_all(&dir);
    let _ = LOG_DIR.set(dir);
}

/// The configured log directory, if any.
pub fn dir() -> Option<PathBuf> {
    LOG_DIR.get().cloned()
}

/// Opens a fresh log file for a new boot/restart, rotating old ones out. Later
/// `write` calls append to it. No-op if the log dir was never set.
pub fn start_session(label: &str) {
    let Some(dir) = LOG_DIR.get() else { return };
    let _ = fs::create_dir_all(dir);
    rotate(dir);

    let now = Local::now();
    let path = dir.join(format!("jarvis-{}.log", now.format("%Y-%m-%d_%H-%M-%S")));
    if let Ok(mut f) = OpenOptions::new().create(true).append(true).open(&path) {
        let _ = writeln!(
            f,
            "==== Jarvis {} - {} ====",
            label,
            now.format("%Y-%m-%d %H:%M:%S")
        );
        let _ = f.flush();
        *current().lock().unwrap() = Some(f);
    }
}

/// Appends one event line to the current session file (if a session is open).
pub fn write(phase: &str, service: Option<&str>, status: &str, message: Option<&str>) {
    let mut guard = current().lock().unwrap();
    if let Some(f) = guard.as_mut() {
        let ts = Local::now().format("%H:%M:%S");
        let target = match service {
            Some(s) => format!("{phase} / {s}"),
            None => phase.to_string(),
        };
        let line = match message {
            Some(m) => format!("[{ts}] [{}] {target} - {m}", status.to_uppercase()),
            None => format!("[{ts}] [{}] {target}", status.to_uppercase()),
        };
        let _ = writeln!(f, "{line}");
        let _ = f.flush();
    }
}

/// Lists log files newest-first with their metadata.
pub fn list() -> Vec<LogMeta> {
    let Some(dir) = LOG_DIR.get() else { return Vec::new() };
    list_files(dir)
        .into_iter()
        .map(|f| LogMeta {
            name: f.name,
            modified_ms: f
                .modified
                .duration_since(std::time::UNIX_EPOCH)
                .map(|d| d.as_millis() as u64)
                .unwrap_or(0),
            size_bytes: f.size,
        })
        .collect()
}

/// Reads a log file by bare name. Rejects any path separators or `..` so the
/// caller can never escape the log directory.
pub fn read(name: &str) -> Result<String, String> {
    let Some(dir) = LOG_DIR.get() else {
        return Err("repertoire de logs non initialise".into());
    };
    if name.contains('/') || name.contains('\\') || name.contains("..") {
        return Err("nom de log invalide".into());
    }
    let path = dir.join(name);
    if path.extension().and_then(|x| x.to_str()) != Some("log") {
        return Err("ce n'est pas un fichier log".into());
    }
    fs::read_to_string(&path).map_err(|e| format!("lecture {name}: {e}"))
}

/// Deletes all but the newest `KEEP - 1` files so the about-to-be-created one
/// brings the total to `KEEP`.
fn rotate(dir: &Path) {
    let mut files = list_files(dir);
    if files.len() >= KEEP {
        for entry in files.split_off(KEEP - 1) {
            let _ = fs::remove_file(entry.path);
        }
    }
}

struct LogFileInfo {
    path: PathBuf,
    name: String,
    modified: std::time::SystemTime,
    size: u64,
}

/// All `*.log` files in `dir`, sorted newest-first by modified time.
fn list_files(dir: &Path) -> Vec<LogFileInfo> {
    let mut out: Vec<LogFileInfo> = Vec::new();
    if let Ok(rd) = fs::read_dir(dir) {
        for e in rd.flatten() {
            let path = e.path();
            if path.extension().and_then(|x| x.to_str()) != Some("log") {
                continue;
            }
            let Ok(meta) = e.metadata() else { continue };
            let Some(name) = path.file_name().map(|n| n.to_string_lossy().into_owned()) else {
                continue;
            };
            out.push(LogFileInfo {
                name,
                modified: meta.modified().unwrap_or(std::time::UNIX_EPOCH),
                size: meta.len(),
                path,
            });
        }
    }
    out.sort_by(|a, b| b.modified.cmp(&a.modified));
    out
}
