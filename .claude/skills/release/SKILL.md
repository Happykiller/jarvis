---
name: release
description: Publie une release de Jarvis de bout en bout — bump de version, notes de version, build et publication GitHub sur le dépôt jarvis-releases. Orchestrateur guidé qui enchaîne bump-version.ps1 et publish-release.ps1. Déclencher avec /release ou quand l'utilisateur veut sortir/publier une nouvelle version.
---

# /release — publier une nouvelle version

Orchestre le flux de distribution complet vers
[`Happykiller/jarvis-releases`](https://github.com/Happykiller/jarvis-releases).
Chaque étape demande une confirmation : une release publiée est immuable.

## Procédure

### 1. Version cible
Demander/confirmer `<x.y.z>` (correction pour un fix, mineur pour une feature),
puis bumper les 6 fichiers :

```powershell
.\scripts\bump-version.ps1 <x.y.z>
```

### 2. Notes de version
Si `notes/<x.y.z>.md` n'existe pas, le créer depuis ce gabarit et **demander à
l'utilisateur de le compléter** (ne pas inventer le contenu) :

```markdown
# Jarvis <x.y.z> - <titre court>

<Ce qui change, en clair. Le pourquoi autant que le quoi.>

## Ce qui change
- ...
```

### 3. Publication en brouillon
```powershell
.\scripts\publish-release.ps1 -NotesFile notes/<x.y.z>.md -Draft
```

Le script build, calcule les SHA256, et crée la release en draft avec les 2 assets
(setup.exe + msi). Il **refuse d'écraser** un tag existant.

### 4. Relecture puis publication
Faire relire la draft à l'utilisateur. Sur son feu vert :

```powershell
gh release edit v<x.y.z> --repo Happykiller/jarvis-releases --draft=false
```

## Garde-fous

- **Ne jamais publier (`--draft=false`) sans validation explicite** de l'utilisateur.
- Committer/pusher le bump + les notes sur `develop` seulement si l'utilisateur le
  demande.
- Détails : `docs/KB/DAF/distribution.md`, `docs/KB/REGLES/process.md`.
