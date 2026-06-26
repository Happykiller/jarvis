# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What Is Jarvis?

Jarvis is a **Windows automation launcher** (PowerShell + VBS) that bootstraps the entire **Galakrond** development environment. It runs as a system tray application and automates the complex setup of a multi-service fitness coaching SaaS platform running in WSL2.

The actual product codebase lives in WSL2 at `/home/admin/galakrond`.

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

**`dockerPhases` — ordered startup.** An array of phases run in order. Each phase has: `name`, `parallel` (true = Start-Job fan-out, false = one-by-one), `services` (each `name`/`path`/`command`/`network`), and optional `waitHealthy` (array of container names to block on via `docker inspect` health) + `healthTimeoutSeconds` before the phase runs. Order: infrastructure -> mail -> api -> frontends. To reorder or add a service, edit only this array.

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
