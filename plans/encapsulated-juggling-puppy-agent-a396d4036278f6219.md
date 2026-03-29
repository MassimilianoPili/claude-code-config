# Research Summary: Code Knowledge Graphs -- AST + Graph DB + Vector Embeddings

## Executive Summary

The field of "code knowledge graphs" -- systems combining tree-sitter AST parsing, graph databases, and vector embeddings for code intelligence -- has undergone rapid maturation in 2024-2026. A "Cambrian explosion" of open-source tools emerged in late 2025, driven by the need for AI coding agents to understand codebase structure beyond naive text retrieval. The dominant architecture pattern is: **tree-sitter parsing -> property graph (nodes: symbols, edges: relationships) -> vector embeddings for semantic search -> MCP/API exposure to LLM agents**. Multiple production-ready open-source implementations exist, and the academic literature (CodexGraph, CGM, GraphCodeBERT) provides solid theoretical grounding.

**Epistemic status:** Active development front with converging best practices. Strong consensus on tree-sitter as parser; graph schema converging on ~6 node types and ~6 edge types; embedding model choice still evolving.
**Confidence:** High for architecture patterns (multiple independent implementations converge); Medium for embedding model recommendations (benchmarks shifting rapidly).

---

## A. Existing Open-Source Tools/Projects

### Tier 1: Full Knowledge Graph Engines

| Project | Stars | Language | Graph DB | Tree-sitter | Embeddings | MCP | License |
|---------|-------|----------|----------|-------------|------------|-----|---------|
| **GitNexus** | ~14K | TypeScript | Browser-side | Yes | Yes | 7 tools, 7 resources, 2 prompts | PolyForm NC |
| **Code-Graph-RAG** | -- | Python | **Memgraph** | Yes | UniXcoder | Via API | -- |
| **Axon** | ~560 | Python | **KuzuDB** (+ Neo4j optional) | Yes | bge-small-en-v1.5 (384d) | 7 MCP tools | -- |
| **CodeGraphContext** | ~2.2K | Python | -- | Yes | Yes | MCP + CLI | MIT |

(T7 -- GitHub repos, verified via fetch)

#### Code-Graph-RAG -- Deep Dive
- **Graph DB**: Memgraph (Cypher-compatible, in-memory)
- **Languages**: C++, Java, JavaScript, Lua, Python, Rust, TypeScript (fully supported); C#, Go, PHP, Scala (in development)
- **Schema**: Nodes = Function, Class, Module, Package + language-specific (C++ templates, Java generics, Rust impl blocks). Edges = CALLS, CONTAINS, + dependency edges
- **Embeddings**: UniXcoder for intent-based semantic code search
- **Incremental**: Real-time file watcher, but recalculates ALL CALLS relationships on every change (performance concern for large repos)
- **Relevance to SOL**: Memgraph is not in your stack. Would need adaptation to Apache AGE.

#### Axon -- Deep Dive
- **Graph DB**: KuzuDB (embedded, columnar graph DB) with optional Neo4j
- **12-phase pipeline**: Parse -> extract symbols -> resolve calls -> build graph -> cluster communities -> detect execution flows
- **Schema**:
  - Nodes: Symbol (function, class, method), File, Folder, Type, Community, ExecutionFlow
  - Edges: CALLS (with confidence scores 0.5-1.0), CONTAINS, EXTENDS, IMPLEMENTS, TYPE_REF (with role: parameter/return/variable), COUPLED_WITH (git co-change)
- **MCP tools**: axon_query (hybrid BM25 + vector + fuzzy), axon_context (360-degree symbol view), axon_impact (blast radius), axon_dead_code, axon_detect_changes (git diff mapping), axon_cypher (raw graph query)
- **Languages**: Python, TypeScript, JavaScript
- **Relevance to SOL**: KuzuDB is embedded; schema is very well-designed and could be adapted to AGE. The COUPLED_WITH edge from git co-change is a clever idea.

### Tier 2: MCP Code Search Tools

| Project | Approach | Notes |
|---------|----------|-------|
| **Octocode MCP** (~751 stars) | Semantic code search | No full graph construction |
| **CodePathFinder** (~111 stars, Go) | Symbol navigation | AGPL-3.0 |
| **Repomix** (~22K stars) | Context packing with tree-sitter compression | Flattens repos into LLM-friendly text; ~70% token reduction |
| **code2prompt** (~7.2K stars, Rust) | Context packing | Similar to Repomix |

(T7 -- via Ry Walker comparison at rywalker.com)

