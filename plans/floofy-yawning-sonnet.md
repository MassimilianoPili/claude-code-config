# Plan: GraphRAG for `web_search` KORE Prepend + Fix `embeddings_search_hybrid`

## Context

The `web_search` MCP tool currently prepends KORE knowledge via pure pgvector semantic search (top 3, threshold 0.85). This misses **structurally related** knowledge — e.g., a paper's authors, a concept's prerequisites, related infrastructure services. The `embeddings_search_hybrid` tool claims to do graph+vector fusion but its graph branch is broken (regex-only, `graphDepth` parameter unused, no actual edge traversal).

**Goal**: Add real AGE graph traversal to both tools, implementing the **vector-first + graph-expansion** pattern (the industry standard used by Neo4j VectorCypherRetriever, AWS Neptune, Uber, Airbnb — per our research).

**Industry standard findings**:
- 1-2 hop traversal is universal; beyond 2 hops degrades quality
- Vector-first + sequential graph expansion is the dominant pattern (not RRF for the expansion step)
- Latency budget: 150-300ms for graph expansion on top of vector search
- Microsoft's approach (community pre-summarization) is powerful but too heavy for our use case
- LazyGraphRAG's NLP concept extraction is interesting for future work but out of scope here

**Community/enthusiast findings** (partial — agent researched 39 turns):
- LangChain `Neo4jVector.from_existing_graph()` + `GraphCypherQAChain` is the most popular community pattern
- **E²GraphRAG** (arXiv:2505.24226): bidirectional entity↔chunk indexes, SpaCy NER, 10x retrieval speedup vs LightRAG
- **LazyGraphRAG**: NLP noun-phrase concept graphs, 700x cheaper than GraphRAG Global Search
- No pgvector+AGE combo found in the wild — our implementation would be novel in that specific stack

## Architecture Decision

**Extend `SemanticLookup` SPI** with a default method (not a new interface). Reasons:
- Graph expansion is tightly coupled to vector results (needs their identifiers)
- Default method preserves backward compatibility for Maven Central consumers
- Avoids coordinating two optional SPIs in `WebSearchTools`

## Implementation

### Phase 1: SPI Extension (`mcp-search-tools` library)

**File**: `Vari/mcp-search-tools/src/main/java/io/github/massimilianopili/mcp/search/spi/SemanticLookup.java`

Add default method:
```java
default String searchWithGraphExpansion(String query, int vectorLimit, int graphDepth) {
    return search(query, vectorLimit);
}
```

**File**: `Vari/mcp-search-tools/src/main/java/io/github/massimilianopili/mcp/search/WebSearchTools.java`

Change KORE prepend call (line ~85):
```java
// Was: semanticLookup.search(query, 3)
String koreResults = semanticLookup.searchWithGraphExpansion(query, 3, 1);
```

Update prefix header to `--- From KORE (cached knowledge + graph context) ---`.

### Phase 2: Graph-Augmented `KoreLookupService` (MCP server app)

**File**: `Vari/mcp/src/main/java/com/example/mcp/tools/KoreLookupService.java`

Add `graphExecutors` dependency (optional, `@Autowired(required = false)`):
```java
private final Map<String, CypherExecutor> graphExecutors;
```

New method `searchGraphAugmented(String query, int vectorLimit, int graphDepth)`:

1. **Step 1**: Existing pgvector search (threshold 0.85, `vectorLimit` results)
2. **Step 2**: For each result with `name` + `label` metadata (web-ingested content), query AGE:
   ```cypher
   MATCH (n {archival_id: '<escaped_name>'})-[r]-(neighbor)
   RETURN {rel_type: type(r),
           title: coalesce(neighbor.title, neighbor.name),
           label: label(neighbor),
           domain: neighbor.domain}
   LIMIT 10
   ```
3. **Step 3**: Format as enriched JSON — each direct hit gets a `graph_context` array:
   ```json
   {
     "title": "Attention Is All You Need",
     "label": "Paper", "type": "docs", "similarity": 0.91,
     "snippet": "...",
     "graph_context": [
       {"rel": "WRITTEN_BY", "title": "Ashish Vaswani", "label": "Author"},
       {"rel": "PUBLISHED_IN", "title": "NeurIPS 2017", "label": "Venue"},
       {"rel": "HAS_TOPIC", "title": "Transformer", "label": "Concept"}
     ]
   }
   ```
4. **Fallback**: If AGE unavailable or query fails, return pgvector-only results (existing behavior). Wrap in try/catch, log warning.

