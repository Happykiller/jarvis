---
titre: Distribution et mise à jour
type: daf
statut: actif
maj: 2026-07-30
---

# Distribution et mise à jour

## Le besoin

Diffuser Jarvis proprement à ses utilisateurs, avec une page de téléchargement
claire et des installeurs vérifiables — séparée du dépôt de dev.

## Le modèle retenu

Un **dépôt de release dédié public**,
[`Happykiller/jarvis-releases`](https://github.com/Happykiller/jarvis-releases)
(README + `assets/` uniquement, branche `develop`), calqué sur `koa-releases`. Les
binaires sont publiés en **GitHub Releases** (`vX.Y.Z`, titre `Jarvis <v>`) avec
deux assets : `Jarvis-<v>-x64-setup.exe` (NSIS) + `Jarvis-<v>-x64.msi`.

Le dépôt source `jarvis` est public lui aussi (contrairement à koa dont les sources
sont privées) ; le dépôt de release reste séparé pour offrir une page de
téléchargement propre.

## Règles fonctionnelles

- Pas de CI : publication depuis le dépôt source via `scripts/publish-release.ps1`.
- Chaque release porte les **empreintes SHA256** et la marche à suivre pour un
  binaire non signé (`Get-FileHash` / `Unblock-File`).
- Le script **refuse d'écraser** un tag existant : bumper la version d'abord.

Détail process : [REGLES/process.md](../REGLES/process.md). Détail technique :
[DAT/environnements.md](../DAT/environnements.md).

## Pistes retenues (backlog)

Décidées mais pas encore faites, suivies dans [BACKLOG.md](../BACKLOG.md) :
**signature de code** (anti-SmartScreen), **auto-update in-app**
(`tauri-plugin-updater`), et **captures d'écran** du dashboard pour la page de
téléchargement.
