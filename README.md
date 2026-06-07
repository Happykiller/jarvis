# Jarvis

Jarvis is a Windows tray launcher for bootstrapping the local Galakrond development environment running in WSL2.

It starts Docker services, opens terminal tabs, waits for local ports, launches VS Code and MongoDB Compass, then opens a dedicated Chrome session.

## What This Repository Contains

- `jarvis.config.json`: single source of truth for all configuration (version, paths, services, tabs)
- `jarvis-tray.ps1`: tray application with context menu
- `jarvis-tray.vbs`: hidden launcher for the tray app
- `dev-setup.ps1`: main setup script (`start` and `debug` modes)
- `dev-setup.bat`: batch wrapper that starts `dev-setup.ps1` in `start` mode
- `jarvis.ico`: tray icon
- `dev-setup.log`: execution log written by the setup script

## Managed Project

The launcher manages the Galakrond codebase located in WSL2:

- WSL path: `/home/admin/galakrond`
- Windows share: `\\wsl.localhost\Debian\home\admin\galakrond`
- Services: alexstrasza (api), afkah, onyxia, sylvanas, tess, xyrella, eudora (via punjabi infrastructure)

## Prerequisites

The machine is expected to have:

- Windows Terminal
- PowerShell 5.1+
- Google Chrome
- VS Code available through the `code` command
- MongoDB Compass at `%LOCALAPPDATA%\MongoDBCompass\MongoDBCompass.exe`
- WSL2 with a `Debian` distribution
- The Galakrond project checked out at `/home/admin/galakrond`
- Docker Desktop with WSL2 backend

## Configuration

All mutable values live in `jarvis.config.json`. Edit that file to change:

- `version`: launcher version (displayed in tray and log)
- `chrome.profileDir`: which Chrome profile to use (default: `Profile 10`)
- `chrome.extraUrls`: URLs opened on every start (Gmail, Jira, etc.)
- `dockerParallelServices` / `dockerSequentialServices`: Docker startup phases
- `services`: ports and health URLs that Jarvis waits for
- `terminalTabs`: WSL terminal tabs opened on start
- `paths.compass`: path to MongoDB Compass executable

## Launcher Version

Current version is read from `jarvis.config.json`. It is displayed in the tray tooltip and written to every log entry.

## Tray Menu

- **Jarvis vX.Y.Z** (disabled label)
- **Start**: launches the full workspace (Docker, terminal, VS Code, Compass, port wait, Chrome)
- **Debug Start**: same as Start but enables Chrome remote debugging and opens DevTools
- **Start (console)**: same as Start but keeps the PowerShell window visible for live log output
- **Open Log**: opens `dev-setup.log` in Notepad
- **Add To Windows Startup** / **Remove From Windows Startup**: toggles tray autostart
- **Quit Jarvis**: closes the tray application

Double-clicking the tray icon triggers **Start**.

## Setup Modes

`dev-setup.ps1` supports two modes:

- `start`: Docker preflight + parallel/sequential services + terminal tabs + VS Code + Compass + port wait + Chrome
- `debug`: same as `start`, but enables Chrome remote debugging and opens DevTools

## Docker Phases

**Phase 1 (parallel)**: punjabi, alexstrasza, afkah, onyxia, sylvanas, tess, xyrella start concurrently.

**Phase 2 (sequential)**: eudora starts after alexstrasza reports healthy (up to 60 s health timeout).

If the Docker phase fails (WSL unavailable, daemon not ready, or a service fails), Jarvis logs a warning and continues opening the terminal, VS Code, and Chrome. Only a complete Docker/WSL failure aborts the run.

## Command Examples

From Windows PowerShell:

```powershell
.\dev-setup.ps1 -Mode start
.\dev-setup.ps1 -Mode debug -ShowConsole
```

From Command Prompt:

```bat
dev-setup.bat
```

Optional flags:

- `-StartupTimeoutSeconds 180`: how long Jarvis waits for service ports
- `-ChromeDebugPort 9222`: Chrome remote debugging port
- `-ShowConsole`: prints setup progress in the PowerShell window
- `-SkipTerminal`: skips Windows Terminal launch
- `-SkipCode`: skips VS Code launch
- `-SkipChrome`: skips Chrome launch
- `-OpenDevTools`: opens DevTools in `start` mode

## Service Expectations

Jarvis waits for these local ports before opening Chrome:

- `3000`: api (onyxia)
- `5173`: frontoffice (tess)
- `5174`: backoffice (sylvanas)
- `5175`: showcase (xyrella)

If some ports do not come up before the timeout, Jarvis logs a warning and opens Chrome anyway. Only a zero-services situation is a hard failure.

## Chrome Session

Chrome opens with the real user profile (`%LOCALAPPDATA%\Google\Chrome\User Data`, profile `Profile 10`) and loads:

1. Gmail
2. bo.fitdesk.io
3. Jira board
4. Mailcatcher (localhost:1080)
5. frontoffice (localhost:5173)
6. backoffice (localhost:5174)
7. showcase (localhost:5175)

In debug mode, Chrome also exposes a remote debugging port (default 9222) and Jarvis opens DevTools for each tab.

## Logging

Every run appends entries to `dev-setup.log`. Open it from the tray menu (Open Log) or inspect it after a failed run. The log includes version, mode, Docker output, port wait status, and Chrome launch details.

## Concurrency Protection

Jarvis uses a named mutex (`Local\JarvisGalakrondSetup`) to prevent two setup runs from executing concurrently. If another instance is starting, the second run exits immediately.

## Troubleshooting

If the launcher does not behave as expected:

- use **Start (console)** from the tray to see live output
- open **Open Log** from the tray to inspect `dev-setup.log`
- verify that `wt`, `code`, and `chrome.exe` are available
- confirm the Galakrond repository exists at `/home/admin/galakrond`
- verify Docker Desktop is running and WSL2 integration is enabled
- check that the expected local ports are not blocked by another process

If Chrome opens but DevTools do not:

- try another debugging port with `-ChromeDebugPort`
- rerun in **Debug Start** mode with **Start (console)**
