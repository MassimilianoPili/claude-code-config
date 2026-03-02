# Claude Code Config

Single source of truth per Claude Code hooks, Git global hooks e skill sul server SOL.
I file in questo repo sono quelli attivi — Claude Code e Git li leggono direttamente via symlink/path configurati.

## Symlink

```
/data/massimiliano/.claude/hooks     → claude-code-config/hooks/
/data/massimiliano/claude-shared/skills → claude-code-config/skills/
~/.claude/skills                     → claude-shared/skills (catena)
~/.git-hooks/commit-msg              → ~/claude-code-config/git-hooks/commit-msg
```

## Hook (13)

Script bash eseguiti automaticamente da Claude Code in risposta a eventi specifici.
Configurazione in `~/.claude/settings.json` (sezione `hooks`). Reference: `settings-hooks.json`.

### Sicurezza

| Hook | Evento | Matcher | Descrizione |
|------|--------|---------|-------------|
| `block-dangerous-commands.sh` | PreToolUse | Bash | Blocca `rm -rf /`, fork bomb, `mkfs`, `dd`, `shutdown`, `curl\|sh`, `docker system prune -a` |
| `git-push-guard.sh` | PreToolUse | Bash | Blocca force-push a main/master |
| `protect-sensitive-files.sh` | PreToolUse | Edit\|Write | Blocca scrittura su `.env`, `.pem`, `.key`, `.ssh/`, `.gnupg/`, `/etc/` |
| `scan-secrets-in-content.sh` | PreToolUse | Edit\|Write | Rileva PEM keys, password hardcodate, AWS keys (esclude `.md/.txt/.json/.sh`) |

### Qualita'

| Hook | Evento | Matcher | Descrizione |
|------|--------|---------|-------------|
| `auto-shellcheck.sh` | PostToolUse | Edit\|Write | Esegue shellcheck su file `.sh` |
| `auto-gofmt.sh` | PostToolUse | Edit\|Write | Esegue `gofmt -w` su file `.go` |
| `auto-stage.sh` | PostToolUse | Edit\|Write | `git add` automatico se il file e' in un repo git |

### Audit

| Hook | Evento | Matcher | Descrizione |
|------|--------|---------|-------------|
| `command-audit-log.sh` | PostToolUse | Bash (async) | Log comandi in `~/.claude/audit/commands.log` |
| `config-audit.sh` | ConfigChange | — | Log modifiche config in `~/.claude/audit/config-changes.log` |

### Sessione

| Hook | Evento | Matcher | Descrizione |
|------|--------|---------|-------------|
| `session-context-loader.sh` | SessionStart | startup | Carica contesto Docker, systemd, disco, RAM |
| `compact-context-preserver.sh` | PreCompact | — | Salva snapshot in `/tmp/claude-pre-compact-context.txt` |

### Lifecycle

| Hook | Evento | Matcher | Descrizione |
|------|--------|---------|-------------|
| `stop-reminder.sh` | Stop | — | Avvisa se ci sono modifiche non committate |
| `readme-update-reminder.sh` | Stop | — | Ricorda di aggiornare README/CLAUDE.md se file infra modificati |

## Git Global Hooks (1)

Hook Git nativi (non eventi Claude Code). Questi hook sono attivati da Git tramite
`core.hooksPath` e non da `settings-hooks.json`.

| Hook | Tipo | Descrizione |
|------|------|-------------|
| `git-hooks/commit-msg` | Git global hook | Rimuove automaticamente `Co-Authored-By: Claude/Anthropic` e `Generated with Claude Code` dai commit message |

## Skill (102)

Skill Claude Code organizzate per categoria.

### aws (25)

