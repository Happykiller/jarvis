//! Launches the Windows-side companion apps after the stack is up: Windows
//! Terminal tabs, VS Code, MongoDB Compass and Chrome. Faithful port of the
//! `Start-TerminalTabs` / `Start-CodeEditor` / `Start-MongoDBCompass` /
//! `Start-ChromeForServices` helpers. Each launch is best-effort and never
//! aborts the boot; results stream as `orchestration` events on phase "apps".

use std::os::windows::process::CommandExt;
use std::process::Command;

use tauri::AppHandle;

use crate::config::{self, Config};
use crate::orchestrator::emit;

const PHASE: &str = "apps";

/// WSL distro backing the project (Windows Terminal profile + VS Code remote).
const WSL_DISTRO: &str = "Debian";

/// Windows `CREATE_NO_WINDOW` - suppresses the console for helper spawns.
const CREATE_NO_WINDOW: u32 = 0x0800_0000;

const CHROME_CANDIDATES: [&str; 2] = [
    r"C:\Program Files\Google\Chrome\Application\chrome.exe",
    r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
];

/// Mirrors PS `New-WslCommand`: cd into the project then run the command,
/// dropping into an interactive shell afterwards so the tab stays open. An empty
/// command opens a plain shell in the project dir (the "free" tab).
fn wsl_command(project_root: &str, command: &str) -> String {
    if command.trim().is_empty() {
        format!("cd {project_root} && exec bash")
    } else {
        format!("cd {project_root} && {command} && exec bash || exec bash")
    }
}

fn ok(app: &AppHandle, name: &str) {
    emit(app, PHASE, Some(name), "ok", None);
}

fn warn(app: &AppHandle, name: &str, msg: String) {
    emit(app, PHASE, Some(name), "warn", Some(msg));
}

fn launch_terminal(app: &AppHandle, cfg: &Config) {
    if cfg.terminal_tabs.is_empty() {
        return;
    }

    let mut args: Vec<String> = vec!["--maximized".into()];
    for (i, tab) in cfg.terminal_tabs.iter().enumerate() {
        if i > 0 {
            args.push(";".into());
        }
        args.push("new-tab".into());
        args.push("--title".into());
        args.push(tab.title.clone());
        args.push("--profile".into());
        args.push(WSL_DISTRO.into());
        args.push("--".into());
        args.push("bash".into());
        args.push("-lic".into());
        args.push(wsl_command(&cfg.project_root, &tab.command));
    }

    match Command::new("wt").args(&args).spawn() {
        Ok(_) => ok(app, "Windows Terminal"),
        Err(e) => warn(app, "Windows Terminal", format!("echec: {e}")),
    }
}

fn launch_vscode(app: &AppHandle, cfg: &Config) {
    let code = cfg
        .paths
        .as_ref()
        .and_then(|p| p.vscode.clone())
        .unwrap_or_else(|| "code".into());

    // Open the project as a proper Remote-WSL workspace via its folder URI rather
    // than the `\\wsl.localhost` UNC share. The UNC path makes VS Code auto-reopen
    // in WSL and pop a separate `wsl.exe` console; the URI starts the server
    // headlessly instead.
    let folder_uri = format!("vscode-remote://wsl+{WSL_DISTRO}{}", cfg.project_root);

    // `code` is a .cmd shim, so it must be invoked through cmd.exe. CREATE_NO_WINDOW
    // suppresses the wrapper console that would otherwise flash/stay open.
    match Command::new("cmd")
        .args(["/c", code.as_str(), "--folder-uri", folder_uri.as_str()])
        .creation_flags(CREATE_NO_WINDOW)
        .spawn()
    {
        Ok(_) => ok(app, "VS Code"),
        Err(e) => warn(app, "VS Code", format!("echec: {e}")),
    }
}

fn launch_compass(app: &AppHandle, cfg: &Config) {
    let Some(raw) = cfg.paths.as_ref().and_then(|p| p.compass.clone()) else {
        return;
    };
    let path = config::expand_env(&raw);
    if !std::path::Path::new(&path).exists() {
        warn(app, "MongoDB Compass", format!("introuvable: {path}"));
        return;
    }
    match Command::new(&path).spawn() {
        Ok(_) => ok(app, "MongoDB Compass"),
        Err(e) => warn(app, "MongoDB Compass", format!("echec: {e}")),
    }
}

fn launch_chrome(app: &AppHandle, cfg: &Config) {
    let Some(chrome) = &cfg.chrome else {
        return;
    };
    let Some(exe) = CHROME_CANDIDATES.iter().find(|p| std::path::Path::new(p).exists()) else {
        warn(app, "Chrome", "chrome.exe introuvable".into());
        return;
    };

    let mut args: Vec<String> = vec![
        "--new-window".into(),
        "--start-maximized".into(),
        format!("--user-data-dir={}", config::expand_env(&chrome.user_data_dir)),
    ];
    if let Some(profile) = &chrome.profile_dir {
        args.push(format!("--profile-directory={profile}"));
    }

    // Extra URLs first, then every service that exposes a browsable URL.
    args.extend(chrome.extra_urls.iter().cloned());
    args.extend(cfg.services.iter().filter_map(|s| s.url.clone()));

    match Command::new(exe).args(&args).spawn() {
        Ok(_) => ok(app, "Chrome"),
        Err(e) => warn(app, "Chrome", format!("echec: {e}")),
    }
}

/// Launches every companion app. Best-effort: a failure on one is logged and the
/// rest still run.
pub fn launch_all(app: &AppHandle, cfg: &Config) {
    emit(app, PHASE, None, "started", Some("Lancement des applications".into()));
    launch_terminal(app, cfg);
    launch_vscode(app, cfg);
    launch_compass(app, cfg);
    launch_chrome(app, cfg);
    emit(app, PHASE, None, "ok", None);
}
