# Piano: Aggiornamento documentazione code-server

## Contesto

Il code-server è stato appena potenziato con pieni poteri sul server (Docker socket, SSH keys,
tool di sistema, shell-scripts nel PATH). La documentazione (README + MEMORY) non riflette
le modifiche e va aggiornata.

## File da modificare

1. `/data/massimiliano/code-server/README.md` — aggiornare completamente con nuova config
2. `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` — aggiungere sezione code-server

## Modifiche al README.md

Aggiornare le sezioni:
- **Dockerfile**: documentare installazione Docker CLI, compose, buildx, tool, gruppo docker GID 988, PATH shell-scripts
- **Volumi**: rimuovere `ide-projects`, aggiungere docker socket, SSH (:ro), gitconfig (:ro)
- **Container**: aggiungere `pid: host`, menzione del gruppo docker
- **Capacità terminale**: nuova sezione che elenca cosa si può fare dal terminale VS Code

## Modifiche alla MEMORY.md

Aggiungere una sezione "code-server" che documenta:
- Container con pieni poteri Docker (socket mount)
- SSH keys e git config montati read-only
- Shell-scripts nel PATH via `/etc/profile.d/sol-path.sh`
- `pid: host` per visibilità processi
- Tool installati (docker, jq, htop, etc.)

## Verifica

Rileggere entrambi i file dopo la modifica per verificare consistenza.
