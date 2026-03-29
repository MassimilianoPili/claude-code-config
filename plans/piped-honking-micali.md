# Piano: mcp-playwright-tools — Libreria MCP per browser automation

## Context

Il server MCP aggregatore (`/data/massimiliano/Vari/mcp/`) aggrega 11 librerie in ~150 tool.
L'utente vuole aggiungere **automazione browser completa** (navigazione, click, fill, screenshot, evaluate JS) come 12ª libreria.

**Non esiste** una libreria Java MCP per Playwright su Maven Central. Il binding ufficiale è `com.microsoft.playwright:playwright:1.58.0` (API Java per Chromium/Firefox/WebKit). Serve creare `mcp-playwright-tools` che wrappa l'API Playwright con annotazioni `@Tool` Spring AI.

**Nota**: il plugin Claude Code `playwright@claude-plugins-official` fornisce tool simili via MCP server Node.js separato. Questa libreria li consolida nel server Java principale.

## Architettura

```
mcp-playwright-tools (nuova libreria Maven Central)
├── PlaywrightProperties.java       # @ConfigurationProperties("mcp.playwright")
├── PlaywrightConfig.java           # Crea Browser + BrowserContext singleton
├── PlaywrightToolsAutoConfiguration.java  # @ConditionalOnProperty + ToolCallbackProvider
└── PlaywrightTools.java            # 15 @Tool methods
```

Attivazione: `MCP_PLAYWRIGHT_ENABLED=true` → `mcp.playwright.enabled=true`

## Step 1 — Creare il progetto `mcp-playwright-tools`

**Directory**: `/data/massimiliano/Vari/mcp-playwright-tools/`

### pom.xml

Seguire il pattern esatto di `mcp-graph-tools/pom.xml`:
- GroupId: `io.github.massimilianopili`
- ArtifactId: `mcp-playwright-tools`
- Version: `0.0.1`
- Dependencies:
  - `com.microsoft.playwright:playwright:1.58.0` (core)
  - `spring-boot-autoconfigure` (optional)
  - `spring-ai-model` (provided, per `@Tool`)
  - `slf4j-api`
  - `jackson-databind` (provided)
- Build plugins: compiler, source, javadoc, gpg, central-publishing (identici a graph-tools)
- Properties: java 17, Spring Boot 3.4.1, Spring AI 1.0.0

### PlaywrightProperties.java

```java
@ConfigurationProperties(prefix = "mcp.playwright")
public class PlaywrightProperties {
    private boolean enabled;
    private String browserType = "chromium";  // chromium, firefox, webkit
    private boolean headless = true;
    private int timeout = 30000;              // ms, default 30s
    private int viewportWidth = 1280;
    private int viewportHeight = 720;
    private String locale = "it-IT";
    // getters/setters
}
```

### PlaywrightConfig.java

Pattern: `GraphConfig.java` — crea bean con lifecycle management.

```java
@Configuration
@ConditionalOnProperty(name = "mcp.playwright.enabled", havingValue = "true")
@EnableConfigurationProperties(PlaywrightProperties.class)
public class PlaywrightConfig {

    @Bean(destroyMethod = "close")
    public Playwright playwright() {
        return Playwright.create();
    }

    @Bean(destroyMethod = "close")
    public Browser browser(Playwright pw, PlaywrightProperties props) {
        BrowserType bt = switch (props.getBrowserType()) {
            case "firefox" -> pw.firefox();
            case "webkit" -> pw.webkit();
            default -> pw.chromium();
        };
        return bt.launch(new BrowserType.LaunchOptions().setHeadless(props.isHeadless()));
    }

    @Bean(destroyMethod = "close")
    public BrowserContext browserContext(Browser browser, PlaywrightProperties props) {
        return browser.newContext(new Browser.NewContextOptions()
                .setViewportSize(props.getViewportWidth(), props.getViewportHeight())
                .setLocale(props.getLocale()));
    }
}
```

**Lifecycle**: `destroyMethod = "close"` garantisce cleanup del processo Chromium allo shutdown della JVM.

### PlaywrightToolsAutoConfiguration.java

Identico al pattern `GraphToolsAutoConfiguration.java`:

```java
@AutoConfiguration
@ConditionalOnProperty(name = "mcp.playwright.enabled", havingValue = "true")
@Import({PlaywrightConfig.class, PlaywrightTools.class})
public class PlaywrightToolsAutoConfiguration {
    @Bean("playwrightToolCallbackProvider")
    public ToolCallbackProvider playwrightToolCallbackProvider(PlaywrightTools tools) {
        return MethodToolCallbackProvider.builder().toolObjects(tools).build();
    }
}
```

