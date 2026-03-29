# Deep Dive: Code Knowledge Graph Projects

## Research Summary

Analysis of 4 open-source code knowledge graph projects with focus on implementation
details adaptable to our stack (PostgreSQL AGE + pgvector + Ollama).

**Epistemic status:** Implementation analysis from primary sources (GitHub repos, docs.rs, DeepWiki).
All details verified against actual repository documentation, not hallucinated.

---

## 1. AXON (PRIMARY) — harshkedia177/axon

**GitHub:** https://github.com/harshkedia177/axon (~560 stars)
**Stack:** Python 3.11+ / FastAPI / KuzuDB / tree-sitter / BAAI/bge-small-en-v1.5 / React+Sigma.js
**Languages:** Python, TypeScript, JavaScript (3 languages only)

### 1.1 The 12-Phase Pipeline

Each phase runs sequentially on first index. Incremental updates split phases into
**file-local** (run immediately on change) and **global** (batched every 30s).

| # | Phase | Type | What it does |
|---|-------|------|-------------|
| 1 | **walk** | file-local | Repository traversal respecting `.gitignore`. Discovers all source files. Produces File nodes. |
| 2 | **structure** | file-local | Builds Folder/File hierarchy with CONTAINS edges. Maps the directory tree into the graph. |
| 3 | **parse** | file-local | Tree-sitter AST extraction. Creates Function, Class, Method, Interface, Enum, TypeAlias nodes. Each node gets `name`, `file_path`, `line_start`, `line_end`. |
| 4 | **imports** | file-local | Maps import statements to actual files. Handles relative, absolute, and bare specifiers. Creates IMPORTS edges with `symbols` list property. |
| 5 | **calls** | file-local | Function call mapping. Creates CALLS edges with `confidence` scores (1.0=exact match, 0.8=receiver method, 0.5=fuzzy). Filters 138 language builtins (Python `print`, `len`; JS `console`, `fetch`; React `useState`). |
| 6 | **heritage** | file-local | Class inheritance (EXTENDS edges) and interface implementation (IMPLEMENTS edges). |
| 7 | **types** | file-local | Extracts type references from parameters, return types, annotations. Creates USES_TYPE edges with `role` property (param/return/variable). |
| 8 | **communities** | global | Leiden algorithm clustering (via igraph + leidenalg). Creates Community nodes and MEMBER_OF edges. Groups tightly-coupled symbols. |
| 9 | **processes** | global | Framework-aware entry point detection + BFS flow tracing. Detects `@app.route`, `@router.get`, `@click.command`, `test_*` functions, `__main__` blocks. Creates Process nodes and STEP_IN_PROCESS edges with `step_number`. |
| 10 | **dead_code** | global | Multi-pass analysis: (1) Initial scan flags symbols with no incoming CALLS. (2) Exemptions: entry points, exports, constructors, test code, dunder methods, `__init__.py` public symbols, decorated functions, `@property`. (3) Override pass: methods overriding non-dead base class methods exempt. (4) Protocol conformance check. Creates HAS_DEAD_CODE edges. |
| 11 | **coupling** | global | Git history analysis over 6-month window. Extracts commit-level co-change patterns. Files with coupling strength >= 0.3 AND >= 3 co-changes get COUPLED_WITH edges with `strength` (float) and `co_changes` (int) properties. |
| 12 | **embeddings** | global | 384-dim vectors via BAAI/bge-small-en-v1.5 (local inference, no API). Stored in KuzuDB's HNSW vector index. Used for semantic search in axon_query. |

### 1.2 Incremental Update Strategy

- **File watcher**: Rust-based `watchfiles` library with 500ms debounce
- **File-local phases** (1-7): Run immediately on detected change for affected files only
- **Global phases** (8-12): Batch every 30 seconds
- **Full rebuild**: `axon analyze --full` flag skips incremental, rebuilds everything
- **Watch mode**: `axon watch` re-indexes on every save

**Key insight for our implementation:** The split between file-local and global phases is
the most important architectural decision. Phases 1-7 are O(changed files), phases 8-12
are O(entire graph). The 30-second batching prevents global phases from running on every keystroke.

### 1.3 The 7 MCP Tools

