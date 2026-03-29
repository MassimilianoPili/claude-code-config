# Piano: Collegare i nodi orfani nel knowledge graph KORE

## Context

Il knowledge graph AGE (`knowledge_graph`) ha **802 nodi** e **730 edge**, ma **108 nodi sono completamente orfani** (grado 0). Questo degrada la visualizzazione D3.js e rende inutili quei nodi per la navigazione grafo. L'obiettivo è collegare ogni orfano al cluster più vicino modificando gli import script esistenti.

## Censimento orfani per causa

| Nodi | Tipo | Script | Causa |
|------|------|--------|-------|
| 55 | Source | import_rationalist.py | Feed OPML senza author mappato → nessun WRITES_FOR |
| 12 | Convention | import_operational.py | **Nessun codice** crea relazioni da Convention |
| 11 | DockerService | import_infrastructure.py | Non in SERVICE_USES_DB, no depends_on, backend non mappato |
| 7 | Command | import_operational.py | `services: []` vuoto → nessun APPLIES_TO |
| 6 | SystemdService | import_operational.py | `services: []` vuoto → nessun MANAGES |
| 4 | NginxPattern | import_networking.py | **Nessun codice** crea relazioni per NginxPattern |
| 4 | Book | import_rationalist.py | Autore non in dizionario AUTHORS |
| 2 | Endpoint | import_networking.py | service="goaccess" non esiste come DockerService |
| 2 | KeycloakUser | import_keycloak.py | "root"/"massimiliano" non in USER_ROLES |
| 1 | Concept | import_rationalist.py | "Philosophy of Mind" senza parent/related |
| 1 | Troubleshooting | import_operational.py | `services: []` vuoto |
| 1 | AuthPattern | import_infrastructure.py | Nodo di test |

## Piano di intervento (per script)

### 1. `import_operational.py` — Convention, Command, SystemdService, Troubleshooting (27 orfani)

**Convention (12)** — Aggiungere relazione `GOVERNS` → DockerService o categoria:
- `docker_shared_network` → GOVERNS → tutti i DockerService (o un nodo "Docker" generico)
- `nginx_force_recreate` → GOVERNS → nginx
- `git_merge_never_rebase`, `git_push_gitea_only` → GOVERNS → gitea
- `backup_restic_nightly` → GOVERNS → generico (o SystemdService "restic")
- `plan_mode_first`, `sequential_work`, `infra_first`, `radical_sincerity`, `docs_italian`, `sudo_ask_first`, `no_file_revert` → GOVERNS → nodo generico "claude-code" o "workflow"

**Azione**: aggiungere un dizionario `CONVENTION_TARGETS` e un loop in `generate_relationship_statements()` che crei `GOVERNS`.

**Command (7)** — Popolare il campo `services` per ogni comando:
- `restart_docker_service` → tutti i DockerService (generico)
- `docker_logs` → tutti i DockerService
- `systemd_logs` → tutti i SystemdService
- `claude_cleanup` → "claude-code" o "code-server"
- `ssh_ensure` → "ssh-agent"
- `network_inspect` → "nginx"
- `restart_host_services` → tutti i SystemdService

**Azione**: popolare `services: [...]` nei dizionari Command esistenti.

**SystemdService (6)** — Aggiungere `services` mapping:
- `dashboard-api` → MANAGES → nessun Docker (è host), ma DEPENDS_ON → nginx (exposed via nginx)
- `ttyd` → DEPENDS_ON → dashboard-api
- `ssh-agent` → USED_BY → gitea, code-server
- `claude-cleanup` → MANAGES → code-server
- `infra-graph-sync` → MANAGES → postgres
- `tailscale-watchdog` → nessun Docker diretto
- `paper-archive-scan` → MANAGES → postgres, wikijs

**Azione**: popolare `services` e/o aggiungere nuovi tipi di relazione.

**Troubleshooting (1)** — Popolare `services` per "Container non si connettono" → target: tutti i DockerService sulla rete shared.

### 2. `import_rationalist.py` — Source, Book, Concept (60 orfani)

