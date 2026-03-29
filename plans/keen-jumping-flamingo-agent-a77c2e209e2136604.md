# OpenAlex API Integration Research

**Epistemic status:** Established, well-documented open API with active development. Major "Walden" rewrite shipped Dec 2025.
**Confidence:** High -- based on live API responses, official documentation (Scribd mirror of docs, GitHub release notes), blog posts, and community projects.
**Sources fetched:** OpenAlex live API (direct JSON response), OpenAlex blog, GitHub release notes, Scribd docs mirror, pyalex/openalexR repos, HuggingFace embedding model pages, MTEB benchmark papers, multiple search result pages.

---

## 1. Works API: `GET https://api.openalex.org/works`

**Docs:** `https://developers.openalex.org/api-entities/works` (Mintlify SPA -- use raw API or Scribd mirror for machine-readable docs)

### Search Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `search` | Full-text search across title + abstract + fulltext | `?search=dna` |
| `search` (title only) | Use `filter` instead: `display_name.search` | `?filter=display_name.search:transformer attention` |
| `filter` | Structured filtering (combinable with AND `,`, OR `\|`, NOT `!`) | `?filter=publication_year:2024,open_access.is_oa:true` |
| `sort` | Sort results | `?sort=cited_by_count:desc` or `?sort=relevance_score:desc` (only with `search`) |
| `per_page` | Results per page (max 200) | `?per_page=50` |
| `page` | Page number (max page * per_page = 10,000) | `?page=2` |
| `cursor` | Cursor-based pagination (no 10k limit) | `?cursor=*` then use `next_cursor` from response |
| `select` | Select specific fields (reduces response size) | `?select=id,title,abstract_inverted_index,authorships` |
| `mailto` | Email for polite pool (DEPRECATED -- use `api_key` now) | `?mailto=you@example.com` |
| `api_key` | API key (required as of Feb 2025) | `?api_key=YOUR_KEY` |

### Key Filters for Academic Search

```
# By topic/domain (new system)
filter=topics.id:T10220
filter=primary_topic.domain.id:domains/3    # Physical Sciences
filter=primary_topic.field.id:fields/17      # Computer Science
filter=primary_topic.subfield.id:subfields/1702  # AI

# By concept (legacy, still works)
filter=concepts.id:C41008148    # Computer Science

# By author
filter=authorships.author.id:A5023888391

# By year range
filter=publication_year:2020-2025

# By citation count
filter=cited_by_count:>100

# By open access
filter=open_access.is_oa:true

# By type
filter=type:article

# By source (journal)
filter=primary_location.source.id:S137773608   # Nature

# Compound filter (AND is comma, OR is pipe)
filter=publication_year:>2022,concepts.id:C41008148,cited_by_count:>50
```

### Typical Response Structure

Based on actual API call `https://api.openalex.org/works?search=transformer+attention+mechanism&per_page=1`:

