# Piano: Migrazione CLAUDE.md → AGE Knowledge Graph

## Contesto

CLAUDE.md (~1288 righe, 34 sezioni) consuma ~12k token/sessione. Il grafo `knowledge_graph` copre gia' infrastruttura Docker/nginx (274 nodi, 370 relazioni, 8 tool `infra_*`). Obiettivo: spostare le 30 sezioni rimanenti nel grafo e ridurre CLAUDE.md a ~50 righe bootstrap.

**Ricerca best practice** (2 round academic-researcher):
- Typed entities 20x piu' veloci di nodi generici con filtro property (benchmark Neo4j community)
- Relationship specifiche: 25.7ms vs 504.8ms — sempre tipi dedicati, mai RELATES_TO generico
- AGE: un solo label per nodo (no multi-label) — usare leaf types + relazioni
- Temporalita': `status` (active/deprecated) + `last_modified`, non versioned subgraphs
- `description` su OGNI nodo — critico per text matching AI agent
- Tutto nel `knowledge_graph` — AGE non supporta cross-graph query native
- Fonti: TOSCA (OASIS), OEG DevOps Infra Ontology (ISWC 2021), HPC ODA (arXiv:2507.06107)

## Schema definitivo

### Vincoli di design
1. Un solo label per nodo (vincolo AGE)
2. `description` TEXT su ogni nodo (per ricerca testuale AI)
3. `domain` su ogni nodo: `infra` | `config` | `ops` | `personal`
4. `status` su nodi mutabili: `active` | `deprecated` | `removed`
5. `last_modified` ISO timestamp su ogni nodo
6. MERGE su chiave naturale (name, client_id, path) — idempotente

### Nuovi tipi nodo

**Identity & Auth** (domain="config"):

| Label | Proprieta' chiave | Nodi | Note |
|-------|-------------------|------|------|
| `KeycloakClient` | client_id, protocol (oidc/saml), realm, redirect_uris, issuer_url, description | ~13 | |
| `KeycloakUser` | username, email, is_admin, login_source, description | ~4 | sol_root, root, massimiliano, visitor |
| `KeycloakRole` | name, client_id, description | ~5 | readonly, gitea_admin, etc. |
| `KeycloakRealm` | name, hostname, discovery_url, description | 1 | realm "sol" |

**Operational** (domain="ops"):

| Label | Proprieta' chiave | Nodi | Note |
|-------|-------------------|------|------|
| `Command` | name, command_text, category, requires_sudo, description | ~15 | restart, logs, cleanup, promote admin |
| `Troubleshooting` | name, symptom, root_cause, resolution, description | ~8 | SSO broken, nginx 502, etc. |
| `Convention` | name, rule_text, rationale, severity (must/should/prefer), description | ~12 | merge never rebase, force-recreate, etc. |
| `SystemdUnit` | name, unit_type (service/timer), scope (user/system), exec_start, description | ~7 | dashboard-api, ttyd, ssh-agent, etc. |

**Networking** (domain="config"):

| Label | Proprieta' chiave | Nodi | Note |
|-------|-------------------|------|------|
| `Endpoint` | url, type (tailscale/public/tor), auth_required, description | ~30 | Ogni URL Tailscale + pubblica |
| `SubpathConfig` | service, parameter, value, effect, description | ~20 | ROOT_URL, KC_HOSTNAME, etc. |
| `NginxPattern` | name, pattern_type, example_config, description | ~4 | lazy DNS, prefix strip, auth_request, WebSocket |
| `RedisDB` | db_number, consumer, purpose, description | ~5 | DB 0-4 (separati, non lista) |

**CI/CD** (domain="config"):

| Label | Proprieta' chiave | Nodi | Note |
|-------|-------------------|------|------|
| `CICDPipeline` | name, trigger, runner, steps, secrets, description | ~1 | Maven Central via act_runner |

**Totale nuovi nodi: ~145. Totale grafo stimato: ~420 nodi.**

### Nuove relazioni