| Skill | Descrizione |
|-------|-------------|
| `aws-cloudformation-auto-scaling` | Auto Scaling groups, launch templates, scaling policies |
| `aws-cloudformation-bedrock` | Bedrock agents, knowledge bases, guardrails, flows |
| `aws-cloudformation-cloudfront` | CloudFront distributions, origins, cache behaviors |
| `aws-cloudformation-cloudwatch` | CloudWatch metrics, alarms, dashboards, logs |
| `aws-cloudformation-dynamodb` | DynamoDB tables, GSI, LSI, auto-scaling, streams |
| `aws-cloudformation-ec2` | EC2 instances, Security Groups, IAM roles, ALB |
| `aws-cloudformation-ecs` | ECS clusters, services, task definitions, CodeDeploy |
| `aws-cloudformation-elasticache` | ElastiCache Redis/Memcached, replication groups |
| `aws-cloudformation-iam` | IAM users, roles, policies, permissions boundaries |
| `aws-cloudformation-lambda` | Lambda functions, layers, API Gateway, triggers |
| `aws-cloudformation-rds` | RDS instances, Aurora, multi-AZ, parameter groups |
| `aws-cloudformation-s3` | S3 buckets, policies, versioning, lifecycle rules |
| `aws-cloudformation-security` | Secrets Manager, KMS, TLS, defense-in-depth |
| `aws-cloudformation-task-ecs-deploy-gh` | ECS deploy con GitHub Actions CI/CD |
| `aws-cloudformation-vpc` | VPC, subnets, route tables, NAT/Internet gateways |
| `aws-rds-spring-boot-integration` | RDS + Spring Boot datasource, connection pooling |
| `aws-sdk-java-v2-bedrock` | Bedrock SDK: text/image generation, embeddings |
| `aws-sdk-java-v2-core` | AWS SDK core: clients, credentials, timeouts |
| `aws-sdk-java-v2-dynamodb` | DynamoDB SDK: CRUD, indexes, transactions |
| `aws-sdk-java-v2-kms` | KMS SDK: encryption, data keys, signing |
| `aws-sdk-java-v2-lambda` | Lambda SDK: invoke, create, manage functions |
| `aws-sdk-java-v2-messaging` | SQS/SNS SDK: queues, topics, pub/sub |
| `aws-sdk-java-v2-rds` | RDS SDK: instances, snapshots, management |
| `aws-sdk-java-v2-s3` | S3 SDK: upload, download, presigned URLs |
| `aws-sdk-java-v2-secrets-manager` | Secrets Manager SDK: store, retrieve, rotate |

### backend (17)

| Skill | Descrizione |
|-------|-------------|
| `dss-framework` | EU DSS 5.12.1: firme digitali, validazione, trusted lists |
| `golang-patterns` | Go HTTP APIs, JWT/OIDC, Docker socket, Redis, SSE |
| `nestjs` | NestJS framework con Drizzle ORM |
| `nodejs-backend` | Node.js JWT, WebSocket proxy, systemd services |
| `spring-boot-actuator` | Actuator: health, metrics, management endpoints |
| `spring-boot-cache` | Spring Cache abstraction |
| `spring-boot-crud-patterns` | CRUD con Spring Data JPA |
| `spring-boot-dependency-injection` | DI patterns: constructor, optional, bean selection |
| `spring-boot-event-driven-patterns` | Event-driven con ApplicationEvent e Kafka |
| `spring-boot-openapi-documentation` | SpringDoc OpenAPI 3.0, Swagger UI |
| `spring-boot-resilience4j` | Circuit breaker, retry, rate limiter, bulkhead |
| `spring-boot-rest-api-standards` | REST API design, DTOs, error handling, HATEOAS |
| `spring-boot-saga-pattern` | Saga pattern per transazioni distribuite |
| `spring-boot-security-jwt` | JWT auth con Spring Security 6.x |
| `spring-data-jpa` | JPA repositories, queries, relazioni, auditing |
| `spring-data-neo4j` | Neo4j graph database con Spring Data |
| `websocket-patterns` | WebSocket binary proxy, nginx, xterm.js, ttyd |

### frontend (14)

| Skill | Descrizione |
|-------|-------------|
| `angular-component` | Angular 20+ standalone components, signals |
| `angular-di` | Angular DI con inject(), injection tokens |
| `angular-directives` | Custom directives, host directives |
| `angular-forms` | Signal Forms API (Angular 21+) |
| `angular-http` | httpResource(), resource(), HttpClient |
| `angular-routing` | Routing, lazy loading, functional guards |
| `angular-signals` | signal(), computed(), linkedSignal(), effect() |
| `angular-ssr` | SSR, hydration, prerendering |
| `angular-testing` | TestBed, Vitest, component harnesses |
| `angular-tooling` | Angular CLI, ng generate, build config |
| `react-patterns` | React 19: Server Components, Actions, use() |
| `shadcn-ui` | shadcn/ui components, React Hook Form, Zod |
| `tailwind-css-patterns` | Tailwind CSS utility-first styling |
| `typescript-docs` | TypeScript docs con JSDoc, TypeDoc |

### testing (16)