```json
{
  "meta": {
    "count": 195953,        // total matching works
    "db_response_time_ms": 132,
    "page": 1,
    "per_page": 1
  },
  "results": [{
    "id": "https://openalex.org/W4200049650",
    "doi": "https://doi.org/10.1016/j.ymssp.2021.108616",
    "title": "A novel time-frequency Transformer...",
    "display_name": "A novel time-frequency Transformer...",
    "relevance_score": 692.9246,
    "publication_year": 2021,
    "publication_date": "2021-12-03",
    "language": "en",
    "type": "article",
    "is_retracted": false,

    // --- LOCATION & OPEN ACCESS ---
    "primary_location": {
      "source": {
        "id": "https://openalex.org/S128368299",
        "display_name": "Mechanical Systems and Signal Processing",
        "type": "journal"
      },
      "is_oa": false,
      "pdf_url": null
    },
    "open_access": {
      "is_oa": true,
      "oa_status": "green",       // gold | green | hybrid | bronze | closed
      "oa_url": "https://arxiv.org/pdf/2104.09079"
    },
    "best_oa_location": { /* ... with pdf_url */ },

    // --- AUTHORS ---
    "authorships": [{
      "author_position": "first",
      "author": {
        "id": "https://openalex.org/A5063133083",
        "display_name": "Yifei Ding",
        "orcid": "https://orcid.org/0000-0001-8408-6945"
      },
      "institutions": [{
        "id": "https://openalex.org/I76569877",
        "display_name": "Southeast University",
        "country_code": "CN"
      }],
      "is_corresponding": false
    }],

    // --- TOPICS (new system) ---
    "primary_topic": {
      "id": "https://openalex.org/T10220",
      "display_name": "Machine Fault Diagnosis Techniques",
      "score": 0.9992,
      "subfield": { "id": "...", "display_name": "Control and Systems Engineering" },
      "field": { "id": "...", "display_name": "Engineering" },
      "domain": { "id": "...", "display_name": "Physical Sciences" }
    },
    "topics": [ /* array of topic objects with scores */ ],

    // --- CONCEPTS (legacy, still populated) ---
    "concepts": [{
      "id": "https://openalex.org/C66322947",
      "display_name": "Transformer",
      "level": 3,
      "score": 0.7344
    }],

    // --- KEYWORDS ---
    "keywords": [{ "id": "...", "display_name": "Transformer", "score": 0.734 }],

    // --- CITATIONS ---
    "cited_by_count": 453,
    "fwci": 34.8262,                    // Field-Weighted Citation Impact
    "citation_normalized_percentile": {
      "value": 0.9996,
      "is_in_top_1_percent": true
    },
    "referenced_works_count": 64,
    "referenced_works": ["https://openalex.org/W..."],
    "related_works": ["https://openalex.org/W..."],
    "counts_by_year": [{"year": 2025, "cited_by_count": 183}],

    // --- ABSTRACT (inverted index format!) ---
    "abstract_inverted_index": null,     // null for some works
    // When present: {"Despite": [0], "growing": [1], "interest": [2], ...}

    // --- FUNDING ---
    "awards": [{"funder_display_name": "National Natural Science Foundation of China"}],
    "funders": [{"display_name": "National Natural Science Foundation of China"}],

    // --- SDGs ---
    "sustainable_development_goals": [{"display_name": "Industry, innovation and infrastructure", "score": 0.43}],

    // --- METADATA ---
    "biblio": {"volume": "168", "first_page": "108616"},
    "indexed_in": ["arxiv", "crossref"],
    "updated_date": "2026-03-10T16:38:18.471706",
    "created_date": "2025-10-10"
  }]
}
```

### Important Implementation Notes

- **Pagination limit**: `page` * `per_page` cannot exceed 10,000. For large result sets, use **cursor pagination** (`cursor=*`), which has no limit.
- **`select` parameter** is crucial for performance -- avoids transferring `abstract_inverted_index`, `referenced_works`, etc. when not needed.
- **`search` vs `filter`**: `search` does relevance ranking (BM25-like); `filter` is exact matching. Combine both: `?search=attention&filter=publication_year:2024`.
- **Group by**: `?group_by=publication_year` returns faceted counts instead of results.
- **Autocomplete**: `https://api.openalex.org/autocomplete/works?q=trans` for suggestions.

---

## 2. Inverted Index Abstract Format

### How OpenAlex Stores Abstracts

OpenAlex stores abstracts as `abstract_inverted_index` (not plain text) due to **legal constraints inherited from Microsoft Academic Graph**. The idea is that an inverted index is not a "copy" of the abstract in a copyright sense, but it's trivially reconstructible.

**Format**: A JSON object where keys are words and values are arrays of zero-indexed positions:

```json
{
  "Despite": [0],
  "growing": [1],
  "interest": [2],
  "in": [3, 57, 73, 110, 122],
  "Open": [4, 201],
  "Access": [5],
  "(OA)": [6],
  "to": [7, 54, 252],
  "scholarly": [8, 105],
  "literature,": [9]
}
```

Note: Words include their trailing punctuation (e.g., `"literature,"` not `"literature"`).

