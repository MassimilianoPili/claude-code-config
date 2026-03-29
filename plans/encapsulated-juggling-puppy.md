# Piano: Code Knowledge Graph (ispirato ad Axon)

## Context

Evolvere KORE aggiungendo comprensione strutturale del codice su **tutto `/data/massimiliano/`**. Parsing AST via Tree-sitter, grafo relazioni in AGE `code_graph`, embedding vettoriali pgvector per ricerca semantica.

Ispirazione primaria: **Axon** (12-phase pipeline, 7 MCP tools). Cherry-pick da **Code-Graph-RAG** (language spec pattern, FunctionRegistryTrie) e **Aider** (PageRank personalizzato, tags.scm per 20+ linguaggi).

**Riferimenti accademici**: CodexGraph (arXiv:2408.03910), Gall et al. 1998 (logical coupling).

## Cosa esiste già nel nostro stack

| Componente | Stato | Riuso |
|------------|-------|-------|
| `mcp-code-tools` (v0.1.0) | ⚠️ Standalone, **JNI tree-sitter non carica in Docker** (commentato in mcp/pom.xml L148) | I 13 tool esistenti (code_stats, code_find_definition, ...) operano su file live. Aggiungere nuovi tool che interrogano AGE `code_graph` (no JNI necessario) |
| `mcp-graph-tools` (v0.1.3) | ✅ In simoge-mcp | Cypher queries su AGE — `graph_query` già opera su `code_graph` |
| `mcp-vector-tools` (v0.3.1) | ✅ In simoge-mcp | pgvector search — `embeddings_search_docs` con filtro `domain="code"` |
| AGE grafo `code_graph` | ✅ Creato (vuoto) | Pronto per nodi/archi |
| `qwen3-embedding:8b` | ✅ Su gaia via Ollama | 4096d, MRL |
| `paper_archive.py` (1354 righe) | ✅ Pattern completo | `get_pg_connection()`, `execute_age()`, `get_embedding()`, `upsert_embedding()` — tutto riutilizzabile |
| `vector_store` table | ✅ Esistente | Riusare con `metadata.domain = "code"` (stesso pattern docs/papers) |

### Decisione architetturale: Python per parsing, Java per query

Il JNI tree-sitter (`ch.usi.si.seart:java-tree-sitter:1.12.0`) non carica nel container Docker scratch di `simoge-mcp`. Conseguenza:
- **Parsing AST + population grafo** → Python batch (`code_graph.py`, pattern `paper_archive.py`)
- **Query runtime sul grafo popolato** → Java MCP tools (query AGE Cypher + pgvector, zero JNI)
- **Vantaggio**: stessa architettura di `paper_archive.py` → AGE → `mcp-graph-tools` query

## Schema grafo AGE `code_graph` (modellato su Axon)

### Nodi (8 tipi)
| Label | Proprietà | Fase |
|-------|-----------|------|
| `Folder` | `name`, `path`, `relative_path` | 2-structure |
| `File` | `name`, `path`, `relative_path`, `extension`, `size`, `language`, `git_hash` | 1-walk |
| `Function` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end`, `signature`, `dead` | 3-parse |
| `Class` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` | 3-parse |
| `Method` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end`, `signature`, `dead` | 3-parse |
| `Interface` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` | 3-parse |
| `Community` | `community_id`, `size` | 8-communities |
| `Process` | `name`, `entry_point`, `framework` | 9-processes |

### Archi (11 tipi)
| Label | Da → A | Proprietà | Fase |
|-------|--------|-----------|------|
| `CONTAINS` | Folder→File, File→Symbol | — | 2-structure |
| `DEFINES` | File→Symbol | — | 3-parse |
| `CALLS` | Symbol→Symbol | `confidence` (1.0/0.8/0.5) | 5-calls |
| `IMPORTS` | File→File | `symbols` (JSON text) | 4-imports |
| `EXTENDS` | Class→Class | — | 6-heritage |
| `IMPLEMENTS` | Class→Interface | — | 6-heritage |
| `USES_TYPE` | Symbol→Symbol | `role` (param/return/variable) | 7-types |
| `MEMBER_OF` | Symbol→Community | — | 8-communities |
| `STEP_IN_PROCESS` | Symbol→Process | `step_number` | 9-processes |
| `COUPLED_WITH` | File→File | `strength` (float), `co_changes` (int) | 11-coupling |
| `HAS_DEAD_CODE` | File→Symbol | — | 10-dead_code |