### Tier 3: Foundational Libraries

| Library | What it does | Relevance |
|---------|-------------|-----------|
| **tree-sitter-graph** (official) | DSL for constructing arbitrary graphs from tree-sitter CSTs | Foundation layer; GitHub uses this for Stack Graphs |
| **IBM tree-sitter-codeviews** | Generates AST + CFG + DFG views; 15+ combinations | Java and C# only; designed for GNN input |
| **GitHub Stack Graphs** | Language-agnostic name resolution using incremental graph construction | Powers GitHub's "Find all references" feature |
| **Aider repo-map** | tree-sitter + NetworkX graph + PageRank ranking | Proven in production; see below |

### Aider's Approach (Important Reference Implementation)

Aider's repo-map is the most battle-tested tree-sitter code indexing in production AI coding tools (T5 -- Aider blog):

1. **Parse** all source files with tree-sitter (17 languages via py-tree-sitter-languages)
2. **Extract** symbol definitions (functions, classes, variables, types) and references
3. **Build** a NetworkX MultiDiGraph: nodes = source files, edges = dependency relationships
4. **Rank** with PageRank (personalized to the files being edited) to find the most relevant context
5. **Budget** via --map-tokens (default 1K tokens): select top-ranked definitions that fit the token budget

Key insight: Aider does NOT build a persistent graph database -- it rebuilds the graph on every interaction. This works for small-to-medium repos but does not scale to large monorepos.

---

## B. Academic Papers

### Seminal Papers (Code Representation Learning)

| Paper | Authors | Year | Venue | Key Contribution |
|-------|---------|------|-------|------------------|
| **code2vec** | Alon et al. | 2019 | POPL | Learn code embeddings from AST paths; introduced path-based code representation |
| **code2seq** | Alon et al. | 2019 | ICLR | LSTM-encoded AST paths + attention decoder; improved over code2vec |
| **ASTNN** | Zhang et al. | 2019 | ICSE | Statement-level AST splitting for neural code representation |
| **GraphCodeBERT** | Guo et al. | 2021 | ICLR | First pre-trained model using data flow graphs; SOTA on code search, clone detection, translation, refinement |
| **UniXcoder** | Guo et al. | 2022 | ACL | Unified cross-modal encoder-decoder; strong code embedding base model |

(T1 -- POPL, ICLR, ICSE, ACL are top venues)

### Recent Papers (2024-2025)

| Paper | Year | Key Contribution |
|-------|------|------------------|
| **CodexGraph** (arXiv:2408.03910) | 2024 | LLM agents + code property graph with Cypher queries; unified schema: MODULE, CLASS, FUNCTION, METHOD, FIELD, GLOBAL_VARIABLE nodes; CONTAINS, HAS_METHOD, INHERITS, USES, CALLS edges. Evaluated on SWE-bench, CrossCodeEval, EvoCodeBench. |
| **Code Graph Model (CGM)** (NeurIPS 2025) | 2025 | Integrates code graph structures directly into LLM attention mechanism via specialized adapter; no agent loop needed |
| **CKGFuzzer** (arXiv:2411.11532) | 2024 | Code knowledge graph via interprocedural analysis for fuzz driver generation; nodes = functions/files |
| **KG-based Repo-Level Code Gen** (arXiv:2505.14394) | 2025 | KG for repository-level code generation; hybrid retrieval (structural + semantic); benchmarked on EvoCodeBench |
| **Prometheus** (arXiv:2507.19942) | 2025 | Unified KG for multilingual codebases; issue resolution |
| **LoRACode** (arXiv:2503.05315) | 2025 | LoRA adapters for code embeddings; evaluated CodeBERT, GraphCodeBERT, UniXcoder, StarCoder as base models |
| **Codified Context** (arXiv:2602.20478) | 2026 | Infrastructure for AI agents in complex codebases |

(T2 -- arXiv preprints; CGM is T1 -- NeurIPS 2025)

### The CodexGraph Schema (Most Relevant to Your Use Case)

From arXiv:2408.03910 -- this is the best-documented code property graph schema for LLM agent integration:

**Node types:**
- MODULE -- source file / module
- CLASS -- class definition
- FUNCTION -- standalone function
- METHOD -- class method
- FIELD -- class attribute / instance variable
- GLOBAL_VARIABLE -- module-level variable

**Edge types:**
- CONTAINS -- structural containment (module contains class, class contains method)
- HAS_METHOD -- class-to-method relationship
- INHERITS -- class inheritance
- USES -- variable/field usage
- CALLS -- function/method invocation
- IMPORTS -- module import dependency

