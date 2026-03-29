# Fix: academic-researcher agent non ha i tool necessari per scrivere piani/todo

## Context

Il subagent `academic-researcher` ha solo 2 tool dichiarati nel frontmatter:
```yaml
tools: mcp__simoge-mcp__web_fetch, mcp__simoge-mcp__web_search
```

Il modello al suo interno tenta giustamente di usare `Write` (per plan file), `TodoWrite` (per tracciare progresso), ecc., ma fallisce perché quei tool non sono nella lista. L'errore `write_to_file` è il modello che cerca il tool con un nome sbagliato (Cline) via ToolSearch.

**Soluzione**: aggiungere i tool mancanti al campo `tools:` dell'agent.

## Piano

### 1. Ampliare la lista tool dell'agent

**File**: `/data/massimiliano/claude-shared/agents/academic-researcher.md` (riga 12)

Cambiare da:
```yaml
tools: mcp__simoge-mcp__web_fetch, mcp__simoge-mcp__web_search
```

A:
```yaml
tools: mcp__simoge-mcp__web_fetch, mcp__simoge-mcp__web_search, *
```

I due MCP tool restano espliciti (erano già lì), il `*` aggiunge tutto il resto (Read, Write, Edit, Bash, TodoWrite, Glob, Grep, Agent, ToolSearch, ecc.).

### 2. Aggiungere nota nel prompt per i nomi corretti dei tool

Aggiungere dopo riga 28 una breve nota:

```markdown
## TOOL NAMES

You have access to all Claude Code tools. Key names:
- File writing: `Write` (NOT `write_to_file`)
- File editing: `Edit`
- File reading: `Read`
- Progress tracking: `TodoWrite`
- Web: `mcp__simoge-mcp__web_search`, `mcp__simoge-mcp__web_fetch`
```

### 3. Verifica

- Lanciare il subagent `academic-researcher` con una query di test (es. "Bradley-Terry model overview")
- Verificare che crei il plan file e usi TodoWrite senza errori
- Verificare che la ricerca web funzioni ancora correttamente
