---
titre: DAT — Dossier d'Architecture Technique
type: index
statut: actif
maj: 2026-07-30
---

# DAT — Dossier d'Architecture Technique

Comment Jarvis est construit. Une page par sujet ; le détail d'implémentation
reste dans le code (`src/`, `src-tauri/src/`).

| Page | Ce qu'elle couvre | Statut | MAJ |
|---|---|---|---|
| [stack.md](stack.md) | Langages, frameworks, versions, gestionnaire de paquets | actif | 2026-07-30 |
| [arborescence.md](arborescence.md) | Dossiers de premier niveau et leur rôle | actif | 2026-07-30 |
| [environnements.md](environnements.md) | Dev, build, release — les commandes réelles | actif | 2026-07-30 |
| [configuration.md](configuration.md) | `jarvis.config.json`, source de vérité unique | actif | 2026-07-30 |
| [orchestration.md](orchestration.md) | La séquence de boot (`orchestrator.rs`) | actif | 2026-07-30 |
| [sante-dashboard.md](sante-dashboard.md) | Sondes de santé + dashboard (`health.rs`) | actif | 2026-07-30 |
| [lanceurs.md](lanceurs.md) | Lancement Terminal / VS Code / Compass / Chrome (`launchers.rs`) | actif | 2026-07-30 |
| [tray-autostart.md](tray-autostart.md) | Tray, instance unique, autostart (`lib.rs`) | actif | 2026-07-30 |
| [logs.md](logs.md) | Journaux persistés et visualiseur (`logger.rs`) | actif | 2026-07-30 |
