# Piano: 4 Librerie MCP per Repository Management

## Context

Ogni volta che serve creare un repo su Gitea, pushare su GitHub, o pubblicare su Maven Central/npm, è una lotta manuale con token, API, e script frammentati. Servono 4 librerie MCP dedicate (una per provider) che rendano queste operazioni tool MCP invocabili da qualsiasi sessione Claude Code.

Pattern esistente: 15 librerie Spring Boot MCP (`mcp-*-tools`), `@ReactiveTool` + `@AutoConfiguration` + `@ConditionalOnProperty`. ~234 tool registrati su `simoge-mcp`.

---

## Le 4 librerie

### 1. `mcp-gitea-tools` — Gitea API

**Properties:**
```properties
mcp.gitea.url=${MCP_GITEA_URL:http://gitea:3000/api/v1}
mcp.gitea.token=${MCP_GITEA_TOKEN:}
mcp.gitea.default-owner=${MCP_GITEA_OWNER:sol_root}
```

**Tool:**
| Tool | Descrizione |
|------|-------------|
| `gitea_list_repos(owner?)` | Lista repository |
| `gitea_create_repo(name, description, private?)` | Crea repository |
| `gitea_delete_repo(owner, name)` | Cancella repository |
| `gitea_get_repo(owner, name)` | Dettagli repository |
| `gitea_list_branches(owner, name)` | Lista branch |
| `gitea_create_release(owner, name, tag, title, body)` | Crea release |
| `gitea_list_releases(owner, name)` | Lista release |
| `gitea_set_secret(owner, name, secretName, value)` | Set Actions secret |
| `gitea_get_file(owner, name, path, ref?)` | Leggi file da repo |
| `gitea_list_tokens()` | Lista API token dell'utente |
| `gitea_create_token(name, scopes)` | Genera nuovo API token |
| `gitea_create_tag(owner, name, tag, message?)` | Crea tag (triggera CI/CD) |
| `gitea_list_tags(owner, name)` | Lista tag |
| `gitea_delete_tag(owner, name, tag)` | Cancella tag |
| `gitea_list_workflows(owner, name)` | Lista workflow Actions |
| `gitea_list_workflow_runs(owner, name, workflow?)` | Lista esecuzioni workflow |
| `gitea_get_workflow_run(owner, name, runId)` | Stato/log di un run |
| `gitea_trigger_workflow(owner, name, workflow, ref?)` | Triggera workflow manualmente |

**Auth:** Header `Authorization: token {token}` (Gitea API token)
**API base:** `GET/POST/PUT/DELETE /api/v1/...`

---

### 2. `mcp-github-tools` — GitHub API

**Properties:**
```properties
mcp.github.token=${MCP_GITHUB_TOKEN:}
mcp.github.default-owner=${MCP_GITHUB_OWNER:massimilianopili}
```

**Tool:**
| Tool | Descrizione |
|------|-------------|
| `github_list_repos(owner?)` | Lista repository |
| `github_create_repo(name, description, private?)` | Crea repository |
| `github_delete_repo(owner, name)` | Cancella repository |
| `github_get_repo(owner, name)` | Dettagli repo (stars, forks, etc.) |
| `github_create_release(owner, name, tag, title, body)` | Crea release |
| `github_list_releases(owner, name)` | Lista release |
| `github_get_file(owner, name, path, ref?)` | Leggi file da repo |
| `github_list_issues(owner, name, state?)` | Lista issue |
| `github_create_issue(owner, name, title, body)` | Crea issue |
| `github_list_pulls(owner, name, state?)` | Lista PR |
| `github_create_pull(owner, name, title, body, head, base)` | Crea PR |
| `github_create_gist(description, files, public?)` | Crea Gist |
| `github_add_comment(owner, name, issueNumber, body)` | Commenta su issue/PR |
| `github_create_tag(owner, name, tag, sha, message?)` | Crea tag |
| `github_list_tags(owner, name)` | Lista tag |
| `github_list_workflows(owner, name)` | Lista workflow Actions |
| `github_list_workflow_runs(owner, name, workflow?)` | Lista esecuzioni workflow |
| `github_get_workflow_run(owner, name, runId)` | Stato/log di un run |
| `github_trigger_workflow(owner, name, workflow, ref?, inputs?)` | Triggera workflow (`workflow_dispatch`) |

**Auth:** Header `Authorization: Bearer {token}` (GitHub PAT)
**API base:** `https://api.github.com/...`

---

### 3. `mcp-maven-tools` — Maven Central Publishing

**Properties:**
```properties
mcp.maven.central-token=${MCP_MAVEN_CENTRAL_TOKEN:}
mcp.maven.search-url=${MCP_MAVEN_SEARCH_URL:https://search.maven.org}
```

**Tool:**
| Tool | Descrizione |
|------|-------------|
| `maven_search(query, groupId?, artifactId?)` | Cerca artifact su Maven Central |
| `maven_get_artifact(groupId, artifactId)` | Info artifact (versioni, date) |
| `maven_get_latest_version(groupId, artifactId)` | Ultima versione pubblicata |
| `maven_list_versions(groupId, artifactId)` | Tutte le versioni |
| `maven_check_publication(groupId, artifactId, version)` | Verifica se una versione è pubblicata |

