# Piano: Migrazione completa CLAUDE.md → AGE Knowledge Graph

## Contesto

CLAUDE.md (~1288 righe, 34 sezioni) è l'unica fonte di verità operativa del server SOL. Consumo context window: ~12k token a ogni sessione. Obiettivo: **eliminare completamente CLAUDE.md** spostando tutta la conoscenza nel grafo AGE `knowledge_graph`, interrogabile via MCP tool.

**Stato attuale** (completato nelle fasi 0-4 precedenti):
- AGE `knowledge_graph`: 274 nodi (173 personal + 101 infra), 370 relazioni
- 8 MCP tool `infra_*` funzionanti (InfraTools.java)
- Import automatico infra: `import_infrastructure.py` + systemd timer giornaliero
- Domain tagging: `domain="personal"` vs `domain="infra"` su tutti i nodi

**Cosa manca**: 30 delle 34 sezioni di CLAUDE.md NON hanno rappresentazione AGE (SSO, utenti, convenzioni, troubleshooting, comandi, networking, CI/CD, systemd, subpath config).

**Insight da agent-framework**: ontologia ricca con 8 entity types (Concept, Entity, Framework, Pattern, Principle, Technique, Metaphor, Person), 3 grafi AGE separati, RAG ibrido pgvector+graph. Pattern riutilizzabili: gerarchia tipi, domain tagging, relazioni tipizzate.

---

## Ontologia estesa

### Nuovi tipi nodo (domain="config")

| Label | Proprietà | Sezioni CLAUDE.md coperte |
|-------|-----------|---------------------------|
| `KeycloakClient` | `client_id, type, realm, redirect_uris[], issuer_url, callback_url, notes` | SSO, OAuth2 Proxy, WikiJS SAML, Gitea OIDC |
| `User` | `username, email, source, is_admin, roles[], notes` | Utenti Keycloak, Utenti Gitea |
| `AuthFlow` | `name, type, steps[], services[]` | Pattern auth (OIDC, SAML, OAuth2 Proxy, JWT) |
| `SystemdService` | `name, unit_file, type, description, exec_start, user_level` | Dashboard API, ttyd, ssh-agent, claude-cleanup, wiki-embargo, infra-graph-sync |
| `Convention` | `name, category, rule, rationale` | Convenzioni operative (git, docker, nginx, backup) |
| `Command` | `name, syntax, description, category, example` | Operazioni comuni, comandi utili |
| `Troubleshooting` | `problem, cause, solution, service` | Sezione Troubleshooting |
| `NetworkEndpoint` | `url, protocol, scope, service, notes` | Tailscale URLs, Cloudflare Tunnel config |
| `CICDPipeline` | `name, trigger, runner, steps[], secrets[]` | Gitea Actions, act_runner |
| `NginxPattern` | `name, type, description, example` | Pattern architetturali nginx |
| `SubpathConfig` | `service, parameter, value, effect` | Configurazioni subpath servizi |
| `RedisDB` | `db_number, consumer, purpose` | Redis database partitioning |

### Nuove relazioni

| Relazione | Da → A | Scopo |
|-----------|--------|-------|
| `AUTHENTICATES_VIA` | KeycloakClient → AuthFlow | Client usa un flusso auth |
| `HAS_USER` | KeycloakClient → User | Utente registrato su client |
| `MANAGED_BY` | SystemdService → DockerService/Host | Chi gestisce il servizio |
| `APPLIES_TO` | Convention → DockerService/NginxRoute | Dove si applica una convenzione |
| `RESOLVES` | Troubleshooting → DockerService | Problema risolto per servizio |
| `CONFIGURED_WITH` | DockerService → SubpathConfig | Config subpath del servizio |
| `LISTENS_ON` | DockerService → NetworkEndpoint | Endpoint di ascolto |
| `TRIGGERS` | CICDPipeline → DockerService | Pipeline deploya servizio |
| `USES_REDIS_DB` | DockerService → RedisDB | Servizio usa un DB Redis specifico |

---

## Wave 1 — SSO e Keycloak (~3h)

### 1a. Script `import_keycloak.py`

**File**: `/data/massimiliano/kindle/import_keycloak.py`