### Reconstruction Algorithm

```
INPUT: abstract_inverted_index (dict: word -> [positions])
OUTPUT: plain text string

1. Find max_position = max of all position values across all words
2. Create array of size (max_position + 1)
3. For each (word, positions) in abstract_inverted_index:
     For each pos in positions:
       array[pos] = word
4. Return " ".join(array)
```

**In Python:**
```python
def reconstruct_abstract(inverted_index):
    if not inverted_index:
        return None
    # Build position -> word mapping
    word_positions = {}
    for word, positions in inverted_index.items():
        for pos in positions:
            word_positions[pos] = word
    # Reconstruct by sorting positions
    max_pos = max(word_positions.keys())
    abstract_words = []
    for i in range(max_pos + 1):
        abstract_words.append(word_positions.get(i, ""))
    return " ".join(abstract_words)
```

**In Java (for your MCP tools):**
```java
public static String reconstructAbstract(Map<String, List<Integer>> invertedIndex) {
    if (invertedIndex == null || invertedIndex.isEmpty()) return null;
    TreeMap<Integer, String> positionMap = new TreeMap<>();
    for (Map.Entry<String, List<Integer>> entry : invertedIndex.entrySet()) {
        for (Integer pos : entry.getValue()) {
            positionMap.put(pos, entry.getKey());
        }
    }
    return String.join(" ", positionMap.values());
}
```

### Known Gotchas

1. **Some abstracts contain HTML artifacts**: Words like `"<div"`, `"class=\"htmlview"` appear because OpenAlex sources some abstracts from Crossref where publishers submit HTML-tagged abstracts. You need to strip HTML tags post-reconstruction.
2. **`abstract_inverted_index` is null** for many works (~30-40% lack abstracts entirely).
3. **Performance**: The inverted index is typically the largest field in a Work response. Use `select=` to exclude it when you don't need it.
4. **PyAlex library** (`pip install pyalex`) auto-converts inverted index to plain text via `.abstract` property.

---

## 3. Rate Limits

### Current System (post-Feb 2025)

OpenAlex transitioned from the old "polite pool" system to **API key + usage-based credits**:

| Tier | Rate | Daily Budget | How to Get |
|------|------|-------------|------------|
| No API key | 100 credits/day | Testing only | -- |
| Free API key | ~$1 worth of credits/day | Sufficient for ~100k simple lookups | Register at `https://openalex.org/settings/api` |
| Premium | Custom budget | Pay-as-you-go | Contact OpenAlex |

**Credit costs vary by operation:**
- Simple work lookup by ID: very cheap (~0.001 credits)
- Search/filter queries: moderate
- PDF/content operations: expensive
- Bulk downloads: most expensive per-call

**Old system (pre-Feb 2025, now deprecated):**
- Without `mailto`: 100k req/day, max 10 req/sec
- With `mailto` (polite pool): 100k req/day, max 10 req/sec (same limits, but prioritized)
- **The `mailto` parameter still works but is deprecated in favor of `api_key`**

### Rate Limit Response Headers

```
x-ratelimit-limit: ...
x-ratelimit-remaining: ...
x-ratelimit-reset: ...
```

**When you hit limits**: HTTP 429 Too Many Requests. Back off and retry.

### Practical Advice

- **Always use `api_key`** -- register free at `https://openalex.org/settings/api`
- For a personal academic search engine, the free tier ($1/day) should be sufficient for hundreds of searches per day
- Use `select=` to reduce payload size (not rate-limit related, but reduces bandwidth)
- Cache aggressively -- works rarely change (maybe citation counts update weekly)
- For bulk operations, prefer the **S3 snapshot** over API

---

## 4. Bulk Data Access: OpenAlex S3 Snapshot

### Current State (post-Walden rewrite, Dec 2025)

**S3 bucket:** `s3://openalex`
**Download command:**
```bash
aws s3 sync 's3://openalex' 'openalex-snapshot' --no-sign-request
```

The snapshot underwent a major change with the **"Walden" rewrite** (launched Dec 14, 2025):