**Note:** La pubblicazione vera avviene via `mvn deploy` (GPG signing richiede accesso al keyring locale). I tool MCP servono per *verificare* e *cercare*, non per pubblicare direttamente. Il deploy resta nel CI/CD (Gitea Actions) o via `deploy-mcp` script.

**Auth:** Token opzionale per Sonatype Central API (query è pubblica)
**API base:** `https://search.maven.org/solrsearch/...` + `https://central.sonatype.com/api/v1/...`

---

### 4. `mcp-npm-tools` — npm Registry

**Properties:**
```properties
mcp.npm.token=${MCP_NPM_TOKEN:}
mcp.npm.registry=${MCP_NPM_REGISTRY:https://registry.npmjs.org}
```

**Tool:**
| Tool | Descrizione |
|------|-------------|
| `npm_search(query)` | Cerca pacchetti su npm |
| `npm_get_package(name)` | Info pacchetto (versioni, readme, maintainers) |
| `npm_get_latest_version(name)` | Ultima versione |
| `npm_list_versions(name)` | Tutte le versioni |
| `npm_check_name_available(name)` | Verifica disponibilità nome |

**Note:** Come per Maven, la pubblicazione (`npm publish`) richiede il CLI locale. I tool servono per query e verifica.

**Auth:** Token opzionale (query è pubblica)
**API base:** `https://registry.npmjs.org/...`

---

## Struttura per ogni libreria

Stessa struttura delle 15 librerie esistenti:

```
mcp-{domain}-tools/
├── pom.xml
├── src/main/java/io/github/massimilianopili/mcp/{domain}/
│   ├── {Domain}ToolsAutoConfiguration.java
│   ├── {Domain}Config.java          # WebClient bean
│   ├── {Domain}Properties.java      # @ConfigurationProperties
│   └── {Domain}Tools.java           # @Service + @ReactiveTool
└── src/main/resources/
    └── META-INF/spring/
        └── org.springframework.boot.autoconfigure.AutoConfiguration.imports
```

**Directory base:** `/data/massimiliano/Vari/mcp-{domain}-tools/`

---

## Integrazione con MCP Server

1. Aggiungere le 4 dipendenze in `/data/massimiliano/Vari/mcp/pom.xml`
2. Aggiungere le env vars in `application.properties`
3. Aggiungere le env vars nel `docker-compose.yml` di simoge-mcp

---

## Sequenza di lavoro

### Priorità: Gitea prima (sblocca il push del repo wikijs-mermaid-patch)

1. **`mcp-gitea-tools`** — Crea libreria, implementa tool, integra in MCP server, deploy
2. **`mcp-github-tools`** — Stessa struttura, API GitHub
3. **`mcp-maven-tools`** — Search/verify su Maven Central
4. **`mcp-npm-tools`** — Search/verify su npm

Ogni libreria: ~1 file Properties, ~1 file Config, ~1 file AutoConfiguration, ~1 file Tools.

### Dopo la prima libreria (Gitea):
- Pushare il repo `wikijs-mermaid-patch` usando il nuovo tool `gitea_create_repo`
- Continuare con le altre 3 librerie

---

## Verifica

Per ogni libreria:
- [ ] Tool registrati in `simoge-mcp` (visibili via `tool/list`)
- [ ] Chiamata di test dal client MCP (es. `gitea_list_repos`)
- [ ] Gestione errori (token mancante, 404, 401)

Test end-to-end:
- [ ] `gitea_create_repo("wikijs-mermaid-patch", "WikiJS patches", false)`
- [ ] Push via SSH dopo creazione
- [ ] `github_create_gist(...)` per pubblicare i file patch
- [ ] `maven_search("massimilianopili")` per verificare le librerie pubblicate

---

## File critici esistenti (pattern da seguire)

- `/data/massimiliano/Vari/mcp-redis-tools/pom.xml` — pom.xml template
- `/data/massimiliano/Vari/mcp-redis-tools/src/main/java/.../RedisTools.java` — @ReactiveTool pattern
- `/data/massimiliano/Vari/mcp-redis-tools/src/main/java/.../RedisConfig.java` — WebClient config
- `/data/massimiliano/Vari/mcp-redis-tools/src/main/java/.../RedisToolsAutoConfiguration.java` — AutoConfig
- `/data/massimiliano/Vari/mcp-devops-tools/src/main/java/.../DevOpsConfig.java` — Token auth pattern
- `/data/massimiliano/Vari/mcp/pom.xml` — dove aggiungere dipendenze
- `/data/massimiliano/Vari/mcp/src/main/resources/application.properties` — dove aggiungere config
- `/data/massimiliano/shell-scripts/bin/deploy-mirror` — Gitea API reference (set secret)
- `/data/massimiliano/shell-scripts/bin/deploy-mcp` — lista progetti Maven da deployare