#### 1. `axon_query(query: str, limit: int = 10)`
Hybrid search combining 3 signals via Reciprocal Rank Fusion (RRF):
- **BM25**: Full-text search on symbol names and code content
- **Vector**: Cosine similarity on 384-dim bge-small embeddings
- **Fuzzy**: Levenshtein distance matching on symbol names

Returns ranked results grouped by execution flow (Process), not flat list.

#### 2. `axon_context(symbol: str)`
360-degree view of a symbol. Returns:
- Callers (who calls this?)
- Callees (what does this call?)
- Type references (what types does this use/return?)
- Community membership
- Process membership (which execution flows include this?)
- Heritage (parent class, implemented interfaces)

#### 3. `axon_impact(symbol: str, depth: int = 3)`
Blast radius analysis. BFS traversal of reverse call graph from target symbol.
Returns affected symbols grouped by depth:
- **Depth 1** = "will break" (direct callers)
- **Depth 2** = "may break" (callers of callers)
- **Depth 3+** = "review" (transitive impact)

Each result includes confidence score from the CALLS edge.
Also includes COUPLED_WITH files -- if you change `user.py`, it flags `user_test.py`
and `auth_middleware.py` as coupled.

#### 4. `axon_dead_code()`
No parameters. Returns all unreachable symbols grouped by file.
Based on the multi-pass dead code detection from phase 10.

#### 5. `axon_detect_changes(git_diff: str)`
Takes raw `git diff` output as input string. Parses the diff to identify:
- Which files changed
- Which line ranges changed
- Maps line ranges to symbols in the graph (using line_start/line_end properties)
- Returns affected symbols with their call graph context

**Implementation note:** This is essentially "overlay the diff on the graph" --
it does NOT re-parse. It uses the existing graph's line number mappings.

#### 6. `axon_list_repos()`
No parameters. Returns all indexed repositories with stats (file count, symbol count, edge count).

#### 7. `axon_cypher(query: str)`
Read-only Cypher query execution against KuzuDB. Raw graph access for ad-hoc analysis.

### 1.4 Complete Graph Schema

**Node Types and Properties:**

| Label | Properties |
|-------|-----------|
| `File` | `name`, `path`, `relative_path`, `extension`, `size` |
| `Folder` | `name`, `path`, `relative_path` |
| `Function` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end`, `signature` |
| `Class` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` |
| `Method` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end`, `signature` |
| `Interface` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` |
| `Enum` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` |
| `TypeAlias` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` |
| `Variable` | `name`, `qualified_name`, `file_path`, `line_start`, `line_end` |
| `Community` | `id`, `size` |
| `Process` | `name`, `entry_point`, `framework` |

**Edge Types and Properties:**

| Edge | From -> To | Properties |
|------|-----------|-----------|
| `CONTAINS` | Folder->File, File->Symbol | — |
| `DEFINES` | File->Symbol | — |
| `CALLS` | Symbol->Symbol | `confidence` (0.0-1.0) |
| `IMPORTS` | File->File | `symbols` (list) |
| `EXTENDS` | Class->Class | — |
| `IMPLEMENTS` | Class->Interface | — |
| `USES_TYPE` | Symbol->Symbol | `role` (param/return/variable) |
| `EXPORTS` | File->Symbol | — |
| `MEMBER_OF` | Symbol->Community | — |
| `STEP_IN_PROCESS` | Symbol->Process | `step_number` (int) |
| `COUPLED_WITH` | File->File | `strength` (float), `co_changes` (int) |
| `HAS_DEAD_CODE` | File->Symbol | — |

**Node ID Format:** `{label}:{relative_path}:{symbol_name}`
Example: `function:src/auth/validate.py:validate_user`

### 1.5 COUPLED_WITH Implementation Detail

The git co-change analysis works as follows:
1. Iterate through git log for last 6 months
2. For each commit, extract the list of changed files
3. For each pair of files changed in the same commit, increment co-change counter
4. Calculate coupling strength = co_changes / max(commits_touching_A, commits_touching_B)
5. Only create COUPLED_WITH edge if strength >= 0.3 AND co_changes >= 3

This is a well-known technique from software evolution research (originally from
Gall et al., "Detection of Logical Coupling Based on Product Release History", ICSM 1998).