Sorgente dati: CLAUDE.md sezioni "Autenticazione e SSO", "OAuth2 Proxy", "WikiJS SSO", "Gitea SSO", "Utenti Gitea", "Mapping ruoli".

Nodi da creare:
- 13 `KeycloakClient` (gitea, oauth2-proxy, wiki, dashboard-chat, go-filemanager, knowledge-graph, server-api, nvidia_client, claude_client, codex_client, grafana, minio, jenkins)
- 4 `AuthFlow` (OIDC nativo, SAML, OAuth2 Proxy → Keycloak, JWT Bearer → Gateway)
- 3 `User` (sol_root, root, massimiliano + visitor)
- Relazioni: `AUTHENTICATES_VIA`, `HAS_USER`, `USES_AUTH` (da DockerService esistenti)

Pattern psycopg2 identico a `import_infrastructure.py`. Supporta `--dry-run`.

### 1b. MCP tool `auth_*`

**File**: `/data/massimiliano/Vari/mcp-graph-tools/src/main/java/io/github/massimilianopili/mcp/graph/AuthTools.java`

| Tool | Query Cypher | Sostituisce |
|------|-------------|-------------|
| `auth_get_client(client_id)` | `MATCH (c:KeycloakClient {client_id: $id})` + relazioni | Sezione SSO client details |
| `auth_get_flow(name)` | `MATCH (f:AuthFlow {name: $name})-[:AUTHENTICATES_VIA]-(c)` | Pattern auth completi |
| `auth_list_clients()` | `MATCH (c:KeycloakClient) RETURN collect(...)` | Tabella client Keycloak |
| `auth_get_user(username)` | `MATCH (u:User {username: $name})` + ruoli + client | Info utente |

### 1c. Registrazione in GraphToolsAutoConfiguration

Aggiungere `AuthTools.class` a `@Import` e nuovo `ToolCallbackProvider` bean.

**File da modificare**:
- `Vari/mcp-graph-tools/src/main/java/.../GraphToolsAutoConfiguration.java` — `@Import` + bean
- `Vari/mcp-graph-tools/src/main/java/.../AuthTools.java` — **nuovo**

**Verifica**: `auth_get_client("gitea")` ritorna client con redirect URIs, flow type, utenti associati.

---

## Wave 2 — Conoscenza procedurale (~4h)

### 2a. Script `import_operational.py`

**File**: `/data/massimiliano/kindle/import_operational.py`

Sorgente: CLAUDE.md sezioni "Operazioni comuni", "Troubleshooting", "Note su Keycloak/Cloudflare", "Convenzioni" (da MEMORY.md).

Nodi da creare:
- ~15 `Command` (restart Docker, restart systemd, logs, cleanup Claude, promuovi admin, token runner, ecc.)
- ~8 `Troubleshooting` (SSO non funziona, OAuth2 500, nginx 500/502, Gitea 404, Keycloak discovery, container disconnessi)
- ~12 `Convention` (git merge never rebase, docker shared network, nginx force-recreate, plan mode first, docs Italian, ecc.)
- 7 `SystemdService` (dashboard-api, ttyd, ssh-agent, claude-cleanup, wiki-embargo, infra-graph-sync, tailscale-watchdog)

### 2b. MCP tool `ops_*`

**File**: `/data/massimiliano/Vari/mcp-graph-tools/src/main/java/io/github/massimilianopili/mcp/graph/OpsTools.java`

| Tool | Scopo | Sostituisce |
|------|-------|-------------|
| `ops_get_command(name_or_category)` | Comando operativo con syntax | "Operazioni comuni" |
| `ops_troubleshoot(problem_or_service)` | Cerca soluzioni per problema/servizio | "Troubleshooting" |
| `ops_get_convention(category)` | Convenzioni per categoria | Sparse in CLAUDE.md + MEMORY.md |
| `ops_list_systemd()` | Tutti i servizi systemd user-level | Sezioni dashboard-api, wiki-embargo, ecc. |

### 2c. Registrazione

`@Import` in `GraphToolsAutoConfiguration` + `ToolCallbackProvider` bean per `OpsTools`.

**File da modificare**:
- `Vari/mcp-graph-tools/src/main/java/.../GraphToolsAutoConfiguration.java`
- `Vari/mcp-graph-tools/src/main/java/.../OpsTools.java` — **nuovo**