### Node ID format (da Axon)
`{label}:{relative_path}:{symbol_name}` — es. `function:Vari/anthropic-api-proxy/main.go:handleRequest`

### pgvector table
```sql
CREATE TABLE code_embeddings (
    id SERIAL PRIMARY KEY,
    node_id TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    qualified_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    source_code TEXT,
    embedding vector(4096),
    embed_model TEXT DEFAULT 'qwen3-embedding:8b',
    embed_version INT DEFAULT 1,
    indexed_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON code_embeddings USING hnsw (embedding vector_cosine_ops);
```

## Pipeline a 12 fasi (adattato da Axon)

Architettura chiave: **file-local** (fasi 1-7, O(file modificati)) vs **global** (fasi 8-12, O(intero grafo)).

### Fasi file-local (esecuzione immediata su file change)

| # | Fase | Input | Output | Note |
|---|------|-------|--------|------|
| 1 | **walk** | Directory root | Nodi `File` + `Folder` | Rispetta `.gitignore`, esclude `node_modules/`, `target/`, `.git/`, `data/`, binary |
| 2 | **structure** | File/Folder nodes | Archi `CONTAINS` (Folder→File) | Gerarchia directory → grafo |
| 3 | **parse** | File sorgenti | Nodi `Function`, `Class`, `Method`, `Interface` + archi `DEFINES` | Tree-sitter AST. Language spec pattern (da Code-Graph-RAG): tuple per linguaggio |
| 4 | **imports** | AST import statements | Archi `IMPORTS` (File→File) con `symbols` JSON | Risoluzione path relativi/assoluti/bare |
| 5 | **calls** | AST call expressions | Archi `CALLS` con `confidence` | FunctionRegistryTrie (da Code-Graph-RAG) + confidence scoring (da Axon): 1.0 exact, 0.8 receiver, 0.5 fuzzy. Blocklist 138 builtin |
| 6 | **heritage** | AST class declarations | Archi `EXTENDS`, `IMPLEMENTS` | Ereditarietà + implementazione interfacce |
| 7 | **types** | AST type annotations | Archi `USES_TYPE` con `role` | Parametri, return type, variabili tipate |

### Fasi globali (batch, non per singolo file)

| # | Fase | Input | Output | Note |
|---|------|-------|--------|------|
| 8 | **communities** | Intero grafo CALLS | Nodi `Community` + archi `MEMBER_OF` | Leiden algorithm via `igraph` + `leidenalg`. Clustering simboli accoppiati |
| 9 | **processes** | Entry points | Nodi `Process` + archi `STEP_IN_PROCESS` | BFS da entry points. Detect: `@app.route`, `main()`, `func main()`, `@RequestMapping`, `@Tool`, `public static void main`, `test_*` |
| 10 | **dead_code** | Grafo CALLS completo | Archi `HAS_DEAD_CODE` | 4 passi Axon: (1) scan no incoming CALLS, (2) exemptions (entry points, constructors, test, decorators, exports), (3) override pass, (4) protocol conformance |
| 11 | **coupling** | Git log 6 mesi | Archi `COUPLED_WITH` | `strength = co_changes / max(commits_A, commits_B)`, soglia ≥0.3 AND ≥3 co-changes (Gall et al. 1998) |
| 12 | **embeddings** | Source code simboli | Tabella `code_embeddings` | `qwen3-embedding:8b` via Ollama su gaia, 4096d. Chunk = signature + body |

## Linguaggi supportati (Language Spec Pattern)

Pattern da Code-Graph-RAG: tuple `(function_nodes, class_nodes, import_nodes, call_nodes)` per linguaggio.

| Linguaggio | Scope iniziale |
|------------|---------------|
| Java | MCP libraries, agent-framework, mcp server |
| Go | anthropic-api-proxy, mcp-proxy, knowledge-graph, embedding-viz, go-filemanager, wg-manager |
| Python | kindle scripts, code_graph.py stesso |
| TypeScript/JavaScript | dashboard, code-server config |
| Bash | shell-scripts/bin/ |
| Lua | configurazioni |

## MCP Tools (8 tool, modellati su Axon)

Estendere `mcp-code-tools` esistente, poi integrarlo in `simoge-mcp`.

