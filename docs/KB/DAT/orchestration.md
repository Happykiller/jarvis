---
titre: Orchestration du boot
type: dat
statut: actif
maj: 2026-07-30
---

# Orchestration du boot

Le cœur de Jarvis : `src-tauri/src/orchestrator.rs`. Porte 1:1 la séquence de boot
de l'ancien script PowerShell. Exposé à l'UI par la commande `start_environment` ;
émet un événement Tauri `orchestration` par étape (`{ phase, service, status,
message }`), rendu en timeline live par le hook React `useOrchestration` +
`ProgressPanel`.

## Séquence

1. **Préflight** WSL/Docker.
2. **`git pull --ff-only`** en parallèle sur tous les `gitPull.repos` (capturé pour
   classifier les échecs ; non bloquant).
3. **Phases Docker ordonnées** (`dockerPhases`) : infrastructure → mail → api →
   frontends. Chaque phase parallèle (`join_all`) ou séquentielle, avec
   `waitHealthy` via `docker inspect`.
4. **`wait_for_services_ready`** (phase `services`) : sonde `health::probe_all`
   toutes les 1s jusqu'à ce que chaque service navigable réponde, ou 120s. Non
   fatal. C'est ce gate qui empêche Chrome d'ouvrir 5173/5174/5175 avant que
   Vite/NestJS soient prêts en HTTP.
5. **`launchers::launch_all`** (phase `apps`) — voir [lanceurs.md](lanceurs.md).

## Invariants de résilience

- **Échec par phase** : une phase `optional: true` (mail, api, frontends) logue un
  WARN et le boot continue (démarrage dégradé). Seule une phase prérequis non
  optionnelle (infrastructure) avorte le boot.
- **Optional par service** : un `PhaseService` peut porter `optional: true`
  (mailcatcher) — il ne fait jamais échouer sa phase, même dans l'infrastructure
  autrement bloquante.
- **Détection d'échec** : vérifier le code de sortie du process, pas seulement
  l'état du job (une commande `wsl`/`make` ratée laisse le job « terminé »).

## Streaming

`run_streaming` pompe stdout/stderr ligne par ligne (événements `status: "log"`),
détecte les marqueurs BuildKit pour signaler « Build de l'image en cours… » quand
un premier boot bloque sur un build multi-Go. Les appels WSL passent par
`run_cmd("wsl", ["bash","-c", script])` (distro `Debian`).

Pièges détaillés (drift des cibles Makefile, entrypoint qui annule le CMD, etc.) :
[CLAUDE.md](../../../CLAUDE.md) et [REGLES/lois.md](../REGLES/lois.md).