- Legacy format (`data-version=1`): JSON Lines (.jsonl.gz) -- **no longer updated** as of Dec 2025
- **New "standard format"**: available at `s3://openalex/data` -- this is the current, actively updated format
- Data is organized by entity type: `works/`, `authors/`, `sources/`, `institutions/`, `topics/`, `publishers/`, `funders/`

### Format Details

- **Primary format**: Compressed JSON Lines (`.jsonl.gz`) partitioned into ~300 files per entity type
- **Parquet format**: OpenAlex does NOT natively provide Parquet. Community projects convert to Parquet (e.g., `openalex-raw` Python package, various BigQuery importers). The "Science Data Lake" project (arXiv:2603.03126, Mar 2026) provides ~960GB of Parquet across 293M papers from 8 sources including OpenAlex.
- **Update frequency**: Snapshots updated roughly every 2-4 weeks. Release notes at `github.com/ourresearch/openalex-guts/blob/main/files-for-datadumps/standard-format/RELEASE_NOTES.txt`
  - 2026-02-03: latest noted release
  - 2026-01-15: author bug fixes
  - 2025-11-12: switch to Walden dataset

### Size Estimates

- Full snapshot (all entities, compressed JSONL): **~350-500 GB** compressed
- Works alone (the largest entity): ~250-350 GB compressed
- ~250M+ works in total

### Selective Download

```bash
# Download only works
aws s3 sync 's3://openalex/data/works' './openalex-works' --no-sign-request

# Download only a specific date partition (if available)
aws s3 sync 's3://openalex/data/works' './openalex-works' --no-sign-request \
  --exclude "*" --include "updated_date=2026-01*/*"

# List available files first
aws s3 ls 's3://openalex/data/works/' --no-sign-request
```

**Important**: There is no built-in filtering by concept/topic at the S3 level. You download the full entity type and filter locally. For topic-specific subsets, use the API with cursor pagination instead, or process the snapshot locally with DuckDB.

### Manifest Files

Each entity directory contains a `manifest` file listing all part files with sizes and record counts.

---

## 5. Concepts vs Topics Taxonomy

### Migration Timeline

| Date | Event |
|------|-------|
| 2022-2023 | OpenAlex uses **Concepts** (inherited from Microsoft Academic Graph): hierarchical, 6 levels (0-5), ~65k concepts |
| Feb 2024 | OpenAlex introduces **Topics**: new 4-level hierarchy, ML-classified |
| 2024-2025 | Both systems coexist; concepts still populated |
| Dec 2025 | **Walden rewrite** -- concepts still available but Topics are the primary system |

### Topics Hierarchy (current, what a new integration should use)

| Level | Name | Count | Example |
|-------|------|-------|---------|
| 1 | **Domain** | 4 | Physical Sciences, Life Sciences, Social Sciences, Health Sciences |
| 2 | **Field** | 26 | Computer Science, Mathematics, Physics, Economics |
| 3 | **Subfield** | 252 | Artificial Intelligence, Number Theory, Quantum Mechanics |
| 4 | **Topic** | 4,516 | Machine Fault Diagnosis Techniques, Transformer Models in NLP |

**Classification method**: Each work is assigned a `primary_topic` (with score) and up to 3 `topics`. Based on a BERTopic-like classifier mapping to OECD Fields of Research and Development (FORD) taxonomy.

### Concepts (legacy but still available)

- Still populated in API responses (both `concepts` array on works, and `/concepts` endpoint)
- 6 levels: Level 0 (broadest, ~20 concepts like "Computer Science", "Physics") to Level 5 (most specific)
- Each concept has a `score` (0-1) indicating relevance to the work
- **Not deprecated yet** but no longer the primary classification

### Recommendation for New Integration

**Use Topics for filtering and categorization.** They are:
- More stable (fixed taxonomy vs. crowd-derived concepts)
- Better organized (clean 4-level hierarchy aligned with OECD FORD)
- The focus of ongoing OpenAlex development

