# Research Summary: AST-Aware Code Chunking for RAG Systems

## Executive Summary

AST-based code chunking using tree-sitter is now the clear state-of-the-art for code RAG, with empirical evidence showing +4.3 NDCG on RepoEval and +2.67 Pass@1 on SWE-bench over line-based baselines (cAST, EMNLP 2025). For embedding models, the field has moved decisively toward code-specialized models: Voyage Code 3, CodeXEmbed (Salesforce), Nomic Embed Code, and Qodo-Embed-1 all substantially outperform general-purpose embedders on the CoIR benchmark. Hybrid retrieval (vector + BM25) consistently improves recall by 15-30% over either method alone, and is especially critical for code search where identifier/API name matching matters. For a self-hosted pgvector setup, the recommended architecture is: tree-sitter AST chunking at function/method granularity, metadata-enriched chunks, a code-specialized embedding model (or Qwen3-Embedding-8B as a strong general-purpose fallback), and hybrid retrieval with BM25.

**Epistemic status:** Strong consensus on AST chunking superiority. Active competition among embedding models. Hybrid retrieval benefits well-established.
**Confidence:** High for chunking strategy (T1 -- EMNLP 2025 + multiple production systems). Medium-High for embedding model rankings (T2 -- arXiv benchmarks, models evolving rapidly). High for hybrid retrieval (T1 -- multiple replicated results).

---

## 1. Tree-sitter for Code Chunking

### The State of the Art: cAST (EMNLP 2025 Findings)