---

## C. Code Embedding Approaches

### AST-Aware vs Text-Based: What the Research Says

**Consensus (T1/T2 sources):** AST-aware embeddings consistently outperform pure text embeddings for structural code tasks (clone detection, bug detection, code classification). However, for **code search** (natural language query -> code), large pre-trained text models (CodeBERT, UniXcoder) have narrowed the gap significantly.

Key findings:
- **GGNN and ASTNN** have the best performance in functionality prediction because they capture control flow and data flow in addition to AST structure (T1 -- arXiv:2109.07173, Comparison of Code Embeddings)
- **GraphCodeBERT** extends CodeBERT with data flow graphs and achieves SOTA on 4 tasks (T1 -- ICLR 2021)
- **LoRACode (2025)**: UniXcoder outperforms CodeBERT and GraphCodeBERT as a base model for fine-tuning code embeddings (T2 -- arXiv:2503.05315)
- Pure text embeddings from large models (StarCoder, GPT) are competitive on code search but miss structural relationships

**Practical recommendation for your setup:** Use a hybrid approach:
1. **Text embeddings** (via Ollama) for semantic code search (NL -> code)
2. **Graph structure** (via AGE) for structural queries (call chains, impact analysis, dead code)
3. The graph IS the AST-aware representation; you do not need AST-aware embeddings if you have the graph

### Embedding Models for Code (Self-Hosted)

| Model | Parameters | Dimensions | Open Source | Ollama | Best For |
|-------|-----------|------------|-------------|--------|----------|
| **Nomic Embed Code** | 7B | Variable (MRL) | Yes (Apache-2) | Via HF | Code retrieval, multi-language |
| **CodeRankEmbed** | 137M | -- | Yes | -- | SOTA code retrieval (specialized bi-encoder) |
| **Nomic Embed Text v2 (MoE)** | -- | -- | Yes (Apache-2) | Yes | General + code (MoE architecture) |
| **UniXcoder** | 125M | 768 | Yes | -- | Good base for fine-tuning; encoder-decoder |
| **bge-small-en-v1.5** | 33M | 384 | Yes | Yes | Fast, lightweight; used by Axon |
| **qwen3-embedding:8b** | 8B | 4096 | Yes | **Yes (current)** | General purpose with MRL support |

(T5 -- Modal blog comparison, T7 -- HuggingFace model cards)

**For your setup (Ollama + pgvector):** Your current qwen3-embedding:8b is a strong general-purpose model. For code-specific tasks, consider adding nomic-embed-code if Ollama gets it (currently HuggingFace only), or use qwen3-embedding:8b with code-specific prefixes/prompts.

### Chunking Strategies

The consensus from both tools and papers:

| Level | When to Use | Pros | Cons |
|-------|-------------|------|------|
| **Function/method** | Default for most use cases | Natural semantic unit; maps 1:1 to graph nodes | Misses file-level context |
| **Class** | OOP-heavy codebases | Captures method relationships | Can be very large |
| **File** | Small files, config files | Captures imports/structure | Too coarse for large files |
| **Statement** | Fine-grained analysis (ASTNN) | Precise bug localization | High overhead |

**Recommendation:** Function-level as primary unit, with class-level for small classes and file-level for config/setup files. Each graph node (Function, Class, Module) gets its own embedding.

---

## D. Integration Patterns

### How AI Coding Agents Index Codebases

| Agent | Indexing Method | Persistent? | Graph? |
|-------|----------------|-------------|--------|
| **Cursor** | Local semantic embeddings; shared team indices | Yes | No (embedding-only) |
| **GitHub Copilot** | Cloud-based RAG via GitHub code search | Yes (cloud) | No |
| **Aider** | tree-sitter + PageRank on NetworkX graph | No (rebuilt per session) | Transient |
| **Sourcegraph Cody** | Organization-wide cross-repo search index | Yes | Partial |
| **GitNexus/Axon** | tree-sitter -> persistent graph DB + embeddings | Yes | **Yes** |

(T5/T7 -- various blog posts and product pages)

Key insight: The major commercial agents (Cursor, Copilot) do NOT use graph databases -- they rely on embedding-based retrieval. The graph-based approach is emerging from the open-source community and academic research as a strictly superior architecture for structural queries (blast radius, dead code, call chains).

### Recommended Graph Schema for Apache AGE

Based on CodexGraph, Axon, and Code-Graph-RAG, here is a converged schema suitable for AGE:

