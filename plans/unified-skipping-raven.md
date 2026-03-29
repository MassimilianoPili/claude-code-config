# Aggiungere README.md ai progetti in Vari/

## Context
Diversi progetti in `/data/massimiliano/Vari/` non hanno README.md. L'utente vuole aggiungerli.

## Progetti che necessitano README (11)

| # | Progetto | Tipo | Lingua |
|---|----------|------|--------|
| 1 | `go-filemanager` | Web file manager con OIDC | Go |
| 2 | `preference-sort` | Bradley-Terry ranking API | Go |
| 3 | `server-api` | Docker management API + UI | Go |
| 4 | `solsec` | Security/sanitization library | Go |
| 5 | `mcp-bash-tool` | MCP shell command tool | Java/Spring |
| 6 | `mcp-azure-tools` | Azure MCP tools suite (multi-module) | Java/Spring |
| 7 | `ClaudeRSS` | Android RSS reader con AI | Kotlin |
| 8 | `places-helper` | Chrome extension (Accenture Places) | JavaScript |
| 9 | `Luna` | Frontend web app | Angular 19 |
| 10 | `JobLab` | Java library | Java/Gradle |
| 11 | `MassimilianoPili.github.io` | Portfolio + tools | Astro |

## Approccio

Per ogni progetto: leggere i file principali (main, Dockerfile, go.mod/pom.xml, .env) e scrivere un README conciso con:
- Titolo + descrizione (1-2 righe)
- Features (bullet list)
- Project structure (albero essenziale)
- Configuration (tabella variabili env, senza valori)
- Run/Build commands
- API endpoints (se applicabile)
- Dependencies (tabella)

Stile: inglese, tecnico, come il README di knowledge-graph appena scritto.

## Piano di esecuzione

1. Leggere i file chiave di ogni progetto (in parallelo dove possibile)
2. Scrivere i README uno alla volta
3. Commit + push per ogni repo separatamente

## Verifica
- Ogni README creato e verificato con `cat`
- `git status` pulito dopo ogni push