**Auth**:
| Relazione | Da → A | Semantica |
|-----------|--------|-----------|
| `AUTHENTICATES_WITH` | DockerService → KeycloakClient | Servizio usa questo client |
| `HAS_ROLE` | KeycloakUser → KeycloakRole | Utente ha questo ruolo |
| `DEFINES_ROLE` | KeycloakClient → KeycloakRole | Client definisce questo ruolo |
| `BELONGS_TO` | KeycloakClient → KeycloakRealm | Client nel realm |
| `PROTECTED_BY` | NginxRoute → KeycloakClient | Route autenticata via client |

**Operational**:
| Relazione | Da → A | Semantica |
|-----------|--------|-----------|
| `OPERATED_BY` | DockerService → Command | Servizio gestito da comando |
| `DIAGNOSES` | Troubleshooting → DockerService | Ricetta per servizio |
| `FIRST_STEP` | Troubleshooting → Command | Primo step diagnostico |
| `PRECEDES` | Command → Command | Ordinamento step (solo troubleshooting) |
| `APPLIES_TO` | Convention → DockerService/NginxRoute | Dove si applica |
| `MANAGED_BY` | DockerService → SystemdUnit | Lifecycle gestito da unit |

**Networking**:
| Relazione | Da → A | Semantica |
|-----------|--------|-----------|
| `REACHABLE_AT` | DockerService → Endpoint | Servizio accessibile a URL |
| `CONFIGURED_WITH` | DockerService → SubpathConfig | Config subpath |
| `IMPLEMENTS` | NginxRoute → NginxPattern | Route usa pattern |
| `USES_REDIS_DB` | DockerService → RedisDB | Servizio usa DB Redis specifico |
| `TRIGGERS` | CICDPipeline → DockerService | Pipeline deploya servizio |
| `TIMER_FOR` | SystemdUnit(timer) → SystemdUnit(service) | Timer attiva servizio |

**Totale nuove relazioni: ~17 tipi**

## RAG Ibrido: Graph + Vector

**Ricerca** (academic-researcher, fonti: HybridRAG arXiv:2408.04948, GraphRAG Survey arXiv:2501.13958, Berdachuk AGE+pgvector, Neo4j HybridCypherRetriever):
- Ibrido graph+vector batte entrambi singolarmente (HybridRAG, NDCG +10-20%)
- Vector-first graph-expand e' il pattern ottimale per il nostro caso
- Embedding arricchiti (nodo + relazioni serializzate, ~100-200 token) >> embedding solo description
- AGE + pgvector sullo stesso PostgreSQL abilita unified SQL (Cypher subquery + cosine similarity)
- Re-embed completo 420 nodi = 2-3 sec locali — non over-engineerare

**Stato pgvector**: tabella `vector_store` non ancora creata (auto-init). `mcp-vector-tools` 0.2.2 nel classpath. Ollama `nomic-embed-text` (768 dim) disponibile.

### Retrieval flow

```
Query dell'agente
  |
  ├── Strutturale ("cosa dipende da X?")  → Cypher puro via graph_query
  |
  ├── Semantica ("come configuro SSO?")   → Vector top-5 → Cypher 1-hop expand
  |
  └── Ibrida ("servizi auth su PostgreSQL") → Vector + Cypher filter
```

L'agente sceglie il tool giusto: `graph_query` per struttura, tool dedicati (`auth_get_client`, `ops_troubleshoot`) per query tipiche, `embeddings_search` per semantica libera.

### Embedding arricchiti (mini-documenti)

NON embeddare solo `description`. Per ogni nodo, generare un mini-documento (~100-200 token):

```
DockerService: Gitea
Git hosting service on port 3000, exposed at /git/ via nginx.
Relationships:
- EXPOSED_VIA → /git/ (NginxRoute, OIDC nativo)
- AUTHENTICATES_WITH → gitea (KeycloakClient, OIDC)
- USES_DATABASE → postgres (Database), redis (Database, DB 0,1,2)
Properties: image=gitea/gitea:latest, directory=/data/massimiliano/gitea
```

Questo cattura sia semantica testuale che struttura del grafo nel vettore.

### Metadata pgvector

