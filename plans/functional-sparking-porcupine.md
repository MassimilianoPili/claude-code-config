# Piano: Re-embedding Progressivo con Chunk Versioning

## Contesto

Il sistema di embedding (mcp-vector-tools) ora usa recursive character splitting (TextSplitter) con context enrichment. Problema: quando si migliora la strategia di chunking (parametri, separatori, context prefix), bisogna fare un full reindex manuale — cancellare `embeddings_sync`, riavviare, aspettare ~20 min.

**Obiettivo**: il job notturno (04:00, `ScheduledReindex`) deve migrare progressivamente gli embedding vecchi alla strategia corrente, senza intervento manuale. Qualità che "inesorabilmente migliora" ad ogni cambio di strategia.

**Ricerca**: nessun paper peer-reviewed su embedding migration. Consenso pratico (blog DBI Services, pgai Vectorizer, Timescale): usare **strategy version integer + content hash**, migrare **oldest-first** con batch limitato. Mixed-version search è gestibile perché il modello embedding (mxbai-embed-large) resta lo stesso — il drift viene solo da boundary diversi, non da rappresentazioni diverse.

---

## Step 1 — CHUNK_VERSION in TextSplitter

**File**: `Vari/mcp-vector-tools/.../ingest/TextSplitter.java`

Aggiungere costante:

```java
public static final int CHUNK_VERSION = 1;
```

Valore iniziale `1` (tutti gli embedding attuali sono v1 — prodotti dal nuovo recursive splitter). Incrementare manualmente quando si cambia la strategia (parametri, separatori, context enrichment).

---

## Step 2 — chunk_version in metadata dei Document

**File**: `Vari/mcp-vector-tools/.../ingest/MarkdownParser.java` (metodo `createDocument`)
**File**: `Vari/mcp-vector-tools/.../ingest/ConversationParser.java` (metodo `createDocument`)

Aggiungere a entrambi:

```java
metadata.put("chunk_version", TextSplitter.CHUNK_VERSION);
```

Backwards compatible: embedding esistenti senza `chunk_version` nel metadata jsonb → trattati come v0 (pre-semantic chunking).

---

## Step 3 — Colonna chunk_version in embeddings_sync

**File**: `Vari/mcp-vector-tools/.../ingest/SyncTracker.java`

### 3a. Schema migration in `initSchema()`

Dopo il `CREATE TABLE IF NOT EXISTS`, aggiungere:

```java
jdbc.execute("ALTER TABLE embeddings_sync ADD COLUMN IF NOT EXISTS chunk_version INTEGER DEFAULT 0");
```

Default `0` per righe preesistenti (segnala "versione sconosciuta, da migrare").

### 3b. Aggiornare `markIndexed()` per salvare la versione

```java
jdbc.update("""
    INSERT INTO embeddings_sync (file_path, last_modified, chunk_count, indexed_at, chunk_version)
    VALUES (?, ?, ?, NOW(), ?)
    ON CONFLICT (file_path) DO UPDATE
    SET last_modified = EXCLUDED.last_modified,
        chunk_count = EXCLUDED.chunk_count,
        indexed_at = NOW(),
        chunk_version = EXCLUDED.chunk_version""",
    file.toString(), Timestamp.from(fileModified), chunkCount, TextSplitter.CHUNK_VERSION);
```

### 3c. Aggiornare `needsReindex()` per controllare anche la versione

```java
public boolean needsReindex(Path file) {
    try {
        Instant fileModified = Files.getLastModifiedTime(file).toInstant();
        List<Map<String, Object>> rows = jdbc.queryForList(
            "SELECT last_modified, chunk_version FROM embeddings_sync WHERE file_path = ?",
            file.toString());

        if (rows.isEmpty()) return true;

        Timestamp lastMod = (Timestamp) rows.get(0).get("last_modified");
        Integer version = (Integer) rows.get(0).get("chunk_version");

        // Re-embed se: file modificato O versione chunking obsoleta
        if (fileModified.isAfter(lastMod.toInstant())) return true;
        if (version == null || version < TextSplitter.CHUNK_VERSION) return true;

        return false;
    } catch (Exception e) {
        log.warn("Errore check sync {}: {}", file, e.getMessage());
        return true;
    }
}
```

### 3d. Nuovo metodo `countStaleFiles()`

Per monitoraggio da `embeddings_stats`:

```java
public int countStaleFiles() {
    Integer count = jdbc.queryForObject(
        "SELECT COUNT(*) FROM embeddings_sync WHERE chunk_version < ?",
        Integer.class, TextSplitter.CHUNK_VERSION);
    return count != null ? count : 0;
}
```

### 3e. Aggiornare `getStats()` per includere versioning info

Aggiungere alla query esistente:

```java
// Dopo la query attuale, aggiungere:
public Map<String, Object> getVersionStats() {
    Map<String, Object> stats = new HashMap<>();
    stats.put("current_version", TextSplitter.CHUNK_VERSION);
    stats.put("stale_files", countStaleFiles());

    List<Map<String, Object>> byVersion = jdbc.queryForList("""
        SELECT chunk_version, COUNT(*) AS file_count, SUM(chunk_count) AS total_chunks
        FROM embeddings_sync
        GROUP BY chunk_version
        ORDER BY chunk_version""");
    stats.put("by_version", byVersion);
    return stats;
}
```

---

## Step 4 — Batch limit nel reindex notturno

**File**: `Vari/mcp-vector-tools/.../ingest/ChunkingService.java`

### Problema

Quando `CHUNK_VERSION` viene incrementato, `needsReindex()` ritorna `true` per TUTTI i file (~2500). Il reindex sincrono processerebbe tutto in un colpo — 20+ min, caricando Ollama al 100%.

### Soluzione: migration batch limit

Aggiungere un campo costante e un parametro al metodo reindex:

```java
private static final int MIGRATION_BATCH_LIMIT = 250;
```

Modificare `reindexDocs()` e `reindexConversations()` per distinguere due fasi:

```java
// Fase 1: file modificati (sempre, senza limite)
// → needsReindex() ritorna true perché fileModified > lastMod

// Fase 2: file con versione obsoleta (con limite)
// → needsReindex() ritorna true perché version < CHUNK_VERSION
// → limitare a MIGRATION_BATCH_LIMIT per run
```

Implementazione: contare separatamente i file processati per "changed" vs "version migration". Quando il contatore migration raggiunge il limite, skippare i restanti file stale (verranno processati la notte successiva).

```java
int migrationCount = 0;

for (Path file : files) {
    boolean fileChanged = isFileModified(file);  // nuovo metodo helper
    boolean versionStale = isVersionStale(file);  // nuovo metodo helper

    if (!fileChanged && !versionStale) {
        filesSkipped++;
        trackedFiles.remove(file.toString());
        continue;
    }

    // File modificati: sempre processati
    // File solo version-stale: limitati a MIGRATION_BATCH_LIMIT
    if (!fileChanged && versionStale) {
        if (migrationCount >= MIGRATION_BATCH_LIMIT) {
            filesSkipped++;
            trackedFiles.remove(file.toString());
            continue;
        }
        migrationCount++;
    }

    // ... processamento normale (removeDocuments + parse + addWithRetry + markIndexed) ...
}
```

