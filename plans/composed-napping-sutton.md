# Piano: code-server — accesso MCP per Claude Code

## Context

Claude Code è già accessibile dal pod code-server, ma le sessioni nuove non hanno accesso MCP.

**Root cause**: la config MCP è in `~/.claude.json` (`/home/massimiliano/.claude.json`):
```json
"mcpServers": { "simoge-mcp": { "type": "sse", "url": "http://localhost:8098/sse", "timeout": 300 } }
```
Il container ha un proprio `.claude.json` **senza** simoge-mcp. Inoltre `~/.claude/` (settings, hooks, plugins) è una directory separata.

**Stato attuale centralizzazione** — `claude-code-config/` già contiene:
- `settings.json` (symlink da `~/.claude/settings.json` E da `/data/massimiliano/.claude/settings.json`)
- `hooks/` (symlink da `/data/massimiliano/.claude/hooks`)
- **Manca**: `.claude.json` (MCP servers, preferenze utente)

## Approccio: centralizzare `.claude.json` + bind mount `~/.claude` + socat

### Step 1 — Centralizzare `.claude.json` in `claude-code-config/`

Sull'host:
```bash
cp /home/massimiliano/.claude.json /data/massimiliano/claude-code-config/.claude.json
ln -sf /data/massimiliano/claude-code-config/.claude.json /home/massimiliano/.claude.json
```

Aggiungere a `claude-code-config/.gitignore`:
```
.claude.json
```
(Cambia ad ogni sessione: `numStartups`, `tipsHistory`, ecc.)

Risultato: `~/.claude.json` → `claude-code-config/.claude.json` (come `settings.json`)

### Step 2 — `docker-compose.yml`: volume mount `~/.claude`

File: `/data/massimiliano/code-server/docker-compose.yml`

Aggiungere ai volumes:
```yaml
- /home/massimiliano/.claude:/home/massimiliano/.claude
```

Questo porta nel container tutta la directory con i symlinks interni:
- `plugins → /data/massimiliano/claude-shared/plugins` ✓
- `agents → /data/massimiliano/claude-shared/agents` ✓
- `skills → /data/massimiliano/claude-shared/skills` ✓
- `plans → /data/massimiliano/claude-shared/plans` ✓
- `projects → /data/massimiliano/claude-shared/projects` ✓
- `settings.json → /data/massimiliano/claude-code-config/settings.json` ✓
- `.credentials.json` (API key) ✓

Tutti risolvono perché `/data/massimiliano` è già montato RW nel container.

### Step 3 — `Dockerfile`: symlink `.claude.json` + socat

File: `/data/massimiliano/code-server/Dockerfile`

- Aggiungere `socat` ai pacchetti
- Symlink: `ln -sf /data/massimiliano/claude-code-config/.claude.json /home/massimiliano/.claude.json`
- Copiare `entrypoint.sh` + `ENTRYPOINT`

### Step 4 — `entrypoint.sh`: socat forwarding MCP

File: `/data/massimiliano/code-server/entrypoint.sh` (nuovo)

```bash
#!/bin/bash
# La config MCP dice localhost:8098, ma dal container serve Docker DNS
socat TCP-LISTEN:8098,fork,reuseaddr TCP:mcp-proxy:8098 &
socat TCP-LISTEN:8099,fork,reuseaddr TCP:simoge-mcp:8099 &
exec "$@"
```

### Mappa centralizzazione completa

| Config | Location centralizzata | Host | Container |
|--------|----------------------|------|-----------|
| `settings.json` | `claude-code-config/settings.json` | symlink `~/.claude/settings.json` | via bind mount `~/.claude` |
| `.claude.json` | `claude-code-config/.claude.json` | symlink `~/.claude.json` | symlink in Dockerfile |
| `hooks/` | `claude-code-config/hooks/` | symlink `/data/massimiliano/.claude/hooks` | via mount `/data/massimiliano` |
| `settings.local.json` | `/data/massimiliano/.claude/` (project-level) | diretto | via mount `/data/massimiliano` |
| plugins/agents/skills | `claude-shared/` | symlink in `~/.claude/` | via bind mount `~/.claude` |

### File da modificare/creare

| File | Azione |
|------|--------|
| Host `~/.claude.json` | Spostare in `claude-code-config/`, symlink |
| `claude-code-config/.gitignore` | +`.claude.json` |
| `code-server/docker-compose.yml` | +volume `~/.claude` |
| `code-server/Dockerfile` | +`socat`, +symlink `.claude.json`, +entrypoint |
| `code-server/entrypoint.sh` | Creare: socat + exec |

### Step 5 — Commit su `claude-code-config`

Dopo aver spostato `.claude.json` e aggiornato `.gitignore`:
```bash
cd /data/massimiliano/claude-code-config
git add .gitignore
git commit -m "Add .claude.json to centralized config (gitignored, symlinked)"
git push origin main
```

### Verifica

```bash
# 1. Verifica symlink host
ls -la /home/massimiliano/.claude.json  # → claude-code-config/.claude.json
cat /home/massimiliano/.claude.json | grep simoge  # deve esserci

# 2. Rebuild container
cd /data/massimiliano/code-server && docker compose up -d --build

# 3. Verifica nel container
docker exec code-server-massimiliano ss -tlnp | grep 8098
docker exec code-server-massimiliano curl -sf http://localhost:8098/sse
docker exec code-server-massimiliano cat /home/massimiliano/.claude.json | grep simoge
docker exec code-server-massimiliano ls -la /home/massimiliano/.claude/settings.json
docker exec code-server-massimiliano ls /home/massimiliano/.claude/plugins/
```