The most rigorous evaluation of AST-based code chunking is **cAST** (T1 -- Zhang et al., EMNLP 2025 Findings, [arXiv:2506.15655](https://arxiv.org/abs/2506.15655), also published as [CMU tech report](https://www.cs.cmu.edu/~sherryw/assets/pubs/2025-cast.pdf)).

**Method:** cAST recursively traverses the AST produced by tree-sitter, breaking large nodes into smaller chunks and merging sibling nodes while respecting size limits. Four design goals:
1. **Syntactic integrity** -- chunk boundaries align with complete syntactic units (functions, classes, blocks)
2. **High information density** -- no wasted space on partial constructs
3. **Language invariance** -- same algorithm works across languages via tree-sitter grammars
4. **Plug-and-play** -- drops into existing RAG pipelines without modification

**Results vs baselines:**
| Metric | Improvement | Benchmark |
|--------|-------------|-----------|
| Recall@5 | +4.3 points | RepoEval retrieval |
| Pass@1 | +2.67 points | SWE-bench generation |
| Recall@5 | +5.5 points avg | RepoEval with StarCoder2-7B |
| Cross-language | +4.3 points | CrossCodeEval |

**Key insight:** Line-based and fixed-token chunking systematically break functions mid-body or merge unrelated code blocks. AST-aware chunking eliminates both failure modes.

### Production Implementations

**Aider** (T5 -- [aider.chat blog](https://aider.chat/2023/10/22/repomap.html)) implements the most sophisticated open-source tree-sitter pipeline:
- Tree-sitter parses 40+ languages into ASTs
- Extracts function/class definitions and cross-file references
- Builds a NetworkX MultiDiGraph of file dependencies
- Ranks nodes using PageRank with personalization
- Formats top-ranked definitions into token-limited context
- Migrated from ctags to tree-sitter for richer maps (full function signatures vs just names)

**Cursor** (T5 -- [TDS article](https://towardsdatascience.com/how-cursor-actually-indexes-your-codebase/)):
- Uses tree-sitter to break files into "meaningful chunks (functions, classes, logical blocks)"
- Computes Merkle tree of file hashes for incremental re-indexing
- Stores only embedding vectors server-side (privacy: path obfuscation, no raw code stored)
- Vector DB: Turbopuffer

**Sourcegraph Cody** (T1 -- [Hartman et al., arXiv:2408.05344](https://arxiv.org/abs/2408.05344)):
- Originally used OpenAI text-embedding-ada-002 for vector embeddings
- Later replaced embeddings with Sourcegraph's native code search (keyword-based)
- Key lesson: "context retrieval sources should be complementary" -- keyword and semantic search use different matching strategies
- Prioritizes **recall over precision** in retrieval, then uses pointwise ranking to filter

### Tree-sitter Java Integration Options

For a Java/Spring codebase, there are several JNI binding options on Maven Central:

| Library | GroupId | Version | Approach |
|---------|---------|---------|----------|
| **seart java-tree-sitter** | `ch.usi.si.seart:java-tree-sitter` | 1.12.0 | JNI, most mature, actively maintained |
| **tree-sitter-ng** | `io.github.bonede:tree-sitter-java` | 0.23.4 | "Next gen" JNI bindings |
| **Official** | `tree-sitter/java-tree-sitter` (GitHub) | -- | Official but less mature |
| **JetBrains jsitter** | JetBrains/jsitter (GitHub) | -- | Uses `sun.misc.Unsafe`, avoids JNI overhead |

**Performance note** (T5 -- [Symflower blog](https://symflower.com/en/company/blog/2023/parsing-code-with-tree-sitter/)): Tree-sitter achieves **36x speedup** over JavaParser for source code parsing. JNI bindings are the standard approach; subprocess spawning would add unnecessary IPC overhead and is not recommended for high-throughput indexing.

**Recommendation for your stack:** Use `ch.usi.si.seart:java-tree-sitter` (Maven Central, actively maintained, JNI). Load grammar files for Java, Go, Python, TypeScript. The JNI approach is standard in production -- subprocess would add ~5-10ms per parse call vs ~0.1ms for JNI, which matters when indexing thousands of files.

---

## 2. Optimal Chunk Granularity for Code

### What the Literature Says

**Function-level is the sweet spot** for most code retrieval tasks. The evidence:

1. **cAST** (T1) recursively breaks at AST node boundaries, which naturally produces function/method-level chunks. Their evaluation shows this granularity works best for both retrieval and generation.

2. **LanceDB CodeRAG guide** (T5 -- [lancedb.com](https://lancedb.com/blog/building-rag-on-codebases-part-1/)) recommends "method/class-level chunking" as the primary unit, noting that "code has a specific syntax with meaningful units."

3. **Mix-of-Granularity (MoG)** (T1 -- [ACL COLING 2025](https://aclanthology.org/2025.coling-main.384.pdf), [arXiv:2406.00456](https://arxiv.org/html/2406.00456v2)): Proposes dynamically selecting optimal granularity per query. For code, this means sometimes retrieving a whole class (for architectural questions) and sometimes a single function (for implementation questions).

4. **Empirical consensus on token sizes** (T5 -- multiple sources): 512-1024 tokens is the sweet spot for embedding models. Larger chunks dilute the embedding; smaller chunks lose context.

### Recommended Granularity Strategy

**Primary unit: function/method** (~200-800 tokens typically). Rationale:
- Functions are the natural unit of code semantics -- one function = one behavior
- They map naturally to search queries ("how does X work?", "where is Y implemented?")
- They fit comfortably within embedding model context windows

**Secondary units for multi-granularity indexing:**
- **Class-level** (with method bodies truncated to signatures): For "what does this class do?" queries
- **Interface/type definitions**: For architectural/API queries
- **File-level summaries** (auto-generated or from header comments): For navigation queries

**What to include as metadata enrichment (prepended to chunk before embedding):**

```
[Language: java]
[File: src/main/java/com/example/service/UserService.java]
[Package: com.example.service]
[Class: UserService]
[Imports: UserRepository, Optional, List, Transactional]
/**
 * Service for user management operations.
 */
public void deleteUser(Long userId) {
    // ... actual code ...
}
```

This pattern is validated by multiple sources:
- **Hugging Face cookbook** (T5 -- [code search tutorial](https://huggingface.co/learn/cookbook/en/code_search)): "normalize data by removing code specifics and including additional context such as module, class, function, and file name"
- **Haystack** (T5 -- [metadata embedding tutorial](https://haystack.deepset.ai/tutorials/39_embedding_metadata_for_improved_retrieval)): Prepending metadata improves retrieval precision
- **Qodo Embed training** (T5 -- [qodo.ai blog](https://www.qodo.ai/blog/qodo-embed-1-code-embedding-code-retrieval/)): They generate synthetic docstrings in Google-style format and prepend them to code for training, showing this enrichment helps

**Critical: imports matter.** Prepending import statements (or at minimum, the imported type names) helps the embedding model understand what external types are being used, which dramatically improves retrieval for queries like "code that uses Spring @Transactional" or "functions that call the UserRepository."

---

## 3. Code Embedding Models: Comparative Analysis

### The Current Landscape (as of early 2026)

The CoIR benchmark (T1 -- [Li et al., ACL 2025](https://arxiv.org/abs/2407.02883)) is the authoritative evaluation for code retrieval, with 10 datasets spanning 8 retrieval tasks across 7 domains.

#### CoIR NDCG@10 Scores (compiled from multiple sources)

| Model | Size | CoIR Avg | CodeSearchNet | Notes |
|-------|------|----------|---------------|-------|
| **Qodo-Embed-1-7B** | 7B | **71.5** | -- | Newest SOTA (T5 -- qodo.ai blog) |
| **Qodo-Embed-1-1.5B** | 1.5B | **68.53** | -- | "Surpasses larger 7B models" |
| **CodeXEmbed-7B** (Salesforce) | 7B | ~67-68* | -- | +20% over Voyage-Code-002 on CoIR (T1 -- [arXiv:2411.12644](https://arxiv.org/abs/2411.12644)) |
| OpenAI text-embedding-3-large | -- | 65.17 | -- | General-purpose baseline |
| Salesforce SFR-Embedding-2_R | 2B | 67.41 | -- | Good quality/size tradeoff |
| **Voyage-Code-3** | Proprietary | ~60-62* | **81.79** (v2) | +13.8% over OpenAI, +16.8% over CodeSage (T5 -- [Voyage blog](https://blog.voyageai.com/2024/12/04/voyage-code-3/)) |
| **Nomic Embed Code** | 7B | -- | SOTA on CSN | Open-source, Apache-2.0 (T5 -- [nomic.ai](https://www.nomic.ai/news/introducing-state-of-the-art-nomic-embed-code)) |
| **Qwen3-Embedding-8B** | 8B | -- | -- | MTEB Code: **80.68** (T2 -- [Qwen blog](https://qwenlm.github.io/blog/qwen3-embedding/)) |
| E5-Mistral | 7B | 55.18 | 54.25 | Strong on StackOverflow (91.54) |
| Voyage-Code-002 | Proprietary | 56.26 | 81.79 | Older version, superseded |
| UniXcoder | 123M | 37.33 | 60.20 | Code-pretrained but poor on CoIR |
| CodeBERT | 125M | -- | ~67* | Older, superseded |
| Jina Code V2 | -- | -- | -- | "Excels at code similarity" but limited benchmarks |

*Estimated from relative comparisons in papers.

### Key Findings

1. **Code-specialized models decisively beat general-purpose** on code retrieval. Voyage-Code-3 outperforms OpenAI-v3-large by 5-8 NDCG points. CodeXEmbed-7B outperforms Voyage-Code-002 by 20%.

2. **Qwen3-Embedding-8B is surprisingly competitive.** Its MTEB Code score of 80.68 surpasses even Gemini-Embedding (T2 -- [arXiv:2506.05176](https://arxiv.org/abs/2506.05176)). This suggests a general-purpose model with sufficient scale can compete with code-specialized models.

3. **Model size matters more than code specialization below 1B.** UniXcoder (123M, code-pretrained) scores only 37.33 on CoIR, while E5-Base (110M, general) scores 50.90. At small scales, general pre-training on diverse data seems more valuable than code-only pre-training.

4. **No single model dominates all code tasks.** On CoIR, Voyage-Code-002 wins on CodeSearchNet (81.79) but E5-Mistral wins on StackOverflow (91.54) and CodeTrans-Contest (82.55). Task diversity matters.

5. **CodeBERT/GraphCodeBERT/UniXcoder are now obsolete** for retrieval. They were important historically but their 123-125M parameter scale cannot compete with modern 1.5-8B models.

### Recommendations for Your Setup

**If self-hosting is mandatory** (your case with Ollama/pgvector):
- **Best option: Qwen3-Embedding-8B** via Ollama. Available as `qwen3-embedding`. 8B params, 4096 dim (can be reduced via Matryoshka). Competitive with code-specialized models. Multilingual. Already supported by Ollama.
- **Lighter alternative: Nomic Embed Code** via Ollama (Apache-2.0, GGUF available). 7B params. SOTA on CodeSearchNet.
- **Budget option: CodeRankEmbed-137M** -- tiny but surprisingly good (77.9 MRR on CSN).

**If API access acceptable:**
- **Voyage-Code-3** is the strongest proprietary option.
- **Qodo-Embed-1-1.5B** achieves 68.53 on CoIR at 1.5B -- excellent quality/size ratio if you can self-host.

**Transition from mxbai-embed-large:** Your current model (1024 dim, general-purpose) will work for code but will underperform a code-specialized model by an estimated 15-25% on code retrieval tasks. The switch to Qwen3-Embedding or Nomic Embed Code would require re-embedding all code chunks but is strongly recommended.

---

## 4. Hybrid Retrieval for Code

### Evidence for Hybrid (Vector + BM25)

**Empirical consensus** (T5 -- multiple engineering blogs and benchmarks): Hybrid search improves recall by **15-30%** over either method alone.

**Why hybrid matters especially for code:**
1. **Identifiers are keyword-sensitive.** A query for `UserRepository.findById` must match that exact token sequence. Vector search alone may retrieve semantically similar but wrong methods.
2. **API names and error messages** are inherently lexical. Searching for `NullPointerException in UserService.createUser` needs BM25 to match the exact class/method names.
3. **Stack traces** contain precise identifiers that BM25 excels at matching.
4. **Import resolution:** If you search for "Spring @Transactional," BM25 finds exact annotation matches while vector search finds semantically related transaction-management code. Both are useful.

**GitHub's choice** (T5 -- [ZenML podcast reference](https://www.zenml.io/llmops-database/bm25-vs-vector-search-for-large-scale-code-repository-search)): GitHub chose BM25 over pure vector search for their code search due to:
- Computational efficiency at 100B+ document scale
- Zero-shot capability (no model training needed)
- Predictable behavior for exact-match queries

**However, GitHub's choice is not your choice.** At their scale (100B documents), vector search infrastructure costs are prohibitive. At your scale (a few repositories), hybrid is clearly optimal because you get both semantic understanding AND exact-match precision.

**Sourcegraph's evolution** (T1 -- [Hartman et al., 2024](https://arxiv.org/abs/2408.05344)): Sourcegraph actually moved *away* from embeddings back to their native keyword search, but noted that "context retrieval sources should be complementary." Their conclusion: the best system uses both.

**IBM multi-way retrieval study** (T5 -- [Infinity DB blog](https://infiniflow.org/blog/multi-way-retrieval-evaluations-on-infinity-database)): Tested BM25-only, vector-only, BM25+vector, vector+sparse, and three-way (BM25+dense+sparse). Conclusion: **three-way retrieval is optimal for RAG**.

### Recommended Hybrid Architecture for pgvector

```
Query
  |
  +--> pgvector: cosine similarity search (top K=20)
  |
  +--> BM25/tsvector: PostgreSQL full-text search (top K=20)
  |
  +--> Reciprocal Rank Fusion (RRF) to merge results
  |
  +--> (Optional) Reranker for top N results
  |
  +--> Final top 5-10 chunks as context
```

PostgreSQL natively supports `tsvector`/`tsquery` for full-text search alongside pgvector. This means you can do hybrid search in a single database without adding ElasticSearch:

```sql
-- Hybrid query combining vector similarity and full-text search
WITH vector_results AS (
    SELECT id, content, 1 - (embedding <=> query_embedding) AS vector_score
    FROM code_chunks
    ORDER BY embedding <=> query_embedding
    LIMIT 20
),
text_results AS (
    SELECT id, content, ts_rank(search_vector, plainto_tsquery('english', 'UserRepository findById')) AS text_score
    FROM code_chunks
    WHERE search_vector @@ plainto_tsquery('english', 'UserRepository findById')
    ORDER BY text_score DESC
    LIMIT 20
)
SELECT COALESCE(v.id, t.id) AS id,
       COALESCE(v.content, t.content) AS content,
       COALESCE(v.vector_score, 0) * 0.7 + COALESCE(t.text_score, 0) * 0.3 AS combined_score
FROM vector_results v
FULL OUTER JOIN text_results t ON v.id = t.id
ORDER BY combined_score DESC
LIMIT 10;
```

**Dynamic Alpha Tuning (DAT)** (T2 -- [arXiv:2503.23013](https://arxiv.org/pdf/2503.23013)): Recent work proposes dynamically adjusting the weight between dense and sparse retrieval per query. For identifier-heavy queries, increase BM25 weight; for natural-language questions, increase vector weight. This is an advanced optimization worth considering after the basic hybrid is working.

---

## 5. Practical Architectures from Production Systems

### Architecture Comparison Table

| System | Chunking | Embedding Model | Vector DB | Hybrid? | Key Innovation |
|--------|----------|-----------------|-----------|---------|----------------|
| **Cursor** | Tree-sitter (functions, classes) | Proprietary | Turbopuffer | Yes (keyword + semantic) | Merkle tree for incremental indexing; path obfuscation for privacy |
| **Sourcegraph Cody** | Not specified (was chunk-based) | Was Ada-002, now native search | Custom | Moved to keyword-only | Replaced embeddings with native code search; MCP for external context |
| **Aider** | Tree-sitter (definitions + references) | N/A (uses graph, not embeddings) | N/A | N/A | PageRank on dependency graph; no vector DB needed |
| **Continue.dev** | User-configurable | User-configurable | User-configurable | Via MCP | MCP-based architecture; "bring your own RAG" |
| **GitHub Copilot** | Proprietary | Proprietary | Proprietary | BM25-primary | Scale-optimized for 100B+ docs |

### Lessons Learned

1. **Incremental indexing is non-negotiable.** Cursor uses Merkle trees of file hashes. You should track file modification timestamps and content hashes to avoid re-embedding unchanged files. (Your existing `embeddings_sync` table with `chunk_version` already supports this pattern.)

2. **Graph analysis complements vector search.** Aider's PageRank on the dependency graph is powerful for finding "which files are most relevant to this change?" without any embedding at all. Consider building a lightweight call graph alongside your vector index.

3. **Sourcegraph's retreat from embeddings is a cautionary tale** -- but for the wrong reasons. They abandoned embeddings because their existing keyword search infrastructure was already excellent at scale. For a smaller system without a sophisticated code search engine, embeddings provide a capability you don't otherwise have.

4. **MCP is the emerging standard** for code context retrieval. Continue.dev already uses it. Your existing MCP infrastructure (simoge-mcp) makes this a natural fit.

---

## Serendipitous Connections

### Connection to Agent COBOL Project
Tree-sitter has a **tree-sitter-cobol** grammar (community-maintained). If the Agent COBOL project involves understanding COBOL codebases for modernization, the same AST-chunking infrastructure built for Java/Go/Python/TypeScript could be extended to COBOL. This would enable semantic search over legacy COBOL code -- "find all paragraphs that modify CUSTOMER-BALANCE" -- which is precisely the capability needed for safe modernization.

### Connection to Kindle Graph Enrichment / Knowledge Graph
The code chunking pipeline produces rich structured metadata (language, file path, class, method, imports, dependencies). These are natural candidates for AGE graph nodes:
- `CodeFunction` nodes with `CALLS` and `IMPORTS` edges
- `CodeClass` nodes with `CONTAINS_METHOD` edges
- Cross-referencing with `Paper` nodes when code implements algorithms from papers

### Connection to Ranking Todo / Preference Sort
The Bradley-Terry model used in Preference Sort could be applied to **reranking** code search results. Instead of simple RRF, you could collect user feedback on which results were actually useful and train a Bradley-Terry ranking model to improve result ordering over time.

### Structural Analogy: Chunking as Lossy Compression
Code chunking for embedding is structurally analogous to lossy compression in signal processing. The AST provides the "frequency domain" decomposition of code, and choosing a granularity (function vs class vs file) is like choosing a bandwidth cutoff. Too fine-grained = noise in the embedding space. Too coarse = loss of discriminative information. The optimal granularity is the one that maximizes mutual information between the embedding and the user's query distribution.

---

## Open Questions

1. **Late chunking for code?** Jina's "late chunking" (T2 -- [arXiv:2409.04701](https://arxiv.org/html/2409.04701v3)) embeds the full document first, then splits into chunks while preserving cross-chunk context. Has anyone applied this to code? No papers found -- this is an open area.

2. **Graph-augmented code embeddings?** GraphCodeBERT used data flow graphs. At larger model scales (7B+), does structural graph information still help, or does the transformer's self-attention learn it implicitly? No definitive answer in the literature.

3. **Optimal dimension for code embeddings?** Most models use 768-4096 dims. pgvector performance degrades above ~2000 dims. Is Matryoshka dimension reduction (e.g., Qwen3 4096 -> 1024) safe for code retrieval, or does it disproportionately lose code-specific features? No benchmarks found.

4. **Cross-language code retrieval:** If you embed Java and Go code together, can you find "the Go equivalent of this Java function"? CodeXEmbed claims to support this across 12 languages, but real-world evaluation is limited.

---

## What to Read Next

1. **cAST paper** ([arXiv:2506.15655](https://arxiv.org/abs/2506.15655)) -- The most rigorous evaluation of AST-based chunking. Read for the algorithm and benchmarks.
2. **CoIR benchmark** ([arXiv:2407.02883](https://arxiv.org/abs/2407.02883)) -- The authoritative code retrieval benchmark. Read Table 3 for all model scores.
3. **CodeXEmbed paper** ([arXiv:2411.12644](https://arxiv.org/abs/2411.12644)) -- Salesforce's code embedding family. Read for training methodology.
4. **Aider repo map blog** ([aider.chat](https://aider.chat/2023/10/22/repomap.html)) -- Most detailed open description of tree-sitter + PageRank for code understanding.
5. **Voyage AI code retrieval evaluation** ([blog.voyageai.com](https://blog.voyageai.com/2024/12/04/code-retrieval-eval/)) -- Critical analysis of benchmark quality (51% of CoSQA labels are wrong).

---

## Knowledge Graph Candidates

- **"AST-aware code chunking"** -- Type: technique. Links: tree-sitter, RAG, code embedding, cAST
- **"CoIR benchmark"** -- Type: framework. Links: code retrieval, embedding evaluation, CodeSearchNet
- **"tree-sitter"** -- Type: technique. Links: AST parsing, code chunking, Aider, Cursor
- **"Reciprocal Rank Fusion (RRF)"** -- Type: technique. Links: hybrid retrieval, BM25, vector search
- **"CodeXEmbed"** -- Type: framework. Links: Salesforce, code embedding, CoIR
- **"Qwen3-Embedding"** -- Type: framework. Links: embedding model, MTEB, multilingual, code retrieval
- **"Mix-of-Granularity (MoG)"** -- Type: technique. Links: chunk size, retrieval granularity, RAG

---

## Sources

### T1 -- Peer-reviewed
- Zhang et al., "cAST: Enhancing Code Retrieval-Augmented Generation with Structural Chunking via Abstract Syntax Tree," EMNLP 2025 Findings. [arXiv:2506.15655](https://arxiv.org/abs/2506.15655)
- Li et al., "CoIR: A Comprehensive Benchmark for Code Information Retrieval Models," ACL 2025. [arXiv:2407.02883](https://arxiv.org/abs/2407.02883)
- CodeXEmbed, "A Generalist Embedding Model Family for Multilingual and Multi-task Code Retrieval," COLM 2025. [arXiv:2411.12644](https://arxiv.org/abs/2411.12644)
- Hartman et al., "AI-assisted Coding with Cody," Sourcegraph, 2024. [arXiv:2408.05344](https://arxiv.org/abs/2408.05344)
- MoG, "Mix-of-Granularity: Optimize the Chunking Granularity for RAG," COLING 2025. [arXiv:2406.00456](https://arxiv.org/abs/2406.00456)

### T2 -- arXiv preprints
- Qwen3-Embedding, "Advancing Text Embedding and Reranking Through Foundation Models." [arXiv:2506.05176](https://arxiv.org/abs/2506.05176)
- Late Chunking, "Contextual Chunk Embeddings Using Long-Context Embedding Models." [arXiv:2409.04701](https://arxiv.org/abs/2409.04701)
- DAT, "Dynamic Alpha Tuning for Hybrid Retrieval." [arXiv:2503.23013](https://arxiv.org/abs/2503.23013)

### T5 -- Engineering blogs
- [Aider: Building a better repository map with tree-sitter](https://aider.chat/2023/10/22/repomap.html)
- [How Cursor Actually Indexes Your Codebase](https://towardsdatascience.com/how-cursor-actually-indexes-your-codebase/) (TDS, Jan 2026)
- [Sourcegraph: How Cody understands your codebase](https://sourcegraph.com/blog/how-cody-understands-your-codebase)
- [Voyage AI: voyage-code-3 announcement](https://blog.voyageai.com/2024/12/04/voyage-code-3/)
- [Voyage AI: How do we evaluate code retrieval?](https://blog.voyageai.com/2024/12/04/code-retrieval-eval/)
- [Modal: 6 Best Code Embedding Models Compared](https://modal.com/blog/6-best-code-embedding-models-compared)
- [Nomic: Introducing Nomic Embed Code](https://www.nomic.ai/news/introducing-state-of-the-art-nomic-embed-code)
- [Qodo: State-of-the-Art Code Retrieval with Qodo-Embed-1](https://www.qodo.ai/blog/qodo-embed-1-code-embedding-code-retrieval/)
- [LanceDB: Building RAG on Codebases Part 1](https://lancedb.com/blog/building-rag-on-codebases-part-1/)
- [Symflower: TreeSitter - the holy grail of parsing](https://symflower.com/en/company/blog/2023/parsing-code-with-tree-sitter/)
- [Hugging Face: Code Search with Vector Embeddings](https://huggingface.co/learn/cookbook/en/code_search)
- [Infinity DB: Multi-way retrieval evaluations](https://infiniflow.org/blog/multi-way-retrieval-evaluations-on-infinity-database)
- [Chroma Research: Evaluating Chunking Strategies](https://research.trychroma.com/evaluating-chunking)

### T7 -- Reference
- [seart-group/java-tree-sitter](https://github.com/seart-group/java-tree-sitter) (Maven Central: ch.usi.si.seart:java-tree-sitter:1.12.0)
- [tree-sitter-ng](https://github.com/bonede/tree-sitter-ng) (Maven Central: io.github.bonede:tree-sitter-java:0.23.4)
- [ASTChunk Python toolkit](https://github.com/yilinjz/astchunk)
- [Qwen3-Embedding on Ollama](https://ollama.com/library/qwen3-embedding)
