---
titre: Process — versionner, releaser, commiter
type: regle
statut: actif
maj: 2026-07-30
---

# Process

## Versionner

La version vit dans **6 fichiers** à garder synchrones (voir [lois.md](lois.md)) :
`package.json`, `src-tauri/Cargo.toml`, `src-tauri/tauri.conf.json`,
`jarvis.config.json`, `src-tauri/Cargo.lock` (paquet `jarvis`), `package-lock.json`
(2 occurrences en tête).

**Ne pas éditer les 6 à la main** (`package-lock.json` a dérivé deux fois) : passer
par `scripts/bump-version.ps1 <x.y.z>` (ou le skill `/bump-version`), qui écrit et
vérifie les 6 emplacements.

Convention : bump de correction pour un fix/livrable, mineur pour une fonctionnalité.
Un changement expédié = un numéro (ne pas rebuilder deux binaires différents sous
le même numéro).

## Releaser

Le skill `/release` orchestre tout ; manuellement :

1. `./scripts/bump-version.ps1 X.Y.Z` (les 6 fichiers).
2. Rédiger `notes/X.Y.Z.md`.
3. `./scripts/publish-release.ps1 -NotesFile notes/X.Y.Z.md -Draft`
   (build + SHA256 + `gh release create` vers `Happykiller/jarvis-releases`).
4. Relire la draft, puis `gh release edit vX.Y.Z --repo Happykiller/jarvis-releases --draft=false`.

Voir [DAF/distribution.md](../DAF/distribution.md).

## Commiter

- Committer/pusher **seulement quand l'utilisateur le demande**.
- Sur la branche par défaut (`develop`), rester sur `develop` a été la pratique de
  ces sessions ; brancher si l'usage l'exige.
- Terminer les messages de commit par le trailer :
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.
- Après édition d'un `.ps1`, **valider la syntaxe** avant de committer (voir
  [normes.md](normes.md)).
