# Piano: Audit e Bonifica Knowledge Base SOL

## Contesto

La knowledge di SOL e' distribuita su ~2.414 file .md (33 CLAUDE.md, 111 README, ~106 docs/, 6 PIANO.md, etc.) ma **nessuno e' ricercabile semanticamente**. Il sistema `mcp-vector-tools` (Ollama, 768 dim) e' **gia' completamente configurato** — modello pullato, path corretti, DB pronto — ma `embeddings_reindex` non e' mai stato chiamato.

**Scelte utente**: Ollama con `mxbai-embed-large` (1024 dim, gia' pullato), solo puntatori nei CLAUDE.md, indicizzare docs + conversazioni.

---

## Fase 1 — Configurare modello e primo reindex

### 1.0 Cambiare modello embedding: nomic-embed-text → mxbai-embed-large

**File**: `/data/massimiliano/Vari/mcp/docker-compose.yml`

Aggiungere sotto le env MCP_VECTOR esistenti:
```yaml
MCP_VECTOR_OLLAMA_MODEL: mxbai-embed-large
MCP_VECTOR_DIMENSIONS: "1024"
```

**Migrazione tabella** (768 dim → 1024 dim incompatibili):
```sql
docker exec postgres psql -U postgres -d embeddings -c "DROP TABLE IF EXISTS vector_store; DROP TABLE IF EXISTS embeddings_sync;"
```
PgVectorStore ricreera' automaticamente la tabella con 1024 dim al restart.

**CONFLITTO script Python**: due script scrivono direttamente in `vector_store` via SQL raw usando `nomic-embed-text` (768 dim). Entrambi vanno aggiornati:

1. `/data/massimiliano/kindle/paper_archive.py` riga 39: `EMBED_MODEL = "nomic-embed-text"` → `"mxbai-embed-large"`
2. `/data/massimiliano/kindle/import_keycloak.py` riga 35: `EMBED_MODEL = "nomic-embed-text"` → `"mxbai-embed-large"`

La funzione `get_embedding()` in entrambi funziona gia' con qualsiasi modello Ollama, basta cambiare il nome.

**Redeploy**: `sol deploy mcp`

### 1.1 Primo reindex

```
embeddings_reindex(type="all")
```

**Verifica immediata**:
- `embeddings_stats` → file > 0, chunk > 0
- `embeddings_search_docs("nginx reverse proxy")` → risultati con heading e file_path
- `embeddings_search_conversations("keycloak SSO")` → risultati da sessioni passate

**Se fallisce**: controllare log `docker logs simoge-mcp --tail 50` per errori Ollama/DB.

### 1.1 Path scansionati dal ChunkingService

`MCP_VECTOR_DOCS_PATH=/data/massimiliano/` → scansiona:
- `/data/massimiliano/CLAUDE.md` (root)
- `/data/massimiliano/README.md` (root)
- `/data/massimiliano/docs/*.md` (directory docs)
- `/data/massimiliano/Vari/*/CLAUDE.md` (tutti i sottoprogetti)
- `~/.claude/projects/-data-massimiliano/memory/MEMORY.md`

`MCP_VECTOR_CONVERSATIONS_PATH=/data/massimiliano/claude-shared/projects/` → scansiona:
- Tutti i `*.jsonl` ricorsivamente

### 1.2 Buco di copertura — file NON scansionati

Il `ChunkingService.findMarkdownFiles()` ha path **hardcoded**. Questi file restano fuori:
- `Vari/*/README.md` (111 README di progetto)
- `docs/progetti/*.md` (27 piani futuri)
- `docs/servizi/*.md` (8 guide servizi)
- `docs/mcp/*.md` (12 doc tool MCP)
- `docs/teoria/*.md` (5 doc teoria)
- `docs/agent-framework/**/*.md` (~20 doc)
- `Vari/*/PIANO.md` (6 piani)
- `knowledge-graph/*.go` (sorgenti, non .md ma utili)

**Azione**: modificare `ChunkingService.findMarkdownFiles()` per fare scan ricorsivo di TUTTI i `.md` sotto `docsPath`, escludendo `node_modules/`, `.git/`, `target/`, plugin cache.

**File da modificare**: `/data/massimiliano/Vari/mcp-vector-tools/src/main/java/io/github/massimilianopili/mcp/vector/ingest/ChunkingService.java`

Cambiare da hardcoded paths a:
```java
// Scan ricorsivo tutti i .md sotto docsPath
Files.walk(Paths.get(docsPath))
    .filter(p -> p.toString().endsWith(".md"))
    .filter(p -> !p.toString().contains("/node_modules/"))
    .filter(p -> !p.toString().contains("/.git/"))
    .filter(p -> !p.toString().contains("/target/"))
    .filter(p -> !p.toString().contains("/claude-shared/plugins/cache/"))
    .collect(toList());
```

Poi rebuild e redeploy: `cd /data/massimiliano/Vari/mcp-vector-tools && mvn clean install && sol deploy mcp`

---

## Fase 2 — Audit copertura graph AGE (398 nodi)

### 2.1 Nodi presenti (confermati)

- DockerService: tutti i container principali
- NginxRoute: ~50 route (tutte le path)
- AuthPattern: 6 tipi (JWT, OIDC, OAuth2 Proxy, SAML, Keycloak, Nessuna)
- Database: postgres, redis, mongodb, neo4j, libsql, age
- Command (ops): 15 comandi operativi
- KeycloakClient/Role/User (config): client, ruoli, utenti

### 2.2 Nodi potenzialmente mancanti (da verificare con query)

- Servizi systemd host: `ttyd`, `dashboard-api`, `claude-cleanup`, `wiki-embargo`, `ssh-agent`, `tailscale-watchdog`, `paper-archive-scan`
- Backup restic (config, schedule, retention)
- Tor relay/client
- Monitoring: Prometheus, Grafana, Loki, Vector, cAdvisor, node-exporter

**Azione**: verificare con `infra_search` e `graph_query`, poi aggiornare import script se mancanti.

**File**: `/data/massimiliano/kindle/import_infrastructure.py` e `/data/massimiliano/kindle/import_operational.py`

---

## Fase 3 — Bonifica CLAUDE.md (solo puntatori)

### 3.1 CLAUDE.md root (`/data/massimiliano/CLAUDE.md`, 1293 righe)

Sezioni da **sostituire con puntatori** (knowledge gia' nel graph + embeddings):

| Sezione | Righe circa | Sostituzione |
|---------|-------------|-------------|
| Routing path-based (tabella) | ~40 | `→ infra_search("NginxRoute") o embeddings_search_docs("routing path-based")` |
| Servizi e Porte (tabella) | ~50 | `→ infra_get_service("<nome>") o embeddings_search_docs("servizi porte")` |
| Rete Docker | ~10 | `→ infra_search("shared network")` |
| Auth e SSO (Keycloak dettagli) | ~80 | `→ auth_get_flow("oidc"), auth_get_client("<id>")` |
| OAuth2 Proxy dettagli | ~30 | `→ auth_get_flow("oauth2-proxy")` |
| WikiJS SSO (SAML) | ~25 | `→ auth_get_flow("saml")` |
| Nginx pattern architetturali | ~60 | `→ net_get_nginx_pattern("<name>")` |
| Configurazioni subpath | ~30 | `→ net_get_subpath("<service>")` |
| Troubleshooting | ~30 | `→ ops_troubleshoot("<problem>")` |
| Operazioni comuni | ~40 | `→ ops_get_command("<name>")` |

**Sezioni da MANTENERE** (non nel graph, servono come contesto immediato):
- Overview (hostname, IP, accessi)
- Directory Layout (struttura filesystem)
- Cloudflare Tunnel (config specifica)
- Note su Keycloak (warning e gotcha)
- Claude Code Shared Storage
- Tailscale Watchdog
- SSH Agent

**Stima riduzione**: da ~1293 a ~700-800 righe (~40% taglio).

### 3.2 CLAUDE.md dei sottoprogetti (20 file in Vari/mcp-*)

Per ogni `Vari/mcp-*/CLAUDE.md`:
- Se contiene solo info gia' nel README.md dello stesso progetto: **rimuovere**, sostituire con 3 righe:
  ```
  # <nome progetto>
  Knowledge ricercabile: `embeddings_search_docs("<nome>")`
  README.md in questa directory per dettagli completi.
  ```
- Se contiene istruzioni build/deploy specifiche non nel README: **mantenere** quelle sezioni

### 3.3 MEMORY.md

**Non toccare** — serve come contesto sessione Claude Code, ha gia' il limite 200 righe.

---

## Fase 4 — Timer periodico reindex

Creare systemd user timer per reindex automatico (come `wiki-embargo`):

**File**: `~/.config/systemd/user/embeddings-reindex.service` + `.timer`

```ini
# embeddings-reindex.service
[Unit]
Description=Reindex embeddings (docs + conversations)

[Service]
Type=oneshot
ExecStart=/usr/bin/curl -s -X POST http://localhost:8099/mcp/tool/embeddings_reindex -d '{"type":"all"}'
```

```ini
# embeddings-reindex.timer
[Unit]
Description=Periodic embeddings reindex

[Timer]
OnCalendar=*-*-* 04:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

**Nota**: il metodo esatto di invocazione dipende dal transport MCP (SSE). Potrebbe servire uno script wrapper che usa il protocollo MCP. Alternativa: aggiungere `@Scheduled` nel server MCP Java stesso.

---

## Fase 5 — Verifica end-to-end

1. `embeddings_stats` → mostra conteggi per tipo (docs, conversation)
2. `embeddings_search_docs("come configurare nginx reverse proxy")` → risultati pertinenti
3. `embeddings_search_docs("keycloak SSO SAML WikiJS")` → sezioni auth
4. `embeddings_search_conversations("preference sort bradley-terry")` → sessioni passate
5. `infra_search("nginx")` → graph AGE ancora funzionante
6. `infra_get_service("proxy-ai")` → dati strutturati servizio
7. Aprire CLAUDE.md root semplificato → verificare che i puntatori siano corretti
8. Nuova sessione Claude Code → verificare che il contesto sia sufficiente con CLAUDE.md ridotto

---

## Stato esecuzione (aggiornato 2026-03-09 00:45)

| Step | Stato | Note |
|------|-------|------|
| 1. Config mxbai-embed-large | ✅ | 3 file aggiornati (docker-compose, paper_archive, import_keycloak) |
| 2. Ollama 4GB | ✅ | Memory limit aumentato da 2g a 4g |
| 3. Fix async reindex | ✅ | Platform thread (`Thread.ofPlatform`) immune a Loom interruption |
| 4. Fix Ollama timeout 120s | ✅ | `SimpleClientHttpRequestFactory` in VectorConfig.java |
| 5. Fix scan ricorsivo .md | ✅ | `Files.walk()` + EXCLUDED_DIRS (code-server, .config, etc.) |
| 6. Primo reindex all | 🔄 | 385 JSONL / ~1530, 584 embeddings. Solo errori `context length exceeded`. |
| 7. MCP client timeout 300s | ✅ | `~/.claude.json` timeout:300 (effettivo dal prossimo restart) |
| 8. Ricerca semantica | ✅ | Verificata funzionante via MCP HTTP diretto |
| 9. Audit graph AGE | ⏳ | Prossimo |
| 10. Bonifica CLAUDE.md root | ⏳ | Prossimo |
| 11. Bonifica CLAUDE.md sottoprogetti | ⏳ | Dopo root |
| 12. Timer periodico | ⏳ | Dopo bonifica |
| 13. Test e2e finale | ⏳ | Ultimo |

## Prossimi passi — Audit AGE + Bonifica CLAUDE.md (in parallelo col reindex)

### Step 9: Audit graph AGE

**Obiettivo**: verificare che tutti i servizi/config di CLAUDE.md siano nel graph, aggiungere quelli mancanti.

**Query di verifica** (via `graph_query` o `infra_search`):
1. Servizi systemd host: `ttyd`, `dashboard-api`, `claude-cleanup`, `wiki-embargo`, `ssh-agent`, `tailscale-watchdog`, `paper-archive-scan`, `infra-graph-sync`
2. Monitoring stack: Prometheus, Grafana, Loki, Vector, cAdvisor, node-exporter, GoAccess
3. Tor: relay + client
4. WireGuard VPN
5. SearXNG
6. Backup restic

**Se mancanti**: aggiornare `/data/massimiliano/kindle/import_infrastructure.py` e/o `import_operational.py`, poi eseguire.

### Step 10: Bonifica CLAUDE.md root

**File**: `/data/massimiliano/CLAUDE.md` (~1293 righe → target ~700-800)

**Strategia "solo puntatori"**: per ogni sezione il cui contenuto è cercabile via graph o embeddings, sostituire il corpo con un blocco:
```
### <Titolo sezione>
→ `infra_get_service("<nome>")` | `auth_get_flow("<tipo>")` | `embeddings_search_docs("<query>")`
```

**Sezioni da ridurre** (ordiniate per impatto):
1. Routing path-based (tabella ~40 righe) → `infra_search("NginxRoute")`
2. Servizi e Porte (tabella ~50 righe) → `infra_get_service("<nome>")`
3. Auth e SSO dettagli (~80 righe) → `auth_get_flow()` + `auth_get_client()`
4. OAuth2 Proxy (~30 righe) → `auth_get_flow("oauth2-proxy")`
5. WikiJS SSO SAML (~25 righe) → `auth_get_flow("saml")`
6. Nginx pattern architetturali (~60 righe) → `net_get_nginx_pattern()`
7. Configurazioni subpath (~30 righe) → `net_get_subpath("<service>")`
8. Troubleshooting (~30 righe) → `ops_troubleshoot("<problem>")`
9. Operazioni comuni (~40 righe) → `ops_get_command("<name>")`

**Sezioni da MANTENERE intatte** (contesto critico non nel graph):
- Overview (hostname, IP)
- Directory Layout
- Cloudflare Tunnel config
- Note su Keycloak (warning/gotcha)
- Claude Code Shared Storage
- Tailscale Watchdog
- SSH Agent
- Accesso Visitor
- Dashboard Home

### Step 11: Bonifica CLAUDE.md sottoprogetti

Per ogni `Vari/mcp-*/CLAUDE.md` (20 file): se duplica il README → ridurre a 3 righe puntatore.

### Step 12: Timer periodico

Opzione preferita: `@Scheduled` dentro il server MCP Java (evita complessità protocollo MCP via curl).
Alternativa: systemd timer che chiama uno script Python MCP client.
