# Piano: Pubblicazione wikijs-mermaid-patch

## Context

Il repo `/data/massimiliano/wikijs-mermaid-patch/` contiene 3 patch per WikiJS v2 (Mermaid v10 + YAML fix), creato nella sessione `0c1c0e87` ma mai pushato. Da allora:
- `page-view-patch.pug` è divergente tra repo e deploy (versione CDN, commenti, safety check)
- Una 4a patch (`disk-common-patch.js`) è stata creata e deployata ma non inclusa nel repo
- Il repo Gitea non esiste, il mirror GitHub nemmeno

Obiettivo: completare il repo, pushare su Gitea, creare mirror GitHub. Commit separati logicamente.

## File critici

- **Repo**: `/data/massimiliano/wikijs-mermaid-patch/`
- **Deploy**: `/data/massimiliano/wikijs/` (file attualmente montati nel container)
- **Mirror script**: `/data/massimiliano/shell-scripts/bin/deploy-mirror`

## Divergenze rilevate (page-view-patch.pug)

| Aspetto | Repo | Deploy |
|---------|------|--------|
| Mermaid CDN | `@10.9.3` (pinned) | `@10` (floating) |
| Safety check | `if (typeof mermaid === 'undefined') return;` | Rimossa |
| Commenti | Inglese, verbose | Italiano, compatti |

**Decisione**: sincronizzare repo ← deploy (la versione deployata è quella testata e funzionante).

## Piano esecutivo

### Commit 1: `fix: sync page-view-patch.pug with deployed version`
- Copiare `/data/massimiliano/wikijs/page-view-patch.pug` → `patches/page-view-patch.pug`
- Questo allinea il repo alla versione effettivamente in produzione

### Commit 2: `feat: add disk-common-patch for public-read git sync import`
- Copiare `/data/massimiliano/wikijs/disk-common-patch.js` → `patches/disk-common-patch.js`
- Aggiornare `docker-compose.override.yml`: aggiungere volume mount per disk-common
- Aggiornare `README.md`:
  - Aggiungere riga nella tabella "The Problem" (pagine non pubblicate dopo git sync)
  - Aggiungere riga nella tabella "Applying only specific patches"
  - Aggiungere menzione nella sezione "How It Works"
  - Aggiornare "3 files" → "4 files" nell'intro

### Commit 3: `ci: add Gitea repo and GitHub mirror workflow`
- Creare repo `wikijs-mermaid-patch` su Gitea (pubblico) via `gitea_create_repo`
- Push su Gitea
- Creare repo su GitHub (via `gh repo create` o manuale)
- Aggiungere remote `github`
- Generare `.gitea/workflows/mirror.yml` via `deploy-mirror`
- Push workflow → trigger mirror automatico

## Verifica

1. `git log --oneline` mostra 4 commit (1 iniziale + 3 nuovi)
2. `patches/` contiene 4 file
3. Repo visibile su Gitea: `https://sol.massimilianopili.com/git/sol_root/wikijs-mermaid-patch`
4. Mirror su GitHub: `https://github.com/MassimilianoPili/wikijs-mermaid-patch`
5. README coerente con i 4 file
