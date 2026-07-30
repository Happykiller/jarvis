---
titre: Tray, instance unique, autostart
type: dat
statut: actif
maj: 2026-07-30
---

# Tray, instance unique, autostart

`src-tauri/src/lib.rs` : setup de l'app, tray, plugin single-instance, commandes
exposées à l'UI (`load_config`, `check_services`, `start_environment`,
`restart_service`) + celles des logs.

## Fenêtre et tray

- Fermeture de fenêtre = **masquer dans le tray** (`WindowEvent::CloseRequested` +
  `api.prevent_close()`) ; quitter uniquement par le menu du tray.
- Icône du tray : `jarvis.ico` via `Image::from_path`, localisée par `locate_asset`
  (dev : racine repo ; installé : `resource_dir()`).
- « Pas d'icône tray » n'est presque jamais un bug : si le process tourne, l'icône
  est enregistrée — Win11 la cache dans le débordement (chevron `^`). Diagnostic :
  process vivant ? → clés HKCU Run/StartupApproved → sinon réglage de visibilité
  Windows.

## Autostart au login

`tauri-plugin-autostart`, basculé par un `CheckMenuItem` « Lancer au demarrage ».
Écrit DEUX entrées HKCU (valeur sous `…\Run` nommée `Jarvis` + REG_BINARY sous
`StartupApproved\Run`). `is_enabled()` exige les deux.

## Invariant

Le classifieur auto-mode de Claude Code **bloque** l'écriture directe d'une clé
registre Run (« persistance non autorisée »), même demandée. Pour activer
l'autostart : lancer l'app et cliquer la bascule du tray — pas de script registre.
Voir [REGLES/lois.md](../REGLES/lois.md).
