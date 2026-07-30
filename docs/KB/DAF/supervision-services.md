---
titre: Superviser et relancer les services
type: daf
statut: actif
maj: 2026-07-30
---

# Superviser et relancer les services

## Le besoin

Une fois l'environnement démarré, savoir d'un coup d'œil ce qui tourne, ce qui est
tombé, et pouvoir relancer un service isolé sans tout rebooter.

## Ce que Jarvis offre

- **Un dashboard** : une carte par service, avec état réel (en ligne / hors ligne),
  port et latence. Clic sur une carte = ouvrir son URL.
- **Un redémarrage ciblé** : bouton restart sur les services adossés à un service
  Docker (`dockerService`), qui relance uniquement ce conteneur.
- **Un panneau de progression** qui streame la sortie des commandes ligne par ligne
  pendant un boot ou un restart.
- **Des journaux** relisibles dans l'app (30 derniers runs, horodatés).

## Règle fonctionnelle

Le dashboard affiche la liste `services` du config (8 entrées : 4 apps +
mongo/redis/mailcatcher/eudora), **indépendante** de ce qui est réellement démarré
par `dockerPhases`. Garder les deux alignées, sinon un service tourne invisible.

Détail technique : [DAT/sante-dashboard.md](../DAT/sante-dashboard.md).