### AutoConfiguration.imports

File: `src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`
```
io.github.massimilianopili.mcp.playwright.PlaywrightToolsAutoConfiguration
```

### PlaywrightTools.java — 15 Tool

La classe gestisce un **singolo Page** (creato on-demand, riusato) nel BrowserContext singleton.

| # | Tool | Parametri | Return | Descrizione |
|---|------|-----------|--------|-------------|
| 1 | `playwright_navigate` | `url`, `waitUntil?` (load/domcontentloaded/networkidle) | `Map` (url, title, status) | Naviga a URL |
| 2 | `playwright_navigate_back` | - | `Map` (url, title) | Torna indietro |
| 3 | `playwright_snapshot` | - | `String` (accessibility tree testuale) | Snapshot accessibilità (come l'ufficiale) |
| 4 | `playwright_screenshot` | `fullPage?` | `Map` (base64 PNG, dimensioni) | Screenshot come base64 |
| 5 | `playwright_click` | `selector` | `Map` (status, selector) | Click su elemento CSS/XPath |
| 6 | `playwright_fill` | `selector`, `value` | `Map` (status) | Riempie input |
| 7 | `playwright_select_option` | `selector`, `value` | `Map` (status, selected) | Seleziona option da dropdown |
| 8 | `playwright_press_key` | `key` | `Map` (status) | Premi tasto (Enter, Tab, etc.) |
| 9 | `playwright_type` | `text`, `selector?` | `Map` (status) | Digita testo (con o senza target) |
| 10 | `playwright_evaluate` | `expression` | `String` (risultato JS serializzato) | Esegui JavaScript nella pagina |
| 11 | `playwright_wait_for` | `selector?`, `text?`, `timeout?` | `Map` (status, found) | Attendi elemento o testo |
| 12 | `playwright_get_content` | `selector?` | `String` (HTML o testo) | Estrai contenuto pagina/elemento |
| 13 | `playwright_tabs` | - | `List<Map>` (url, title per ogni tab) | Lista tab aperti |
| 14 | `playwright_close` | - | `Map` (status) | Chiudi pagina corrente |
| 15 | `playwright_resize` | `width`, `height` | `Map` (status) | Ridimensiona viewport |

**Pattern Page management**:
```java
private Page getOrCreatePage() {
    if (currentPage == null || currentPage.isClosed()) {
        currentPage = browserContext.newPage();
    }
    return currentPage;
}
```

**Scelte implementative**:
- `playwright_snapshot` usa `page.accessibility().snapshot()` → serializza l'albero come testo indentato (simile al server MCP ufficiale Playwright)
- `playwright_screenshot` restituisce base64 per compatibilità MCP (nessun filesystem richiesto)
- `playwright_evaluate` serializza il risultato come JSON string
- Timeout configurabile via property, override per-call con parametro opzionale
- Errori restituiti come `Map.of("error", message)` — mai eccezione non gestita (pattern esistente)

## Step 2 — Repo Git + CI/CD

1. `mkdir /data/massimiliano/Vari/mcp-playwright-tools && cd $_`
2. `git init`, commit iniziale
3. Aggiungere remote `origin` (Gitea: `sol_root/mcp-playwright-tools`) e `github` (mirror)
4. Copiare workflow CI da `mcp-graph-tools/.gitea/workflows/` (tag `v*` → Maven Central)
5. **Non pubblicare su Maven Central subito** — prima testare localmente con `mvn install`

## Step 3 — Integrare nel server MCP

### File da modificare

**`/data/massimiliano/Vari/mcp/pom.xml`** — aggiungere dependency:
```xml
<dependency>
    <groupId>io.github.massimilianopili</groupId>
    <artifactId>mcp-playwright-tools</artifactId>
    <version>0.0.1</version>
</dependency>
```

**`/data/massimiliano/Vari/mcp/src/main/resources/application.properties`** — aggiungere:
```properties
# === Playwright Browser Automation (attivo se MCP_PLAYWRIGHT_ENABLED=true) ===
mcp.playwright.enabled=${MCP_PLAYWRIGHT_ENABLED:false}
mcp.playwright.browser-type=${MCP_PLAYWRIGHT_BROWSER:chromium}
mcp.playwright.headless=${MCP_PLAYWRIGHT_HEADLESS:true}
mcp.playwright.timeout=${MCP_PLAYWRIGHT_TIMEOUT:30000}
mcp.playwright.viewport-width=${MCP_PLAYWRIGHT_VIEWPORT_WIDTH:1280}
mcp.playwright.viewport-height=${MCP_PLAYWRIGHT_VIEWPORT_HEIGHT:720}
mcp.playwright.locale=${MCP_PLAYWRIGHT_LOCALE:it-IT}
```

**`/data/massimiliano/Vari/mcp/CLAUDE.md`** — aggiungere sezione Playwright nella tabella tool e configurazione.

## Step 4 — Installare browser Playwright sull'host

Playwright Java scarica i browser la prima volta che vengono usati, ma è meglio pre-installarli:

```bash
cd /data/massimiliano/Vari/mcp-playwright-tools
/opt/maven/bin/mvn exec:java \
  -Dexec.mainClass=com.microsoft.playwright.CLI \
  -Dexec.args="install --with-deps chromium"
```

Questo installa Chromium + dipendenze di sistema (libglib, libnss, etc.) in `~/.cache/ms-playwright/`.

**Spazio stimato**: ~300-400 MB per Chromium.

## Step 5 — Aumentare memoria JVM

Aggiornare il comando di registrazione MCP server (scope user):

```bash
claude mcp remove simoge-mcp
claude mcp add --transport stdio --scope user simoge-mcp -- \
  env MCP_PLAYWRIGHT_ENABLED=true \
  MCP_FS_BASEDIR=/data/massimiliano \
  MCP_DOCKER_HOST=tcp://127.0.0.1:2375 \
  MCP_VECTOR_ENABLED=true \
  MCP_VECTOR_PROVIDER=onnx \
  MCP_VECTOR_DB_URL=jdbc:postgresql://127.0.0.1:5432/embeddings \
  MCP_GRAPH_ENABLED=true \
  MCP_GRAPH_NEO4J_URI=bolt://127.0.0.1:7687 \
  /opt/java/bin/java -Xmx512m -jar /data/massimiliano/Vari/mcp/target/mcp-server-0.0.1-SNAPSHOT.jar
```

Nota: le variabili env esatte vanno copiate dalla configurazione corrente. Il punto chiave è `-Xmx512m` (da assente/384m).

## Step 6 — Build e test

```bash
# 1. Build libreria
cd /data/massimiliano/Vari/mcp-playwright-tools
/opt/maven/bin/mvn clean install -DskipTests

# 2. Rebuild server
cd /data/massimiliano/Vari/mcp
/opt/maven/bin/mvn clean package -DskipTests

# 3. Test diretto (fuori da Claude)
MCP_PLAYWRIGHT_ENABLED=true /opt/java/bin/java -Xmx512m -jar target/mcp-server-0.0.1-SNAPSHOT.jar
# Verificare nei log: "Playwright tools abilitati", "15 tool registrati"

# 4. Restart Claude Code e verificare che i tool playwright_* appaiano
```

## Verifica end-to-end

1. **Build**: `mvn clean install` nella libreria → SUCCESS
2. **Package**: `mvn clean package` nel server → JAR con Playwright incluso
3. **Startup**: log deve mostrare browser Chromium lanciato + 15 tool registrati
4. **Tool test**: usare `playwright_navigate` con un URL pubblico (es. `https://example.com`)
5. **Screenshot**: `playwright_screenshot` deve restituire base64 valido
6. **Cleanup**: verificare che `playwright_close` chiuda il browser e che lo shutdown JVM sia pulito

## Rischi e mitigazioni

| Rischio | Mitigazione |
|---------|-------------|
| Chromium usa troppa RAM | `-Xmx512m` + `--disable-gpu --disable-dev-shm-usage` via LaunchOptions args |
| Browser crash non gestito | `getOrCreatePage()` rilancia browser se necessario |
| Timeout lunghi bloccano altri tool | Ogni operazione ha timeout configurabile (default 30s) |
| Dipendenze di sistema mancanti | `install --with-deps` scarica tutto; Ubuntu 24.04 ha quasi tutto |
| JAR size aumenta (~60MB per Playwright) | Accettabile, JAR attuale è già 164MB |

## File coinvolti (riepilogo)

| File | Azione |
|------|--------|
| `/data/massimiliano/Vari/mcp-playwright-tools/` (nuovo) | Creare intera libreria |
| `/data/massimiliano/Vari/mcp/pom.xml` | Aggiungere dependency |
| `/data/massimiliano/Vari/mcp/src/main/resources/application.properties` | Aggiungere config Playwright |
| `/data/massimiliano/Vari/mcp/CLAUDE.md` | Aggiungere docs Playwright |
| Registrazione MCP (`claude mcp add`) | Aggiornare con `-Xmx512m` e `MCP_PLAYWRIGHT_ENABLED=true` |
