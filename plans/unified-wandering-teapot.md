# Piano: Import configurazioni Claude condivise in KORE

## Contesto

Le configurazioni condivise di Claude Code (skills, agents, memory, plugins) non sono presenti come nodi nel knowledge graph AGE. Queste contengono informazioni strutturate (frontmatter YAML) ideali per il graph. L'obiettivo è creare un import script che le porti in KORE e aggiungerlo allo scheduler notturno.

**Entità da importare:**
- **Skill** (~104): `/data/massimiliano/claude-shared/skills/*/SKILL.md` — frontmatter con name, description, category, tags, version
- **Agent** (4): `/data/massimiliano/claude-shared/agents/*.md` — frontmatter con name, description, tools, model
- **Memory** (~11): `/home/massimiliano/.claude/projects/-data-massimiliano/memory/*.md` — frontmatter con name, description, type
- **Plugin** (~41): `/data/massimiliano/claude-shared/plugins/installed_plugins.json` — JSON con plugin_id, version, scope

## Step 1 — Creare `import_claude_config.py`

Nuovo file: `/data/massimiliano/kindle/import_claude_config.py`

Pattern: identico a `import_chat_plans.py` (MERGE idempotente, batch 20, docker cp + psql, two-phase).

### Nodi AGE

| Label | Key | Proprietà | Source |
|-------|-----|-----------|--------|
| `Skill` | `name` | description, category, tags, version, allowed_tools, file_count, domain='personal' | SKILL.md frontmatter |
| `ClaudeAgent` | `name` | description, model, tools, version, domain='personal' | agents/*.md frontmatter |
| `Memory` | `name` | description, memory_type, path, domain='personal' | memory/*.md frontmatter |
| `Plugin` | `plugin_id` | version, scope, installed_at, last_updated, git_commit_sha, domain='personal' | installed_plugins.json |

> `ClaudeAgent` invece di `Agent` per evitare conflitto con label AGE riservate.

### Relazioni AGE

| Da | Tipo | A | Logica |
|----|------|---|--------|
| `Skill` | `IN_CATEGORY` | `SkillCategory` | Estratto dal campo `category` del frontmatter |
| `Skill` | `HAS_TAG` | `Tag` | Ciascun tag dal frontmatter, nodi Tag condivisi |

> Le relazioni Agent→Skill e Memory→* sono troppo ambigue da estrarre automaticamente — meglio non forzarle.

### Funzioni principali

```python
def scan_skills(skills_dir):
    """Scan skills/*/SKILL.md, parse YAML frontmatter, return list of dicts."""

def scan_agents(agents_dir):
    """Scan agents/*.md (esclude *.v*.md), parse YAML frontmatter."""

def scan_memory(memory_dir):
    """Scan memory/*.md (esclude MEMORY.md indice), parse YAML frontmatter."""

def scan_plugins(json_path):
    """Parse installed_plugins.json, return list of plugin dicts."""

def parse_frontmatter(filepath):
    """Extract YAML between --- markers, return dict."""

def generate_node_statements(skills, agents, memories, plugins):
    """Phase 1: MERGE tutti i nodi."""

def generate_relationship_statements(skills):
    """Phase 2: MERGE IN_CATEGORY e HAS_TAG edges."""
```

## Step 2 — Aggiungere al timer notturno

File: `/home/massimiliano/.config/systemd/user/infra-graph-sync.service`

Aggiungere terzo `ExecStart`:
```
ExecStart=python3 /data/massimiliano/kindle/import_claude_config.py --quiet
```

Poi `systemctl --user daemon-reload`.

## Step 3 — Test e verifica

```bash
# Dry run
python3 /data/massimiliano/kindle/import_claude_config.py --dry-run

# Esecuzione
python3 /data/massimiliano/kindle/import_claude_config.py

# Verifica nodi
graph_query("MATCH (s:Skill) RETURN count(s)")
graph_query("MATCH (a:ClaudeAgent) RETURN a.name, a.description")
graph_query("MATCH (m:Memory) RETURN m.name, m.memory_type")
graph_query("MATCH (p:Plugin) RETURN count(p)")

# Verifica relazioni
graph_query("MATCH (s:Skill)-[:IN_CATEGORY]->(c:SkillCategory) RETURN c.name, count(s) ORDER BY count(s) DESC")
```

## File coinvolti

- **Nuovo**: `/data/massimiliano/kindle/import_claude_config.py`
- **Modifica**: `/home/massimiliano/.config/systemd/user/infra-graph-sync.service` (aggiunta ExecStart)
- **Read-only**: `claude-shared/skills/*/SKILL.md`, `claude-shared/agents/*.md`, `memory/*.md`, `installed_plugins.json`
- **Pattern da seguire**: `/data/massimiliano/kindle/import_chat_plans.py`