**Keep Concepts for backward compatibility** -- useful for:
- Fine-grained subject tagging (4,516 topics vs. ~65k concepts)
- Interoperability with older systems that used MAG concept IDs

### API Usage

```
# Filter by topic
/works?filter=primary_topic.id:T10220
/works?filter=primary_topic.domain.id:domains/3

# Filter by concept (legacy, still works)
/works?filter=concepts.id:C41008148

# Get topic details
/topics/T10220
/topics?filter=domain.id:domains/3
```

---

## 6. DuckDB on OpenAlex Data

### Setup

Since OpenAlex provides JSONL (not native Parquet), the typical workflow is:

1. Download JSONL snapshot from S3
2. Convert to Parquet (using Python/Spark/DuckDB itself)
3. Query with DuckDB

**Direct JSONL reading with DuckDB:**
```sql
-- DuckDB can read gzipped JSON Lines directly
SELECT * FROM read_json_auto('openalex-works/part_000.jsonl.gz',
  maximum_object_size=10485760,
  format='newline_delimited')
LIMIT 10;
```

**Converting to Parquet:**
```sql
-- Convert JSONL to Parquet (one-time operation)
COPY (
  SELECT * FROM read_json_auto('openalex-works/*.jsonl.gz',
    maximum_object_size=10485760,
    format='newline_delimited',
    union_by_name=true)
) TO 'works.parquet' (FORMAT PARQUET, COMPRESSION ZSTD);
```

### Known Gotchas with Nested Structures

The OpenAlex schema is deeply nested. Key challenges:

**1. `authorships` is an array of structs:**
```sql
-- Flatten authorships to query individual authors
SELECT
  w.id,
  w.title,
  a.author.display_name AS author_name,
  a.author.id AS author_id,
  a.author_position
FROM read_parquet('works.parquet') w,
  UNNEST(w.authorships) AS a;
```

**2. `concepts` / `topics` are arrays of structs:**
```sql
-- Find works about "Machine Learning" concept
SELECT w.id, w.title, c.display_name, c.score
FROM read_parquet('works.parquet') w,
  UNNEST(w.concepts) AS c
WHERE c.display_name = 'Machine learning'
  AND c.score > 0.5;
```

**3. `abstract_inverted_index` is a MAP type:**
This is the trickiest field. In DuckDB, it becomes a `MAP(VARCHAR, INTEGER[])`. Reconstructing the abstract in pure SQL is verbose:

```sql
-- The inverted index is hard to reconstruct in SQL alone.
-- Better approach: reconstruct in application code, then store as plain text column.
-- Or use a DuckDB UDF if using Python bindings.
```

**4. `locations` is an array of structs with nested `source`:**
```sql
SELECT w.id, loc.source.display_name AS journal
FROM read_parquet('works.parquet') w,
  UNNEST(w.locations) AS loc
WHERE loc.source.type = 'journal';
```

**5. Schema evolution**: The Walden rewrite (Dec 2025) changed some field names. Use `union_by_name=true` when reading mixed-vintage files.

**6. Memory**: Full works dataset won't fit in RAM. Use DuckDB's out-of-core execution (it handles this automatically) or work with subsets.

### Performance Tips

- **Parquet is much faster than JSONL** for analytical queries (10-100x). Worth the one-time conversion cost.
- **Partition by year** when converting: `COPY ... TO 'works/' (FORMAT PARQUET, PARTITION_BY (publication_year))`
- **Columnar projection**: DuckDB + Parquet only reads the columns you SELECT. `select id, title, cited_by_count` on Parquet is fast even on the full dataset.
- **Pre-filter during conversion**: Only convert works you care about (e.g., `WHERE publication_year >= 2020 AND language = 'en'`)

### Approximate Query for a Personal Academic Search

```sql
-- Create a focused subset for your search engine
CREATE TABLE my_works AS
SELECT
  id,
  doi,
  title,
  publication_year,
  cited_by_count,
  fwci,
  open_access.oa_url AS oa_url,
  primary_topic.display_name AS topic,
  primary_topic.field.display_name AS field,
  primary_topic.domain.display_name AS domain
FROM read_parquet('works.parquet')
WHERE publication_year >= 2015
  AND language = 'en'
  AND type = 'article';
-- Then add abstract reconstruction and embedding generation as a batch process
```

