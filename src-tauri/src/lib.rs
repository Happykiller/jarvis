//! Jarvis - Tauri backend. Loads the shared `jarvis.config.json`, probes
//! service health, and lives in the system tray.

mod config;
mod health;
mod launchers;
mod orchestrator;

use std::path::PathBuf;

use tauri::{
    menu::{CheckMenuItem, Menu, MenuItem},
    tray::TrayIconBuilder,
    Manager, WindowEvent,
};
use tauri_plugin_autostart::{ManagerExt, MacosLauncher};

use config::Config;
use health::ServiceStatus;

/// Returns the parsed `jarvis.config.json`.
#[tauri::command]
async fn load_config() -> Result<Config, String> {
    config::load()
}

/// Probes every configured service and returns their live status.
#[tauri::command]
async fn check_services() -> Result<Vec<ServiceStatus>, String> {
    let cfg = config::load()?;
    Ok(health::probe_all(&cfg.services).await)
}

/// Boots the Galakrond environment (preflight, git pull, docker phases),
/// streaming progress as `orchestration` events.
#[tauri::command]
async fn start_environment(app: tauri::AppHandle) -> Result<(), String> {
    let cfg = config::load()?;
    orchestrator::run(app, cfg).await
}

/// Restarts a single service by re-running its backing docker service.
#[tauri::command]
async fn restart_service(app: tauri::AppHandle, name: String) -> Result<(), String> {
    let cfg = config::load()?;
    orchestrator::restart(app, &cfg, &name).await
}

/// Brings the main window to the foreground, creating focus from the tray.
fn show_main_window(app: &tauri::AppHandle) {
    if let Some(win) = app.get_webview_window("main") {
        let _ = win.show();
        let _ = win.unminimize();
        let _ = win.set_focus();
    }
}

/// Finds a sidecar asset (config, icon) in dev (repo root) or in an installed
/// build (Tauri resource dir, where `../foo` is mapped to `_up_/foo`).
fn locate_asset(app: &tauri::App, name: &str) -> Option<PathBuf> {
    if let Some(p) = config::locate(name) {
        return Some(p);
    }
    if let Ok(dir) = app.path().resource_dir() {
        for cand in [dir.join(name), dir.join("_up_").join(name)] {
            if cand.exists() {
                return Some(cand);
            }
        }
    }
    None
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        // Single-instance must be the first plugin registered: a second launch
        // focuses the running window instead of spawning a duplicate tray.
        .plugin(tauri_plugin_single_instance::init(|app, _args, _cwd| {
            show_main_window(app);
        }))
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_autostart::init(MacosLauncher::LaunchAgent, None))
        .setup(|app| {
            // Make the bundled config discoverable in an installed build.
            if config::locate_config().is_none() {
                if let Some(p) = locate_asset(app, "jarvis.config.json") {
                    std::env::set_var("JARVIS_CONFIG", p);
                }
            }

            // Brand the window/taskbar icon at runtime from jarvis.ico.
            if let (Some(win), Some(p)) =
                (app.get_webview_window("main"), locate_asset(app, "jarvis.ico"))
            {
                if let Ok(img) = tauri::image::Image::from_path(p) {
                    let _ = win.set_icon(img);
                }
            }

            let autostart_on = app.autolaunch().is_enabled().unwrap_or(false);

            let open_i = MenuItem::with_id(app, "open", "Ouvrir Jarvis", true, None::<&str>)?;
            let autostart_i = CheckMenuItem::with_id(
                app,
                "autostart",
                "Lancer au demarrage",
                true,
                autostart_on,
                None::<&str>,
            )?;
            let quit_i = MenuItem::with_id(app, "quit", "Quitter", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&open_i, &autostart_i, &quit_i])?;

            // Prefer the branded jarvis.ico; fall back to the bundled icon.
            let tray_icon = locate_asset(app, "jarvis.ico")
                .and_then(|p| tauri::image::Image::from_path(p).ok())
                .unwrap_or_else(|| app.default_window_icon().unwrap().clone());

            let autostart_item = autostart_i.clone();
            TrayIconBuilder::new()
                .icon(tray_icon)
                .tooltip("Jarvis - Galakrond launcher")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(move |app, event| match event.id.as_ref() {
                    "open" => show_main_window(app),
                    "autostart" => {
                        let mgr = app.autolaunch();
                        let enabled = mgr.is_enabled().unwrap_or(false);
                        let _ = if enabled { mgr.disable() } else { mgr.enable() };
                        let _ = autostart_item.set_checked(!enabled);
                    }
                    "quit" => app.exit(0),
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    use tauri::tray::{MouseButton, MouseButtonState, TrayIconEvent};
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        show_main_window(tray.app_handle());
                    }
                })
                .build(app)?;

            Ok(())
        })
        // Closing the window hides Jarvis to the tray instead of quitting.
        .on_window_event(|window, event| {
            if let WindowEvent::CloseRequested { api, .. } = event {
                let _ = window.hide();
                api.prevent_close();
            }
        })
        .invoke_handler(tauri::generate_handler![
            load_config,
            check_services,
            start_environment,
            restart_service
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
