---
titre: Arborescence du dépôt
type: dat
statut: actif
maj: 2026-07-30
---

# Arborescence du dépôt

Dossiers de premier niveau et leur rôle.

| Chemin | Rôle |
|---|---|
| `src/` | Frontend React (dashboard, composants, hooks, `lib/`, `types.ts`) |
| `src-tauri/` | Backend Rust (`src/*.rs`), `Cargo.toml`, `tauri.conf.json`, `icons/` |
| `scripts/` | Outillage local — `publish-release.ps1` (publication des releases) |
| `notes/` | Notes de version, une par release (`notes/X.Y.Z.md`) |
| `public/` | Assets statiques servis par Vite (dont `jarvis-icon.png`) |
| `docs/KB/` | Cette base de connaissance |
| `.claude/` | Cerveau moteur — voir [MOTEUR.md](../MOTEUR.md) |
| `.vscode/` | Réglages éditeur du dépôt |
| `dist/` | Build frontend (git-ignoré) |
| `dist-release/` | Artefacts renommés pour upload (git-ignoré) |
| `logs/` | Journaux de l'ancien launcher PS (git-ignoré) |

## Fichiers racine notables

- `jarvis.config.json` — **source de vérité unique**, voir [configuration.md](configuration.md).
- `CLAUDE.md` — instructions projet + branchement KB.
- Ancien launcher PowerShell (transition) : `dev-setup.ps1`, `jarvis-tray.ps1`,
  `jarvis-tray.vbs`, `dev-setup.bat`. Toujours fonctionnel, à retirer une fois
  l'app Tauri en usage quotidien.

## Backend Rust — un module par responsabilité

`src-tauri/src/` : `config.rs`, `health.rs`, `launchers.rs`, `logger.rs`,
`orchestrator.rs`, `lib.rs` (setup/tray/commandes), `main.rs` (entrée). Chacun a
sa fiche DAT.