| Tool | Parametri | Ispirazione | Descrizione |
|------|-----------|-------------|-------------|
| `code_query(query, limit)` | query: string, limit: int=10 | Axon `axon_query` | Ricerca ibrida: BM25 + vector (RRF fusion) su code_embeddings |
| `code_context(symbol)` | symbol: string | Axon `axon_context` | Vista 360°: callers, callees, types, community, process, heritage |
| `code_impact(symbol, depth)` | symbol: string, depth: int=3 | Axon `axon_impact` | Blast radius BFS: depth 1="will break", 2="may break", 3+="review". Include COUPLED_WITH |
| `code_dead_code()` | — | Axon `axon_dead_code` | Simboli irraggiungibili raggruppati per file |
| `code_detect_changes(git_diff)` | git_diff: string | Axon `axon_detect_changes` | Overlay diff su grafo: mappa range linee a simboli + contesto call graph |
| `code_structure(path)` | path: string | Nostro | Schema file: classi, funzioni, imports, archi |
| `code_dependencies(path, depth)` | path: string, depth: int=3 | Nostro | Grafo dipendenze transitivo (IMPORTS ricorsivo) |
| `code_stats()` | — | Axon `axon_list_repos` | Statistiche: file, simboli, archi per tipo/linguaggio |

## Implementazione — 4 fasi di sviluppo

### Fase 0: Pipeline Python (`code_graph.py`) — CORE
**File**: `/data/massimiliano/kindle/code_graph.py`
**Wrapper**: `shell-scripts/bin/code-graph`
**Stima**: ~800-1200 righe (confronto: `paper_archive.py` = 1354 righe)

#### Pattern riusati da `paper_archive.py`
```python
# Connessione — riusare identico (kindle/paper_archive.py L48-59)
get_pg_connection()          # lazy singleton psycopg2, PG_HOST=172.20.0.9, PG_DB=embeddings
execute_age(statements)      # Cypher via psycopg2 diretto, fallback docker exec
esc(s)                       # AGE string escaping (L88-92)

# Embedding — riusare identico (kindle/paper_archive.py L959-976)
get_embedding(text)          # POST http://127.0.0.1:11434/api/embed, qwen3-embedding:8b

# Vector store — riusare vector_store table con domain="code" (L979-1023)
upsert_embedding(name, label, domain="code", mini_doc, embedding)
```

**Strategia**: importare direttamente da `paper_archive.py` oppure estrarre un modulo comune `kindle/db_utils.py` con le funzioni condivise.

#### Struttura script
```python
# Subcomandi (argparse, stesso pattern paper_archive.py)
code-graph index <dir>       # Full pipeline 12 fasi
code-graph update <dir>      # Incrementale (file modificati via git diff / hash)
code-graph parse <dir>       # Solo parse AST, output JSON (debug)
code-graph stats             # Statistiche grafo da AGE
code-graph coupling <dir>    # Solo fase 11 (git co-change analysis)

# Language spec pattern (da Code-Graph-RAG)
LANG_SPECS = {
    "java":       LangSpec(func=["method_declaration", "constructor_declaration"],
                           cls=["class_declaration", "interface_declaration", "enum_declaration", "record_declaration"],
                           imp=["import_declaration"],
                           call=["method_invocation"]),
    "go":         LangSpec(func=["function_declaration", "method_declaration"],
                           cls=["type_spec"],
                           imp=["import_declaration", "import_spec"],
                           call=["call_expression"]),
    "python":     LangSpec(func=["function_definition"],
                           cls=["class_definition"],
                           imp=["import_statement", "import_from_statement"],
                           call=["call"]),
    "typescript": LangSpec(func=["function_declaration", "method_definition", "arrow_function"],
                           cls=["class_declaration", "interface_declaration"],
                           imp=["import_statement"],
                           call=["call_expression"]),
    "bash":       LangSpec(func=["function_definition"],
                           cls=[],
                           imp=["command"],  # source/. commands
                           call=["command"]),
}
```

#### Esclusioni directory
```python
EXCLUDED_DIRS = {
    "node_modules", "target", ".git", "data", "__pycache__", ".idea",
    "build", "dist", ".gradle", "vendor", "venv", ".venv",
    "relay-data", "client-data", "runner-data", "gitea-data",
    "grafana", "loki", "prometheus",  # monitoring data
}
EXCLUDED_EXTENSIONS = {".class", ".jar", ".war", ".so", ".dylib", ".o", ".pyc", ".pyo"}
```

