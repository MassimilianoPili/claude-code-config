# Piano — MCP Discovery, Resources, Prompts, Annotations

## Contesto

simoge-mcp ha ~286 tool su 29 librerie (Spring Boot 3.5.11, Spring AI 1.1.1, MCP SDK 0.17.0). Il `mcp-protocol-patch` accetta protocollo 2025-11-25. Zero Resources, zero Prompts, zero Tool Annotations implementati. 286 tool caricati tutti = ~114K token per client non-Claude-Code.

### Scoperta chiave
Spring AI 1.1.3 (disponibile ora) ha **supporto nativo completo** per:
- `@McpTool` con `annotations(readOnlyHint, destructiveHint, idempotentHint)`
- `@McpResource(uri, name, description, mimeType)` — con URI template
- `@McpPrompt(name, description)` + `@McpArg(name, description, required)`
- `@McpComplete(prompt)` — auto-completion per prompt
- Annotation scanner auto-configurato via `spring.ai.mcp.server.annotation-scanner.enabled=true`

**NON serve Spring AI 2.0** (ancora milestone M2) né Spring Boot 4 (Jakarta EE 11, Jackson 3 — migrazione massiccia). Bump 1.1.1 → 1.1.3 sufficiente.

**Coesistenza**: `@McpResource` e `@McpPrompt` sono registrazioni MCP indipendenti dai tool. I 286 tool `@ReactiveTool` esistenti continuano a funzionare. Le nuove Resources/Prompts usano le annotazioni native Spring AI.

---

## Fase 0 — Bump Spring AI 1.1.1 → 1.1.3

### File da modificare

**`/data/massimiliano/Vari/mcp/pom.xml`** — riga ~23:
```xml
<spring-ai.version>1.1.3</spring-ai.version>
```

**`/data/massimiliano/Vari/mcp/src/main/resources/application.properties`** — aggiungere:
```properties
spring.ai.mcp.server.annotation-scanner.enabled=true
spring.ai.mcp.server.capabilities.resource=true
spring.ai.mcp.server.capabilities.prompt=true
spring.ai.mcp.server.capabilities.completion=true
```

### Rischio
Possibili breaking changes tra 1.1.1 e 1.1.3 nelle API MCP. Mitigazione: build + test immediato.

### Verifica
1. `cd /data/massimiliano/Vari/mcp && mvn clean install -Dgpg.skip=true`
2. `deploy-mcp`
3. Verificare che i 286 tool esistenti funzionino ancora (chiamata test a `web_search` o `infra_search`)

---

## Fase 1 — Progressive Discovery Meta-Tools

### Problema
286 tool × ~400 token = ~114K token. Client non-Claude-Code (agent-framework, n8n) non hanno deferred loading.

### Soluzione
2 meta-tool nel server simoge-mcp. Iniettano `ToolCallbackProvider` (API: `getToolCallbacks()` → `ToolCallback[]` → `getToolDefinition()` → name, description, inputSchema).

### File da creare

**`/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ToolDiscoveryTools.java`**

```java
@Service
public class ToolDiscoveryTools {

    private final ToolCallbackProvider toolProvider;
    private List<ToolMetadata> toolIndex; // cached at startup

    record ToolMetadata(String name, String description, String category, String inputSchema) {}

    @PostConstruct
    void buildIndex() {
        toolIndex = Arrays.stream(toolProvider.getToolCallbacks())
            .map(cb -> {
                ToolDefinition def = cb.getToolDefinition();
                return new ToolMetadata(def.getName(), def.getDescription(),
                    inferCategory(def.getName()), def.getInputSchema());
            })
            .sorted(Comparator.comparing(ToolMetadata::name))
            .toList();
    }

    @ReactiveTool(name = "tool_search",
        description = "Search available MCP tools by query or category. Returns matching tool names "
                    + "and descriptions. Categories: infra, docker, ocp, code, sql, web, devops, gitea, "
                    + "jira, ai, ollama, embeddings, keycloak, graph, s3, redis, ssh, csv, json, markdown, "
                    + "pdf, http, playwright, anki, openalex, claude, meta, auth, ops, net.")
    public Mono<String> toolSearch(String query, String category) { ... }

    @ReactiveTool(name = "tool_info",
        description = "Get the full JSON schema of a specific tool including all parameters, types, and descriptions.")
    public Mono<String> toolInfo(String toolName) { ... }

    private String inferCategory(String name) {
        // prefix-based: docker_* → "docker", infra_* → "infra", etc.
    }
}
```

