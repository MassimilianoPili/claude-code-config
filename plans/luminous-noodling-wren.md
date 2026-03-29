# Aggiornamento documentazione MCP Server + mcp-playwright-tools

## Context

La migrazione a Java 21, l'aggiunta di `mcp-playwright-tools` (12a libreria) e il fix lazy init hanno reso la documentazione obsoleta. I README dicono Java 17, 11 librerie, ~251 tool. Manca il README per playwright-tools, manca un SETUP.md operativo per il deployment del server MCP su SOL.

---

## File da modificare/creare

| File | Azione | Motivo |
|------|--------|--------|
| `/data/massimiliano/Vari/mcp/README.md` | **MODIFICA** | Java 21, 12 librerie, +Playwright, versioni aggiornate |
| `/data/massimiliano/Vari/mcp/SETUP.md` | **NUOVO** | Guida deployment su SOL (build, install browser, config Claude Code, verifica) |
| `/data/massimiliano/docs/mcp/server.md` | **MODIFICA** | Sync con README |
| `/data/massimiliano/Vari/mcp-playwright-tools/README.md` | **NUOVO** | README libreria (15 tool, lazy init, config) |
| `/data/massimiliano/docs/mcp/playwright-tools.md` | **NUOVO** | Copia per docs/ |

---

## Step 1 — Aggiornare README.md del server MCP

File: `/data/massimiliano/Vari/mcp/README.md`

Modifiche:
- "11 tool libraries" → "12 tool libraries"
- "Requires Java 17+" → "Requires Java 21+"
- Aggiungere riga Playwright nella tabella Included Libraries:
  `| mcp-playwright-tools | 15 | MCP_PLAYWRIGHT_ENABLED=true | Browser automation (navigate, click, screenshot, snapshot, evaluate JS) |`
- Aggiornare "Total: ~251 tools" → "~266 tools" (251 + 15)
- Aggiungere `@Tool` Playwright nella sezione Tool Annotations
- Aggiungere sezione Configuration per Playwright:
  ```
  # Playwright Browser Automation (conditional)
  MCP_PLAYWRIGHT_ENABLED=true
  MCP_PLAYWRIGHT_BROWSER=chromium
  MCP_PLAYWRIGHT_HEADLESS=true
  ```
- Aggiornare sezione SQL: ora condizionale con `MCP_SQL_ENABLED=true` (default true)
- Requirements: Java 21, reactive-tools 0.3.0

## Step 2 — Creare SETUP.md del server MCP

File: `/data/massimiliano/Vari/mcp/SETUP.md`

Contenuto:
- **Prerequisiti**: Java 21 (Temurin), Maven 3.9+
- **Build**: `mvn clean package -DskipTests`
- **Playwright browser install**: `cd ../mcp-playwright-tools && mvn exec:java -e -Dexec.mainClass=com.microsoft.playwright.CLI -Dexec.args="install --with-deps chromium"`
- **Registrazione Claude Code**: sia `claude mcp add` che config manuale `~/.claude.json` con esempio completo env vars
- **Env vars reference**: tabella completa per libreria con default e note
- **Virtual threads**: `spring.threads.virtual.enabled=true` (Java 21)
- **Verifica**: come testare che il server parta (JSON-RPC initialize via stdin)
- **Troubleshooting**: errori comuni (UnsupportedClassVersionError se Java 17, Playwright browser non installato, ecc.)
- **Deployment su SOL**: path specifici (/opt/java21, /data/massimiliano/Vari/mcp/), build con `deploy-mcp` o manuale

## Step 3 — Sync docs/mcp/server.md

File: `/data/massimiliano/docs/mcp/server.md`

Stesso contenuto del README aggiornato (step 1).

## Step 4 — Creare README mcp-playwright-tools

File: `/data/massimiliano/Vari/mcp-playwright-tools/README.md`

Contenuto:
- Descrizione: Spring Boot starter per browser automation via Playwright Java
- 15 tool MCP: navigate, navigate_back, snapshot, screenshot, click, fill, select_option, press_key, type, evaluate, wait_for, get_content, tabs, close, resize
- Architettura: lazy init (PlaywrightProvider) + auto-recovery + graceful degradation
- Configurazione (`mcp.playwright.*` properties)
- Browser install (`mvn exec:java ... install chromium`)
- Dipendenze: Spring AI, Playwright Java
- Maven coordinates

## Step 5 — Creare docs/mcp/playwright-tools.md

File: `/data/massimiliano/docs/mcp/playwright-tools.md`

Stesso contenuto del README playwright-tools (step 4).

---

## Verifica

1. Leggere README.md e verificare coerenza con pom.xml (versioni, librerie)
2. Verificare che SETUP.md contenga tutti i passi per un deployment da zero
3. Controllare che docs/mcp/ sia in sync con i README