**Source (55)** — Ogni Source RSS deve avere almeno una relazione. Due approcci:
- **Approccio A**: creare `COVERS` → Concept basandosi su keyword matching del nome/URL del feed (es. "Bayesian Investor Blog" → COVERS → "Bayesian Reasoning")
- **Approccio B** (più semplice): creare un mapping `SOURCE_TOPICS` che associa ogni Source a 1-2 Concept

**Azione**: aggiungere dizionario `SOURCE_TOPICS` con mapping Source→Concept, e loop per creare `COVERS`.

**Book (4)** — Aggiungere gli autori mancanti al dizionario AUTHORS, oppure creare direttamente WROTE relazioni con mapping esplicito.

**Concept "Philosophy of Mind" (1)** — Verificare se ha RELATED_TO in CONCEPT_RELATIONS, altrimenti aggiungere.

### 3. `import_infrastructure.py` — DockerService (11 orfani)

**DockerService isolati**: redis, ollama, prometheus, loki, node-exporter, cadvisor, vector, tor-relay, wg-manager, claude-proxy, intellij.

**Azione**: estendere `SERVICE_USES_DB` e il mapping backend hostname (linee 335-342) per includere:
- `redis` → USES_DATABASE → Database "redis" (già esiste)
- `ollama` → aggiungere EXPOSED_VIA o DEPENDS_ON
- `prometheus`, `loki`, `node-exporter`, `cadvisor`, `vector` → chain DEPENDS_ON (stack monitoring)
- `tor-relay` → standalone, ma almeno EXPOSED_VIA se ha route nginx
- `wg-manager` → standalone, EXPOSED_VIA
- `claude-proxy` → DEPENDS_ON proxy-ai? O rinominare

**Azione**: aggiungere entries in SERVICE_USES_DB e/o creare `ADDITIONAL_DEPS` per relazioni DEPENDS_ON manuali.

### 4. `import_networking.py` — NginxPattern, Endpoint (6 orfani)

**NginxPattern (4)** — `lazy_dns`, `prefix_stripping`, `auth_request_oauth2`, `auth_request_jwt`

**Azione**: aggiungere loop che crei `USES_PATTERN` da NginxRoute → NginxPattern, basato su pattern matching nel nginx.conf (es. route con `set $var` → usa `lazy_dns`).

**Endpoint (2)** — Un Endpoint senza nome e "MCP Remote". Verificare il service associato e fixare.

### 5. `import_keycloak.py` — KeycloakUser (2 orfani)

**KeycloakUser "root" e "massimiliano"** — Aggiungere entries in `USER_ROLES`:
```python
"root": ["admin"],
"massimiliano": ["admin"]
```

### 6. `import_infrastructure.py` — AuthPattern test (1 orfano)

**"Test AuthPattern"** — Eliminare il nodo di test oppure collegarlo.

**Azione**: rimuovere dal codice.

## File da modificare

1. `/data/massimiliano/kindle/import_operational.py` — Convention targets, Command services, SystemdService services
2. `/data/massimiliano/kindle/import_rationalist.py` — SOURCE_TOPICS mapping, Book authors, Concept relations
3. `/data/massimiliano/kindle/import_infrastructure.py` — SERVICE_USES_DB, ADDITIONAL_DEPS, rimuovere test AuthPattern
4. `/data/massimiliano/kindle/import_networking.py` — NginxPattern→NginxRoute relationships, fix Endpoint orfani
5. `/data/massimiliano/kindle/import_keycloak.py` — USER_ROLES entries per root/massimiliano

## Ordine di esecuzione

1. **import_operational.py** (27 orfani — impatto maggiore)
2. **import_rationalist.py** (60 orfani — il più numeroso ma richiede mapping manuali)
3. **import_infrastructure.py** (12 orfani)
4. **import_networking.py** (6 orfani)
5. **import_keycloak.py** (2 orfani)

## Verifica

1. Eseguire ogni script con `python3 <script> --quiet` dopo le modifiche
2. Verificare con query: `MATCH (n) WHERE NOT EXISTS((n)--()) RETURN {label: label(n), name: n.name}` — deve tornare 0 risultati (o quasi)
3. Verificare visivamente su `notes.massimilianopili.com` che i cluster siano collegati
4. Controllare che il conteggio nodi resti ~802 (non duplicati)
