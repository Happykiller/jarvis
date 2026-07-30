---
titre: MOTEUR — cartographie du cerveau moteur
type: index
statut: actif
maj: 2026-07-30
---

# MOTEUR — cartographie de `.claude/`

Ce que Claude sait *faire* sur ce projet. On constate l'existant ; on n'ajoute un
outil que quand l'usage l'a prouvé nécessaire (seuil : trois répétitions).

## Skills

| Skill | Quand l'utiliser | Fichier |
|---|---|---|
| `/capitalize` | En fin de session ayant produit un apprentissage : trier ce qui rejoint la KB vs devient un outil | `.claude/skills/capitalize/SKILL.md` |
| `/bump-version` | Incrémenter la version sur les 6 fichiers (délègue à `scripts/bump-version.ps1`) | `.claude/skills/bump-version/SKILL.md` |
| `/release` | Publier une version de bout en bout : bump -> notes -> build+publish sur `jarvis-releases` | `.claude/skills/release/SKILL.md` |

## Sous-agents

_Aucun._ Les explorations passent par les agents génériques (Explore, general-purpose).

## Hooks

| Événement | Ce qu'il automatise | Fichier |
|---|---|---|
| `Stop` | Rappelle à Claude de reporter les apprentissages de session dans `CLAUDE.md` (garde-fou anti-boucle par fichier flag) | `.claude/stop-hook.ps1` (câblé dans `.claude/settings.json`) |
| `PostToolUse` (Edit/Write/MultiEdit) | Après édition d'un `.ps1`, valide la syntaxe PowerShell ; bloque avec les erreurs si le fichier est cassé | `.claude/hooks/validate-ps1.ps1` |

## Scripts outillés (`scripts/`)

| Script | Rôle |
|---|---|
| `bump-version.ps1 <x.y.z>` | Écrit + vérifie la version sur les 6 emplacements |
| `publish-release.ps1` | Build + SHA256 + `gh release create` vers `jarvis-releases` |

## MCP

_Aucun serveur MCP au niveau projet_ (`.mcp.json` absent à la racine). Le `.mcp.json`
mentionné dans `CLAUDE.md` concerne la plateforme **Galakrond** (dans WSL), pas le
dépôt Jarvis.

> Recoupement à connaître : le hook `Stop` et `/capitalize` visent le même but
> (capitaliser en fin de session). Le hook **déclenche tout seul** un rappel minimal
> vers `CLAUDE.md` ; `/capitalize` **structure** le tri KB vs outil quand on l'invoque.
> À terme, `/capitalize` peut devenir la forme aboutie de ce que le hook amorce.