#### Hash cache per incrementale (da Code-Graph-RAG)
```python
# File: /data/massimiliano/.code_graph_hashes.json
# {"relative/path/file.java": "sha256hex", ...}
# Su update: confronta hash, re-parse solo file cambiati
# Su index: ricalcola tutto, sovrascrive cache
```

### Fase 1: Storage (vector_store + AGE `code_graph`)

**Nessuna nuova tabella** — riusare `vector_store` esistente con `metadata.domain = "code"`:
```python
upsert_embedding(
    name="function:Vari/anthropic-api-proxy/main.go:handleRequest",
    label="Function",
    domain="code",  # distingue da "docs", "paper", etc.
    mini_doc="func handleRequest(w http.ResponseWriter, r *http.Request) { ... }",
    embedding=get_embedding(source_code),
    source="code_graph",
    file_path="Vari/anthropic-api-proxy/main.go",
    language="go",
    line_start=42,
    line_end=98
)
```

**AGE `code_graph`**: già esiste, verificare con:
```sql
SELECT * FROM ag_catalog.ag_graph WHERE name = 'code_graph';
```

### Fase 2: MCP Tools — nuova classe `CodeGraphTools.java`
**Dir**: `/data/massimiliano/Vari/mcp-code-tools/src/main/java/io/github/massimilianopili/mcp/code/`
**File nuovo**: `CodeGraphTools.java`

**Architettura**: i nuovi tool **non usano tree-sitter JNI** — interrogano solo AGE e pgvector via JDBC/psycopg2.
Dipendenze: `mcp-graph-tools` (per `AgeQueryService`) + `mcp-vector-tools` (per `VectorSearchService`).

```java
@ReactiveTool(name = "code_query", description = "Hybrid semantic + text search on code graph",
              timeoutSeconds = 30)
public Mono<String> codeQuery(@ToolArg("query") String query,
                               @ToolArg(value = "limit", required = false) Integer limit) {
    // 1. Vector search: embeddings_search_docs(query, domain="code")
    // 2. Text search: AGE MATCH WHERE f.name CONTAINS query
    // 3. RRF fusion: 1/(k+rank_vector) + 1/(k+rank_text), k=60
}

@ReactiveTool(name = "code_context", description = "360° view of a symbol: callers, callees, types, community")
// AGE Cypher: MATCH (s)-[:CALLS]->(target), MATCH (caller)-[:CALLS]->(s), etc.

@ReactiveTool(name = "code_impact", description = "Blast radius BFS: will break / may break / review")
// AGE Cypher: recursive BFS on reverse CALLS + COUPLED_WITH

@ReactiveTool(name = "code_dead_code", description = "Unreachable symbols grouped by file")
// AGE Cypher: MATCH (f:Function) WHERE NOT ()-[:CALLS]->(f) AND f.dead = true

@ReactiveTool(name = "code_detect_changes", description = "Overlay git diff on graph, map line ranges to symbols")
// Parse diff → extract file + line ranges → AGE MATCH WHERE line_start/line_end overlap

@ReactiveTool(name = "code_structure", description = "File structure: classes, functions, imports")
// AGE Cypher: MATCH (file:File {path: X})-[:DEFINES]->(s) RETURN s

@ReactiveTool(name = "code_dependencies", description = "Transitive import graph")
// AGE Cypher: recursive IMPORTS traversal

@ReactiveTool(name = "code_stats", description = "Graph statistics: nodes, edges by type and language")
// AGE Cypher: MATCH (n) RETURN labels(n), count(n) + edges
```

**Integrazione in simoge-mcp**:
- Problema JNI: i tool di Fase 2 **non** usano tree-sitter → si possono abilitare separatamente
- Opzione A: abilitare solo `CodeGraphTools` (nuova) in simoge-mcp, lasciare `CodeParser` disabilitato
- Opzione B: creare una nuova libreria `mcp-code-graph-tools` (senza dipendenza tree-sitter)
- **Scelta**: Opzione A — condizionare con `@ConditionalOnProperty("mcp.code.graph.enabled")`

### Fase 3: Aggiornamento incrementale + timer

#### Incrementale via hash
```bash
code-graph update /data/massimiliano/
# 1. Legge .code_graph_hashes.json
# 2. Walk directory, calcola hash SHA256 per ogni file sorgente
# 3. File nuovi/modificati → re-parse (fasi 1-7 file-local)
# 4. File rimossi → delete nodi/archi dal grafo
# 5. Se ≥10 file cambiati → ricalcola fasi globali (8-12)
# 6. Aggiorna .code_graph_hashes.json
```