### Categorizzazione prefix-based
`docker_*→docker`, `ocp_*→ocp`, `devops_*→devops`, `jira_*→jira`, `gitea_*→gitea`,
`keycloak_*→keycloak`, `redis_*→redis`, `s3_*→s3`, `ssh_*→ssh`, `db_*→sql`,
`graph_*→graph`, `embeddings_*→embeddings`, `web_*→web`, `http_*→http`,
`playwright_*→playwright`, `code_*→code`, `csv_*→csv`, `json_*→json`,
`markdown_*→markdown`, `pdf_*→pdf`, `yaml_*→yaml`, `llm_*→ollama`, `ai_*→ai`,
`meta_*→meta`, `claude_*→claude`, `anki_*→anki`, `openalex_*→openalex`,
`fs_*→filesystem`, `recovery_*→recovery`, `infra_*→infra`, `auth_*→auth`,
`ops_*→ops`, `net_*→net`, `metrics_*→monitoring`, `backup_*→backup`,
`systemd_*→systemd`, `cf_*→cloudflare`, `research_*→research`, `tool_*→discovery`

### Verifica
- `tool_search("prometheus")` → lista tool matching
- `tool_search("", "docker")` → tutti i 34 docker_*
- `tool_info("web_search")` → schema completo con parametri e tipi

---

## Fase 2 — MCP Resources

### Cosa
6 MCP Resource URI registrate con `@McpResource`. Dati read-only esposti via protocollo MCP — client li pre-caricano senza tool call.

### File da creare

**`/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/resources/InfraResources.java`**

```java
@Component
public class InfraResources {

    @McpResource(uri = "sol://services",
        name = "Docker Services",
        description = "All running Docker services with status, image, and ports",
        mimeType = "application/json")
    public ReadResourceResult getServices() {
        // Docker API via WebClient → lista container
        // Return JSON array di {name, image, status, ports}
    }

    @McpResource(uri = "sol://services/{name}",
        name = "Service Details",
        description = "Detailed information about a specific Docker service")
    public ReadResourceResult getService(String name) {
        // Stessa logica di infra_get_service ma come Resource
    }

    @McpResource(uri = "sol://routes",
        name = "Nginx Routes",
        description = "All nginx route entries with path, upstream, and auth pattern",
        mimeType = "application/json")
    public ReadResourceResult getRoutes() {
        // AGE query: MATCH (r:NginxRoute) RETURN r
    }

    @McpResource(uri = "sol://graph/schema",
        name = "Knowledge Graph Schema",
        description = "AGE knowledge graph labels, relationships, and node counts",
        mimeType = "application/json")
    public ReadResourceResult getGraphSchema() {
        // Stessa logica di graph_schema(backend="age")
    }

    @McpResource(uri = "sol://health",
        name = "System Health",
        description = "Current system health: CPU, memory, disk, container count",
        mimeType = "application/json")
    public ReadResourceResult getHealth() {
        // Prometheus queries: up, node_memory, node_filesystem, container count
    }

    @McpResource(uri = "sol://timers",
        name = "Systemd Timers",
        description = "All systemd timers with next run time and last status",
        mimeType = "application/json")
    public ReadResourceResult getTimers() {
        // Via dashboard-api o ssh_exec
    }
}
```

### Dipendenze interne
- Docker API: riutilizzare `DockerTools` WebClient (già configurato in mcp-docker-tools)
- AGE queries: riutilizzare `GraphTools` connection (già configurato in mcp-graph-tools)
- Prometheus: WebClient verso `http://prometheus:9090/api/v1/query` (no auth)

### Verifica
- `resources/list` MCP → 6 risorse con URI template
- `resources/read` con `uri=sol://services` → JSON di tutti i container
- `resources/read` con `uri=sol://services/nginx` → dettagli nginx

---

## Fase 3 — MCP Prompts

### Cosa
4 MCP Prompt template con `@McpPrompt` + `@McpArg`. Workflow invocabili da qualsiasi client MCP.

