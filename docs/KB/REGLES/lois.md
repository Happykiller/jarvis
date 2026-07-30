---
titre: Lois — invariants non négociables
type: regle
statut: actif
maj: 2026-07-30
---

# Lois — invariants non négociables

Ce qu'on ne fait **jamais** sur ce projet, et pourquoi.

## Configuration

- **`jarvis.config.json` est la seule source de vérité.** Ne jamais coder en dur
  version, chemins, ports, profil Chrome, listes de services dans les `.rs` ou les
  `.ps1`. Pourquoi : deux sources divergent, et l'app installée embarque sa propre
  copie du config.

## Version

- **La version vit dans 6 fichiers, tous synchrones** (cf. [process.md](process.md)).
  Un binaire expédié = un numéro unique. Pourquoi : deux builds différents sous le
  même numéro rendent une release ambiguë.

## PowerShell

- **`.ps1` en ASCII pur, syntaxe validée avant commit** (cf. [normes.md](normes.md)).
  Pourquoi : crash silencieux en PS 5.1.

## Windows / persistance

- **Ne jamais scripter une clé registre Run pour l'autostart.** Le classifieur
  auto-mode de Claude Code le bloque comme « persistance non autorisée ». Passer par
  la bascule du tray. Voir [DAT/tray-autostart.md](../DAT/tray-autostart.md).

## Santé des services

- **Un port TCP ouvert n'est pas un service prêt.** Gater sur une réponse HTTP
  (`healthUrl`), toute réponse (même 4xx/5xx) valant « prêt ». Pourquoi : NestJS/Vite
  acceptent des connexions avant d'avoir fini de charger. Voir
  [DAT/sante-dashboard.md](../DAT/sante-dashboard.md).

## Release

- **Le script de publication refuse d'écraser un tag existant.** Bumper la version
  d'abord. Pourquoi : une release publiée est immuable pour ses utilisateurs.

> Les pièges d'implémentation associés (Test-Port + EndConnect, Start-Job +
> `$LASTEXITCODE`, entrypoint Docker + `command:`, etc.) sont détaillés dans
> [`CLAUDE.md`](../../../CLAUDE.md) — référence, non recopiée ici.
