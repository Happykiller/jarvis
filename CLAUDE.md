# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Is Jarvis?

Jarvis is a **Windows automation launcher** (PowerShell + VBS) that bootstraps the entire **Galakrond** development environment. It runs as a system tray application and automates the complex setup of a multi-service fitness coaching SaaS platform running in WSL2.

The actual product codebase lives in WSL2 at `/home/admin/galakrond`.

## Migration in progress: Tauri app (branch `feat/tauri-app`)

Jarvis is being rebuilt as a **Tauri 2 + React 19 + Tailwind 4** desktop app to
replace the PowerShell tray + WinForms status window. The legacy `.ps1` files
still work and stay until the port is complete.

- **Frontend** `src/` - React dashboard (Tailwind 4 via `@tailwindcss/vite`,
  Framer Motion). `src/lib/api.ts` wraps Tauri `invoke`; `src/lib/tts.ts` is the
  Web Speech greeting; `src/types.ts` mirrors the Rust structs (camelCase).
- **Backend** `src-tauri/src/` - `config.rs` (reads the SAME
  `jarvis.config.json`, serde `rename_all = "camelCase"`), `health.rs` (async
  TCP + HTTP probes, ports the `Test-Port`/`Test-HealthUrl` rules), `lib.rs`
  (tray, single-instance plugin, `load_config` + `check_services` commands).
- **Dev**: `npm install` then `npm run tauri dev`. Cargo must be on PATH
  (`$env:USERPROFILE\.cargo\bin`). Prereqs: Rust (rustup) + MSVC C++ Build Tools
  (`winget install Microsoft.VisualStudio.2022.BuildTools` with the VCTools
  workload) + WebView2 (present on Win11).

### Tauri/Windows gotchas found
- `jarvis.config.json` is located by probing CWD, CWD/.., exe dir, exe/.. (in
  `tauri dev` the CWD is `src-tauri`, so it sits one level up). It is bundled as
  a Tauri `resources` entry for release builds.
- ServiceStatus/Config Rust structs need `#[serde(rename_all = "camelCase")]` or
  the React types (`latencyMs`, `healthUrl`) won't match.
- `reqwest::Client` has no `Default` impl - build with
  `.unwrap_or_else(|_| reqwest::Client::new())`.
- Window close is overridden to hide-to-tray (`WindowEvent::CloseRequested` +
  `api.prevent_close()`); quit only via the tray menu.
- `start_environment` (orchestrator.rs) ports the PS boot 1:1: preflight,
  parallel `git pull --ff-only` with failure classification, ordered
  `dockerPhases` (parallel `join_all` / sequential, `waitHealthy` via
  `docker inspect`). It streams an `orchestration` Tauri event per step
  (`{ phase, service, status, message }`); the React `useOrchestration` hook +
  `ProgressPanel` render the live timeline. WSL calls go through
  `run_cmd("wsl", ["bash","-c", script])` - don't name a private helper `run`
  (collides with the public `orchestrator::run` entry point).
- Phase failure is per-phase: a phase with `"optional": true` (mail, api,
  frontends in the config) logs a WARN and the boot continues to the next phase
  (degraded start - apps still launch, `done` event is `warn` listing the failed
  phases). Only a non-optional prerequisite phase (infrastructure) aborts the
  boot via `Err`. This stops one broken service (or a slow first-run image
  build) from taking the whole environment down. To make a new phase blocking,
  omit `optional` (defaults false).
- Per-SERVICE optional (v2.2.1+): a `PhaseService` can also carry
  `"optional": true` (punjabi/mailcatcher has it). In `run_phase` an optional
  service that fails only WARNs; it never fails its phase - even inside the
  otherwise-blocking `infrastructure` phase. This is how mailcatcher sits next
  to the hard deps (afkah mongo, alexstrasza redis) without its failure aborting
  the boot. Use it for non-critical members of a fatal phase; use phase-level
  `optional` when the whole phase is non-critical.
