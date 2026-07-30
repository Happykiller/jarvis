---
titre: Stack technique
type: dat
statut: actif
maj: 2026-07-30
---

# Stack technique

Jarvis est une application [Tauri 2](https://tauri.app) : backend Rust, interface
web (React) rendue dans la WebView2 de Windows. Un seul binaire, pas de serveur.

Versions lues dans les fichiers de dépendances (`package.json`, `src-tauri/Cargo.toml`) —
à ne pas deviner, les relire après un bump.

## Frontend (`src/`)

| Domaine | Choix |
|---|---|
| UI | React 19 + TypeScript |
| Build | Vite 8 (`@vitejs/plugin-react`) |
| Style | Tailwind 4 (`@tailwindcss/vite`) |
| Animations | framer-motion 12 (import `from "framer-motion"`) |
| Pont Tauri | `@tauri-apps/api`, `@tauri-apps/plugin-opener` |

Gestionnaire de paquets : **npm**. TypeScript volontairement maintenu en 5.8
(pas 7) — voir [REGLES/lois.md](../REGLES/lois.md).

## Backend (`src-tauri/`)

Rust edition 2021. Dépendances notables : `tauri` (features `tray-icon`,
`image-ico`), plugins `opener` / `single-instance` / `autostart`, `tokio` (async),
`reqwest` (sondes HTTP, TLS `rustls`), `serde`/`serde_json`, `chrono`, `futures`.

## Cible

Windows 10 (2004+) / 11, x64. WebView2 requis (présent sur Win11 à jour). Build
via la toolchain MSVC + C++ Build Tools.

## Le pourquoi

Tauri plutôt qu'Electron : binaire léger, backend Rust natif pour les appels
système (WSL, Docker, process Windows) que l'orchestration exige. La migration
depuis l'ancien launcher PowerShell + WinForms est documentée dans
[HISTORY.md](../HISTORY.md) et [CLAUDE.md](../../../CLAUDE.md).