```
-- Node labels
(:Module name, path, language, hash, last_modified)
(:Class name, path, line_start, line_end, docstring)
(:Function name, path, line_start, line_end, signature, docstring, is_method)
(:Variable name, path, scope, type_annotation)
(:Import module_path, alias)
(:Package name, version)

-- Edge types
[:CONTAINS]            -- Module->Class, Module->Function, Class->Function
[:CALLS confidence]    -- Function->Function (confidence score 0.5-1.0)
[:IMPORTS]             -- Module->Module or Module->Import
[:INHERITS]            -- Class->Class
[:IMPLEMENTS]          -- Class->Class (interface)
[:USES]                -- Function->Variable, Function->Class
[:TYPE_REF role]       -- Function->Class (role: parameter/return/variable)
[:COUPLED_WITH]        -- File->File (git co-change correlation)
[:DEFINED_IN]          -- Symbol->Module (reverse of CONTAINS)
```

### Incremental Updates (git diff -> graph delta)

This is the least mature area. Current approaches:

1. **Full rebuild** (Code-Graph-RAG): Recalculate all CALLS on every file change. Simple but O(n).

2. **File-level delta** (Axon): axon_detect_changes maps git diff to affected symbols, then re-indexes only changed files. Practical for most repos.

3. **AST-level delta** (academic):
   - **GumTree** (T1 -- ASE 2014): Fine-grained AST diff with insert, remove, update, move operations. NP-hard in general, uses greedy heuristics.
   - **Difftastic**: tree-sitter-based structural diff tool. Uses longest-common-subsequence on syntax tree leaves.
   - Neither is integrated into a graph update pipeline yet.

4. **Recommended approach for your setup:**
   - On git commit: parse changed files with tree-sitter
   - Delete all nodes/edges for changed files from AGE
   - Re-extract and re-insert nodes/edges for changed files
   - Re-compute CALLS edges that cross file boundaries (the expensive part)
   - Re-embed only changed/new Function and Class nodes

This is a file-level delta approach (option 2) -- the pragmatic sweet spot.

---

## Serendipitous Connections

### Agent COBOL Project
The code knowledge graph architecture maps directly to **Agent COBOL** (future project for legacy system modernization). COBOL's rigid structure (DIVISION, SECTION, PARAGRAPH, PERFORM, CALL) is actually easier to graph than dynamic languages. A tree-sitter grammar for COBOL exists (tree-sitter-cobol on GitHub). The graph schema would be:
- Nodes: DIVISION, SECTION, PARAGRAPH, COPYBOOK, DATA_ITEM
- Edges: PERFORMS, CALLS, COPIES, REDEFINES

### Agent Framework
The code_graph in your AGE database (embeddings.code_graph) is already set up for this. The 12-phase pipeline from Axon could be adapted as an Agent Framework task, with each phase as a step in an HTN plan.

### Kindle Graph Enrichment
The pattern of "parse structured content -> extract entities and relationships -> store in graph + embed" is identical to what you do with Kindle highlights. The code graph is just a different domain with the same architecture.

### Preference Sort / Bradley-Terry
Axon's confidence scores on CALLS edges (0.5-1.0) could be refined using pairwise comparison: when the parser is uncertain about a call target (dynamic dispatch, reflection), present alternatives to the user via Preference Sort.

---

## Open Questions

1. **Embedding model for code on Ollama**: No dedicated code embedding model is currently mainstream on Ollama. qwen3-embedding:8b is your best option; nomic-embed-code (7B, Apache-2) is the best open code-specific model but needs manual Ollama integration.

2. **Graph vs embeddings for retrieval**: The emerging consensus is "both" -- graph for structural queries (blast radius, call chains), embeddings for semantic queries (NL -> code). No single system dominates both.

3. **Scaling incremental updates**: File-level delta works up to ~100K files. Beyond that, you need smarter dependency tracking (only re-check CALLS edges that could have been affected by the change).

4. **Cross-language resolution**: When Module A (Python) calls Module B (Java) via API/RPC, the graph needs inter-language edges. No open-source tool handles this well yet.

---

## Recommendations for Your Setup (PG + AGE + pgvector + Ollama)

### Architecture