### File da creare

**`/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/prompts/WorkflowPrompts.java`**

```java
@Component
public class WorkflowPrompts {

    @McpPrompt(name = "research",
        description = "Academic research workflow: systematic literature search and synthesis")
    public GetPromptResult researchPrompt(
            @McpArg(name = "topic", description = "Research topic", required = true) String topic,
            @McpArg(name = "depth", description = "quick or deep", required = false) String depth) {
        String d = depth != null ? depth : "quick";
        String system = "You are a research assistant. Follow this methodology:\n"
            + "1. Search KORE first: graph_query for existing knowledge\n"
            + "2. Search OpenAlex: openalex_search for papers\n"
            + "3. Web search: web_search for recent results\n"
            + "4. Synthesize findings with confidence levels and source tiers";
        String user = String.format("Research topic: %s\nDepth: %s", topic, d);
        return new GetPromptResult("Research: " + topic, List.of(
            new PromptMessage(Role.SYSTEM, new TextContent(system)),
            new PromptMessage(Role.USER, new TextContent(user))));
    }

    @McpPrompt(name = "deploy",
        description = "Service deployment checklist with health verification")
    public GetPromptResult deployPrompt(
            @McpArg(name = "service", description = "Service name to deploy", required = true) String service) {
        // Deploy checklist: verify image, check deps, deploy, health check, update KORE
    }

    @McpPrompt(name = "troubleshoot",
        description = "Diagnostic workflow: status, logs, metrics, recent changes")
    public GetPromptResult troubleshootPrompt(
            @McpArg(name = "service", description = "Service to diagnose", required = true) String service) {
        // Troubleshoot workflow: infra_get_service, logs, metrics, ops_troubleshoot
    }

    @McpPrompt(name = "server-health",
        description = "Full server health check: containers, disk, memory, alerts")
    public GetPromptResult serverHealthPrompt() {
        // Health check: metrics_query("up"), disk, memory, alerts
    }
}
```

### Verifica
- `prompts/list` MCP → 4 prompts con argomenti
- `prompts/get` con `name=research, arguments={topic: "transformer"}` → system + user messages

---

## Fase 4 — Tool Annotations

### Problema
317 tool senza metadata di safety. I client MCP non sanno quali tool sono safe da auto-approvare.

### Gap architetturale
Spring AI `DefaultToolDefinition` ha solo 3 campi (`name`, `description`, `inputSchema`). `McpToolUtils.toSharedSyncToolSpecification()` costruisce `McpSchema.Tool` via `Tool.Builder` ma **non chiama mai** `.annotations()`. Il metodo esiste nel builder — nessuno lo usa.

Target: `McpSchema.ToolAnnotations` record — `readOnlyHint`, `destructiveHint`, `idempotentHint` (Boolean).

### Fix corretta — 3 step

#### 4a: Estendere `@ReactiveTool` (spring-ai-reactive-tools v0.5.0)

**`/data/massimiliano/Vari/spring-ai-reactive-tools/src/.../annotation/ReactiveTool.java`**:
```java
@interface ReactiveTool {
    String name();
    String description() default "";
    long timeoutMs() default 30000;
    boolean readOnly() default false;      // NUOVO
    boolean destructive() default false;   // NUOVO
    boolean idempotent() default false;    // NUOVO
}
```

**`/data/massimiliano/Vari/spring-ai-reactive-tools/src/.../callback/ReactiveToolCallbackAdapter.java`**:
- Aggiungere 3 campi `boolean readOnly, destructive, idempotent`
- Leggerli dall'annotazione nel costruttore (dove già legge `name`, `description`, `timeoutMs`)
- Esporre via 3 getter pubblici: `isReadOnly()`, `isDestructive()`, `isIdempotent()`

#### 4b: Converter diretto in mcp-protocol-patch

`McpServerAutoConfiguration.mcpAsyncServer()` accetta `ObjectProvider<List<AsyncToolSpecification>>`. La conversione default avviene in `StatelessToolCallbackConverterAutoConfiguration`.

**Strategia**: escludere il converter default, fornire il nostro che chiama `Tool.Builder.annotations()`.

