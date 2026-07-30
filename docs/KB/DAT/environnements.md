---
titre: Environnements — dev, build, release
type: dat
statut: actif
maj: 2026-07-30
---

# Environnements — dev, build, release

Les commandes réelles du projet. Prérequis pour builder : Node/npm, Rust (MSVC) +
C++ Build Tools, Cargo sur le PATH (`%USERPROFILE%\.cargo\bin`).

## Développement

```bash
npm install
npm run tauri dev      # hot-reload React ET Rust (rebuild + relance la fenêtre)
```

`tauri dev` lit le `jarvis.config.json` du dépôt en direct. Un log dev vide
signifie souvent un rebuild Rust en cours (lock de build tenu).

## Build des installeurs

```bash
npm run tauri build
```

Produit sous `src-tauri/target/release/bundle/` :
- `nsis/Jarvis_<version>_x64-setup.exe` (installeur NSIS)
- `msi/Jarvis_<version>_x64_en-US.msi` (MSI)

Avant un build, fermer l'app en cours (`Get-Process jarvis | Stop-Process -Force`) :
l'exe cible peut être verrouillé.

## Release

Voir [REGLES/process.md](../REGLES/process.md) et [DAF/distribution.md](../DAF/distribution.md).
En bref : `./scripts/publish-release.ps1 -NotesFile notes/X.Y.Z.md -Draft`.

## Tests

Le dépôt Jarvis n'expose **aujourd'hui aucun test automatisé** (ni Vitest/Jest côté
`src/`, ni `#[test]` côté Rust). Décision prise : c'est un manque à combler, mettre
en place un harnais minimal est au [BACKLOG.md](../BACKLOG.md).
