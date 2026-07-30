---
titre: Lanceurs d'applications compagnes
type: dat
statut: actif
maj: 2026-07-30
---

# Lanceurs d'applications compagnes

`src-tauri/src/launchers.rs` — dernière étape du boot (phase `apps`, best-effort :
un échec est logué, les autres continuent). Lance Windows Terminal, VS Code,
MongoDB Compass et Chrome.

## Windows Terminal

Tous les `terminalTabs` sont joints par `;` en **un seul** appel `wt` (une fenêtre,
N onglets). Un onglet à `command` vide ouvre un shell nu dans `projectRoot`.
**`terminalTabs: []` désactive le terminal** (early-return, aucun `wt`).

## VS Code

`code` est un shim `.cmd` → passer par `cmd /c` avec `CREATE_NO_WINDOW` (0x08000000)
pour supprimer la console. Ouvrir via l'URI Remote-WSL
(`vscode-remote://wsl+Debian<projectRoot>`), **pas** la part UNC `\\wsl.localhost\…`
(qui ferait rouvrir en WSL et spawnerait un `wsl.exe` parasite).

## Chrome

`--new-window --start-maximized --user-data-dir=… [--profile-directory=…]` puis les
URLs : `extraUrls` d'abord, puis chaque `services[].url`. Les URLs sont
**dédoublonnées** (HashSet, 1re occurrence gardée) : un chevauchement
`extraUrls`/`services` n'ouvre plus deux fois le même onglet.

## Compass

Chemin depuis `paths.compass`, `expand_env` pour `%VAR%`, vérifié avant spawn.

Détails Windows (flags, shims) : [CLAUDE.md](../../../CLAUDE.md).