#### Timer systemd (pattern `paper-archive-scan.timer`)
```ini
# ~/.config/systemd/user/code-graph-sync.timer
[Timer]
OnCalendar=*-*-* 02:30:00
Persistent=true

# ~/.config/systemd/user/code-graph-sync.service
[Service]
ExecStart=/data/massimiliano/shell-scripts/bin/code-graph index /data/massimiliano/
Environment=PG_HOST=172.20.0.9
```

#### Hook post-deploy (in `sol` script)
```bash
# Dopo deploy di qualsiasi servizio, re-index incrementale
code-graph update /data/massimiliano/ &
```

## File da creare/modificare

| File | Azione | Note |
|------|--------|------|
| `kindle/code_graph.py` | **Nuovo** | Pipeline 12 fasi (~800-1200 righe) |
| `kindle/db_utils.py` | **Nuovo** (opzionale) | Estrarre funzioni condivise da paper_archive.py: `get_pg_connection`, `execute_age`, `esc`, `get_embedding`, `upsert_embedding` |
| `shell-scripts/bin/code-graph` | **Nuovo** | Wrapper CLI (pattern `paper-archive`, 5 righe) |
| `Vari/mcp-code-tools/.../CodeGraphTools.java` | **Nuovo** | 8 tool @ReactiveTool (query AGE + pgvector, zero JNI) |
| `Vari/mcp-code-tools/.../CodeToolsAutoConfiguration.java` | **Modifica** | +import `CodeGraphTools`, `@ConditionalOnProperty` |
| `Vari/mcp/pom.xml` | **Modifica** | Riabilitare `mcp-code-tools` (solo graph tools, non parser) |
| `Vari/mcp/.env` | **Modifica** | `MCP_CODE_GRAPH_ENABLED=true` |
| `~/.config/systemd/user/code-graph-sync.{timer,service}` | **Nuovo** | Timer notturno full reindex |

## Dipendenze

| Dipendenza | Stato | Azione |
|------------|-------|--------|
| `py-tree-sitter` | ❌ | `pip install tree-sitter` |
| `tree-sitter-languages` | ❌ | `pip install tree-sitter-languages` |
| `igraph` | ❌ | `pip install igraph` (community detection Leiden) |
| `leidenalg` | ❌ | `pip install leidenalg` |
| `psycopg2-binary` | ✅ | — |
| `mcp-code-tools` (Java) | ✅ v0.1.0 | Aggiungere `CodeGraphTools.java` |
| `mcp-graph-tools` | ✅ In simoge-mcp | Riusare `AgeQueryService` |
| `mcp-vector-tools` | ✅ In simoge-mcp | Riusare `VectorSearchService` |
| AGE `code_graph` | ✅ Creato | — |
| `vector_store` table | ✅ Esistente | Riusare con `domain="code"` |
| `qwen3-embedding:8b` | ✅ Su gaia | — |

## Verifica end-to-end

### Python pipeline
1. `pip install tree-sitter tree-sitter-languages igraph leidenalg` → OK
2. `code-graph parse /data/massimiliano/Vari/anthropic-api-proxy/` → JSON con nodi/archi (4 file Go)
3. `code-graph index /data/massimiliano/Vari/anthropic-api-proxy/` → nodi in AGE, embedding in vector_store
4. `graph_stats(backend="age", graph="code_graph")` → conteggio nodi/archi per tipo
5. `code-graph index /data/massimiliano/` → full index tutto il codice del server (~stimato 500-1000 file sorgente)
6. `code-graph update /data/massimiliano/` → incrementale (solo file con hash diverso)

### MCP tools (dopo Fase 2)
7. `code_query("JWT token validation")` → trova funzioni rilevanti (RRF search)
8. `code_context("handleRequest")` → vista 360° (callers, callees, types)
9. `code_impact("handleRequest", depth=3)` → blast radius raggruppato per profondità
10. `code_dead_code()` → funzioni mai chiamate con exemptions
11. `code_detect_changes("<git diff output>")` → overlay diff su grafo
12. `code_stats()` → statistiche complete

### Cross-reference con KORE esistente
13. `graph_query("MATCH (f:Function)-[:CALLS]->(g:Function) RETURN f.name, g.name LIMIT 20", graph="code_graph")` → call graph funzionante
14. `embeddings_search_docs("proxy authentication handler", domain="code")` → ricerca semantica su codice