**Verifica**: `ops_troubleshoot("nginx 502")` ritorna causa + soluzione + servizi coinvolti.

---

## Wave 3 — Networking e subpath (~3h)

### 3a. Estendere `import_infrastructure.py`

Aggiungere a `import_infrastructure.py` esistente:

- `NetworkEndpoint` per ogni URL Tailscale (tabella completa) + Cloudflare Tunnel ingress
- `SubpathConfig` per ogni riga della tabella "Configurazioni subpath"
- `NginxPattern` per i 4 pattern architetturali (lazy DNS, prefix stripping, auth_request, WebSocket)
- `RedisDB` per i 5 database Redis (DB 0-4)
- `CICDPipeline` per il workflow Maven Central (act_runner)

Relazioni: `LISTENS_ON`, `CONFIGURED_WITH`, `USES_REDIS_DB`, `TRIGGERS`.

### 3b. MCP tool `net_*`

**File**: `/data/massimiliano/Vari/mcp-graph-tools/src/main/java/io/github/massimilianopili/mcp/graph/NetTools.java`

| Tool | Scopo |
|------|-------|
| `net_get_endpoint(service_or_url)` | URL Tailscale + pubblico per un servizio |
| `net_get_subpath(service)` | Config subpath di un servizio |
| `net_get_nginx_pattern(name)` | Pattern architetturale nginx |

**File da modificare**:
- `Vari/mcp-graph-tools/src/main/java/.../GraphToolsAutoConfiguration.java`
- `Vari/mcp-graph-tools/src/main/java/.../NetTools.java` — **nuovo**
- `kindle/import_infrastructure.py` — estendere

**Verifica**: `net_get_endpoint("gitea")` ritorna sia URL Tailscale che pubblica, auth, porta.

---

## Wave 4 — Build, deploy e test integrato (~2h)

### 4a. Build chain

```bash
cd /data/massimiliano/Vari/mcp-graph-tools && /opt/maven/bin/mvn clean install -Dgpg.skip=true
cd /data/massimiliano/Vari/mcp && /opt/maven/bin/mvn clean package -DskipTests
deploy-mcp
```

### 4b. Import dati

```bash
python3 /data/massimiliano/kindle/import_keycloak.py
python3 /data/massimiliano/kindle/import_operational.py
python3 /data/massimiliano/kindle/import_infrastructure.py  # re-run con estensioni Wave 3
```

### 4c. Test completo

Verificare ogni tool con query reali:
- `auth_get_client("oauth2-proxy")` → redirect URIs, flow OAuth2 Proxy
- `ops_troubleshoot("SSO")` → soluzioni per problemi SSO
- `ops_get_convention("docker")` → convenzioni Docker
- `net_get_endpoint("keycloak")` → URL Tailscale :8443 + pubblica /auth/
- `infra_port_map()` → mappa completa (deve includere nuovi endpoint)

### 4d. Knowledge Graph UI

Estendere `knowledge-graph/age.go` per le nuove label + `static/index.html` per colori CSS:
- `KeycloakClient` → viola
- `SystemdService` → arancione
- `Convention/Command/Troubleshooting` → giallo
- `NetworkEndpoint` → ciano

---

## Wave 5 — Riduzione CLAUDE.md (~2h)

### Target: CLAUDE.md < 50 righe

Contenuto residuo:
```markdown
# Server SOL — Bootstrap

## Knowledge Graph
Tutte le informazioni infrastrutturali, di configurazione, operative e di troubleshooting
sono nel grafo AGE `knowledge_graph` (database `embeddings`, container `postgres`).

### Tool MCP disponibili
- `infra_*` — servizi Docker, route nginx, auth, database, porte
- `auth_*` — client Keycloak, flussi SSO, utenti
- `ops_*` — comandi operativi, troubleshooting, convenzioni, servizi systemd
- `net_*` — endpoint di rete, configurazioni subpath, pattern nginx
- `graph_query` — query Cypher dirette (backend: "age")
- `graph_write` — scrittura nodi/relazioni (backend: "age")

### Directory base
`/data/massimiliano/`

### Rete Docker
Tutti i container su rete `shared`. DNS Docker per nome container.
```

### Sezioni eliminate (con mapping)