| Skill | Descrizione |
|-------|-------------|
| `spring-boot-test-patterns` | Test patterns: unit, integration, slice, Testcontainers |
| `unit-test-application-events` | Test ApplicationEvent, @EventListener |
| `unit-test-bean-validation` | Test Jakarta Bean Validation |
| `unit-test-boundary-conditions` | Edge case, min/max, null, empty |
| `unit-test-caching` | Test @Cacheable, @CachePut, @CacheEvict |
| `unit-test-config-properties` | Test @ConfigurationProperties |
| `unit-test-controller-layer` | MockMvc, @WebMvcTest |
| `unit-test-exception-handler` | Test @ExceptionHandler, @ControllerAdvice |
| `unit-test-json-serialization` | Test Jackson, @JsonTest |
| `unit-test-mapper-converter` | Test MapStruct, custom mappers |
| `unit-test-parameterized` | @ParameterizedTest, @ValueSource, @CsvSource |
| `unit-test-scheduled-async` | Test @Scheduled, @Async |
| `unit-test-security-authorization` | Test @PreAuthorize, @Secured, RBAC |
| `unit-test-service-layer` | Mockito, business logic in isolation |
| `unit-test-utility-methods` | Test utility/helper classes |
| `unit-test-wiremock-rest-api` | WireMock per mock HTTP endpoints |

### ai-integration (9)

| Skill | Descrizione |
|-------|-------------|
| `langchain4j-ai-services-patterns` | AI Services declarativi con LangChain4j |
| `langchain4j-mcp-server-patterns` | MCP server con LangChain4j |
| `langchain4j-rag-implementation-patterns` | RAG con LangChain4j |
| `langchain4j-spring-boot-integration` | LangChain4j + Spring Boot auto-config |
| `langchain4j-testing-strategies` | Test per app LangChain4j |
| `langchain4j-tool-function-calling-patterns` | Tool/function calling con LangChain4j |
| `langchain4j-vector-stores-configuration` | Vector stores: pgvector, Pinecone, MongoDB |
| `qdrant-vector-database-integration` | Qdrant vector DB con LangChain4j |
| `spring-ai-mcp-server-patterns` | MCP server con Spring AI |

### ai-engineering (3)

| Skill | Descrizione |
|-------|-------------|
| `chunking-strategy` | Chunking per RAG e document processing |
| `prompt-engineering` | Prompt patterns, few-shot, chain-of-thought |
| `rag-implementation` | RAG systems con vector DB e semantic search |

### infrastructure (8)

| Skill | Descrizione |
|-------|-------------|
| `activemq-artemis-jms` | Artemis broker, multi-protocollo, Hawtio, Docker |
| `docker-compose-patterns` | Compose multi-servizio, rete shared, health checks |
| `keycloak-oidc` | Keycloak SSO, realm, client OIDC, role mapping |
| `kubernetes-openshift-patterns` | K8s/OCP: deploy, services, ConfigMaps, scaling |
| `nginx-reverse-proxy` | Nginx path-based routing, lazy DNS, WebSocket |
| `oauth2-proxy-patterns` | OAuth2 Proxy dual-instance, auth_request, PKCE |
| `portainer-management` | Portainer CE, Docker management UI, stacks |
| `systemd-services` | Systemd user-level, NVM, service dependencies |

### devops (4)

| Skill | Descrizione |
|-------|-------------|
| `bash-scripting` | Bash scripting, Docker management, Git multi-repo |
| `gitea-actions-ci` | Gitea Actions, act_runner, Maven Central publish |
| `maven-build-patterns` | Maven multi-module, OSSRH, GPG signing |
| `restic-backup` | Restic backup, retention, pg_dump, cron |

### database (4)

| Skill | Descrizione |
|-------|-------------|
| `libsql-sqlite` | libSQL/Turso server, HTTP API, hrana protocol |
| `mongodb-patterns` | MongoDB Docker, auth, mongo-express, CRUD |
| `postgresql-patterns` | PostgreSQL multi-DB, init scripts, pgAdmin |
| `redis-patterns` | Redis DB partitioning, caching, session, queues |

### networking (2)

| Skill | Descrizione |
|-------|-------------|
| `cloudflare-tunnel` | Cloudflare Tunnel QUIC, ingress, DNS CNAME |
| `tailscale-networking` | Tailscale VPN mesh, MagicDNS, SSHFS, dual-network |

## Installazione

### Su questo server (gia' configurato)

I symlink sono gia' attivi. Per aggiornare dopo un `git pull`:

```bash
cd /data/massimiliano/claude-code-config && git pull
# Nessun altro passo — i symlink puntano direttamente qui
# Hook Git globale gia' configurato: core.hooksPath=~/.git-hooks
```

### Su un'altra macchina

```bash
git clone <url-repo> ~/claude-code-config

# Symlink hooks
ln -sf ~/claude-code-config/hooks ~/.claude/hooks

# Symlink skills
ln -sf ~/claude-code-config/skills ~/.claude/skills

# Git global hooks (commit-msg)
mkdir -p ~/.git-hooks
git config --global core.hooksPath ~/.git-hooks
ln -snf ~/claude-code-config/git-hooks/commit-msg ~/.git-hooks/commit-msg

# Merge solo hook Claude Code in settings.json
# Copiare il contenuto di settings-hooks.json dentro ~/.claude/settings.json
```
