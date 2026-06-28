# Jarvis

Jarvis is a **Windows desktop app** that bootstraps the local **Galakrond**
development environment running in WSL2. Since **v2.0** it is a native
[Tauri](https://tauri.app) application (Rust backend + React frontend) that lives
in the system tray, replacing the previous PowerShell tray + WinForms solution.

From one window it boots the whole stack: WSL/Docker preflight, parallel
`git pull`, ordered Docker phases with health gating, then launches Windows
Terminal, VS Code, MongoDB Compass and Chrome - while a live dashboard tracks
each service's health.

![Jarvis](public/jarvis-icon.png)

## Features

- **Live dashboard** - every service shown as a card (online/offline, port,
  latency); click to open its URL, or restart it in place.
- **One-click boot** - "Demarrer l'environnement" runs the full sequence with a
  slide-in **progress panel** streaming command output line by line.
- **Per-service restart** - re-run a single Docker service from its card.
- **Text-to-speech** greeting on launch (Web Speech API).
- **System tray** - hide-to-tray on close, single-instance, **autostart at
  login** toggle (replaces the old `.vbs`).
- Branded cyan-orb icon across window, taskbar, tray and installer.

## Architecture

```
src/                 React 19 + TypeScript + Vite + Tailwind 4 frontend
  App.tsx              dashboard
  components/          ServiceCard, ProgressPanel
  hooks/               useOrchestration (listens to Tauri events)
  lib/                 api (invoke wrappers), tts
src-tauri/src/       Rust backend
  config.rs            loads/models jarvis.config.json
  health.rs            async TCP + HTTP service probes
  orchestrator.rs      boot sequence + per-service restart + log streaming
  launchers.rs         Terminal / VS Code / Compass / Chrome
  lib.rs               tray, single-instance, autostart, commands
jarvis.config.json   single source of truth (shared with legacy scripts)
```

The backend exposes four commands to the UI - `load_config`, `check_services`,
`start_environment`, `restart_service` - and streams progress as `orchestration`
events.

## Prerequisites

**To run the built app:** just install it (WebView2 ships with Windows 11).

**To develop / build from source:**

- [Node.js](https://nodejs.org) 18+ and npm
- [Rust](https://rustup.rs) (MSVC toolchain) + **Microsoft C++ Build Tools**
  (`winget install Microsoft.VisualStudio.2022.BuildTools` with the
  "Desktop development with C++" workload)
- WSL2 with a `Debian` distribution, Docker Desktop (WSL2 backend), and the
  Galakrond repo at `/home/admin/galakrond`
- For the launchers: Windows Terminal, `code` on PATH, Google Chrome, MongoDB
  Compass

## Development

```bash
npm install
npm run tauri dev      # hot-reloads both React and Rust
```

## Build installers

```bash
npm run tauri build
```

Produces, under `src-tauri/target/release/bundle/`:

- `nsis/Jarvis_<version>_x64-setup.exe` (NSIS installer)
- `msi/Jarvis_<version>_x64_en-US.msi` (MSI)

## Configuration - `jarvis.config.json`

All mutable values live here; both the Tauri app and the legacy scripts read it.

| Field | Purpose |
|-------|---------|
| `version` | App version (window header, tray tooltip) |
| `projectRoot` / `projectShare` | WSL path / Windows share of Galakrond |
| `gitPull` | `enabled` + explicit `repos` pulled in parallel before Docker |
| `dockerPhases` | Ordered startup phases (parallel/sequential + `waitHealthy`) |
| `services` | Dashboard cards: `port`, `url`, `healthUrl`, `dockerService` |
| `terminalTabs` | WSL terminal tabs |
| `chrome` | `userDataDir`, `profileDir`, `debugPort`, `extraUrls` |
| `paths` | `compass`, `vscode` |

`services[].dockerService` links a dashboard card (e.g. `api`) to the
`dockerPhases` service backing it (e.g. `onyxia`), enabling per-service restart.

## Docker phases

Services start in ordered phases, each parallel or sequential, with optional
health gating:

1. **infrastructure** (parallel): afkah (mongo), alexstrasza (redis), punjabi
2. **mail** (sequential): eudora, after afkah + alexstrasza are healthy
3. **api** (sequential): onyxia
4. **frontends** (parallel): xyrella, sylvanas, tess

A WSL/Docker preflight failure aborts the boot; individual service failures are
surfaced in the progress panel.

## Updating the app icon

The icon is generated from `jarvis-icon.png` (square, >=1024px):

```bash
npm run tauri -- icon jarvis-icon.png
cp src-tauri/icons/icon.ico jarvis.ico            # keep the tray in sync
cp src-tauri/icons/128x128@2x.png public/jarvis-icon.png   # header logo
```

## Legacy PowerShell launcher

The original PowerShell solution (`dev-setup.ps1`, `jarvis-tray.ps1`,
`jarvis-tray.vbs`, `dev-setup.bat`) is kept in the repo during the transition and
remains fully functional. It will be retired once the Tauri app is the daily
driver.
