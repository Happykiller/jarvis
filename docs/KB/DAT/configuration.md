---
titre: Configuration — jarvis.config.json
type: dat
statut: actif
maj: 2026-07-30
---

# Configuration — `jarvis.config.json`

**Source de vérité unique.** Toute valeur mutable (version, chemins, services,
profil Chrome, onglets, phases Docker) vit ici — jamais codée en dur dans les
`.rs` ou les `.ps1`. L'app Tauri et les scripts PS legacy le lisent tous les deux.

Structure côté Rust : `config.rs`, avec `#[serde(rename_all = "camelCase")]` — les
types React (`src/types.ts`) doivent matcher (ex. `latencyMs`, `healthUrl`).

## Deux listes distinctes à ne pas confondre

- **`dockerPhases`** = ce qu'on **démarre** (les 8 conteneurs, en phases ordonnées).
- **`services`** = ce que le **dashboard affiche et sonde** (une carte par entrée).

Un conteneur démarré par `dockerPhases` mais absent de `services` tourne
invisible. Voir [orchestration.md](orchestration.md) et [sante-dashboard.md](sante-dashboard.md).

## Champs principaux

| Champ | Rôle |
|---|---|
| `version` | Version de l'app (un des 6 emplacements à synchroniser) |
| `projectRoot` / `projectShare` | Chemin WSL / part Windows de Galakrond |
| `gitPull` | `enabled` + liste explicite `repos` pull en parallèle avant Docker |
| `dockerPhases` | Phases de démarrage ordonnées (parallèle/séquentiel + `waitHealthy`) |
| `services` | Cartes dashboard : `port`, `url`, `healthUrl`, `container`, `dockerService` |
| `terminalTabs` | Onglets terminal WSL (vide = pas de terminal lancé) |
| `chrome` | `userDataDir`, `profileDir`, `debugPort`, `extraUrls` |
| `paths` | `compass`, `vscode` |

## Invariants

- **La version vit dans 6 fichiers** — voir [REGLES/lois.md](../REGLES/lois.md).
- Ne pas mettre l'`url` d'un service à la fois dans `services` et dans
  `chrome.extraUrls` : Chrome dédoublonne désormais, mais la place canonique est
  l'entrée `services`.
- L'app installée embarque **sa propre copie** du config (bundle `resources`) :
  une modif ne prend effet qu'après rebuild+réinstall, ou en `tauri dev`.