### Helper methods in SyncTracker

```java
public boolean isFileModified(Path file) {
    // true se file mtime > last_modified in sync table
}

public boolean isVersionStale(Path file) {
    // true se chunk_version < TextSplitter.CHUNK_VERSION (ma file non modificato)
}
```

### Stima tempi migrazione

Con 250 file/notte e ~2500 file totali → **full migration in 10 notti**. Con ~2 chunk/file medio e ~5 chunk/sec su CPU → ~100 sec per batch → trascurabile nel budget notturno.

---

## Step 5 — Esporre versioning info in embeddings_stats

**File**: `Vari/mcp-vector-tools/.../tools/VectorTools.java` (o equivalente tool class)

Aggiungere alla risposta di `embeddings_stats()`:

```java
result.put("chunk_versioning", syncTracker.getVersionStats());
```

Output esempio:

```json
{
  "chunk_versioning": {
    "current_version": 2,
    "stale_files": 1875,
    "by_version": [
      {"chunk_version": 1, "file_count": 1875, "total_chunks": 4200},
      {"chunk_version": 2, "file_count": 625, "total_chunks": 1400}
    ]
  }
}
```

---

## Step 6 — Rebuild, deploy, test

1. Build libreria: `/opt/maven/bin/mvn clean install -Dgpg.skip=true` in `Vari/mcp-vector-tools/`
2. Build MCP server: `/opt/maven/bin/mvn clean install -Dgpg.skip=true` in `Vari/mcp/`
3. Deploy: `sol deploy mcp`

**Non serve full reindex**: tutti gli embedding attuali verranno marcati v0 (default della nuova colonna), e `markIndexed()` li aggiornerà a v1 man mano che vengono processati. Al primo reindex notturno dopo il deploy, i file saranno gradualmente migrati.

**Test del meccanismo**:
1. Verificare che `embeddings_stats()` mostri `chunk_versioning` con `stale_files > 0`
2. Trigger manuale: `curl -s -X POST http://localhost:8099/admin/reindex/docs`
3. Verificare che processi max 250 file version-stale
4. Verificare che `stale_files` diminuisca dopo ogni run
5. Dopo 10 notti: `stale_files == 0`

**Test futuro cambio versione**:
1. Incrementare `CHUNK_VERSION` da 1 a 2 in `TextSplitter.java`
2. Rebuild + deploy
3. Verificare che `stale_files` torni a ~2500
4. Il job notturno inizia a migrare automaticamente

---

## File da modificare

| File | Modifica |
|------|----------|
| `Vari/mcp-vector-tools/.../ingest/TextSplitter.java` | Aggiungere `CHUNK_VERSION = 1` |
| `Vari/mcp-vector-tools/.../ingest/MarkdownParser.java` | `metadata.put("chunk_version", ...)` in `createDocument()` |
| `Vari/mcp-vector-tools/.../ingest/ConversationParser.java` | `metadata.put("chunk_version", ...)` in `createDocument()` |
| `Vari/mcp-vector-tools/.../ingest/SyncTracker.java` | ALTER TABLE, `needsReindex()` version check, `countStaleFiles()`, `getVersionStats()`, helper methods |
| `Vari/mcp-vector-tools/.../ingest/ChunkingService.java` | Migration batch limit (250), split fase 1/fase 2 |
| `Vari/mcp-vector-tools/.../tools/VectorTools.java` | `embeddings_stats()` include versioning info |

## Funzioni da riusare

- `SyncTracker.needsReindex()` — estendere con version check (non riscrivere)
- `SyncTracker.markIndexed()` — estendere con chunk_version param
- `ChunkingService.addWithRetry()` — invariato
- `ChunkingService.removeDocumentsForFile()` — invariato
- `TextSplitter.CHUNK_VERSION` — unica costante da incrementare per trigger migration

## Cosa NON cambia

- Nessuna modifica allo schema `vector_store` (il metadata jsonb accetta chunk_version senza ALTER)
- Nessuna modifica alla query di ricerca semantica (chunk_version è solo metadata, non filtro di ricerca — il modello embedding è lo stesso)
- Nessuna modifica a `ScheduledReindex.java` (chiama già `reindexAsync("all")`)
- Nessuna modifica a `AdminController.java`
- Nessuna modifica a `paper_archive.py` (paper embedding sono gestiti separatamente)

## Decisione: NO version-filtered search

La ricerca suggerisce di filtrare per versione durante la ricerca. **Non lo facciamo** perché:
1. Il modello embedding (mxbai-embed-large) resta lo stesso → drift geometrico minimo
2. Sistema single-user → recall leggermente degradata per 10 notti è accettabile
3. La complessità aggiuntiva nella query non giustifica il beneficio marginale
4. Una volta completata la migrazione, il filtro sarebbe inutile

Se in futuro si cambia modello embedding (non solo strategia chunking), allora il version-filtered search diventa necessario.

---

# Idee applicabili dai Research Domains (agent-framework)

