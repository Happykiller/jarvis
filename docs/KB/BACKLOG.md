---
titre: BACKLOG — roadmap et pistes
type: index
statut: actif
maj: 2026-07-30
---

# BACKLOG — roadmap et pistes

Ce qu'on veut faire mais qu'on n'a pas encore fait. Décidé avec l'utilisateur ;
n'invente rien ici. Une piste réalisée sort d'ici et rejoint la KB + `HISTORY.md`.

| Piste | Pourquoi | Statut |
|---|---|---|
| Mettre en place des tests automatisés | Le dépôt n'en a aucun aujourd'hui (ni Vitest côté `src/`, ni `#[test]` côté Rust) ; filet de sécurité pour les refactors | à faire |
| Signature de code | Supprimerait l'avertissement SmartScreen « Windows a protégé votre ordinateur » sur les installeurs non signés | backlog |
| Auto-update in-app (`tauri-plugin-updater`) | Éviter le re-téléchargement manuel à chaque release ; absent aujourd'hui (comme koa) | backlog |
| Captures d'écran du dashboard | Enrichir le README de `jarvis-releases` (page de téléchargement) | backlog |
| Retirer le launcher PowerShell legacy | `dev-setup.ps1` / `jarvis-tray.*` / `dev-setup.bat`, une fois l'app Tauri en usage quotidien | backlog |

> La distribution renvoie ici : [DAF/distribution.md](DAF/distribution.md).