### 1.6 Embedding Strategy

- **Model:** BAAI/bge-small-en-v1.5 (384 dimensions)
- **What gets embedded:** Symbol source code (function body, class definition)
- **Storage:** KuzuDB HNSW vector index (embedded DB, not external)
- **Local inference:** sentence-transformers library, no API calls
- **Search:** Combined with BM25 + fuzzy via Reciprocal Rank Fusion

**Adaptation for our stack:** Replace bge-small with `qwen3-embedding:8b` via Ollama
(4096 dim, MRL supported). Store in pgvector. RRF fusion logic is straightforward to implement.

### 1.7 Confidence Scoring System

CALLS edges have confidence levels:
- **1.0** = Exact qualified name match (e.g., `module.function()`)
- **0.8** = Receiver method match (e.g., `obj.method()` where obj's type is known)
- **0.5** = Fuzzy match (same function name, ambiguous module)

### 1.8 Architecture Notes

- **Python 3.11+** with FastAPI for HTTP/SSE
- **KuzuDB** as embedded graph DB (no separate server process)
- **React + Sigma.js** frontend with WebGL force-directed graph
- **SSE** (Server-Sent Events) for live dashboard reload
- **Zero cloud dependencies** -- everything runs locally
- All tree-sitter parsing via `py-tree-sitter` bindings

---

## 2. Code-Graph-RAG — vitali87/code-graph-rag

**GitHub:** https://github.com/vitali87/code-graph-rag
**Stack:** Python 3.12+ / Memgraph / tree-sitter / UniXcoder / Qdrant / Multiple LLM providers

### 2.1 Graph Schema

**Node Types:**

| Label | Properties |
|-------|-----------|
| `Project` | `name` |
| `Package` | `name`, `qualified_name`, `path` |
| `Module` | `name`, `qualified_name`, `path` |
| `File` | `name`, `path` |
| `Function` | `name`, `qualified_name`, `path`, `line_start`, `line_end` |
| `Class` | `name`, `qualified_name`, `path`, `line_start`, `line_end` |
| `Method` | `name`, `qualified_name`, `path`, `line_start`, `line_end` |

**Edge Types:**
- `CONTAINS` -- structural hierarchy (Package->Module->Function)
- `IMPORTS` -- module-to-module imports
- `CALLS` -- function-to-function calls
- `INHERITS_FROM` -- class inheritance
- `IMPLEMENTS` -- interface implementation
- `DEPENDS_ON` -- generic dependency

### 2.2 Multi-Pass Processing Pipeline

| Pass | Name | Processor | What it does |
|------|------|-----------|-------------|
| 1 | **Structure** | `identify_structure()` | Detects packages via `__init__.py`, `Cargo.toml`, etc. |
| 2 | **Definitions** | `DefinitionProcessor` | Tree-sitter AST parsing. Extracts functions/classes. Uses incremental hash caching (`.cgr_file_hashes.json`) to skip unchanged files. |
| 3 | **Calls** | `CallProcessor` | Call resolution using `TypeInferenceEngine`. Matches call targets via `FunctionRegistryTrie` (O(log n) prefix lookup) + `simple_name_lookup` (O(1)). |
| 4 | **Embeddings** | `_generate_semantic_embeddings()` | Optional. UniXcoder embeddings stored in Qdrant. |

### 2.3 File Watcher Implementation

File: `realtime_updater.py`

```
RealTimeUpdater (watchdog FileSystemEventHandler)
  |
  on_modified(event) -->
    1. Delete affected MODULE node + all descendants (CYPHER_DELETE_MODULE query)
    2. Re-parse modified file through DefinitionProcessor
    3. Delete ALL CALLS relationships (CYPHER_DELETE_CALLS)
    4. Re-run CallProcessor for entire codebase
    5. Merge results into Memgraph
```

**Critical design choice:** Step 4 recalculates ALL calls on every file change,
not just calls involving the changed file. This prevents "island" problems where
a renamed function in file A would leave stale CALLS from file B. The tradeoff
is performance on large codebases.

**Usage:** `python realtime_updater.py /path/to/repo` (runs in separate terminal)

### 2.4 UniXcoder Embedding Details

- **Model:** `microsoft/unixcoder-base` (RoBERTa-based)
- **Dimensions:** 768
- **Tokenizer:** `RobertaTokenizer` from HuggingFace transformers
- **Model class:** `RobertaModel` (not the classifier head -- raw embeddings)
- **What gets embedded:** Function bodies (source code text)
- **Storage:** Qdrant vector DB, local path `.qdrant_code_embeddings`
- **Cache:** `.embedding_cache.json` for incremental updates
- **Retrieval:** Cosine similarity search for "find functions that do X"

**Dependencies are optional:** torch, transformers, qdrant-client. If not installed,
Pass 4 is skipped gracefully.

### 2.5 Call Resolution Architecture

The `CallProcessor` uses a `TypeInferenceEngine` with two lookup strategies:

1. **FunctionRegistryTrie** -- O(log n) prefix-based lookup. Resolves qualified names
   like `auth.validate_user` by walking the trie.
2. **simple_name_lookup** -- O(1) hash map for unqualified names.

For method calls (`obj.method()`), the type inference engine:
1. Looks up `obj`'s type from variable declarations/assignments
2. Resolves `type.method` against the FunctionRegistry
3. Falls back to fuzzy matching if type is unknown

Language-specific call node types are normalized:
- Python: `call` (tree-sitter node type)
- Rust: `call_expression`
- Java: `method_invocation`
- All mapped to unified CALLS edges

### 2.6 Supported Languages

Full support (10): Python, JavaScript, TypeScript, Rust, Java, C++, Go, PHP, Scala, Lua, C#
Each language has a spec in `language_spec.py` with tuples:
`(function_node_types, class_node_types, import_node_types, call_node_types)`

### 2.7 Additional Features

- **AI-powered Cypher generation:** NL->Cypher via configurable LLM (Gemini, GPT-4, Ollama)
- **Safety:** `_validate_cypher_read_only()` blocks DELETE/DROP/CREATE
- **Code editing:** Surgical AST-based function replacement with visual diff preview
- **MCP server:** Works with Claude Code for NL queries

---

## 3. Aider repo-map — Aider-AI/aider

**Source:** `aider/repomap.py` in the aider codebase
**Stack:** Python / tree-sitter / NetworkX / grep-ast / diskcache

### 3.1 Tag Extraction

Aider uses tree-sitter with language-specific `tags.scm` query files (from `aider.queries` resources).

**Tag namedtuple structure:**
```python
Tag = namedtuple("Tag", ["rel_fname", "fname", "line", "name", "kind"])
# rel_fname: relative path from repo root
# fname: absolute file path
# line: line number (-1 for references)
# name: identifier name (function, class, variable)
# kind: "def" (definition) or "ref" (reference)
```

**How definitions vs. references are distinguished:**
- Tree-sitter captures named `name.definition.*` become `kind="def"`
- Captures named `name.reference.*` become `kind="ref"`
- **Fallback for languages without reference queries** (e.g., C++):
  Pygments lexer extracts all identifiers as references

### 3.2 Graph Construction

The system builds a **NetworkX MultiDiGraph**:

```
Nodes = source files (relative paths)
Edges = code references between files
Edge attributes: weight=1.0, ident=identifier_name
```

**Edge creation logic:**
```python
for each identifier appearing in both `defines` and `references`:
    for each referencing_file in references[ident]:
        for each defining_file in defines[ident]:
            G.add_edge(referencing_file, defining_file, weight=1.0, ident=ident)
```

**Self-loops:** Every file gets a self-loop edge with `weight=0.1` to prevent
isolated nodes from losing all PageRank importance.

### 3.3 PageRank with Personalization

The personalization vector biases ranking toward context-relevant files:

| Condition | Weight |
|-----------|--------|
| File in `chat_fnames` (files user is editing) | `100 / len(fnames)` |
| File in `mentioned_fnames` (files mentioned in chat) | `100 / len(fnames)` |
| Filename stem matches `mentioned_idents` (identifiers mentioned) | `100 / len(fnames)` |
| Default (no special relevance) | `1 / len(fnames)` |

The 100:1 ratio strongly biases toward files the user is actively working with.
NetworkX's `pagerank()` with this personalization dict produces per-file scores.

### 3.4 From PageRank to Ranked Tags

After PageRank computes node (file) scores:

1. Each node's rank is distributed across its **outgoing edges** proportionally to edge weights
2. This associates rank with specific `(file, identifier)` pairs
3. Pairs are sorted by distributed rank (descending)
4. Result: `ranked_tags` list ordered by importance

### 3.5 Token Budget Optimization

```python
target = min(
    max_map_tokens * map_mul_no_files,  # expand when no files in chat
    max_context_window - 4096            # never exceed context window
)
```

- Default `--map-tokens`: 1024 tokens
- When no files in chat: multiplied by 8 (configurable via `--map-multiplier-no-files`)
- `to_tree()` method formats ranked tags into hierarchical tree structure:
  1. Sort files by PageRank score (descending)
  2. Accumulate tokens as files added
  3. Stop when budget exhausted
  4. Use grep-ast's `TreeContext` for proper indentation hierarchy

### 3.6 Caching

- **Cache location:** `<repo>/.aider.tags.cache.v{version}/`
- **Backend:** `diskcache.Cache` (SQLite-based)
- **Cache key:** absolute file path
- **Cache value:** `{"mtime": float, "data": [Tag, ...]}`
- **Invalidation:** file modification time comparison
- **Fallback:** in-memory dict if SQLite errors occur

### 3.7 Key Design Insight

Aider's approach is fundamentally different from Axon/Code-Graph-RAG:
- **No persistent graph database** -- graph is rebuilt in-memory on each invocation
- **No embeddings** -- purely structural (definitions/references via tree-sitter)
- **PageRank personalization** is the key innovation -- context-aware ranking
  biases toward what the user is currently working on
- **Token-budget aware** -- designed for LLM context window limits

**What to steal for our implementation:** The PageRank personalization idea is
excellent. When a user asks about a specific file or symbol, we can personalize
the graph traversal to prioritize related symbols. This works even with AGE --
we can compute PageRank on a subgraph extracted via Cypher.

---

## 4. tree-sitter-graph (Official)

**GitHub:** https://github.com/tree-sitter/tree-sitter-graph (312 stars)
**Stack:** Rust / tree-sitter / DSL
**Docs:** https://docs.rs/tree-sitter-graph

### 4.1 DSL Structure

A `.tsg` file consists of **stanzas**. Each stanza = tree-sitter query pattern + block of statements.

```tsg
; Match all function definitions
(function_definition
  name: (identifier) @name
  body: (block) @body) @func
{
  ; Create a graph node for this function
  node @func.node
  attr (@func.node) name = (source-text @name), kind = "function"

  ; Create edge from parent scope to this function
  edge @func.scope -> @func.node
}
```

### 4.2 Statement Types

| Statement | Syntax | Purpose |
|-----------|--------|---------|
| `node` | `node @capture.var` | Create graph node, assign to scoped variable |
| `edge` | `edge source -> sink` | Create directed edge (deduplicated) |
| `attr` | `attr (node) key = value` | Set node attribute |
| `attr` | `attr (src -> dst) key = value` | Set edge attribute |
| `let` | `let x = expr` | Immutable local variable |
| `var` | `var x = expr` | Mutable local variable |
| `set` | `set x = expr` | Update mutable variable |
| `if` | `if some @cap { } else { }` | Conditional (test with `some`/`none`) |
| `for` | `for x in list { }` | Iteration over lists |
| `scan` | `scan str { "regex" { } }` | Regex pattern matching on strings |
| `print` | `print expr1, expr2` | Debug output to stderr |
| `global` | `global filename` | Declare external variable |
| `inherit` | `inherit .scope` | Share scoped var across stanzas |

### 4.3 Variable Scoping Model

Three scoping levels:

1. **Global variables** -- declared with `global name`, provided externally via CLI `--global KEY=VALUE`.
   Quantifiers: `?` (optional), `+` (one-or-more list), `*` (zero-or-more list).

2. **Local variables** -- `let` (immutable) and `var`/`set` (mutable). Block-scoped, reset between stanza matches.

3. **Scoped variables** -- `@node.variable`. Attached to syntax nodes, **persist across stanzas**.
   This is the key feature: one stanza can annotate a node, and a later stanza reads it.

### 4.4 Built-in Functions

- `(source-text @node)` -- extract source text of syntax node
- `(node)` -- create a new graph node
- `(named-child-index @node)` -- get child index in parent
- `(plus a b)` -- arithmetic
- `(replace str old new)` -- string manipulation
- `(start-row @node)`, `(end-row @node)` -- line numbers

### 4.5 Execution Model

1. Parse `.tsg` file into AST
2. Semantic validation (variable usage, query well-formedness)
3. Parse source code with tree-sitter into CST
4. For each stanza, run tree-sitter query against CST
5. For each match, execute the stanza's block (creating nodes/edges)
6. Output the accumulated graph

**Two modes:**
- **Strict** (default): executes statements immediately
- **Lazy** (`--lazy`): records operations, applies them at the end

### 4.6 Practical Assessment for Our Use Case

**Advantages:**
- Declarative: one `.tsg` file per language instead of imperative visitor code
- Handles all tree-sitter languages via the same DSL
- Scoped variables enable multi-pass analysis in a single file
- The `scan` statement handles string-based pattern matching (useful for import paths)

**Disadvantages:**
- **Rust-only library** -- no Python bindings. Would need to shell out to CLI or write FFI.
- The DSL is powerful but has a learning curve
- No built-in support for cross-file analysis (designed for single-file graphs)
- Stack graphs (the primary use case) is a specific graph formalism, not general-purpose

**Verdict:** For our implementation, writing custom Python tree-sitter visitors
per language (like Axon does) is more practical. The tree-sitter-graph DSL is
elegant but the Rust-only constraint and single-file limitation make it awkward
for a Python/Java system. The `.tsg` approach would be ideal if we had a Rust
pipeline or needed to support 20+ languages with minimal per-language code.

---

## 5. Comparative Analysis

### 5.1 Feature Matrix

| Feature | Axon | Code-Graph-RAG | Aider repo-map |
|---------|------|----------------|----------------|
| Graph DB | KuzuDB (embedded) | Memgraph (server) | NetworkX (in-memory) |
| Embeddings | bge-small 384d | UniXcoder 768d | None |
| Vector store | KuzuDB HNSW | Qdrant | None |
| Languages | 3 | 10+ | 20+ (via grep-ast) |
| Incremental | Yes (file-local + batch) | Yes (hash-based) | No (rebuild each time) |
| File watcher | watchfiles (Rust) | watchdog (Python) | None |
| Dead code | Yes (multi-pass) | No | No |
| Git coupling | Yes (6-month window) | No | No |
| Community detection | Yes (Leiden) | No | No |
| Process/flow detection | Yes (BFS) | No | No |
| PageRank | No | No | Yes (personalized) |
| MCP tools | 7 | Yes (MCP server) | No |
| Call confidence | Yes (0.0-1.0) | No | No |
| Token budget | No | No | Yes |

### 5.2 Adaptation Plan for AGE + pgvector + Ollama

**From Axon (adopt heavily):**
- 12-phase pipeline architecture (adapt all 12 phases)
- File-local vs global phase split for incremental updates
- COUPLED_WITH git analysis (direct port)
- Dead code detection (multi-pass with exemptions)
- Process/flow detection (BFS from entry points)
- Confidence scoring on CALLS edges
- Node ID format: `{label}:{path}:{symbol}`
- 138 builtin blocklist

**From Code-Graph-RAG (selective):**
- `FunctionRegistryTrie` for O(log n) call resolution
- Language spec pattern: `(function_node_types, class_node_types, import_node_types, call_node_types)`
- Hash-based incremental detection (`.cgr_file_hashes.json` approach)

**From Aider (selective):**
- PageRank with personalization for context-aware queries
- Token budget optimization for LLM context generation
- `tags.scm` query files for tree-sitter (reuse their existing queries for 20+ languages)

**Stack mapping:**
- KuzuDB -> **Apache AGE** (both use Cypher)
- KuzuDB HNSW -> **pgvector** (same concept, different engine)
- BAAI/bge-small -> **qwen3-embedding:8b via Ollama** (4096d, MRL)
- watchfiles -> can use **inotify** or **watchdog** in Python
- sentence-transformers -> **Ollama API** (`/api/embed`)
- FastAPI -> **Spring Boot** or keep as Python service
- Community detection (Leiden) -> **igraph** in Python or compute in-memory then store in AGE

**AGE Schema (proposed Cypher):**
```cypher
-- Node labels
CREATE (:File {name, path, relative_path, extension, size})
CREATE (:Folder {name, path, relative_path})
CREATE (:Function {name, qualified_name, file_path, line_start, line_end, signature, dead: boolean})
CREATE (:Class {name, qualified_name, file_path, line_start, line_end})
CREATE (:Method {name, qualified_name, file_path, line_start, line_end, signature, dead: boolean})
CREATE (:Interface {name, qualified_name, file_path, line_start, line_end})
CREATE (:Community {community_id, size})
CREATE (:Process {name, entry_point, framework})

-- Edge types
CREATE ()-[:CONTAINS]->()
CREATE ()-[:DEFINES]->()
CREATE ()-[:CALLS {confidence: float}]->()
CREATE ()-[:IMPORTS {symbols: text}]->()    -- AGE doesn't support list props, use JSON string
CREATE ()-[:EXTENDS]->()
CREATE ()-[:IMPLEMENTS]->()
CREATE ()-[:USES_TYPE {role: text}]->()
CREATE ()-[:MEMBER_OF]->()
CREATE ()-[:STEP_IN_PROCESS {step_number: int}]->()
CREATE ()-[:COUPLED_WITH {strength: float, co_changes: int}]->()
```

**pgvector table (proposed):**
```sql
CREATE TABLE code_embeddings (
    id SERIAL PRIMARY KEY,
    node_id TEXT NOT NULL,         -- matches AGE node ID format
    label TEXT NOT NULL,           -- Function, Method, Class
    qualified_name TEXT NOT NULL,
    file_path TEXT NOT NULL,
    source_code TEXT,
    embedding vector(4096),       -- qwen3-embedding:8b
    embed_model TEXT DEFAULT 'qwen3-embedding:8b',
    embed_version INT DEFAULT 1,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON code_embeddings USING hnsw (embedding vector_cosine_ops);
```

---

## 6. Serendipitous Connections

**Agent Framework project:** The 12-phase pipeline from Axon maps directly to
the task decomposition pattern in agent-framework. Each phase could be modeled
as a Task node in `task_graph`, with dependencies expressed as edges. The
file-local vs global split maps to the "can parallelize" vs "must serialize"
distinction in task scheduling.

**KORE knowledge graph:** The code graph can live in the same AGE database
(`embeddings`) as `knowledge_graph`. A new graph name `code_graph` is already
reserved in the schema. Cross-graph queries would allow linking Paper nodes
(academic references) to Function nodes (implementations), creating a
research-to-code traceability graph.

**Preference Sort / Ranking Todo:** Aider's PageRank personalization is
structurally similar to the Bradley-Terry model used in preference-sort --
both produce a total ordering from pairwise comparisons (edges = comparisons
in Bradley-Terry, edges = references in PageRank).

---

## Sources

- [Axon GitHub](https://github.com/harshkedia177/axon) -- primary source
- [Axon on Glama](https://glama.ai/mcp/servers/@harshkedia177/axon) -- MCP tool details
- [Code-Graph-RAG GitHub](https://github.com/vitali87/code-graph-rag) -- primary source
- [Code-Graph-RAG DeepWiki](https://deepwiki.com/vitali87/code-graph-rag) -- implementation analysis
- [Aider repo-map blog post](https://aider.chat/2023/10/22/repomap.html) -- original description
- [Aider repo-map DeepWiki](https://deepwiki.com/Aider-AI/aider/4.1-repository-mapping) -- implementation details
- [tree-sitter-graph GitHub](https://github.com/tree-sitter/tree-sitter-graph) -- repository
- [tree-sitter-graph DSL reference](https://docs.rs/tree-sitter-graph/latest/tree_sitter_graph/reference/index.html) -- full DSL spec
- [tree-sitter-graph DeepWiki](https://deepwiki.com/tree-sitter/tree-sitter-graph) -- DSL overview
