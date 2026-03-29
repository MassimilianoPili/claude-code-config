# OpenAlex S4 Pipeline: Download 7M Papers + Fix Import

## Context

S2 download (>1000 citations, 174K papers) is complete on `/mnt/hdd/openalex/` as JSONL.
S2 import to AGE **failed** — all 4 parallel domain imports were killed (SIGTERM) during
entity node creation, which is the critical bottleneck (~3h for 78K nodes, would take weeks at S4 scale).
S4 download (>100 citations, ~7M papers) was never started.

**Root cause**: `execute_age()` runs one Cypher MERGE per PostgreSQL transaction (autocommit).
Entity nodes are accumulated in memory then flushed in a single giant batch at end of Pass 1.
For physics (189K entities), this takes 3+ hours and was killed before completing.

**Numbers:**

| Domain | S2 JSONL (done) | S4 estimated |
|--------|----------------|--------------|
| CS | 60,336 | ~2.3M |
| Economics | 37,223 | ~1.8M |
| Math | 41,633 | ~1.5M |
| Physics | 35,554 | ~1.4M |
| **Total** | **174,746** | **~7M** |

Resources: 3.4 TB free `/mnt/hdd`, 16 GB RAM, gaia GPU for embeddings.

## Phase 1: Fix Import Performance (do first)

### 1.1 Transaction batching in `execute_age()` (~20 lines)

**File**: `kindle/paper_archive.py (shared module, used by openalex via PYTHONPATH)` lines 840-898

Current: autocommit, one `cur.execute(sql)` per statement → 1 transaction per MERGE.
Fix: wrap batches of 500 statements in a single `BEGIN...COMMIT` transaction.

```python
# In _execute_age_direct(), change from per-statement autocommit to:
for batch in chunks(statements, 500):
    for stmt in batch:
        cur.execute(sql)
    conn.commit()
```

Expected speedup: **10-50x** on entity creation (from 3h to ~5-10 min for 189K nodes).

### 1.2 Stream entity nodes during Pass 1 scan (~40 lines)

**File**: `openalex/openalex_import.py` lines 178-214

Current: accumulates ALL entity MERGE statements in `entity_stmts` list, flushes once after scan.
Fix: flush entity batches inline during the scan, same as paper_stmts already does.

- Keep dedup sets (author names, venue keys, topic IDs, institution IDs) to avoid duplicate MERGEs
- When entity batch hits `STREAM_BATCH` (500), flush to DB immediately
- No more monolithic entity creation phase

### 1.3 Add AGE property indexes (~5 SQL statements)

Create indexes on MERGE lookup keys to speed up the "does this node exist?" check:

```sql
-- On AGE vertex tables in knowledge_graph
CREATE INDEX IF NOT EXISTS idx_paper_archival ON "knowledge_graph"."Paper" (properties->>'archival_id');
CREATE INDEX IF NOT EXISTS idx_author_name ON "knowledge_graph"."Author" (properties->>'name');
CREATE INDEX IF NOT EXISTS idx_venue_name ON "knowledge_graph"."Venue" (properties->>'name');
CREATE INDEX IF NOT EXISTS idx_topic_oaid ON "knowledge_graph"."Topic" (properties->>'openalex_id');
CREATE INDEX IF NOT EXISTS idx_inst_oaid ON "knowledge_graph"."Institution" (properties->>'openalex_id');
```

### 1.4 Run S2 import — SEQUENTIAL, one domain at a time

**No parallel imports** (previous 4-in-parallel caused DB contention + 13.67 load average).

```bash
openalex-import --jsonl /mnt/hdd/openalex/economics.jsonl --skip-cites   # smallest first
openalex-import --jsonl /mnt/hdd/openalex/physics.jsonl --skip-cites
openalex-import --jsonl /mnt/hdd/openalex/math.jsonl --skip-cites
openalex-import --jsonl /mnt/hdd/openalex/cs.jsonl --skip-cites          # largest last
```

Estimated time after fixes: **~30-60 min total** (down from impossible).

## Phase 2: S4 Download (~7M papers)

### 2.1 Cache partition plans to disk

**File**: `openalex/openalex_download.py`

The partition computation (year→week→citation-range) requires hundreds of API count queries
and takes ~30 min per domain. Cache the result to a JSON file:

```
/mnt/hdd/openalex/.partition_cache_s4_{domain}.json
```

On subsequent runs, load from cache if <24h old. Add `--recalc-partitions` flag to force.

### 2.2 Download directly to JSONL (not individual JSON files)

For S4 scale, 7M individual `.json` files = 7M inodes on HDD = extremely slow.
Add `--format jsonl` flag (default for tiers with >100K expected papers).
Append to `{domain}.jsonl`, dedup by OpenAlex ID via companion `.ids` set file.

### 2.3 Run S4 download with nohup

```bash
nohup openalex-download --tier s4 --domains all --format jsonl &
```

Estimated: ~10h for all domains at 200 papers/sec. ~70 GB JSONL data on HDD.

## Phase 3: S4 Import

### 3.1 Add checkpoint/resumability to import

**File**: `openalex/openalex_import.py`

Write checkpoint every 10K papers:
```
/mnt/hdd/openalex/.import_checkpoint_{domain}.json
```

On restart with `--resume`, seek to last checkpoint position. MERGE is idempotent so
partial re-imports are safe (just slow).

### 3.2 Run S4 import sequentially

One domain at a time, nohup. Estimated ~12-20 hours total with transaction batching + indexes.

## Phase 4: Embedding + Verification

```bash
openalex-embed --input /mnt/hdd/openalex    # checkpoint-based, resumable
```

Verify: `graph_stats(backend="age")`, `embeddings_stats`, `openalex-download --stats`.

## Critical Files

| File | Changes |
|------|---------|
| `kindle/paper_archive.py (shared module, used by openalex via PYTHONPATH)` :840 | Transaction batching in `execute_age()` |
| `openalex/openalex_import.py` :92-216 | Stream entity nodes inline, remove monolithic flush |
| `openalex/openalex_download.py` | Partition caching, JSONL output mode |
| `postgres/init/` or SQL directly | AGE property indexes |

## Implementation Order

1. Fix `execute_age()` transaction batching (biggest bang: 10-50x speedup)
2. Add AGE indexes (quick SQL, big impact on MERGE lookups)
3. Stream entity nodes in import Pass 1
4. Test with economics.jsonl (smallest domain, 37K papers)
5. Run full S2 import sequentially
6. Add partition caching to download
7. Add JSONL output mode to download
8. Start S4 download (background, ~10h)
9. Add checkpoint to import
10. Run S4 import (background, ~12-20h)

## Design Decisions

1. **Sequential imports, not parallel**: Previous 4-in-parallel caused load 13.67 + DB contention + all killed.
2. **Transaction batching**: Single biggest fix — autocommit per MERGE is the root cause of 3h entity creation.
3. **Skip CITES**: Billions of extra edges at S4 scale. Add later as targeted batch job.
4. **JSONL over individual JSON**: 7M inodes on HDD is a non-starter. JSONL = sequential I/O.
5. **Partition caching**: 30 min of API count queries per domain is unacceptable for restarts.
6. **S4 supersedes S2/S3**: No need for separate tiers on disk. S4 includes all higher-citation papers.
