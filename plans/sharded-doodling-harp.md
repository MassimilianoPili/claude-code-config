# Piano: Pagina docs/ — Inventario completo Claude Code

## Context

Documentare **tutti** gli hook, skill, plugin e tool MCP configurati nell'ambiente Claude Code su Server SOL. Reference page per consultazione rapida, salvata in `/data/massimiliano/docs/` (visibile da MkDocs :8892).

Dati raccolti: **28 hook**, **103 skill + 22 plugin skill**, **41 plugin**, **286 tool MCP** (20 librerie).

## File da creare

`/data/massimiliano/docs/claude-code-inventario.md`

## Struttura della pagina

### 1. Hook (28)
Per evento: PreToolUse (6), PostToolUse (10), SessionStart (4), Stop (5), PreCompact (1), ConfigChange (1), UserPromptSubmit (1).
Tabella: Nome | Evento | Matcher | Descrizione | Async

### 2. Plugin (41)
Per categoria: Development (9), LSP (10), Output Styles (3), Security (2), Browser & Analysis (4), VCS & CI/CD (3), Project Management (4), Backend & Infra (3), Misc (3).
Tabella: Nome | Categoria | Descrizione | Stato

### 3. Skill (103 + 22 plugin)
Per dominio: Spring Boot/Java (33), AWS (26), Infra/DevOps (16), Frontend/Web (11), LangChain4j/AI (8), Specialized (6+), Plugin (22).
Tabella: Nome | Dominio | Descrizione

### 4. Tool MCP (286)
Per libreria (20):
- redis-tools (13), sql-tools (5), docker-tools (36), gitea-tools (17)
- graph-tools (24), vector-tools (5), mongo-tools (5)
- devops-tools (63 ⚠️ PAT revoked), ocp-tools (64), jira-tools (30)
- filesystem-tools (5), bash-tool (1), python-tool (1)
- playwright-tools (15), ollama-tools (4)
- recovery-tools (4), metacognition-tools (3), token-tools (2)
- Inline/main app (31): anki (11), web (5), claude task queue (5), api (3), openalex (3), context7 (2), research (1), ping (1)

Tabella: Nome | Libreria | Descrizione | Stato

## Verifica

- Conteggi: 28 hook + 41 plugin + 125 skill + 286 tool MCP
- Markdown standard (compatibile MkDocs Material)
- Lingua: italiano per struttura, nomi tecnici in inglese