**Bridge field**: `name` in vector metadata = `archival_id` in AGE nodes. Only web-ingested content has both fields; plain markdown docs are silently skipped for graph expansion (correct — they have no AGE nodes).

**Performance**: Embedding query ~100ms + 3 AGE queries ~150ms + JSON ~50ms = ~300ms total. Well within 500ms budget.

### Phase 3: SPI Adapter Update (MCP server app)

**File**: `Vari/mcp/src/main/java/com/example/mcp/adapter/SpiAdapterConfig.java`

Override `searchWithGraphExpansion` in the anonymous `SemanticLookup` impl:
```java
@Override
public String searchWithGraphExpansion(String query, int vectorLimit, int graphDepth) {
    return svc.searchGraphAugmented(query, vectorLimit, graphDepth);
}
```

### Phase 4: Fix `embeddings_search_hybrid` Graph Branch (`mcp-vector-tools` library)

**File**: `Vari/mcp-vector-tools/src/main/java/io/github/massimilianopili/mcp/vector/search/HybridSearchTools.java`

Rewrite `executeGraphSearch()` (lines 128-167):

**Current** (broken): regex `=~` on title/description, `graphDepth` ignored.

**New**: Two-step — use vector results as seed nodes, then traverse AGE edges:

1. Extract `name`/`label` from vector results metadata to identify seed AGE nodes
2. For each seed node, run depth-aware Cypher:
   ```cypher
   MATCH (n {archival_id: '<id>'})-[r]-(neighbor)
   RETURN {name: coalesce(neighbor.title, neighbor.name),
           label: label(neighbor), domain: neighbor.domain,
           archival_id: coalesce(neighbor.archival_id, neighbor.name),
           rel_type: type(r)}
   LIMIT 20
   ```
3. For `graphDepth > 1`, chain a second hop (separate query, not variable-length paths — AGE compatibility):
   ```cypher
   MATCH (n {archival_id: '<id>'})-[r1]-(n2)-[r2]-(n3)
   WHERE n3 <> n
   RETURN {name: coalesce(n3.title, n3.name),
           label: label(n3), path: type(r1) + ' -> ' + type(r2)}
   LIMIT 5
   ```
4. Feed graph-expanded results into existing RRF fusion (weights 0.7/0.3)

### Phase 5: Publish & Deploy

**Sequence** (respecting TDT — publish before consuming):
1. `mcp-search-tools` — bump version, publish to Maven Central (default method = backward-compatible)
2. `mcp-vector-tools` — bump version, publish to Maven Central
3. `mcp` server app — update deps, rebuild, `sol deploy mcp`

## Files to Modify

| File | Change |
|------|--------|
| `Vari/mcp-search-tools/.../spi/SemanticLookup.java` | Add `searchWithGraphExpansion` default method |
| `Vari/mcp-search-tools/.../WebSearchTools.java` | Call new method, update prefix header |
| `Vari/mcp/src/.../KoreLookupService.java` | Add `graphExecutors` dep + `searchGraphAugmented()` |
| `Vari/mcp/src/.../SpiAdapterConfig.java` | Override new SPI method in adapter |
| `Vari/mcp-vector-tools/.../HybridSearchTools.java` | Rewrite `executeGraphSearch()` with real traversal |

## Existing Code to Reuse

- `AgeCypherExecutor.execute()` in `mcp-graph-tools` — AGE SQL wrapping + agtype parsing
- `WebIngestService.escCypher()` pattern in MCP server — Cypher string escaping
- `MmrReranker` in `mcp-vector-tools` — existing vector search pipeline (unchanged)
- RRF fusion logic in `HybridSearchTools` (lines 76-110) — keep as-is, just feed better graph results

## Verification

1. **Unit test**: `KoreLookupService.searchGraphAugmented()` with mocked VectorStore + mocked CypherExecutor
2. **Integration test**: Call `web_search("transformer architecture")` and verify KORE prefix includes graph context (authors, venues, topics)
3. **Integration test**: Call `embeddings_search_hybrid("machine learning", null, 1, 10, null)` and verify graph results have actual neighbor nodes (not just regex title matches)
4. **Performance**: Time the KORE prepend step — should be < 500ms total
5. **Fallback**: Stop AGE container, verify `web_search` still works (pgvector-only fallback)
6. **MCP tool test**: `tool_info("web_search")` + `tool_info("embeddings_search_hybrid")` — descriptions should reflect graph augmentation