Analisi dei domini di ricerca (#78, #94, #104, #110) dalla wiki agent-framework, con validazione tramite ricerca accademica (arXiv, Semantic Scholar, blog tecnici).

## Priorità 1: Retrieval Diversity — MMR + Adaptive-k (#104 rivisitato)

**Problema**: il top-k attuale restituisce chunk ridondanti dallo stesso cluster tematico.

**Ricerca**: Information Foraging Theory (Pirolli & Card 1999) è stata recentemente applicata a RAG con risultati notevoli:

| Approccio | Fonte | Risultato |
|-----------|-------|-----------|
| **InForage** (NeurIPS 2025 Spotlight) | T1 — Qian & Liu, arXiv:2505.09316 | IFT + RL per retrieval adattivo. Prima applicazione diretta MVT→RAG |
| **CAR** (Coinbase, 2025) | T2 — Xu et al., arXiv:2511.14769 | Breakpoint detection su similarity scores. **-60% token, -22% latenza, -10% allucinazioni** |
| **MMR** (SIGIR 1998) | T1 — Carbonell & Goldstein | Standard de facto, in LangChain/Chroma/Qdrant. `λ` bilancia relevance vs diversity |
| **Lost in the Middle** (TACL 2024) | T1 — Liu et al., arXiv:2307.03172 | Dopo k=20, aggiungere documenti *peggiora* qualità. Curva a U posizionale |
| **Diversity in RAG** (2025) | T2 — Wang et al., arXiv:2502.09017 | MMR + FPS aumentano recall rispetto a top-k puro |
| **Better RAG via Info Gain** (EMNLP sub 2024) | T2 — Pickett et al., arXiv:2407.12101 | Diversità emerge organicamente senza parametri lambda |
| **DynamicRAG** (2025) | T2 — Sun et al., arXiv:2505.07233 | RL per dynamic k + reranking, SOTA su 7 dataset |
| **Adaptive-k** (EMNLP 2025) | T1 — Taguchi et al., arXiv:2506.08479 | Gap detection, fino a 10x meno token |

**Insight chiave**: CAR (breakpoint detection) è il più implementabile — algoritmo semplice, risultati misurabili, no training ML. Combinato con MMR per diversity, copre entrambi i problemi (quanti documenti + quali documenti).

**Implementazione proposta su SOL** (in `mcp-vector-tools`):

### Step A — MMR reranking nel tool di ricerca

**File**: nuovo `MmrReranker.java` (o integrato in VectorTools)

**Problema critico**: Spring AI `PgVectorStore.similaritySearch()` **NON espone i vettori embedding** — ritorna solo content + metadata + similarity score. Per MMR servono i vettori per calcolare inter-document similarity.

**Soluzione**: custom `JdbcTemplate` query che seleziona anche la colonna `embedding`:

```sql
SELECT id, content, metadata, embedding,
       1 - (embedding <=> ?::vector) AS similarity
FROM vector_store
WHERE 1 - (embedding <=> ?::vector) >= ?
  AND metadata->>'type' = ?
ORDER BY embedding <=> ?::vector
LIMIT 50
```

Poi MMR application-layer in Java (raccomandato su PL/pgSQL — debugging più facile, ~200KB transfer per 50 vettori è trascurabile su Docker localhost):

```
score(d_i) = λ · sim(d_i, query) - (1-λ) · max_{d_j ∈ selected} sim(d_i, d_j)
```

**Lambda**: `0.6` (corpus mixed: infra docs + conversations + papers — redundanza moderata). Esporre come config property (`mmr.lambda=0.6`).

| Lambda | Caso d'uso | Fonte |
|--------|-----------|-------|
| 0.4-0.5 | Alta ridondanza (news, code duplicato) | Carbonell & Goldstein 1998 (T1) |
| 0.5 | LangChain default | T7 |
| **0.6** | **Mixed corpus (SOL)** | Raccomandazione composita |
| 0.7-0.8 | Bassa ridondanza (docs diversificati) | Weaviate docs (T7) |

**Nessuno studio sistematico su lambda per RAG** — gap nella letteratura. Tuning empirico necessario.

**Effort**: ~80 righe Java (record `EmbeddedDocument`, metodo `mmrRerank()`, `cosineSimilarity()`).

### Step B — Adaptive-k stopping criterion (combined algorithm)

Tre livelli di cutoff combinati (raccomandazione composita dalla ricerca):

```java
// 1. Absolute threshold: cosine < 0.3 → skip (documenti irrilevanti)
// 2. Relative dropoff: cosine < topScore * 0.65 → skip (troppo lontani dal migliore)
// 3. Gap detection: max gap > 0.05 nell'intervallo [minK, thresholdK]
int k = adaptiveK(similarities, absoluteThreshold=0.3, relativeDropoff=0.65, minK=3, maxK=20);
```

**Pipeline**: Adaptive-k prima (quanti documenti), poi MMR (quali documenti).

**Effort**: ~40 righe Java. Config properties: `adaptive-k.absolute-threshold`, `adaptive-k.relative-dropoff`, `adaptive-k.min-k`, `adaptive-k.max-k`.

### Step B.5 — Position-aware context assembly (best-at-edges)

Mitigare "lost in the middle" (Liu et al. TACL 2024): chunk più rilevanti a **inizio e fine** del contesto.

```java
// Input:  [doc1, doc2, doc3, doc4, doc5] (ranked by MMR score)
// Output: [doc1, doc3, doc5, doc4, doc2] (best at edges, worst in middle)
```

- doc1 (più rilevante) sempre in posizione 1 (primacy bias, il più forte)
- doc pari-indicizzati alla fine in ordine inverso
- doc dispari-indicizzati all'inizio in ordine
- Effetto significativo con >5 documenti; con 3-5 l'ordine di relevance è sufficiente (Hsieh et al. 2024, T2)

**Effort**: ~15 righe Java. Costo zero — solo riordinamento array.

### Cosa NON implementare

- **DPP**: O(n³), overengineering per single-user
- **VRSD**: elegante ma richiede ristrutturazione del retrieval pipeline
- **Full MVT patch model**: InForage (NeurIPS 2025) richiede RL training — CAR + MMR coprono il caso d'uso senza training
- **Compressed Sensing (#94)**: L1-regularized reranking — troppo complesso, beneficio marginale rispetto a MMR

---

## Priorità 2: Semantic Caching (#110)

**Idea**: cacheare risposte a query semanticamente simili. Cache hit → risposta immediata senza retrieval né LLM.

**Ricerca accademica** (GPTCache ACL 2023, vCache ICLR 2026, Regmi & Pun arXiv:2411.05276, Biton & Friedman arXiv:2603.03301):

| Finding | Fonte | Dettaglio |
|---------|-------|-----------|
| **Threshold 0.95 è troppo conservativo** | T2 — Regmi & Pun | Sweep 0.60-0.90: ottimale a **0.80** per FAQ. Per single-user diversificato: **0.90** |
| **Adaptive threshold > statico** | T1 — vCache, ICLR 2026 | 12.5x hit rate, 26x meno errori. Ma complessità alta |
| **Eviction ottimale è NP-hard** | T2 — Biton & Friedman 2026 | LFU è "strong baseline". LRU + TTL sufficiente per single-user |
| **Version-stamp invalidation** | T5 — Redis blog, Brain.co | `corpus_version` counter, mismatch = miss |
| **Latenza attesa** | Composito | Cache hit: ~55ms (embed query + lookup). Miss: 2-15s (full RAG) → **36-270x speedup** |
| **Hit rate single-user** | Stima conservativa | **15-30%** (query diverse, non FAQ ripetitive) |

**Infrastruttura già presente**: pgvector + Redis. Nessuna libreria esterna necessaria.

**Implementazione proposta**:

### Step C — Tabella semantic_cache + version-stamp

```sql
CREATE TABLE semantic_cache (
    id SERIAL PRIMARY KEY,
    query_embedding vector(1024),
    query_text TEXT,
    response TEXT,
    search_type TEXT, -- 'docs' | 'conversations'
    corpus_version INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_hit_at TIMESTAMPTZ DEFAULT NOW(),
    hit_count INTEGER DEFAULT 0
);
CREATE INDEX ON semantic_cache USING ivfflat (query_embedding vector_cosine_ops) WITH (lists = 10);
```

**Nota**: IVFFlat (non HNSW) — a <1000 cache entries, sequential scan è più veloce ma IVFFlat non fa male.

### Step D — Cache lookup (threshold 0.90)

Prima di eseguire la ricerca pgvector, controllare la cache:

```sql
SELECT id, response, 1 - (query_embedding <=> $1) AS similarity
FROM semantic_cache
WHERE search_type = $2
  AND corpus_version = $current_version
  AND 1 - (query_embedding <=> $1) > 0.90
ORDER BY query_embedding <=> $1
LIMIT 1;
```

Se hit: restituire risposta cached + `UPDATE hit_count = hit_count + 1, last_hit_at = NOW()`.

**Threshold 0.90**: partire da qui, monitorare false positive per 2 settimane. Se zero FP → abbassare a 0.88. Se FP → alzare a 0.92.

### Step E — Cache invalidation (version-stamp + TTL)

Due livelli di invalidation:
1. **Version-stamp**: `corpus_version` counter (in PG o Redis). Incrementato da `ChunkingService` dopo ogni reindex. Query cache filtra per `corpus_version = current` → miss automatico per entry stale.
2. **TTL safety net**: entry > 48h → candidabili per eviction anche se version match.

### Step F — Eviction (LRU + capacity cap)

Cap a 500 entry. Quando superato:
```sql
DELETE FROM semantic_cache WHERE id IN (
    SELECT id FROM semantic_cache ORDER BY last_hit_at ASC LIMIT $excess
);
```

**Effort**: medio. ~150 righe Java. Nuovo `SemanticCacheService.java` + modifiche a `VectorTools.java`.

**Evoluzione futura**: se i dati mostrano che 0.90 statico lascia troppi false positive, considerare vCache (per-prompt adaptive threshold, arXiv:2502.03771). Ma richiede ML per-entry — valutare solo con dati empirici.

---

## Priorità 3: Dimensionality Reduction (#78) — NON implementare ora

**Ricerca accademica** (mxbai-embed-large, pgvector, MRL — Huerga-Perez et al. arXiv:2505.00105, HuggingFace benchmark):

| Strategia | Compressione | Qualità | Note |
|-----------|-------------|---------|------|
| float32 1024 (attuale) | 1x | 100% | Baseline |
| **halfvec 1024** | 2x | ~99.9% | pgvector nativo, gratis |
| MRL truncation 512 | 2x | 93-97% | mxbai supporta nativamente |
| int8 1024 | 4x | 97.1% | Testato su mxbai (HF blog) |
| PCA 50% + float8 | 8x | 95-99% | Sweet spot per volumi alti |
| Binary 1024 | 32x | 96.5% | Solo per >100K embedding |

- A ~3800 embedding, storage = 15 MB. **Nessun beneficio pratico**.
- **Matryoshka truncation è gratis** per mxbai: `embedding[:512] / norm(embedding[:512])` funziona out-of-the-box (MRL-trained).
- PCA a 50% su modelli 1024d perde solo 0.4-2% (Huerga-Perez et al. 2025) — meno dei modelli 384d.
- **Azione diagnostica futura**: PCA variance analysis sui 3800 embedding per misurare dimensionalità intrinseca per tipo (docs vs conversations vs papers).

**Decisione**: lasciare 1024 dim float32. Riconsiderare a >10K embedding (aggiungere HNSW index) o >50K (Matryoshka truncation 512).

---

## Priorità 4: Graph-Guided Vector Retrieval (futuro)

**Ricerca accademica** (Microsoft GraphRAG arXiv:2404.16130, Neo4j GraphRAG library, Pan et al. survey arXiv:2306.08302):

**Stato**: tecnica reale e validata empiricamente, non solo teorica. 4 pattern identificati:

| Pattern | Flusso | Miglioramento | Rischio |
|---------|--------|---------------|---------|
| **A. Entity-First** (Graph→Vector) | NER→match graph→traverse→vector search filtrato | +5-15% factual, +20-40% multi-hop | Miss se KG incompleto |
| **B. Vector-First, Graph-Enriched** (Vector→Graph) | Vector search→estrai entità→graph traverse→re-rank | Sicuro (non peggiora mai) | Latenza +1 query |
| **C. Parallel + RRF** (Graph‖Vector→merge) | Graph retrieval + Vector retrieval in parallelo → Reciprocal Rank Fusion | Copertura massima | Complessità |
| **D. Graph-Constrained** (graph come filtro) | Identifica regione grafo→restringe vector search a quella regione | Precision alta | Recall bassa se grafo incompleto |

**Architettura SOL vantaggiosa**: AGE + pgvector sullo **stesso PostgreSQL** — la maggior parte dei sistemi usa DB separati (Neo4j + Pinecone). Due query sequenziali sulla stessa connessione: latenza trascurabile.

**Pattern raccomandato**: **B (Vector-First, Graph-Enriched)** come default — non può peggiorare il baseline.

**Prerequisiti**:
1. Metadata linking: aggiungere `entity_names` o `graph_node_ids` ai chunk pgvector
2. Entity extraction: per dominio infra → keyword/regex (vocabolario chiuso); per dominio accademico → LLM
3. Soft boosting (non hard filtering): `final_score = vector_sim * (1 + 0.3 * graph_proximity)` — preserva recall

**Stima miglioramento**: +10-20% per query su dominio infra (entity-dense), +5% per query generiche.

**Decisione**: implementare **dopo** MMR + Semantic Caching. Richiede evaluation set (20-50 domande con risposte note).

---

## Priorità 5: Cache Hit Mining per Knowledge Graph (futuro avanzato)

**Ricerca accademica** (Lin et al. WWW 2012 — T1, Beeferman & Berger KDD 2000 — T1, Lucchese et al. ACM TOIS 2011 — T1):

**Stato**: le componenti sono scienza matura (query log mining, implicit feedback, KG completion). La **combinazione specifica** (RAG cache hits → KG enrichment) è **novel e non validata** a scala personale.

**Principio validato (T1)**: la co-occorrenza comportamentale è un proxy affidabile per relazione semantica.

| Segnale | Affidabilità | Fonte |
|---------|-------------|-------|
| Query reformulation nella stessa sessione | Molto alta | Baeza-Yates & Tiberi 2007 (T1) |
| Click su stesso documento da query diverse | Alta | Beeferman & Berger 2000 (T1) |
| Co-occorrenza query nella stessa sessione | Alta | Jones & Klinkner 2008 (T1) |
| Cache hit semantico (soglia-dipendente) | Media | Stimato |

**Volume dati minimo**: ~500-1000 query cached prima che i pattern siano significativi. ~50-100 cluster di cache hit per edge affidabili. Co-occorrenza minima: ≥3 in sessioni *diverse*.

**Architettura proposta**:
1. **Logging**: ogni query RAG → `{query_text, query_embedding, timestamp, session_id, cache_hit, cached_query_id, similarity, retrieved_chunk_ids}`
2. **Mining settimanale**: PMI (Pointwise Mutual Information) su coppie concettuali: `PMI(A,B) = log[P(A,B) / (P(A) * P(B))]`
3. **Candidati edge**: top-N coppie PMI → review umano via `rank-tui`
4. **Edge type separato**: `IMPLICITLY_RELATED` (distinto da edge espliciti)
5. **Protezione feedback loop**: run periodici blind (senza boosting KG) per dati non biased; edge decay senza rinforzo

**Rischi**:
- **Feedback loop**: KG influenza retrieval → retrieval pattern arricchisce KG → amplificazione (ben documentato nei recommender systems)
- **Basso volume dati**: false positive frequenti a scala single-user
- **Cold start**: la cache deve popolarsi prima che i pattern emergano

**Decisione**: implementare in due fasi — logging subito (costo zero), mining notturno appena la cache è operativa.

### Step G — Query logging (subito, integrato nel tool di ricerca)

Ogni query RAG → riga in `query_log`:

```sql
CREATE TABLE query_log (
    id SERIAL PRIMARY KEY,
    query_text TEXT NOT NULL,
    query_embedding vector(1024),
    search_type TEXT,           -- 'docs' | 'conversations'
    session_id TEXT,            -- se disponibile
    cache_hit BOOLEAN DEFAULT FALSE,
    cached_query_id INTEGER,    -- FK a semantic_cache.id se cache hit
    similarity FLOAT,           -- top similarity score
    retrieved_chunk_ids TEXT[],  -- array di ID chunk recuperati
    result_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX ON query_log (created_at);
CREATE INDEX ON query_log USING ivfflat (query_embedding vector_cosine_ops) WITH (lists = 10);
```

**Effort**: ~20 righe Java in `VectorTools.java` — INSERT dopo ogni ricerca.

### Step H — Mining notturno (job schedulato, dopo 500+ query)

Timer: `@Scheduled(cron = "0 30 4 * * *")` — alle 04:30, dopo il reindex embedding (04:00).

**Algoritmo**:

1. **Finestra temporale**: ultime 7 giorni di `query_log`
2. **Co-retrieval matrix**: per ogni coppia di chunk (A, B), contare quante query diverse hanno recuperato entrambi
3. **PMI filtering**: `PMI(A,B) = log[P(A,B) / (P(A) * P(B))]` — soglia PMI > 2.0 (forte associazione)
4. **Co-retrieval minimo**: ≥3 query diverse (evitare correlazioni spurie)
5. **Edge candidati**: coppie che superano entrambe le soglie
6. **Deduplicazione**: non creare edge se già esiste (esplicito o implicito) nel knowledge graph
7. **Scrittura**: `MERGE (a)-[:IMPLICITLY_RELATED {pmi: $pmi, co_count: $count, discovered_at: $ts}]->(b)` in AGE
8. **Decay**: edge impliciti non rinforzati per 30 giorni → rimossi (evita accumulo di noise)

**Volume minimo**: il job si auto-salta se `COUNT(*) FROM query_log WHERE created_at > NOW() - INTERVAL '7 days' < 50`.

**Batch limit**: max 20 nuovi edge per run (come il chunk versioning: progressivo, inesorabile).

**Protezione feedback loop**:
- Edge `IMPLICITLY_RELATED` **non** usati nel graph-guided retrieval (Pattern B) — solo per visualizzazione e discovery
- Ogni 4 settimane: run blind senza boosting KG per dati non biased
- Metrica di monitoring: rapporto edge creati/rimossi per settimana (deve tendere a stabilizzarsi)

**Effort**: ~100 righe Java. Nuovo `QueryMiningService.java` + `@Scheduled`.

### Step I — Visualizzazione e review

I nuovi edge `IMPLICITLY_RELATED` appaiono nel Knowledge Graph viewer (`notes.massimilianopili.com`) con colore distinto (es. tratteggiato grigio). L'utente può promuoverli a edge espliciti via `rank-tui` o eliminarli.

**Flusso completo**:
```
Query RAG → log → mining notturno → edge candidati → KG viewer → review umano → promozione/eliminazione
```

Il sistema impara dai pattern d'uso dell'utente senza automazione cieca. Ogni notte, il knowledge graph diventa un po' più ricco — stessa filosofia del chunk versioning progressivo.

---

## Roadmap implementativa

| Fase | Step | Effort | Impatto |
|------|------|--------|---------|
| **Già completato** | Chunk versioning (Step 1-6) | — | Migrazione progressiva ✅ |
| **Prossimo** | A+B+B.5: MMR + Adaptive-k + best-at-edges | Basso (~135 righe) | Elimina ridondanza, retrieval adattivo, posizionamento ottimale |
| **Dopo** | C-F: Semantic Caching | Medio (~150 righe) | Latenza zero per query ripetitive |
| **Futuro** | Graph-Guided Retrieval (Pattern B) | Medio (~200 righe) | +10-20% precision dominio infra |
| **Con caching** | G: Query logging | Triviale (~20 righe) | Prerequisito per mining |
| **Dopo 500 query** | H+I: Mining notturno + review | Medio (~100 righe) | Serendipity engine — KG si arricchisce ogni notte |
| **Ogni fase** | Aggiornamento documentazione | Basso | Allineamento MEMORY.md, CLAUDE.md, AGE, WikiJS |
| **Non ora** | Dimensionality reduction | — | Non necessario a questa scala |

## Principio architetturale: Inesorabilità

Il pattern unificante di questo piano è l'**inesorabilità**: job notturni che progressivamente e automaticamente migliorano la qualità del sistema, senza intervento manuale. Ogni notte, il sistema diventa un po' migliore.

| Job notturno | Cosa migliora | Velocità |
|-------------|--------------|----------|
| **Chunk versioning** (04:00) | Qualità embedding — migra 250 file/notte alla strategia corrente | ~10 notti per full migration |
| **Reindex** (04:00) | Copertura — indicizza file nuovi/modificati | Continuo |
| **Query mining** (04:30) | Knowledge graph — scopre relazioni implicite dai pattern d'uso | Progressivo, dopo 500+ query |
| **Cache decay** (integrato) | Pulizia — rimuove edge impliciti non rinforzati dopo 30 giorni | Continuo |
| **Paper archive scan** (ogni 6h) | Archivio accademico — scansiona wiki per nuove citazioni | Continuo |

Il principio: **non chiedere all'utente di fare nulla**. Incrementare `CHUNK_VERSION`? Il sistema migra. Nuovi documenti? Il sistema indicizza. Pattern d'uso ricorrenti? Il sistema li scopre. L'unica cosa che migliora col tempo senza costo è un sistema che migliora da solo.

**TODO post-plan-mode**: creare memory file `feedback_inesorabilita.md` con questo principio.

### Inventario completo job notturni/periodici (esistenti + pianificati)

#### Esistenti (operativi)

| Job | Tipo | Schedule | File/Config | Cosa fa |
|-----|------|----------|-------------|---------|
| **restic backup** | cron system | `0 3 * * *` (03:00) | crontab root | Backup completo /data/massimiliano |
| **infra-graph-sync** | systemd timer | `0 3:30 * * *` (03:30) | `infra-graph-sync.timer` | Sync infra → AGE knowledge_graph |
| **ScheduledReindex** | Spring @Scheduled | `0 0 4 * * *` (04:00) | `ScheduledReindex.java` | Reindex embedding: file modificati + migration versione (max 250) |
| **paper-archive-scan** | systemd timer | ogni 6h | `paper-archive-scan.timer` | Scansiona wiki per nuove citazioni → WikiJS + AGE + pgvector |
| **claude-cleanup** | systemd timer | ogni 30min | `claude-cleanup.service` | Pulizia file temporanei Claude Code |
| **tailscale-watchdog** | systemd timer | ogni 5min | system-level | Healthcheck Tailscale, escalation graduale |
| **docs-sync** | script manuale/cron | ogni 30min (WikiJS git sync) | `docs-sync` | Sync docs/ → Gitea → WikiJS |

#### Pianificati (da implementare)

| Job | Tipo | Schedule proposto | Dipendenze | Cosa fa |
|-----|------|-------------------|------------|---------|
| **QueryMiningService** | Spring @Scheduled | `0 30 4 * * *` (04:30) | Dopo ScheduledReindex | PMI mining su query_log → edge `IMPLICITLY_RELATED` in AGE (max 20 edge/run) |
| **Cache decay** | Spring @Scheduled | `0 0 5 * * *` (05:00) | Dopo mining | Rimuovi edge impliciti non rinforzati >30 giorni + cache entries >48h TTL |
| **Cache eviction** | In-line (non scheduled) | Ad ogni write | Semantic cache operativa | LRU eviction se cache > 500 entry |

#### Timeline notturna completa

```
03:00  restic backup (system)
03:30  infra-graph-sync (systemd) — sync infrastruttura → AGE
04:00  ScheduledReindex (Spring) — embedding: file modificati + migration versione
04:30  QueryMiningService (Spring) — PMI mining → edge impliciti KG [NUOVO]
05:00  Cache decay (Spring) — pulizia edge stale + cache TTL [NUOVO]
```

#### Timer periodici

```
ogni 5min   tailscale-watchdog (system)
ogni 30min  claude-cleanup (systemd user)
ogni 30min  docs-sync / WikiJS git sync
ogni 6h     paper-archive-scan (systemd)
```

**Principio di non-conflitto**: nessun job CPU-intensive (Ollama embedding, AGE write) nella stessa finestra temporale. Il reindex (04:00, usa Ollama) deve completare prima del mining (04:30, usa solo SQL). Il backup (03:00) non tocca DB attivi.

## File da modificare (prossimi step — MMR + Adaptive-k)

| File | Modifica |
|------|----------|
| `Vari/mcp-vector-tools/.../tools/VectorTools.java` | Custom JdbcTemplate query con embedding, integrazione MMR + Adaptive-k |
| `Vari/mcp-vector-tools/.../search/MmrReranker.java` (nuovo) | `EmbeddedDocument` record, `fetchCandidates()`, `mmrRerank()`, `adaptiveK()`, `bestAtEdges()`, `cosineSimilarity()` |
| `Vari/mcp-vector-tools/.../VectorProperties.java` | Config properties: `mmr.lambda`, `mmr.candidate-count`, `adaptive-k.*` |

## File da modificare (semantic caching — fase successiva)

| File | Modifica |
|------|----------|
| `Vari/mcp-vector-tools/.../search/SemanticCacheService.java` (nuovo) | Cache CRUD, lookup, invalidation, eviction |
| `Vari/mcp-vector-tools/.../ingest/SyncTracker.java` | `initSchema()`: CREATE TABLE semantic_cache |
| `Vari/mcp-vector-tools/.../tools/VectorTools.java` | Cache lookup prima di search, cache store dopo search |

## Fonti accademiche

### Information Foraging & Retrieval Diversity (#104)
- **InForage** — Qian & Liu, NeurIPS 2025 Spotlight, arXiv:2505.09316 — IFT + RL per retrieval adattivo (T1)
- **CAR** — Xu et al., arXiv:2511.14769 — Cluster-based Adaptive Retrieval, -60% token, -22% latenza (T2)
- **Lost in the Middle** — Liu et al., TACL 2024, arXiv:2307.03172 — k>20 peggiora qualità (T1)
- **Diversity in RAG** — Wang et al., arXiv:2502.09017 — MMR+FPS > top-k (T2)
- **Better RAG via Info Gain** — Pickett et al., arXiv:2407.12101 — diversità senza parametri (T2)
- **DynamicRAG** — Sun et al., arXiv:2505.07233 — RL per dynamic k (T2)
- **Self-RAG** — Asai et al., ICLR 2024, arXiv:2310.11511 — reflection tokens (T1)
- **FLARE** — Jiang et al., EMNLP 2023 — active retrieval on low-confidence tokens (T1)
- Carbonell & Goldstein, "MMR" (SIGIR 1998) — T1
- Taguchi et al., "Adaptive-k" (EMNLP 2025, arXiv:2506.08479) — T1, codice disponibile

### Semantic Caching (#110)
- **vCache** — Schroeder et al., ICLR 2026, arXiv:2502.03771 — adaptive threshold, 12.5x hit rate (T1)
- **GPTCache** — Fu Bang, ACL NLP-OSS 2023 — primo framework open-source (T1)
- **GPT Semantic Cache** — Regmi & Pun, arXiv:2411.05276 — sweep threshold 0.60-0.90, ottimale 0.80 (T2)
- **Krites** — Singh et al., arXiv:2602.13165 — async LLM-verified caching (T2)
- **Semantic Caching Eviction** — Biton & Friedman, arXiv:2603.03301 — NP-hardness, LFU baseline (T2)
- **RAGCache** — Jin et al., ACM TCS 2024, arXiv:2404.12457 — KV-state caching, 4x TTFT (T1)

### Information Bottleneck & Dimensionality (#78)
- **Matryoshka Representation Learning** — Kusupati et al., NeurIPS 2022, arXiv:2205.13147 (T1)
- **Embedding Storage Optimization** — Huerga-Perez et al., arXiv:2505.00105 — PCA+quantization benchmark (T2)
- **Beyond Matryoshka (CSR)** — Wen et al., ICML 2025, arXiv:2503.01776 — sparse coding > MRL (T2)
- **Information-Ordered Bottlenecks** — Ho et al., arXiv:2305.11213 — IB-derived compression (T2)
- Benchmark quantization mxbai: HuggingFace blog "Binary and Scalar Embedding Quantization" — T5

### Graph-Guided Retrieval (Priorità 4)
- **Microsoft GraphRAG** — Edge et al., arXiv:2404.16130 — Local+Global search, community detection (T2)
- **LLMs + KG survey** — Pan et al., arXiv:2306.08302 — landscape completo (T2)
- **Reciprocal Rank Fusion** — Cormack, Clarke, Butt, SIGIR 2009 — score fusion (T1)

### Cache Hit Mining / Query Log Mining (Priorità 5)
- **Search Logs → KG Construction** — Lin et al., WWW 2012, Microsoft — entity relatedness da Bing logs (T1)
- **Query Clustering** — Beeferman & Berger, KDD 2000 — click co-occurrence = semantic similarity (T1)
- **Session-Based Task Discovery** — Lucchese et al., ACM TOIS 2011 — query grouping per task (T1)
- **Query Similarity by Interaction** — Baeza-Yates & Tiberi, SIGIR 2007 — session co-occurrence (T1)
- **PMI ≈ word2vec** — Levy & Goldberg, NIPS 2014 — skip-gram fattorizza matrice PMI (T1)

### MMR Implementation & Adaptive-k
- **MMR originale** — Carbonell & Goldstein, SIGIR 1998 (~4000 citazioni) — formula λ-weighted (T1)
- **Ranking Free RAG** — arXiv:2505.16014 — elbow detection su similarity score per adaptive-k (T2)
- **Kneedle algorithm** — Satopaa et al., ICDCS Workshop 2011 — knee/elbow detection (T1)
- **Serial Position Effect** — Murdock, JEPLMC 1962 — primacy + recency in human memory (T1)
- **Vendi-RAG** — +4.2% HotpotQA con metrica diversità principled (T2)
- **MECW** — Paulsen 2024 — Maximum Effective Context Window è 10-20x più piccolo del nominale (T2)

### Lost in the Middle
- **Lost in the Middle** — Liu et al., TACL 2024, arXiv:2307.03172 — U-shaped, ~20% gap (T1)
- **Menschikov et al. 2025** — effetto persiste in GPT-4o, Claude 3.5, Gemini 1.5 Pro, Llama 3.1 (~8-15% gap ridotto ma non eliminato) (T2)
- **Hsieh et al. 2024** — sandwich ordering significativo solo con >5 documenti (T2)
- **ChatQA 2** — ICLR 2025 — oltre top-30 chunk i ritorni sono piatti o negativi (T2)

### Source Routing & Multi-Index RAG
- **MultiRAG** — ICDE 2025 — multi-index per fonti eterogenee (T2)
- **DeepSieve** — EACL 2026 — filtraggio iterativo multi-source (T2)
- **Enterprise Hybrid Retrieval** — Rao et al. — fino a +80% su fonti eterogenee (Jira/Git/Confluence) (T7)
- **Azzopardi & Roegiest** — arXiv:2601.12544 — foraging theory aggiornata per RAG era (T2)
- **Louis et al.** — COLING 2025 — fusion non sempre batte single retriever (caveat importante) (T2)
- **RRF** — Cormack et al., SIGIR 2009 — score-distribution agnostic, ideale per multi-source (T1)

### Altre
- Moore, "Optimal Foraging in Memory Retrieval" (arXiv:2511.12759) — T2, MVT validato in embedding spaces
- **Domain-Specific Embeddings for Caching** — Gill et al., Redis + Virginia Tech, arXiv:2504.02268 — embedding fine-tuned batte general-purpose per caching (T2)
- **Ensemble Embedding** — Ghaffari et al., arXiv:2507.07061 — 92% hit, multi-model consensus riduce false positive (T2)
- **Generative Caching** — Chakraborty et al., arXiv:2511.17565 — 83% hit, adatta risposte cached a variazioni (T2)
- **RAC: Relation-Aware Eviction** — Wu et al., arXiv:2602.21547 — topical prevalence + structural importance, +20-30% hit vs LRU (T2)
- **Security in Semantic Caching** — Nature Scientific Reports, Feb 2026 — query adversariali estraggono risposte cached (solo multi-tenant)

---

## Nozioni aggiuntive dalla ricerca

### Connessioni cross-progetto

1. **MVT ↔ Bradley-Terry** (Preference Sort): la selezione "prey" nel Diet Model è strutturalmente isomorfa alla selezione coppie nel ranking. Entrambi massimizzano informazione condizionale con budget limitato. L'information gain di Pickett et al. (2024) è correlato al criterio di selezione coppie nel Bradley-Terry.

2. **Embedding patch structure ↔ Knowledge Graph**: se gli embedding mxbai formano cluster semantici naturali (confermato da arXiv:2511.12759), questi corrispondono ai cluster tematici in Neo4j/AGE. Retrieval ibrido: **usare la topologia del grafo come "information scent" macro-livello** per guidare la ricerca vettoriale.

3. **CAR breakpoint ↔ Change-point detection**: il metodo CAR (gap detection su similarity score ordinati) è matematicamente correlato a CUSUM/changepoint bayesiano — stesse tecniche di anomaly detection e phase transition detection.

4. **Cache hit patterns ↔ Knowledge Graph**: le query frequentemente cached rivelano cluster concettuali usati insieme. Mining dei pattern di cache hit può scoprire link impliciti per il grafo Neo4j — costruzione implicita del grafo da dati d'uso.

5. **Eviction NP-hard ↔ euristiche semplici**: Biton & Friedman (2026) dimostrano che l'eviction ottimale semantica è NP-hard. Questo giustifica formalmente l'uso di LRU+TTL senza overhead algoritmico.

6. **Lost in the middle ↔ Serial Position Effect** (Murdock 1962): la curva a U dell'attenzione LLM sui documenti in contesto ricalca il primacy+recency effect nella memoria umana. Non è coincidenza — i pattern di attenzione transformer codificano le stesse regolarità statistiche del testo naturale. Il fix (best-at-edges) è la stessa strategia di un buon insegnante: conclusione prima, evidenze nel mezzo, riassunto alla fine.

7. **Co-retrieval graph ↔ Co-citation analysis** (Small & Griffith 1974): documenti recuperati insieme = documenti citati insieme. Lo stesso principio che ha fondato la bibliometria si applica ai log RAG. PMI su coppie co-retrieved è isomorfo a collaborative filtering ("also bought").

8. **Adaptive-k ↔ Rate-distortion theory**: il "breakpoint naturale" negli score è correlato a diminishing information gain. C'è un ammontare ottimale di contesto dato un context window fisso (capacità del canale). Derivare adaptive-k da primi principi information-theorici è una potenziale direzione di ricerca.

9. **Graph-guided retrieval ↔ Agent COBOL** (progetto futuro): entity-enriched RAG è direttamente applicabile: grafo di programmi, copybook, data item, call relationships. Query su un data item → graph traversal trova tutti i programmi referenzianti → vector search trova documentazione pertinente.

### Finding chiave dalle ultime ricerche

**Spring AI NON ha MMR built-in** (verificato su sorgente `PgVectorStore.java`). Il `DocumentRowMapper` non restituisce mai il vettore embedding — solo id, content, metadata, distance. Tutti i vector store (FAISS, Chroma, Qdrant, Weaviate, LangChain) implementano MMR client-side. Default ratio: `fetch_k:k = 5:1`. Soluzione: custom JdbcTemplate query con `embedding` nella SELECT.

**Lost in the middle persiste nei modelli 2025** (Menschikov et al.): GPT-4o, Claude 3.5, Gemini 1.5 Pro, Llama 3.1 mostrano ancora l'effetto (~8-15% gap, ridotto da ~20% ma non eliminato). Sandwich ordering: +3-8% over naive descending. Significativo solo con >5 documenti.

**MECW (Maximum Effective Context Window)** è 10-20x più piccolo del nominale (Paulsen 2024). Un context window da 200K token non significa riempire 200K. Sweet spot: 5-10K token di chunk ad alta qualità, diverse e sandwich-ordered, batte 50K token di "tutto ciò che trovi".

**Fill ratio ottimale: 30-50%** del context nominale. 10-20 chunk da ~500 token. Oltre top-30 chunk, ritorni piatti o negativi (ChatQA 2, ICLR 2025).

**Source routing senza ML**: per 3 source types (docs/conversations/papers) su stesso pgvector, keyword heuristics sufficienti. Alternativa zero-training: embedding prototype classifier (media embedding per tipo → cosine con query embedding). **RRF score-distribution agnostic** — non serve normalizzare score tra source types. **Caveat critico**: Louis et al. (COLING 2025) — fusion non sempre batte un singolo buon retriever. Mantenere sempre un baseline.

**Source weight learning ↔ Bradley-Terry**: calibrare i pesi delle fonti è strutturalmente identico a preference learning. L'infrastruttura Preference Sort esistente potrebbe essere riusata per calibrare empiricamente quale source type è più prezioso per quale tipo di query.

### Tecniche avanzate da monitorare (non implementare)

| Tecnica | Paper | Perché interessante | Perché NON ora |
|---------|-------|--------------------|--------------------|
| **vCache** (adaptive threshold) | ICLR 2026, arXiv:2502.03771 | Per-prompt threshold batte qualsiasi statico 12.5x | Richiede ML per-entry, overengineering single-user |
| **CSR** (sparse coding per embedding) | ICML 2025, arXiv:2503.01776 | Batte MRL senza retraining, 7x speedup | Utile solo a >10K embedding |
| **Generative Caching** | arXiv:2511.17565 | Adatta risposte cached a variazioni context | Complessità non giustificata per single-user |
| **Krites tiered cache** | arXiv:2602.13165 | Static (curated) + dynamic tiers, LLM-judge async | 3.9x coverage ma complessità multi-tier eccessiva |
| **RAC eviction** | arXiv:2602.21547 | +20-30% hit ratio, topical prevalence | Progettato per multi-tenant ad alto throughput |
| **FLARE active retrieval** | EMNLP 2023, arXiv:2305.06983 | Retrieve solo su token a bassa confidenza | Richiede accesso al processo generativo del LLM |
| **Self-RAG reflection tokens** | ICLR 2024, arXiv:2310.11511 | Decide autonomamente se/quando retrievare | Richiede fine-tuning del modello |
| **Ensemble embeddings** | arXiv:2507.07061 | Multi-model consensus riduce false positive cache | Overhead doppio embedding non giustificato a questa scala |

### Pattern di invalidazione cache per RAG (gap nella letteratura)

Nessun paper affronta direttamente l'invalidazione di cache RAG quando il corpus cambia. 4 pattern ingegneristici identificati:

| Pattern | Complessità | Precisione | Adatto a SOL? |
|---------|------------|------------|---------------|
| **A. TTL-based** | Triviale | Bassa (stale fino a max_age) | Sì, come fallback |
| **B. Corpus-version tag** | Bassa | Media (invalida tutto al reindex) | **Sì, raccomandato** |
| **C. Document-fingerprint** | Media | Alta (invalida solo entry con doc modificati) | Futuro, se serve precisione |
| **D. Stale-while-revalidate** | Alta | Alta (serve subito, verifica async) | No, troppo complesso |

**Scelta per SOL**: Pattern B (corpus-version) + TTL 7d come safety net. Il `ScheduledReindex` incrementa un contatore dopo ogni run. Cache entry con versione precedente → miss.

### Threshold per caching: calibrazione empirica

| Threshold | Hit rate atteso | Precision | Tradeoff |
|-----------|----------------|-----------|----------|
| 0.98 | ~5-10% | ~100% | Quasi inutile — troppo conservativo |
| 0.95 | ~15-25% | >99% | Conservativo, cattura solo riformulazioni esatte |
| 0.90 | ~30-50% | >97% | **Sweet spot per single-user** |
| 0.85 | ~50-70% | ~93% | Rischio false positive su query correlate |
| 0.80 | ~60-80% | ~90% | Aggressivo, OK per FAQ ma rischioso per RAG |

Dati: Regmi & Pun (arXiv:2411.05276), sweep 0.60-0.90 su 2000 query. **Raccomandazione**: partire con **0.90**, monitorare false positive, abbassare se hit rate troppo basso.

### Nota: cosine similarity in 1024 dimensioni

In spazi ad alta dimensionalità (1024d), i vettori tendono a essere più uniformemente distribuiti. La differenza tra 0.90 e 0.95 è **più significativa** di quanto l'intuizione 2D/3D suggerisca. Il range "interessante" di cosine similarity è compresso — la maggior parte delle coppie random cade tra 0.0 e 0.3. Quindi 0.90 è già molto stretto in termini assoluti.

---

## Aggiornamento documentazione (dopo ogni fase)

Dopo il completamento di ogni fase implementativa, aggiornare **tutti** i layer di documentazione per mantenerli allineati.

### Documenti da aggiornare

| Documento | Path | Cosa aggiornare |
|-----------|------|----------------|
| **MEMORY.md** | `~/.claude/projects/-data-massimiliano/memory/MEMORY.md` | Sezione "Embeddings" con nuove feature (MMR, adaptive-k, cache, mining) |
| **Memory: inesorabilità** | `~/.claude/projects/-data-massimiliano/memory/feedback_inesorabilita.md` | **NUOVO** — principio architetturale, inventario job notturni |
| **CLAUDE.md** | `/data/massimiliano/CLAUDE.md` | Sezione servizi individuali: nuovi tool MCP, nuove tabelle PG |
| **AGE knowledge_graph** | `embeddings` DB, graph `knowledge_graph` | Nodi: `DockerService(simoge-mcp)` aggiornato con nuove capability. Nuovi nodi `Convention` per MMR, adaptive-k, semantic cache |
| **pgvector embeddings** | `embeddings` DB, tabella `vector_store` | Re-embed dei docs aggiornati (automatico via ScheduledReindex) |
| **WikiJS** | `wiki.massimilianopili.com` | Pagine docs aggiornate via `docs-sync` (automatico se docs/ modificati) |
| **Swagger/OpenAPI** | `/data/massimiliano/proxy/home/docs/` | Se nuovi endpoint REST esposti |

### Checklist per ogni fase

```
□ Codice implementato e testato
□ MEMORY.md aggiornato (sezione Embeddings)
□ CLAUDE.md aggiornato (se nuovi servizi/porte/tool)
□ Memory file creati (se nuovi concetti da ricordare)
□ AGE nodi aggiornati (import_infrastructure.py --service mcp --quiet)
□ docs/ aggiornati (se nuova documentazione operativa)
□ Commit + deploy
□ Verifica post-deploy (embeddings_stats, tool MCP funzionanti)
```

### Aggiornamenti specifici per fase

#### Dopo MMR + Adaptive-k (Priorità 1)
- MEMORY.md: aggiungere sotto "Embeddings" → "Retrieval: MMR reranking (λ=0.6), adaptive-k (gap detection), best-at-edges ordering"
- MEMORY.md: creare `feedback_inesorabilita.md`
- CLAUDE.md: aggiungere parametri config (`mmr.lambda`, `adaptive-k.*`) nella sezione mcp-vector-tools
- AGE: `import_infrastructure.py` per aggiornare nodo simoge-mcp

#### Dopo Semantic Caching (Priorità 2)
- MEMORY.md: aggiungere sotto "Embeddings" → "Semantic cache: threshold 0.90, corpus-version invalidation, LRU 500 entry"
- CLAUDE.md: nuova tabella `semantic_cache` nella sezione PostgreSQL
- AGE: nuovo nodo `Database(semantic_cache)` con edge a `DockerService(simoge-mcp)`

#### Dopo Query Logging + Mining (Priorità 5)
- MEMORY.md: aggiungere sotto "Embeddings" → "Query mining: PMI notturno (04:30), edge IMPLICITLY_RELATED, decay 30d"
- CLAUDE.md: nuova tabella `query_log`, nuovo job notturno nella sezione operazioni
- AGE: nodo `Convention(query-mining)` con procedura operativa
- Memory file dedicato se emergono pattern significativi dal mining

### Principio: documentazione come codice

La documentazione segue lo stesso ciclo del codice: modifica → commit → deploy → sync automatico. Non è un afterthought — è parte della definizione di "done" per ogni fase.

I layer automatici (AGE sync, WikiJS git sync, embedding reindex) riducono il lavoro manuale: basta aggiornare i file sorgente (MEMORY.md, CLAUDE.md, docs/) e i job notturni propagano le modifiche a graph e vector store.