- Codename->make-target drift: service Makefiles change targets out from under
  the config. punjabi's `make up` became `make start` (targets now: start/stop/
  restart/logs/status; `make start` does `docker run -d --rm --name mailcatcher
  ...`). Symptom in logs: `make: *** No rule to make target 'up'. Stop.` +
  `exit 2`. When a service's docker command fails with a make error, check the
  repo's current Makefile targets, don't assume the config command is right.
- Build feedback: `run_streaming`'s pump watches streamed lines for docker
  BuildKit markers (`is_build_line`: `[+] Building`, `load build definition`,
  `=> [`, `exporting to image`) and emits a one-shot `info` ("Build de l'image
  en cours...") the first time one appears, shared across stdout+stderr via an
  `Arc<AtomicBool>`. This is why a first boot after a compose gains a `build:`
  (e.g. eudora's dropped `docker-compose.dev.yml`, merged Jul 2026) shows
  "building" instead of looking frozen while `docker compose up` blocks on a
  multi-GB image build.
- After the docker phases and BEFORE `launchers::launch_all`, `run()` calls
  `wait_for_services_ready` (phase `"services"`): it polls `health::probe_all`
  every 1s until every browsable service (those with a `url`) answers, or a 120s
  deadline. Non-fatal like the PS `Wait-ForPorts` - on timeout it warns and
  launches the apps anyway. This gate is what stops Chrome opening 5173/5174/5175
  before Vite/NestJS are HTTP-ready (a `make dev-up` returning != listening).
- `tauri dev` hot-reloads Rust edits (rebuild + relaunch the window). An empty
  dev-output log usually means a rebuild is mid-flight; a manual `cargo check`
  will print "Blocking waiting for file lock" while dev holds the build lock.
- `launchers.rs` runs at the end of the boot (best-effort, phase "apps"):
  Windows Terminal tabs (`wt`), VS Code, MongoDB Compass, Chrome (profile +
  extraUrls + service URLs). `config::expand_env` resolves `%VAR%`. All tabs in
  `terminalTabs` are joined with `;` into ONE `wt` call => one window, N tabs; a
  tab with an empty `command` opens a plain shell in `projectRoot` (the "free"
  tab). The WSL distro is the `WSL_DISTRO` const (`Debian`). `terminalTabs: []`
  disables the terminal entirely (`launch_terminal` early-returns on empty, no
  `wt` spawned) - the intended way to stop launching the Claude/free tabs (v2.3.2).
- Chrome tabs are deduped (v2.3.2): `launch_chrome` chains `extraUrls` + service
  `url`s through a `HashSet` (first occurrence wins, order preserved), so listing
  a service url in `extraUrls` too (mailcatcher's `localhost:1080` used to be in
  both) no longer opens the tab twice. Put a browsable service's url ONLY in its
  `services` entry, not also in `extraUrls`.
- VS Code launch gotcha: `code` is a .cmd shim so it MUST go through `cmd /c`
  (can't `Command::new("code")`), but that cmd wrapper pops a console window - so
  spawn it with `.creation_flags(CREATE_NO_WINDOW)` (0x08000000, needs
  `use std::os::windows::process::CommandExt`). AND open the project via its
  Remote-WSL folder URI (`--folder-uri vscode-remote://wsl+Debian<projectRoot>`),
  NOT the `\\wsl.localhost\...` UNC share: the UNC path makes VS Code auto-reopen
  in WSL and spawn a SECOND stray `wsl.exe` console. URI => headless server, no
  extra window. (`project_share` is now unused by launchers but kept in config.)
- Tray icon loads `jarvis.ico` via `Image::from_path` (tauri feature
  `image-ico`), located by `locate_asset` (dev: repo root via `config::locate`;
  installed: `resource_dir()`, where a bundled `../foo` lands in `_up_/foo`).
  Falls back to the bundled icon. Branding all bundle icons needs a 1024x1024
  PNG source for `tauri icon`.
- App icon (v2.0.0+): source is `jarvis-icon.png` (1254x1254 cyan orb). Regenerate
  all icons with `npm run tauri -- icon jarvis-icon.png` (fills `src-tauri/icons/`).
  Then copy `src-tauri/icons/icon.ico` -> root `jarvis.ico` so the tray matches,
  and `src-tauri/icons/128x128@2x.png` -> `public/jarvis-icon.png` for the header.
  The window/taskbar icon is also set at runtime in `setup()` via
  `win.set_icon(Image::from_path(jarvis.ico))`, so it updates without a rebuild;
  the embedded exe/installer icon updates on the next `tauri build`.
- Autostart-at-login uses `tauri-plugin-autostart` (trait
  `tauri_plugin_autostart::ManagerExt` -> `app.autolaunch()`), toggled by a tray
  `CheckMenuItem` "Lancer au demarrage". Replaces the old `jarvis-tray.vbs`
  startup hack. Rust-side calls need no capability entry (only JS invoke does).
- Bundled sidecars: `jarvis.config.json` + `jarvis.ico` are listed under
  `bundle.resources`; in an installed build `config::load` finds the config via
  `JARVIS_CONFIG`, set in `setup()` from `locate_asset`. Build the installer with
  `npm run tauri build` (MSI via WiX + NSIS .exe, both auto-downloaded).
- Per-service restart: each dashboard `services` entry has a `dockerService`
  field linking it to its `dockerPhases` service (api->onyxia, backoffice->
  sylvanas, frontoffice->tess, showcase->xyrella). `restart_service(name)`
  re-runs that service's command; the `ServiceCard` shows a restart button only
  when `dockerService` is set.
- Real-time logs: `orchestrator::run_streaming` spawns wsl with piped
  stdout/stderr (tokio `io-util`) and emits one `orchestration` event per line
  with `status: "log"`; `ProgressPanel` renders those as dim monospace lines.
  Used by `start_service` (boot + restart). git pull stays captured (needs the
  full output to classify failures).
- Autostart internals: the tray toggle calls `auto-launch` (v0.5.0, via plugin
  2.5.1), which writes TWO HKCU entries - a String value under
  `...\CurrentVersion\Run` named after `package_info().name` (= productName
  `Jarvis`), data `"<exe> "` (format `"{} {}"` with empty args -> trailing
  space); AND a REG_BINARY under `...\Explorer\StartupApproved\Run` (same name)
  with the 12-byte enabled marker (last 8 bytes zero). `is_enabled()` requires
  BOTH (Run value exists AND StartupApproved last-8-bytes are zero). Installed
  exe lives at `%LOCALAPPDATA%\Jarvis\jarvis.exe`.
- The OLD launcher's autostart was a Startup-folder shortcut
  `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\Jarvis.lnk` ->
  `wscript.exe jarvis-tray.vbs` (NOT a registry Run key). Removing it is the
  clean way to stop the legacy tray at login; sweep scheduled tasks + all
  Run/RunOnce keys to confirm no other remnants.
- Claude Code's auto-mode classifier BLOCKS direct registry Run writes as
  "unauthorized persistence" even when the user asked for it. To enable
  autostart, launch the installed app and click the tray "Lancer au demarrage"
  toggle (the intended path) rather than scripting the registry.
- "No tray icon" is usually NOT an app bug. The `TrayIconBuilder::build(app)?`
  in `lib.rs` setup() returns `?`, so if the icon failed to create the process
  would exit. If `jarvis.exe` is running (check `Get-Process jarvis`), the tray
  icon IS registered - Win11 just hides new icons in the overflow (`^` chevron).
  Fix: Settings > Personalization > Taskbar > "Other system tray icons" > toggle
  Jarvis on (or drag it out of the overflow). Only if it's absent from the
  overflow too is the systray cache corrupt (restart explorer.exe to refresh).
  Diagnose order: process alive? -> HKCU Run\Jarvis + StartupApproved last-8-zero
  (autostart on?) -> then it's a Windows visibility setting, not code.
- Persisted logs (v2.2.0+): `logger.rs` writes every orchestration event to a
  rotating file (last 30) under `app_log_dir()`
  (`%LOCALAPPDATA%\net.happykiller.jarvis\logs` installed). A global
  `Mutex<Option<File>>` is opened by `logger::start_session(label)` at the top of
  `orchestrator::run` ("boot") and `restart` ("restart <svc>"), and appended by
  `logger::write`, called from the `emit` choke point so EVERY streamed event
  (incl. `log` lines) is captured. `set_dir` is called once in `setup()`.
  Commands `list_logs` / `read_log(name)` / `open_logs_dir` back the in-app
  viewer (`LogsPanel.tsx`, opened by the header "Logs" button): runs list left,
  colored monospace content right. `read_log` rejects names with `/ \ ..` to stay
  inside the log dir. `open_logs_dir` uses the opener plugin from Rust (no JS
  capability needed). Needs `chrono` (clock+std) for timestamps.
- Version bump: the version really lives in SIX spots that must stay in sync -
  the 4 source-of-truth files (`package.json`, `src-tauri/Cargo.toml`,
  `src-tauri/tauri.conf.json`, `jarvis.config.json`) PLUS the two lockfiles:
  `src-tauri/Cargo.lock` (the `[[package]] name = "jarvis"` entry) and
  `package-lock.json` (TWO occurrences at the top: root `version` + the `""`
  package). The lockfiles do NOT self-update on a plain `npm run tauri build`, and
  `package-lock.json` in particular keeps drifting stale (seen at 1.7.1 then 2.1.0
  while the app was 2.3.x) - edit all six by hand. The installed app bundles its
  OWN `jarvis.config.json` + binary, so source/config edits only take effect after
  a rebuild+reinstall (or `npm run tauri dev`, which reads the repo config live).
- Dependency upgrades (done Jul 2026, v2.3.3): safe "stability" bumps = `npm update`
  (in-range patches/minors) + `cargo update` (rewrites Cargo.lock to latest
  semver-compatible, ~93 crates, no manifest edit). `cargo-outdated` is NOT
  installed - use `cargo update --dry-run` to preview. Majors taken: vite 7->8,
  @vitejs/plugin-react 4->6, framer-motion 11->12 (package `framer-motion` still
  publishes v12, `from "framer-motion"` imports unchanged - no code churn). Held
  back: TypeScript (5.8, NOT 7 - TS7 is the new native/Go compiler, too fresh for a
  stability pass). Always `npm run tauri build` after to confirm Vite + crates still
  compile before shipping.
- Roadmap: Phases 1-3 DONE (scaffold, orchestration, launchers, tray, autostart,
  installer, per-service restart, live logs). Remaining: retire the
  `.ps1`/`.vbs`/`.bat` scripts once the Tauri app is the daily driver.

## Jarvis Files

| File | Purpose |
|------|---------|
| `jarvis.config.json` | Single source of truth: version, paths, services, Chrome settings, tabs |
| `jarvis-tray.ps1` | System tray app with context menu (main entry point) |
| `jarvis-tray.vbs` | VBS wrapper for hidden (no console) execution |
| `dev-setup.ps1` | Orchestration script: Docker phases, terminal tabs, VS Code, Compass, port wait, Chrome |
| `dev-setup.bat` | Batch wrapper for PowerShell execution policy bypass |
| `jarvis.ico` | System tray icon |

## What dev-setup.ps1 Does

1. Loads `jarvis.config.json` (single source of truth for all config)
2. Detects screen dimensions
3. Pulls every git repo (`gitPull.repos`) in parallel with `git pull --ff-only` before Docker starts (non-fatal: failures are logged as WARN; skip with `-SkipGitPull`)
4. Runs Docker in ordered phases (`dockerPhases`), each phase parallel or sequential, with optional health gating between phases:
   - `infrastructure` (parallel): afkah (mongo), alexstrasza (redis), punjabi (mailcatcher)
   - `mail` (sequential, waits afkah + alexstrasza healthy): eudora
   - `api` (sequential): onyxia
   - `frontends` (parallel): xyrella, sylvanas, tess
4. Launches Windows Terminal with 4 tabs: codex, Claude, agy, sandbox
6. Launches VS Code on the project share
7. Launches MongoDB Compass
8. Shows a live status window (bottom-right) monitoring 4 ports until services are ready
9. Launches Chrome with Gmail, bo.fitdesk.io, Jira board, Mailcatcher, and the 3 dev servers

## Configuration — jarvis.config.json

**All mutable values belong in `jarvis.config.json`.** Never hardcode version, paths, Chrome profile, service lists, or port numbers directly in `.ps1` files. Both `dev-setup.ps1` and `jarvis-tray.ps1` read this file at startup.

Key fields: `version`, `projectRoot`, `projectShare`, `gitPull` (enabled, repos), `chrome` (userDataDir, profileDir, debugPort, extraUrls), `dockerPhases`, `services` (name/port/url/healthUrl), `terminalTabs`, `paths` (compass, vscode).

**`gitPull` — repos pulled at startup.** `enabled` toggles the phase; `repos` is the explicit list of WSL repo paths pulled in parallel (`git pull --ff-only`) before Docker. The list is explicit (not derived from `dockerPhases`) because it also includes the `galakrond` root repo, which has no service entry. Failures (dirty tree, diverged branch, no upstream) are logged as WARN and never block startup.

**`dockerPhases` — ordered startup.** An array of phases run in order. Each phase has: `name`, `parallel` (true = Start-Job fan-out, false = one-by-one), `services` (each `name`/`path`/`command`/`network`, plus optional per-service `optional`) and optional `waitHealthy` (array of container names to block on via `docker inspect` health) + `healthTimeoutSeconds` + phase-level `optional`. Order: infrastructure -> mail -> api -> frontends. To reorder or add a service, edit only this array.

**Two DISTINCT lists — `dockerPhases` (start) vs `services` (display).** These are
independent and easy to confuse. `dockerPhases` is what to BOOT (8 services).
`services` is what the dashboard shows and health-probes — the Tauri UI renders
one `ServiceCard` per `services` entry (via `check_services` ->
`health::probe_all(cfg.services)`), NOT per docker service. A container started
by `dockerPhases` but absent from `services` runs invisibly. As of v2.3.0
`services` lists all 8 (4 apps + mongo/redis/mailcatcher/eudora). Each entry:
`name`, `port`, `url` (clickable + joins the pre-launch `wait_for_services_ready`
gate), `healthUrl`, optional `container`, `dockerService` (restart target).
Probe priority in `health.rs`: `healthUrl` (HTTP, any status = up) ->
`container` (`docker inspect --format {{.State.Running}}` via `wsl`; args passed
straight to wsl so the braces need no quoting) -> TCP `port`. eudora is probed
via HTTP on 8025 (eudora-dev exposes `0.0.0.0:8025->8000`; GET / = 404 which
still proves it listens) - NOT the container-state fallback. `container` stays
as a general escape hatch for any genuinely port-less container (`port: 0` +
card shows "docker" instead of `:0`); nothing uses it right now. Infra ports
(27017/6379/1080/8025) are reachable from the Windows side via WSL2 localhost
forwarding, so the probes work from the app. Gotcha that bit us: check a
container's ACTUAL `docker ps` Ports column before assuming it's port-less -
eudora-dev's 8025 was there all along.

## PowerShell Rules

**Always use ASCII-only strings in `.ps1` files.**
PowerShell 5.1 (Windows default) reads scripts as Windows-1252 unless the file has a UTF-16 LE BOM. Non-ASCII characters (em dashes, accented letters, etc.) cause silent parse errors: the script crashes instantly with a flashing CMD window and no error message visible.

- Use `-` instead of an em dash
- Avoid accented letters in string literals and comments
- Comments must be in ASCII English (not French with accents)
- After every edit to a `.ps1` file, validate syntax before committing:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('.\dev-setup.ps1', [ref]$null, [ref]$errors) | Out-Null
"Errors: $($errors.Count)"
$errors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }
```

## PowerShell Pitfalls (Jarvis-specific)

**Mutex pattern — always use `initiallyOwned=$false` + `WaitOne(0)`:**
```powershell
$mutex = New-Object System.Threading.Mutex($false, "Local\MyMutex")
try { $acquired = $mutex.WaitOne(0) } catch [System.Threading.AbandonedMutexException] { $acquired = $true }
```
Using `initiallyOwned=$true` can throw `AbandonedMutexException` on the *next* run after a crash.

**Test-Port must call `EndConnect` — `WaitOne` alone gives false positives:**
A refused connection signals the wait handle almost instantly (elapsed ~0ms). Without `EndConnect`, the port appears open even when it is closed.
```powershell
if (-not $async.AsyncWaitHandle.WaitOne(1000, $false)) { return $false }
try { $tcp.EndConnect($async); return $true } catch { return $false }
```

**Service readiness — an open TCP port is NOT an HTTP-ready service:**
NestJS binds `:3000` before its modules finish loading; Vite accepts connections while still compiling. Gating Chrome on `Test-Port` alone launches it too early. Use the service's `healthUrl` with an actual HTTP GET (`Test-HealthUrl`) and treat ANY HTTP response as ready - even 4xx/5xx (e.g. GET /graphql returns 400 but proves NestJS is listening). Only a refused/timed-out connection means "not ready". `Wait-ForPorts` falls back to `Test-Port` when a service has no `healthUrl`.

**Start-Job failure detection — check `$LASTEXITCODE`, not just `job.State`:**
A `wsl`/`make` command that fails leaves `job.State = Completed`. Throw inside the scriptblock to force `State = Failed`:
```powershell
$out = (wsl bash -c "cd '$path' && $cmd 2>&1" | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw "exit $LASTEXITCODE : $out" }
```

**`ErrorActionPreference = Stop` + early phase failure = everything aborts:**
Wrap each phase (`Start-DockerServices`, etc.) in its own `try/catch`. Terminal, VS Code, and Chrome do not depend on Docker being healthy.

**WinForms modal (`ShowDialog`) — every exit branch must call `$form.Close()`:**
If the timer's timeout branch does not call `$form.Close()`, `ShowDialog()` blocks forever. The user must manually close the window.

**`"$var:"` in a string is parsed as a scope qualifier:**
A colon immediately after a variable in a double-quoted string (e.g. `"$name: healthy"`) makes PowerShell read `$name:` as a drive/scope reference (like `$env:PATH`), causing a parse error. Always delimit: `"${name}: healthy"`. (`"$($expr):"` is fine because of the `$(...)`.)

**JSON port numbers and hashtable key types:**
`ConvertFrom-Json` may return port numbers as `Int64`. PowerShell hashtable key lookups use `GetHashCode()`, so `Int32(3000) != Int64(3000)`. Always cast: `$portNames[[int]$svc.Port] = $svc.Name`.

**WSL/Docker preflight on Windows startup:**
If Jarvis runs at login, WSL and the Docker daemon may not be ready. Run `wsl -e true` then retry `docker info` (5x, 2s) before launching services.

**Docker compose `entrypoint` overrides the Dockerfile CMD:**
Setting `entrypoint:` in docker-compose.yml without `command:` **nullifies the Dockerfile CMD**. The entrypoint runs, reaches `exec "$@"` with empty args, and exits 0 silently. Always pair a custom entrypoint with an explicit `command:` in the compose file.
```yaml
entrypoint: ["sh", "/app/entrypoint.dev.sh"]
command: ["npm", "run", "dev"]   # required — without this, CMD from Dockerfile is erased
```
Symptom: container exits with code 0 immediately after startup tasks (npm install, etc.) with no error.

## Log Rotation

Logs are written to `logs/dev-setup-YYYY-MM-DD_HH-mm-ss.log` (one file per run). The last 30 files are kept; older ones are deleted automatically. The tray "Open Log" menu item opens the most recent file in the `logs/` directory.

## Galakrond Platform (the managed project)

**Location**: `/home/admin/galakrond` (WSL2)
**Windows share**: `\\wsl.localhost\Debian\home\admin\galakrond`

### Service Codenames

| Codename | Role | Dev port |
|----------|------|----------|
| onyxia | API (NestJS + GraphQL) | 3000 |
| sylvanas | Backoffice (React + Vite) | 5174 |
| tess | Frontoffice (React + Vite) | 5173 |
| xyrella | Showcase (React + Vite) | 5175 |
| alexstrasza | Core infrastructure | — |
| afkah | Auxiliary service | — |
| eudora | Background workers (depends on alexstrasza) | — |
| punjabi | Shared infrastructure (`/home/admin/punjabi`) | — |

### Stack
- **API (onyxia)**: NestJS 11 + Fastify + Mercurius (GraphQL) + MongoDB 7 — hexagonal architecture with Inversify DI
- **Frontoffice / Backoffice / Showcase**: React 19 + Vite 8 + TypeScript 5.9.3 + Material UI 7 + Zustand + TanStack Query + i18next (EN/FR)
- **Infrastructure**: Docker Compose + Nginx reverse proxy

### Development Commands

```bash
# API (onyxia) — run from /home/admin/galakrond/onyxia/
npm run start:dev        # watch mode
npm run test             # Jest
npm run test:coverage
npm run lint
npm run db:fresh         # full reset + seed

# Frontend apps (sylvanas / tess / xyrella)
npm run dev              # Vite dev server
npm run build            # type-check + build
npm run test             # Vitest
npm run lint
```

### Architecture Principles

**API — Hexagonal (Ports & Adapters)**
Business logic lives in usecases; MongoDB adapters and GraphQL resolvers are driving/driven adapters. Never let framework concerns bleed into usecases.

**Frontend — Layered**
GraphQL fetch service → TanStack Query hooks → Zustand stores (session, loader, flash) → Custom domain hooks → Pure rendering components. All async operations must use the `useAsyncTask` hook for global loader sync.

**REGEX source of truth**: `onyxia/src/common/REGEX.ts` — frontend validation regexes must match this file exactly.

**i18n parity**: EN and FR translation keys must stay synchronized in all three frontend apps.

### Cross-Stack Rules
- All files must be committed unless in `.gitignore` — no untracked files
- English-only code comments; no commented-out code
- Staircase import formatting: external libs grouped separately from internal modules
- JSX templates require `{/* General information */}` section markers

### Service Endpoints

| Service | Dev | Production |
|---------|-----|-----------|
| API (GraphQL) | `http://localhost:3000/graphql` | `api.fitdesk.happykiller.net` |
| Frontoffice | `http://localhost:5173` | `fo.fitdesk.happykiller.net` |
| Backoffice | `http://localhost:5174` | `bo.fitdesk.happykiller.net` |
| Showcase | `http://localhost:5175` | `showcase.fitdesk.happykiller.net` |

### MCP Servers (`.mcp.json`)
MongoDB, Playwright, Docker, and Fetch MCP servers are configured for agent use against the local dev environment.

### Environment
Copy `.env.example` → `.env` (never commit `.env`). Key variables: `API_PORT`, `DB_CONN_STRING`, `VITE_GRAPHQL_ENDPOINT`, `MORGANS_ENDPOINT` (email service).
