---
titre: Consignes de l'utilisateur envers Claude
type: regle
statut: actif
maj: 2026-07-30
---

# Consignes de l'utilisateur envers Claude

Ce que l'utilisateur attend de Claude sur ce projet — surtout ce qui est né d'une
correction. Contraignant.

- **KB et projet en français.** Écrire la documentation et les échanges de travail
  en français.
- **Bumper la version pour chaque livrable.** L'utilisateur demande explicitement
  un incrément de version à chaque changement expédié (fix ou feature).
- **Fin de session = capitaliser.** Le hook Stop rappelle déjà de reporter les
  apprentissages dans `CLAUDE.md` ; le skill `/capitalize` structure ce geste.
- **Ne pas écraser en silence.** Sur les fichiers de doc/config existants,
  enrichir et signaler les contradictions plutôt que réécrire d'office.
- **Committer/pusher uniquement sur demande explicite.** Ne jamais committer de sa
  propre initiative ; l'utilisateur dit « commit et push » quand c'est le moment.
- **Agir quand l'info suffit, rester concis.** L'utilisateur enchaîne par des
  ordres courts (« go build », « go publish ») : exécuter sans re-broder, et
  **vérifier par un build/résultat réel** avant d'annoncer « terminé ».
- **Valider avant de publier vers l'extérieur.** Une release se prépare en `-Draft`,
  se relit, puis se publie sur confirmation.

## À COMPLÉTER

Continuer à ajouter au fil des sessions les corrections marquantes (ton, niveau de
détail, gestes à éviter). Une correction non capitalisée se reproduit.
