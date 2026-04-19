# Jarvis

Jarvis is a Windows tray launcher for bootstrapping the local DraftDream development environment running in WSL2.

It opens the expected terminal tabs, waits for local services, launches the editor, and can start a dedicated Chrome session for development and debugging.

## What This Repository Contains

- `jarvis-tray.ps1`: tray application with the context menu
- `jarvis-tray.vbs`: hidden launcher for the tray app
- `dev-setup.ps1`: main setup script with `bootstrap`, `start`, and `debug` modes
- `dev-setup.bat`: batch wrapper that starts `dev-setup.ps1` in `start` mode
- `jarvis.ico`: tray icon
- `dev-setup.log`: execution log written by the setup script

## Managed Project

The launcher manages the DraftDream codebase located in WSL2:

- WSL path: `/home/admin/DraftDream`
- Windows share: `\\wsl.localhost\Debian\home\admin\DraftDream`

## Prerequisites

The machine is expected to have:

- Windows Terminal
- PowerShell
- Google Chrome
- VS Code available through the `code` command
- WSL2 with a `Debian` distribution
- The DraftDream project checked out at `/home/admin/DraftDream`
- Node.js and project dependencies available in WSL

## Launcher Version

Current launcher version: `1.1.0`

The version is visible in the tray menu and in the setup log.

## Tray Menu

Jarvis exposes the following actions from the system tray:

- `Quick Start`: opens the standard development workspace
- `Debug Start`: starts the workspace and launches Chrome with remote debugging enabled
- `Bootstrap Deps`: opens install tabs that run `npx npm-check-updates --target minor -u` then `npm install` for the managed services
- `Debug Start With Console`: same as `Debug Start`, but keeps the PowerShell window visible
- `Add To Windows Startup` or `Remove From Windows Startup`: toggles tray autostart
- `Quit Jarvis`: closes the tray application

Double-clicking the tray icon triggers `Quick Start`.

## Setup Modes

`dev-setup.ps1` supports the following modes:

- `bootstrap`: opens service tabs that update minor dependency versions with `npm-check-updates`, then run `npm install`
- `start`: opens the normal dev tabs, waits for services, launches VS Code, then opens Chrome
- `debug`: same as `start`, but enables Chrome remote debugging and opens DevTools
- `full`: currently launches bootstrap tabs only and reminds the user to run `start` or `debug` afterward

## Command Examples

From Windows PowerShell:

```powershell
.\dev-setup.ps1 -Mode start
.\dev-setup.ps1 -Mode debug -ShowConsole
.\dev-setup.ps1 -Mode bootstrap -ShowConsole
```

From Command Prompt:

```bat
dev-setup.bat
```

Optional flags:

- `-StartupTimeoutSeconds 180`: controls how long Jarvis waits for service ports
- `-ChromeDebugPort 9222`: changes the Chrome remote debugging port
- `-ShowConsole`: prints setup progress in the PowerShell window
- `-SkipTerminal`: skips Windows Terminal launch
- `-SkipCode`: skips VS Code launch
- `-SkipChrome`: skips Chrome launch
- `-OpenDevTools`: opens DevTools when Chrome debugging is enabled, or when used with `start`

## Service Expectations

Jarvis waits for these local ports before opening Chrome:

- `3000`: API
- `5173`: frontoffice
- `5174`: backoffice
- `5175`: showcase

If those ports do not come up before the timeout, the script exits with an error and writes the failure to `dev-setup.log`.

## Chrome Debug Strategy

Debug mode uses a dedicated Chrome profile under `%TEMP%\jarvis-chrome-dev`.

This avoids:

- reusing a personal Chrome profile
- clashing with unrelated open Chrome windows
- sending DevTools shortcuts to the wrong browser session

When debug mode is active, Jarvis:

1. starts Chrome with `--remote-debugging-port`
2. waits for Chrome DevTools Protocol targets
3. finds the main window for the Chrome process it launched
4. activates each target tab and opens DevTools

## Logging

Every run appends entries to `dev-setup.log`.

The log includes:

- launcher version
- selected mode
- service wait status
- Chrome launch information
- setup failures and warnings

## Concurrency Protection

Jarvis uses a named mutex to prevent two setup runs from executing at the same time.

If another instance is already starting the environment, the second run exits early and logs a warning.

## Troubleshooting

If the launcher does not behave as expected:

- use `Debug Start With Console` first
- inspect `dev-setup.log`
- verify that `wt`, `code`, and `chrome.exe` are available on the machine
- confirm the DraftDream repository exists at `/home/admin/DraftDream`
- verify that the expected local ports are not blocked by another process

If Chrome opens but DevTools do not:

- try another debugging port with `-ChromeDebugPort`
- close stale development Chrome windows using the temporary profile
- rerun the setup in `debug` mode with `-ShowConsole`

## Notes

- Jarvis updates managed service dependencies only in `bootstrap` mode, not in the normal `start` flow.
- `bootstrap` applies minor version updates with `npm-check-updates` before reinstalling packages.
- The repository intentionally focuses on the Windows launcher, not the DraftDream application source code itself.