| Campo | Tipo | Uso |
|-------|------|-----|
| `label` | text | Tipo nodo (DockerService, KeycloakClient, etc.) |
| `name` | text | Nome nodo (chiave per join con AGE) |
| `domain` | text | config, ops, infra, personal |
| `embedding_hash` | text | SHA-256 del mini-documento (per staleness check) |
| `updated_at` | timestamp | Ultima modifica |

### Sync embeddings

- **On write** (negli import script): genera mini-doc → SHA-256 → se diverso da hash esistente → re-embed via Ollama API → UPSERT in vector_store
- **Batch nightly** (safety net): scan tutti i nodi AGE, rigenera mini-doc, re-embed se hash diverso. ~420 nodi = <5 sec.
- **Neighbor staleness**: quando nodo A cambia, i vicini di A hanno mini-doc stale (contengono info su A). Il batch nightly li cattura.

### Unified SQL (pattern Berdachuk)

AGE e pgvector sullo stesso database `embeddings` — join nativo:

```sql
SELECT v.content, v.metadata, 1 - (v.embedding <=> $query_vec) AS similarity
FROM vector_store v
WHERE v.metadata->>'domain' = 'auth'
  AND v.id::text IN (
    SELECT (r->>'id')::text FROM cypher('knowledge_graph', $$
      MATCH (n)-[:DEPENDS_ON*1..2]->(t {name: 'keycloak'})
      RETURN {id: id(n)}
    $$) AS (r agtype)
  )
ORDER BY v.embedding <=> $query_vec LIMIT 5;
```

## Implementazione — 5 Wave (+Wave 0)

### Wave 0 — Attivare pgvector (~30min)

1. Aggiornare `/data/massimiliano/Vari/mcp/docker-compose.yml`:
   ```yaml
   MCP_VECTOR_ENABLED: "true"
   MCP_VECTOR_PROVIDER: ollama
   MCP_VECTOR_OLLAMA_MODEL: nomic-embed-text
   MCP_VECTOR_OLLAMA_BASE_URL: http://ollama:11434
   ```
2. Rebuild + redeploy simoge-mcp
3. Verificare: `embeddings_stats()` ritorna tabella vuota (0 documenti)

### Wave 1 — SSO e Keycloak (~3h)

**1a. `import_keycloak.py`** — Creare `/data/massimiliano/kindle/import_keycloak.py`
- 1 KeycloakRealm + 13 KeycloakClient + 5 KeycloakRole + 4 KeycloakUser
- Relazioni: AUTHENTICATES_WITH, BELONGS_TO, DEFINES_ROLE, HAS_ROLE, PROTECTED_BY
- Pattern: identico a import_infrastructure.py (MERGE, --dry-run, batch psql)
- Dati: hardcoded da CLAUDE.md (13 client noti con protocol, redirect_uris, etc.)
- Embedding: dopo MERGE, genera embedding di `description` per ogni nodo → INSERT in vector_store via Ollama API

**1b. `AuthTools.java`** — Creare `Vari/mcp-graph-tools/src/.../AuthTools.java`
- `auth_get_client(client_id)` — dettagli client + flow + utenti
- `auth_get_flow(name)` — flusso auth completo con servizi coinvolti
- `auth_list_clients()` — tutti i client con protocol
- `auth_get_user(username)` — info utente + ruoli + client associati

**1c.** `GraphToolsAutoConfiguration.java`: +AuthTools @Import + bean

### Wave 2 — Conoscenza procedurale (~4h)

**2a. `import_operational.py`** — Creare `/data/massimiliano/kindle/import_operational.py`
- ~15 Command + ~8 Troubleshooting (con chain FIRST_STEP/PRECEDES) + ~12 Convention + 7 SystemdUnit
- Relazioni: OPERATED_BY, DIAGNOSES, FIRST_STEP, PRECEDES, APPLIES_TO, MANAGED_BY, TIMER_FOR
- Dati: hardcoded da CLAUDE.md + MEMORY.md
- Embedding: description di ogni Command/Troubleshooting/Convention → vector_store

