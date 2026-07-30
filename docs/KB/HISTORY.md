---
titre: HISTORY — index chronologique des sujets
type: index
statut: actif
maj: 2026-07-30
---

# HISTORY — index des sujets abordés

Une ligne par session utile, pour ne pas refaire deux fois le même chemin. Ce
n'est pas un journal de commits (git le fait déjà).

| Date | Sujet | Ce qui en est sorti | Traces |
|---|---|---|---|
| 2026-07-30 | Fix boot : plus de terminal + dédup Chrome | `terminalTabs: []`, dédup URLs dans `launch_chrome` (v2.3.2) | commit `0a26221`, [DAT/lanceurs.md](DAT/lanceurs.md) |
| 2026-07-30 | Montée de version des dépendances | Vite 8, plugin-react 6, framer-motion 12, ~93 crates ; TS gardé en 5.8 (v2.3.3) | commit `9c9c3b6`, [DAT/stack.md](DAT/stack.md) |
| 2026-07-30 | Process de diffusion | Repo `jarvis-releases` + `scripts/publish-release.ps1`, release v2.3.3 publiée | commits `ec66690`/`48d2972`, [DAF/distribution.md](DAF/distribution.md) |
| 2026-07-30 | Mise en place de la KB (factory-ghost) | Squelette + amorce DAT/DAF/REGLES, `MOTEUR.md`, skill `/capitalize`, branchement `CLAUDE.md` | [README.md](README.md) |
| 2026-07-30 | Industrialisation moteur (capitalize) | `scripts/bump-version.ps1`, skills `/bump-version` + `/release`, hook PostToolUse de validation `.ps1` | [MOTEUR.md](MOTEUR.md) |