**`/data/massimiliano/Vari/mcp-protocol-patch/src/.../McpAnnotatedToolConverter.java`** (NUOVO):
```java
@Configuration
@AutoConfigureBefore(StatelessToolCallbackConverterAutoConfiguration.class)
public class McpAnnotatedToolConverter {

    @Bean
    public List<McpServerFeatures.AsyncToolSpecification> annotatedAsyncToolSpecs(
            List<ToolCallbackProvider> providers) {

        List<AsyncToolSpecification> specs = new ArrayList<>();
        for (ToolCallbackProvider provider : providers) {
            for (ToolCallback callback : provider.getToolCallbacks()) {
                ToolDefinition def = callback.getToolDefinition();

                // Build McpSchema.Tool WITH annotations
                McpSchema.Tool.Builder toolBuilder = McpSchema.Tool.builder()
                    .name(def.name())
                    .description(def.description())
                    .inputSchema(/* parse def.inputSchema() as JsonSchema */);

                // Extract annotations if callback is ReactiveToolCallbackAdapter
                if (callback instanceof ReactiveToolCallbackAdapter rta) {
                    toolBuilder.annotations(new McpSchema.ToolAnnotations(
                        null,                     // title
                        rta.isReadOnly(),         // readOnlyHint
                        rta.isDestructive(),      // destructiveHint
                        rta.isIdempotent(),       // idempotentHint
                        null,                     // openWorldHint
                        null                      // returnDirect
                    ));
                }

                McpSchema.Tool tool = toolBuilder.build();

                // Build AsyncToolSpecification with call handler
                specs.add(AsyncToolSpecification.builder()
                    .tool(tool)
                    .callHandler((exchange, request) ->
                        Mono.fromCallable(() -> callback.call(
                            /* serialize request.arguments() */))
                        .subscribeOn(Schedulers.boundedElastic())
                        .map(result -> new McpSchema.CallToolResult(
                            List.of(new McpSchema.TextContent(result)), false)))
                    .build());
            }
        }
        return specs;
    }
}
```

**`/data/massimiliano/Vari/mcp/src/main/resources/application.properties`** — escludere il converter default:
```properties
spring.autoconfigure.exclude=org.springframework.ai.mcp.server.common.autoconfigure.StatelessToolCallbackConverterAutoConfiguration
```
(Nome esatto della classe da verificare dalla decompilazione.)

#### 4c: Applicare annotations ai 317 tool

Batch update di tutti i `@ReactiveTool` nelle 29 librerie + tool inline:

```java
// Esempio read-only:
@ReactiveTool(name = "docker_list_containers", description = "...", readOnly = true, idempotent = true)

// Esempio destructive:
@ReactiveTool(name = "docker_remove_container", description = "...", destructive = true, idempotent = true)

// Esempio mutating idempotent:
@ReactiveTool(name = "docker_restart_container", description = "...", idempotent = true)

// Esempio non-idempotent (default — nessun attributo aggiuntivo):
@ReactiveTool(name = "docker_start_container", description = "...")
```

### File da modificare

| File | Modifica |
|------|----------|
| `spring-ai-reactive-tools/.../ReactiveTool.java` | +3 attributi boolean |
| `spring-ai-reactive-tools/.../ReactiveToolCallbackAdapter.java` | +3 campi, +3 getter, lettura da annotation |
| `spring-ai-reactive-tools/pom.xml` | versione → 0.5.0 |
| `mcp-protocol-patch/.../McpAnnotatedToolConverter.java` | NUOVO — converter diretto |
| `mcp-protocol-patch/pom.xml` | dipendenza `spring-ai-reactive-tools:0.5.0` |
| `mcp/src/main/resources/application.properties` | exclude converter default |
| `mcp/pom.xml` | `reactive-tools.version` → 0.5.0 |
| Tutte le classi `*Tools.java` nelle 29 librerie | +`readOnly`/`destructive`/`idempotent` |
| Tutti i tool inline in `mcp/src/.../tools/` | +attributi |

### Ordine di esecuzione

