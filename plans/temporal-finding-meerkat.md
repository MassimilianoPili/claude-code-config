# Piano: Import Completo Agent Claude Code in KORE

## Context

KORE ha già 1 nodo `ClaudeAgent` (academic-researcher, creato in questa sessione). Servono ~60 nodi per mappare tutti gli agent Claude Code attivi nel sistema, suddivisi in 4 categorie. Questo crea un inventario queryable di tutte le capacità AI disponibili.

## Inventario agent (58 totali)

| Categoria | Count | Sorgente | Esempio |
|-----------|-------|----------|---------|
| **custom** | 3 | `claude-shared/agents/*.md` | academic-researcher, spring-boot-migrator |
| **builtin** | 3 | Hardcoded (nessun file) | general-purpose, Explore, Plan |
| **plugin** | 16 | `plugins/marketplaces/.../agents/*.md` | code-architect, silent-failure-hunter |
| **framework** | 38 | `agent-framework/.claude/agents/*/SKILL.md` | be-kotlin, dba-postgres, planner |

## Modello grafo

### Label: `ClaudeAgent`

Properties:
- `name` (string, PK per MERGE) — nome univoco, prefisso plugin per plugin agents (es. `pr-review-toolkit:code-reviewer`)
- `category` — `custom` | `builtin` | `plugin` | `framework`
- `plugin` — nome plugin (solo per category=plugin, es. `pr-review-toolkit`)
- `model` — `claude-opus-4-6` | `sonnet` | null
- `description` — prima riga della description dal frontmatter (troncata a 200 char)
- `file_path` — path assoluto del file .md
- `domain` — `config` (sempre, come da nodo esistente)
- `updated_at` — data dell'import

### Relazioni

| Relazione | Da | A | Quando |
|-----------|-----|---|--------|
| `PART_OF` | ClaudeAgent (plugin) | Plugin (nuovo label) | Per ogni agent di un plugin |
| `PART_OF` | ClaudeAgent (framework) | DockerService `agentfw-orchestrator` | Se esiste, altrimenti collegamento generico |
| `USED_BY` | ClaudeAgent (custom/builtin) | DockerService `simoge-mcp` | Agent disponibili nel server MCP |
| `IMPLEMENTS` | ClaudeAgent | Convention | Per academic-researcher (già fatto) |

### Label: `Plugin` (nuovo)

Properties:
- `name` — nome plugin (es. `pr-review-toolkit`)
- `source` — `claude-plugins-official`
- `domain` — `config`

## Implementazione

### Script: `/data/massimiliano/kindle/import_agents.py`

Pattern: stesso degli altri import script (psql, AGE cypher, MERGE idempotente, two-phase).

**Phase 1 — Data collection:**
1. Scan `claude-shared/agents/*.md` → parse YAML frontmatter → custom agents
2. Hardcode built-in agents (general-purpose, Explore, Plan) con descrizioni dal system prompt
3. Scan `plugins/marketplaces/.../plugins/*/agents/*.md` → parse YAML frontmatter → plugin agents
4. Scan `agent-framework/.claude/agents/*/SKILL.md` → parse YAML frontmatter → framework agents
5. Deduplicate (skip `academic-researcher.v1.md`, skip plugin cache duplicates)

**Phase 2 — Node generation:**
- MERGE per ogni ClaudeAgent
- MERGE per ogni Plugin (deduplicated)

**Phase 3 — Relationship generation:**
- Plugin agents → PART_OF → Plugin
- Framework agents → PART_OF → (DockerService agentfw se esiste, altrimenti skip)
- Custom/builtin → USED_BY → DockerService simoge-mcp

**Execution:** `python3 import_agents.py [--dry-run]`

## File da creare

- `/data/massimiliano/kindle/import_agents.py` — script di import (~200 righe)

## Verifica

1. `--dry-run` mostra tutti gli statement senza eseguirli
2. Query: `MATCH (a:ClaudeAgent) RETURN a.category, count(a)` → 4 categorie, ~58 totali
3. Query: `MATCH (a:ClaudeAgent)-[:PART_OF]->(p:Plugin) RETURN p.name, count(a)` → 6 plugin con agent
4. Idempotente: eseguire 2 volte non crea duplicati