```
Git repo
    |
    v
tree-sitter parser (py-tree-sitter-languages, Python)
    |
    v
Symbol extractor (Functions, Classes, Imports, Calls)
    |
    +--> Apache AGE: code_graph (Cypher queries for structural analysis)
    |
    +--> pgvector: embeddings (qwen3-embedding:8b for semantic search)
    |
    v
MCP tools (exposed via simoge-mcp)
    - code_search(query) -- hybrid: graph + embedding
    - code_impact(symbol) -- blast radius via graph traversal
    - code_calls(function) -- call chain via Cypher
    - code_dead() -- unreachable symbols
    - code_changes(commit) -- git diff -> affected symbols
```

### Implementation Priority

1. **Phase 0**: tree-sitter parser + symbol extraction (Python script, similar to paper_archive.py)
2. **Phase 1**: AGE graph construction (code_graph, Cypher schema above)
3. **Phase 2**: pgvector embeddings for Function/Class nodes (reuse existing openalex_embed.py pattern)
4. **Phase 3**: MCP tool exposure (5 tools in simoge-mcp)
5. **Phase 4**: Incremental updates via git hooks
6. **Phase 5**: Cross-repo support (index multiple Gitea repos)

### Key Dependencies
- py-tree-sitter-languages (Python, MIT) -- binary wheels for 17+ languages
- psycopg2 -- direct AGE access (already in your stack)
- qwen3-embedding:8b via Ollama (already deployed on gaia)
- Apache AGE code_graph (already exists in embeddings DB)

---

## What to Read Next

1. **CodexGraph paper** (arXiv:2408.03910) -- The most comprehensive code property graph schema for LLM agents. Read the full paper for schema details and Cypher query patterns.
2. **Axon source code** (github.com/harshkedia177/axon) -- Best-engineered open-source implementation. Study the 12-phase pipeline and MCP tool design.
3. **Aider repo-map blog** (aider.chat/2023/10/22/repomap.html) -- Practical tree-sitter + PageRank approach. Simple and proven.
4. **Ry Walker comparison** (rywalker.com/research/code-intelligence-tools) -- Best overview of the tool landscape as of early 2026.

---

## Sources

### T1 (Peer-reviewed)
- GraphCodeBERT -- ICLR 2021 (openreview.net/pdf?id=jLoC4ez43PZ)
- code2vec -- POPL 2019 (github.com/tech-srl/code2vec)
- code2seq -- ICLR 2019 (openreview.net/forum?id=H1gKYo09tX)
- ASTNN -- ICSE 2019
- GumTree -- ASE 2014 (hal.science/hal-01054552/document)
- Code Graph Model (CGM) -- NeurIPS 2025 (openreview.net/forum?id=b98ODdeYq5)

### T2 (arXiv preprints)
- CodexGraph -- arXiv:2408.03910
- CKGFuzzer -- arXiv:2411.11532
- KG-based Repo-Level Code Gen -- arXiv:2505.14394
- LoRACode -- arXiv:2503.05315
- Prometheus -- arXiv:2507.19942
- Codified Context -- arXiv:2602.20478
- Nomic Embed -- arXiv:2402.01613
- Code Embeddings Comparison -- arXiv:2109.07173

### T5 (Blogs / Comparisons)
- Aider repo-map blog (aider.chat/2023/10/22/repomap.html)
- Ry Walker -- Code Intelligence Tools Compared (rywalker.com/research/code-intelligence-tools)
- Modal -- 6 Best Code Embedding Models (modal.com/blog/6-best-code-embedding-models-compared)
- Memgraph -- GraphRAG for Devs (memgraph.com/blog/graphrag-for-devs-coding-assistant)
- Difftastic manual -- Tree Diffing (difftastic.wilfred.me.uk/tree_diffing.html)

### T7 (GitHub repos)
- Code-Graph-RAG (github.com/vitali87/code-graph-rag)
- Axon (github.com/harshkedia177/axon)
- GitNexus (github.com/abhigyanpatwari/GitNexus)
- tree-sitter-graph (github.com/tree-sitter/tree-sitter-graph)
- IBM tree-sitter-codeviews (github.com/IBM/tree-sitter-codeviews)
- GitHub Stack Graphs (github.blog/open-source/introducing-stack-graphs/)
- Nomic Embed Code -- HuggingFace (huggingface.co/nomic-ai/nomic-embed-code)

### Knowledge Graph Candidates
- "Code Property Graph" -- Type: framework. Links: code_graph (AGE), Agent COBOL, Agent Framework
- "tree-sitter" -- Type: technique. Links: AST, code_graph, incremental parsing
- "PageRank for code relevance" -- Type: technique. Links: Aider, graph ranking, code_graph
- "CodexGraph schema" -- Type: framework. Links: code_graph, MCP tools, Cypher
