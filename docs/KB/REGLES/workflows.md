---
titre: Workflows outillés
type: regle
statut: actif
maj: 2026-07-30
---

# Workflows outillés

Les enchaînements récurrents du projet, et dans quel ordre.

## Développer

`npm install` → `npm run tauri dev` (hot-reload React + Rust). Les édits Rust
déclenchent un rebuild + relance de la fenêtre.

## Bumper la version

`/bump-version <x.y.z>` (ou `scripts/bump-version.ps1 <x.y.z>`) écrit et vérifie la
version sur les 6 fichiers. Rebuild ensuite pour que le binaire porte le numéro.

## Builder et publier une release

`/release` orchestre bump → notes → publication. Manuellement : fermer l'app →
`npm run tauri build` → `scripts/publish-release.ps1`. Le script enchaîne build,
staging renommé (`dist-release/`), SHA256, et création de la release GitHub.
`-SkipBuild` réutilise les bundles existants ; `-Draft` publie en brouillon.

## Mettre à jour les dépendances

Bumps sûrs : `npm update` (in-range) + `cargo update` (réécrit `Cargo.lock` au
dernier compatible). Toujours `npm run tauri build` ensuite pour valider que Vite +
crates compilent avant d'expédier. `cargo-outdated` n'est pas installé — utiliser
`cargo update --dry-run` pour prévisualiser.

## Capitaliser en fin de session

Lancer `/capitalize` pour trier ce qui doit rejoindre cette KB (faire mieux) ou
devenir un outil `.claude/` (faire plus efficacement). Voir [MOTEUR.md](../MOTEUR.md).

## Régénérer les icônes

`npm run tauri -- icon jarvis-icon.png`, puis recopier `icon.ico` → `jarvis.ico`
(tray) et `128x128@2x.png` → `public/jarvis-icon.png` (en-tête).
