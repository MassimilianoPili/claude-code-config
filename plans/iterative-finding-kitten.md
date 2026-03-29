# Piano: Commit & Push All Dirty Repos

## Context
Ci sono ~14 repo con modifiche non committate su /data/massimiliano. L'utente vuole fare un giro completo e pushare tutto. Per policy: includere tutti i file extra, non chiedere, pushare direttamente.

## Repo Dirty (14)

| # | Repo | Dirty Files | Remote | Note |
|---|------|-------------|--------|------|
| 1 | `proxy` | 1 untracked (`home/timeline/data.json`) | gitea-local | |
| 2 | `shell-scripts` | 8 (new: `audit-verify`, `session-replay`; mod: `openalex-download`) | gitea-local | |
| 3 | `embedding-viz` | 1 (`main.go`) | gitea-local | |
| 4 | `knowledge-graph` | 1 (`static/index.html`) | gitea-local | |
| 5 | `anki` | 9 (api service, models, main) | gitea-local | |
| 6 | `dashboard-api` | 2 (`package.json`, `package-lock.json`) | gitea-local | |
| 7 | `postgres` | 5 (`Dockerfile`, `docker-compose.yml`, `docker-entrypoint.sh`) | gitea-local | |
| 8 | `claude-shared` | 148 (plans, plugins, history) | **CREARE su Gitea** | gitea_create_repo + add remote + push |
| 9 | `Vari/preference-sort` | 2 (`Dockerfile`, `docker-compose.yml`) | gitea-local | |
| 10 | `Vari/mcp-graph-tools` | 1 (`GraphTools.java`) | gitea + github | |
| 11 | `Vari/kp-manager` | 1 (`docker-compose.yml`) | gitea-local | |
| 12 | `Vari/tools.MassimilianoPili` | 1 untracked (`CLAUDE.md`) | github | |
| 13 | `Vari/anthropic-api-proxy` | 4 (`README.md`, binary, test file) | gitea-local + github | skip binary |
| 14 | `Vari/MassimilianoPili.github.io` | 12 (RPG Godot web export) | github | |

## Approccio

Per ogni repo dirty:
1. `git add -A` (include tutto, per policy "se ci sono file extra, includerli")
2. Commit con messaggio descrittivo in italiano
3. `git push` a tutti i remote configurati (origin + github mirror se presente)

**Eccezioni:**
- `claude-shared`: creare repo `claude-shared` su Gitea (via `gitea_create_repo`), aggiungere remote origin, poi commit + push
- `anthropic-api-proxy`: verificare se il binary è nel .gitignore, altrimenti escluderlo
- Per i repo con mirror GitHub: push sia origin che github

## Ordine di esecuzione
Batch sequenziale, un repo alla volta. ~14 commit + push.

## Verifica
Alla fine: `find /data/massimiliano -maxdepth 3 -name ".git" -exec git -C {}/.. status --short \;` per confermare tutto pulito.
