---
titre: Journaux persistés et visualiseur
type: dat
statut: actif
maj: 2026-07-30
---

# Journaux persistés et visualiseur

`src-tauri/src/logger.rs` (depuis v2.2.0). Écrit chaque événement d'orchestration
dans un fichier rotatif (30 derniers) sous `app_log_dir()`
(`%LOCALAPPDATA%\net.happykiller.jarvis\logs` en installé).

## Mécanique

- Un `Mutex<Option<File>>` global, ouvert par `logger::start_session(label)` en tête
  de `orchestrator::run` (« boot ») et `restart` (« restart <svc> »).
- Appendé par `logger::write`, appelé depuis le point de passage `emit` — donc
  **chaque** événement streamé (y compris les lignes `log`) est capturé.
- `set_dir` appelé une fois dans `setup()`.

## Commandes UI

`list_logs` / `read_log(name)` / `open_logs_dir` alimentent le visualiseur in-app
(`LogsPanel.tsx`, bouton « Logs » de l'en-tête). `read_log` rejette les noms
contenant `/ \ ..` (reste dans le dossier de logs). Dépend de `chrono` pour
l'horodatage.

> Ne pas confondre avec `logs/` à la racine du dépôt : ce sont les journaux de
> l'ancien launcher PowerShell (git-ignorés).