**2b. `OpsTools.java`** — Creare `Vari/mcp-graph-tools/src/.../OpsTools.java`
- `ops_get_command(name_or_category)` — comando con syntax
- `ops_troubleshoot(problem_or_service)` — cerca soluzioni, segue chain PRECEDES
- `ops_get_convention(category)` — convenzioni per area
- `ops_list_systemd()` — servizi systemd user-level

### Wave 3 — Networking e subpath (~3h)

**3a. Estendere `import_infrastructure.py`**
- +30 Endpoint + +20 SubpathConfig + +4 NginxPattern + +5 RedisDB + +1 CICDPipeline
- Relazioni: REACHABLE_AT, CONFIGURED_WITH, IMPLEMENTS, USES_REDIS_DB, TRIGGERS

**3b. `NetTools.java`** — Creare `Vari/mcp-graph-tools/src/.../NetTools.java`
- `net_get_endpoint(service_or_url)` — URL Tailscale + pubblica per servizio
- `net_get_subpath(service)` — config subpath
- `net_get_nginx_pattern(name)` — pattern architetturale

### Wave 4 — Build, deploy, test (~2h)

```bash
cd /data/massimiliano/Vari/mcp-graph-tools && mvn clean install -Dgpg.skip=true
cd /data/massimiliano/Vari/mcp && mvn clean package -DskipTests
deploy-mcp
python3 import_keycloak.py && python3 import_operational.py && python3 import_infrastructure.py
```

Test:
- `auth_get_client("gitea")` → redirect URIs, flow, utenti
- `ops_troubleshoot("nginx 502")` → causa + soluzione + step
- `net_get_endpoint("keycloak")` → URL :8443 Tailscale + /auth/ pubblica
- `graph_stats(backend="age")` → ~420 nodi totali

### Wave 5 — Riduzione CLAUDE.md (~2h)

Target: **< 50 righe**. Contenuto residuo: directory base, rete Docker shared, lista tool MCP.

| Sezione eliminata | Tool sostitutivo |
|-------------------|------------------|
| Routing, Servizi e Porte | `infra_port_map()`, `infra_get_service()` |
| SSO, OAuth2, SAML, JWT | `auth_get_client()`, `auth_get_flow()` |
| Utenti | `auth_get_user()` |
| Operazioni comuni | `ops_get_command()` |
| Troubleshooting | `ops_troubleshoot()` |
| Convenzioni | `ops_get_convention()` |
| Subpath config | `net_get_subpath()` |
| Rete/Tailscale/Cloudflare | `net_get_endpoint()` |
| Pattern nginx | `net_get_nginx_pattern()` |
| Redis, PostgreSQL | `infra_get_db_consumers()` |

## File critici

| File | Azione | Wave |
|------|--------|------|
| `kindle/import_keycloak.py` | Creare | 1 |
| `kindle/import_operational.py` | Creare | 2 |
| `kindle/import_infrastructure.py` | Estendere | 3 |
| `Vari/mcp-graph-tools/.../AuthTools.java` | Creare | 1 |
| `Vari/mcp-graph-tools/.../OpsTools.java` | Creare | 2 |
| `Vari/mcp-graph-tools/.../NetTools.java` | Creare | 3 |
| `Vari/mcp-graph-tools/.../GraphToolsAutoConfiguration.java` | +3 @Import + 3 bean | 1-3 |
| `CLAUDE.md` | Ridurre a ~50 righe | 5 |
| `MEMORY.md` | Aggiornare con nuovi tool | 5 |

## Pattern da riutilizzare

- **InfraTools.java** → template per AuthTools/OpsTools/NetTools (`Map<String, CypherExecutor>`, `RETURN {k:v}`)
- **import_infrastructure.py** → template per import script (MERGE, --dry-run, batch psql, timestamp ISO)
- **GraphToolsAutoConfiguration.java** → pattern @Import + ToolCallbackProvider gia' rodato

## Stima

| Wave | Ore |
|------|-----|
| 1 — SSO e Keycloak | 3 |
| 2 — Conoscenza procedurale | 4 |
| 3 — Networking e subpath | 3 |
| 4 — Build, deploy, test | 2 |
| 5 — Riduzione CLAUDE.md | 2 |
| 0 — Attivare pgvector | 0.5 |
| **Totale** | **~14.5 ore** |