| Sezione | Tool sostitutivo |
|---------|-----------------|
| Routing path-based | `infra_port_map()`, `infra_get_route()` |
| Servizi e Porte | `infra_get_service()`, `infra_port_map()` |
| Autenticazione e SSO | `auth_get_client()`, `auth_get_flow()` |
| OAuth2 Proxy | `auth_get_client("oauth2-proxy")` |
| WikiJS SSO | `auth_get_client("wiki")` |
| Gitea SSO | `auth_get_client("gitea")` |
| Utenti Gitea | `auth_get_user()` |
| Operazioni comuni | `ops_get_command()` |
| Troubleshooting | `ops_troubleshoot()` |
| Configurazioni subpath | `net_get_subpath()` |
| Rete Docker + Tailscale | `net_get_endpoint()` |
| Pattern nginx | `net_get_nginx_pattern()` |
| Dashboard API | `infra_get_service("dashboard-api")` + `ops_list_systemd()` |
| Redis | `infra_get_db_consumers("redis")` |
| PostgreSQL | `infra_get_db_consumers("postgres")` |
| Cloudflare Tunnel | `net_get_endpoint("cloudflared")` |
| Tor | `infra_get_service("tor-relay")` |
| WireGuard | `infra_get_service("wg-manager")` |

### Aggiornamento MEMORY.md

Aggiornare la sezione "Knowledge Graph (FONTE PRIMARIA)" con i nuovi tool `auth_*`, `ops_*`, `net_*`.

---

## File critici

| File | Azione | Wave |
|------|--------|------|
| `kindle/import_keycloak.py` | **CREARE** | 1 |
| `kindle/import_operational.py` | **CREARE** | 2 |
| `kindle/import_infrastructure.py` | Estendere (NetworkEndpoint, SubpathConfig, NginxPattern, RedisDB, CICD) | 3 |
| `Vari/mcp-graph-tools/.../AuthTools.java` | **CREARE** (4 tool) | 1 |
| `Vari/mcp-graph-tools/.../OpsTools.java` | **CREARE** (4 tool) | 2 |
| `Vari/mcp-graph-tools/.../NetTools.java` | **CREARE** (3 tool) | 3 |
| `Vari/mcp-graph-tools/.../GraphToolsAutoConfiguration.java` | Aggiungere @Import + bean per AuthTools, OpsTools, NetTools | 1-3 |
| `knowledge-graph/age.go` | Nuove label nel query Graph() | 4 |
| `knowledge-graph/static/index.html` | Colori CSS nuove label | 4 |
| `CLAUDE.md` | Ridurre a ~50 righe bootstrap | 5 |
| `MEMORY.md` | Aggiornare con nuovi tool | 5 |

## Pattern da riutilizzare

- **InfraTools.java** — template per AuthTools/OpsTools/NetTools (stessa struttura: `@ConditionalOnProperty`, `Map<String, CypherExecutor>`, `RETURN {k: v}` map)
- **import_infrastructure.py** — template per import_keycloak.py e import_operational.py (psycopg2, MERGE+SET, `--dry-run`, timestamp ISO)
- **Agent-framework ontologia** — gerarchia tipi, proprietà `domain` su ogni nodo, relazioni tipizzate

## Verifica end-to-end

1. **Dopo Wave 1**: `graph_stats` mostra +20 nodi (KeycloakClient, User, AuthFlow). `auth_get_client("gitea")` ritorna dati completi.
2. **Dopo Wave 2**: `ops_troubleshoot("nginx 502")` ritorna causa+soluzione. `ops_get_convention("git")` ritorna "merge never rebase".
3. **Dopo Wave 3**: `net_get_endpoint("keycloak")` ritorna URL Tailscale+pubblica. Total nodi >350.
4. **Dopo Wave 4**: D3.js mostra nuovi nodi colorati. Tutti i tool rispondono.
5. **Dopo Wave 5**: CLAUDE.md < 50 righe. Nuova sessione Claude funziona SENZA leggere le vecchie sezioni.

## Stima

| Wave | Ore |
|------|-----|
| 1 — SSO e Keycloak | 3 |
| 2 — Conoscenza procedurale | 4 |
| 3 — Networking e subpath | 3 |
| 4 — Build, deploy, test, UI | 2 |
| 5 — Riduzione CLAUDE.md | 2 |
| **Totale** | **~14 ore** |