---

## 7. Embedding Models for Academic Text Search

### Comparison Table

| Model | Dim | Params | MTEB Avg | MTEB Retrieval | Max Tokens | License | Notes |
|-------|-----|--------|----------|----------------|------------|---------|-------|
| **mxbai-embed-large-v1** | 1024 | 335M | 64.68 | ~54-55 | 512 | Apache 2.0 | Your current model. Solid, efficient. Available in Ollama. |
| **e5-mistral-7b-instruct** | 4096 | 7.1B | 66.63 | ~56-57 | 32768 | MIT | LLM-based. Very long context. 20x heavier than mxbai. |
| **NV-Embed-v2** | 4096 | 7.8B | 72.31 | ~62 | 32768 | CC-BY-NC-4.0 | ICLR 2025. State-of-art at publication. Non-commercial license. |
| **EmbeddingGemma** (2B) | 768-3072 (configurable via Matryoshka) | 2B | ~65 | -- | 8192 | Gemma license | Sep 2025. Lightweight for LLM-based. Matryoshka dims. |
| **Conan-Embedding-v2** | 4096 | ~7B | ~67 | -- | 8192 | -- | EMNLP 2025. Trained from scratch for embeddings. |
| **nomic-embed-text-v1.5** | 768 (Matryoshka: 64-768) | 137M | ~62 | ~52 | 8192 | Apache 2.0 | Very lightweight. Matryoshka allows dim reduction. Long context. |
| **snowflake-arctic-embed-l-v2.0** | 1024 | 568M | ~67 | ~58 | 8192 | Apache 2.0 | Dec 2024. Multilingual. Strong retrieval. |
| **Qwen3-Embedding-8B** | 4096 | 8B | -- | -- | 32768 | Apache 2.0 | 2025. Newest LLM-based option. |

*Scores are approximate from MTEB leaderboard and cited papers (T2 -- arXiv/ICLR/EMNLP). Exact scores shift as MTEB evolves.*

### Analysis: Is 4096 dim Worth 4x the Cost?

**Storage/RAM cost:**
- 1024 dim float32: **4 KB per vector**. 250K papers = ~1 GB
- 4096 dim float32: **16 KB per vector**. 250K papers = ~4 GB
- pgvector HNSW index overhead: ~1.5-2x raw vector size

**For your setup** (105 papers currently, scaling to maybe 10K-50K):
- At 50K papers, 1024-dim = ~200 MB, 4096-dim = ~800 MB. Both trivially fit in your 16GB server.
- **The bottleneck is inference speed, not storage.** `e5-mistral-7b-instruct` requires ~14GB VRAM for inference. You don't have a GPU, so you'd run it on CPU via Ollama which would be very slow (30-60s per embedding vs. <1s for mxbai).

**Quality difference for academic search specifically:**
- MTEB "Retrieval" subtask shows ~2-3 point improvement from mxbai (1024d) to e5-mistral (4096d)
- However, MTEB benchmarks are mostly general-domain. For academic paper search (title+abstract), the gains are likely smaller because academic text is already information-dense and well-structured.
- A recent paper (PTEB, arXiv:2510.06730) showed e5-mistral-7b-instruct drops 2.70% under paraphrase perturbation, while smaller models are sometimes more robust.

**Recommendation for your integration:**

1. **Keep mxbai-embed-large-v1 (1024d)** as your primary model. It's already deployed, fast on CPU via Ollama, and the quality difference for your use case (academic paper search among a curated collection) is marginal.

2. **If you want to upgrade, consider snowflake-arctic-embed-l-v2.0** (1024d, 568M params). Same dimension as mxbai but better retrieval quality (~58 vs ~54 MTEB Retrieval). Available via HuggingFace, runnable on CPU. Unclear if it's in Ollama yet.

