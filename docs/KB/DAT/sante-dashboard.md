---
titre: Santé des services et dashboard
type: dat
statut: actif
maj: 2026-07-30
---

# Santé des services et dashboard

`src-tauri/src/health.rs` sonde les services ; l'UI rend une `ServiceCard` par
entrée de `services` (via la commande `check_services` → `health::probe_all`),
**pas** par service Docker.

## Priorité des sondes (par service)

1. **`healthUrl`** — GET HTTP, *toute* réponse (même 4xx/5xx) = up. Un port TCP
   ouvert ne suffit pas : NestJS/Vite acceptent des connexions avant d'être prêts.
2. **`container`** — `docker inspect --format {{.State.Running}}` via `wsl` (les
   accolades passent telles quelles). Échappatoire pour un conteneur sans port.
3. **`port`** — connexion TCP en dernier recours.

Les ports infra (27017/6379/1080/8025) sont joignables depuis Windows via le
forwarding localhost de WSL2, donc les sondes marchent depuis l'app.

## Restart par service

Chaque carte `services` porte un `dockerService` qui la relie à son service dans
`dockerPhases` (ex. `api`→`onyxia`, `backoffice`→`sylvanas`). `restart_service`
relance cette commande ; le bouton restart n'apparaît que si `dockerService` est
défini.

## Invariant

`services` et `dockerPhases` sont **indépendants** : garder les 8 services listés
dans `services` pour qu'ils soient tous visibles/sondés. Vérifier la colonne Ports
réelle (`docker ps`) avant de supposer un conteneur sans port (ex. eudora-dev
expose bien `8025`).
