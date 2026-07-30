---
name: bump-version
description: Incrémente la version de Jarvis de façon synchrone sur les 6 fichiers (package.json, Cargo.toml, tauri.conf.json, jarvis.config.json, Cargo.lock, package-lock.json). Utilise le script scripts/bump-version.ps1. Déclencher avec /bump-version <x.y.z> ou quand l'utilisateur demande de bumper/incrémenter la version.
---

# /bump-version — synchroniser la version sur les 6 fichiers

La version de Jarvis vit dans **6 emplacements** qui doivent rester synchrones (voir
`docs/KB/REGLES/lois.md`). Les éditer à la main dérive — `package-lock.json` a
décroché deux fois. Ce skill délègue au script déterministe.

## Procédure

1. Déterminer la version cible `<x.y.z>` (argument de la commande, ou demander à
   l'utilisateur). Semver strict `x.y.z`.
2. Lancer le script :

   ```powershell
   .\scripts\bump-version.ps1 <x.y.z>
   ```

3. Rendre compte du tableau des 6 emplacements (le script échoue si l'un diverge).
4. Rappeler que **l'app installée nécessite un rebuild** (`npm run tauri build`)
   pour refléter le nouveau numéro — le bump seul ne change pas le binaire.

## Notes

- Ne pas éditer les 6 fichiers à la main : c'est le rôle du script.
- Pour une release complète (bump + notes + publication), voir le skill `/release`.
- Détail process : `docs/KB/REGLES/process.md`.
