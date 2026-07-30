---
titre: Démarrer l'environnement en un clic
type: daf
statut: actif
maj: 2026-07-30
---

# Démarrer l'environnement en un clic

## Le besoin

Démarrer Galakrond à la main, c'est une liste de corvées dans le bon ordre :
vérifier WSL et Docker, `git pull` sur 8 dépôts, lancer les conteneurs par vagues
en attendant que chacun soit *réellement* prêt, puis ouvrir VS Code, Compass et
Chrome sur les bonnes URLs. Long, faillible, refait chaque matin.

## Ce que Jarvis garantit

- **Un seul geste** (« Démarrer l'environnement ») déclenche toute la séquence,
  dans l'ordre, avec attente de santé entre les phases.
- **Un démarrage qui ne ment pas** : Chrome n'ouvre les frontends qu'une fois
  qu'ils répondent en HTTP, pas dès que le port écoute.
- **Un démarrage résilient** : un service non critique en échec ne bloque pas le
  reste (démarrage dégradé, les apps se lancent quand même).

## Règles fonctionnelles

- L'ordre des phases (infrastructure → mail → api → frontends) est porté par
  `dockerPhases` dans le config, pas codé en dur. Réordonner = éditer le config.
- La criticité est déclarative : `optional` au niveau phase ou service décide si un
  échec est fatal.

Détail technique : [DAT/orchestration.md](../DAT/orchestration.md).

## Périmètre assumé

Pas de démarrage partiel (« infra seule », « frontends seuls »). Le boot est
**tout-ou-dégradé** et cela suffit : décision prise le 2026-07-30. La résilience
par phase/service couvre déjà le cas d'un service qui tombe.