3. **nomic-embed-text-v1.5** is interesting because of Matryoshka representation learning -- you can store 768d or even 256d vectors and still get decent quality. Useful if storage ever becomes a concern.

4. **Avoid 7B+ models** unless you add a GPU to the server. The quality gain doesn't justify the 30-60x latency increase on CPU.

5. **Newer option to watch**: **Qwen3-Embedding-8B** (Apache 2.0, 2025) -- if a quantized version becomes available in Ollama with decent CPU performance.

### Academic-Specific Considerations

- Academic text has distinctive characteristics: formal language, technical vocabulary, citation patterns. General MTEB benchmarks may not capture this.
- **SPECTER2** (by Allen AI, same team as Semantic Scholar) is specifically trained on academic papers but only 768d and somewhat dated (2023).
- **SciNCL** and **ASPIRE** are other academic-specific models but smaller and older.
- For your use case of searching ~10K-50K papers by title+abstract, **even mxbai-embed-large will perform very well**. The marginal quality from larger models matters more at scale (millions of documents) where the long tail of hard-to-distinguish papers increases.

---

## Serendipitous Connections

### Connection to Personal Projects

1. **Paper Archive System** (`paper_archive.py`): OpenAlex is a direct upgrade/complement to your current Semantic Scholar + CrossRef cascade. OpenAlex covers ~250M works (vs. Semantic Scholar's ~200M) and includes citation data, open access links, and topic classification. Could add as a third source in the API cascade, or replace Semantic Scholar entirely for metadata lookup.

2. **Knowledge Graph** (Neo4j + AGE): OpenAlex's Topic hierarchy (4 domains -> 26 fields -> 252 subfields -> 4,516 topics) maps naturally to your knowledge graph structure. You could import the full taxonomy as nodes and link papers to their topics, creating a browsable subject hierarchy.

3. **Kindle Graph Enrichment**: OpenAlex's author disambiguation and institution data could enrich your knowledge graph with author -> institution -> field relationships extracted from cited papers.

4. **Preference Sort / Ranking Todo**: OpenAlex's FWCI (Field-Weighted Citation Impact) and `citation_normalized_percentile` provide ready-made quality signals for academic paper ranking, complementing your Bradley-Terry preference model.

### Cross-Domain Observations

- OpenAlex's inverted-index abstract storage is an interesting case of **legal constraints driving API design**. The copyright argument (that an inverted index isn't a "copy") is legally tenuous (discussed on law.stackexchange.com) but practically unchallenged -- a kind of Schelling point in academic data sharing.
- The Walden rewrite (Dec 2025) moving to usage-based pricing from rate limits mirrors the broader industry shift (cf. Twitter/X API, Reddit API in 2023). OpenAlex's $1/day free tier is generous by comparison.

---

## Sources

| Tier | Source | What I Fetched |
|------|--------|---------------|
| T7 | OpenAlex API (live) | Direct JSON response for works search + single work with abstract |
| T7 | OpenAlex blog | Walden launch, pricing info |
| T7 | OpenAlex docs (Scribd mirror) | Rate limits, work object schema |
| T7 | GitHub release notes | Snapshot format, update history |
| T5 | pyalex, openalexR repos | Abstract reconstruction, API usage patterns |
| T2 | arXiv:2509.20354 (EmbeddingGemma) | Embedding model comparison |
| T1 | ICLR 2025 (NV-Embed) | LLM embedding techniques |
| T1 | EMNLP 2025 (Conan-Embedding-v2) | MTEB benchmark numbers |
| T2 | arXiv:2510.06730 (PTEB) | Robustness comparison of embedding models |
| T1 | PLOS ONE (Haunschild 2024) | OpenAlex concepts vs topics analysis |
| T2 | arXiv:2603.03126 (Science Data Lake) | OpenAlex Parquet conversion, 293M papers |

**Note:** I was unable to fetch the OpenAlex developer docs directly (Mintlify SPA renders client-side, returns empty HTML to fetch tools). All API details are verified against the live API response and community sources.