1. ✅ Modificare `spring-ai-reactive-tools` → build + install locale (FATTO)
2. ✅ Creare `AnnotatedToolConverterConfig` nel server MCP (FATTO)
3. ✅ Escludere converter default in `application.properties` (FATTO)
4. Pubblicare `spring-ai-reactive-tools:0.5.0` su Gitea Maven registry:
   - `cd /data/massimiliano/Vari/spring-ai-reactive-tools`
   - Commit modifiche
   - `git tag g0.5.0 && git push origin main --tags`
   - CI (`deploy-gitea.yml`) pubblica su `http://gitea:3000/api/packages/sol_root/maven`
5. `sol deploy mcp` — Docker build scarica 0.5.0 da Gitea registry
6. Verificare tool annotations nei log + protocollo MCP
7. Batch-applicare annotations alle 29 librerie + tool inline (una alla volta)
8. Rilasciare `spring-ai-reactive-tools:0.5.0` su Maven Central (tag `v0.5.0`)

### Verifica
1. `cd /data/massimiliano/Vari/spring-ai-reactive-tools && mvn clean install -Dgpg.skip=true`
2. `cd /data/massimiliano/Vari/mcp-protocol-patch && mvn clean install -Dgpg.skip=true`
3. `cd /data/massimiliano/Vari/mcp && mvn clean install -Dgpg.skip=true`
4. `sol deploy mcp`
5. Log: nessun "No tool methods" warning, 317 tool registrati
6. Test protocol: i `tools/list` MCP response deve includere `annotations` per tool annotati
7. Test: `tool_info("docker_list_containers")` → `readOnly: true, idempotent: true`
8. Test: `tool_info("docker_remove_container")` → `destructive: true`

---

## Upgrade Spring Boot 4 / Spring AI 2.0 — RIMANDATO

### Motivazione
- Spring AI 2.0 ancora milestone (M2, gen 2026) — non GA
- Spring Boot 4 richiede: Jakarta EE 11, Spring Framework 7, Jackson 3 (nuovi groupId), modularizzazione starter
- Impatto: tutte le 20 librerie mcp-*-tools + agent-framework (~1579 test) + tutte le app Go (nessun impatto) + app Node.js (nessun impatto)
- Rischio alto per beneficio marginale (le feature MCP che servono sono già in 1.1.3)
- Pianificare come progetto separato quando Spring AI 2.0 raggiunge GA

---

## Ordine di esecuzione

| # | Fase | Effort | Dipendenze | Note |
|---|------|--------|------------|------|
| 0 | Bump Spring AI 1.1.3 | 30min | Nessuna | Build + test immediato |
| 1 | Progressive Discovery | 2h | Fase 0 | 2 meta-tool, `ToolCallbackProvider` |
| 2 | MCP Resources | 3h | Fase 0 | 6 `@McpResource`, annotation scanner |
| 3 | MCP Prompts | 2h | Fase 0 | 4 `@McpPrompt` + `@McpArg` |
| 4 | Tool Annotations | 4-6h | Fase 0 | Modifica `spring-ai-reactive-tools` + batch 29 librerie |

**Fasi 1, 2, 3** sono indipendenti (dopo Fase 0) — possono essere parallele.
**Fase 4** è indipendente ma più lunga — può iniziare appena Fase 0 è verificata.

## File critici

| File | Scopo |
|------|-------|
| `/data/massimiliano/Vari/mcp/pom.xml` | Versione Spring AI (riga ~23) |
| `/data/massimiliano/Vari/mcp/src/main/resources/application.properties` | Capabilities MCP |
| `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/McpServerApplication.java` | Entry point |
| `/data/massimiliano/Vari/spring-ai-reactive-tools/src/.../annotation/ReactiveTool.java` | Annotazione custom |
| `/data/massimiliano/Vari/spring-ai-reactive-tools/src/.../callback/ReactiveToolCallbackAdapter.java` | Adapter (207 righe) |
| `/data/massimiliano/Vari/spring-ai-reactive-tools/src/.../provider/ReactiveMethodToolCallbackProvider.java` | Registry (127 righe) |

## Verifica end-to-end

Dopo ogni fase:
1. `cd /data/massimiliano/Vari/mcp && mvn clean install -Dgpg.skip=true`
2. `deploy-mcp`
3. Test specifico della fase (vedi sezioni sopra)
4. Verificare i tool esistenti non siano rotti: `tool_search("web")` o chiamata diretta
