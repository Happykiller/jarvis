---
titre: Normes de code et de langue
type: regle
statut: actif
maj: 2026-07-30
---

# Normes de code et de langue

## PowerShell — ASCII uniquement

Les fichiers `.ps1` doivent être **ASCII pur** (pas d'em-dash, pas de lettres
accentuées, commentaires en anglais). PowerShell 5.1 lit les scripts en
Windows-1252 sans BOM UTF-16 : un caractère non-ASCII provoque un crash silencieux.
Après chaque édition d'un `.ps1`, valider la syntaxe :

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('.\script.ps1', [ref]$null, [ref]$errors) | Out-Null
"Errors: $($errors.Count)"
```

## Commentaires de code en anglais

Le code (Rust, TS, PS) commente en anglais. La **documentation projet** (cette KB,
les notes de release) est en français.

## Langue de la KB

Français, en-tête YAML sur chaque page (`titre`, `type`, `statut`, `maj`).

## Synchronisation de version

6 fichiers, cf. [process.md](process.md) et [lois.md](lois.md).

## Nommage (observé dans le code)

- **Composants React** : `PascalCase`, export nommé, fichier `PascalCase.tsx`
  (`ServiceCard.tsx` → `export function ServiceCard`). Props via `interface Props`.
- **Hooks** : préfixe `use`, `camelCase`, fichier `useX.ts` (`useOrchestration.ts`).
- **`lib/`** : fichiers en minuscules (`api.ts`, `tts.ts`).
- **Modules Rust** : `snake_case` (`orchestrator.rs`, `health.rs`), un module par
  responsabilité.
- **Frontière JS/Rust** : les structs Rust portent `#[serde(rename_all = "camelCase")]` ;
  les interfaces de `src/types.ts` (champs `camelCase`) doivent matcher à
  l'identique (`latencyMs`, `healthUrl`).

## Imports (TS/TSX)

Deux groupes séparés par une ligne vide : **libs externes** d'abord (`react`,
`framer-motion`, `@tauri-apps/*`), puis **modules internes** (`./lib`, `./hooks`,
`./components`). Les `import type` viennent en dernier.

## Messages de commit

Trailer `Co-Authored-By` obligatoire (cf. [process.md](process.md)). Préfixes
conventionnels observés : `feat:`, `fix:`, `chore:`, `docs:`.
