# Piano: KORE-GC — Da Baseline ad arXiv

## Context

Paper accademico sul pruning transazionale per knowledge store graph+vector co-locati.
Gap verificato (9/10): zero paper sull'intersezione. KORE (AGE + pgvector su PG18) è unico per co-locazione ACID.
Fase 1 (diagnostica) completata. Research complete (6 report, ~100 paper). Outline: 268 righe.
**Target**: arXiv preprint → VLDB 2027 Experiments track (~Mar 2027).

## Completato

- ✅ Ricerca: 6 report in `docs/papers/kore-gc/research/01-06*.md`
- ✅ Paper outline: `docs/papers/kore-gc/paper/outline.md` (268 righe)
- ✅ `kindle/kore_health.py` + wrapper + timer domenica 04:00 + ScheduledJob in KORE
- ✅ Primo report: CSCS=0.99, 50845 nodi, 136964 edges, 400676 embeddings
- ✅ Gap re-verification (Mar 23): CONFERMATO 9/10 — zero paper sull'intersezione
- ✅ Rationalist/meta-science research: 6 angoli, 15 nuovi paper, 10 action items

## Nuovi risultati ricerca (questa sessione)

### Gap re-verification: CONFERMATO 9/10
15 ricerche eseguite. Terminologia "neural materialized view", "cross-store consistency", "transactional GC" → zero risultati.
5 nuovi paper per Related Work (nessuno minaccia novelty):
- **CraniMem** (2026): agent memory pruning, no DB-level, no formalism
- **Annam** (2026): misura RAG freshness degradation, no soluzione (CITARE come evidenza problema)
- **euRAG** (2025): chunk-level update, no graph, no GC
- **Mem0** (2025, ECAI, 201 cit): graph-based memory consolidation, no transactional guarantees
- **Samyama** (2026): unified graph-vector DB (Rust), ma solo query/indexing, zero maintenance

**Claim da riformulare**: non "primi a costruire unified store" ma "primi a formalizzare e risolvere il maintenance problem"

### Rationalist/neuroscience: 6 angoli per rafforzare il paper
| Angolo | Dove | Fonti | Tipo |
|--------|------|-------|------|
| A: Generational = Lindy Effect | Sec 2.3 | Ord 2023 (arXiv, prova formale) | A-citable |
| B: GC = Memory Consolidation (CLS) | Discussion | McClelland+ 1995 (T1, 4800 cit) | A-citable |
| C: Inesorabilità = Synaptic Homeostasis | Discussion | Tononi & Cirelli 2014 (T1, 2500 cit) | A-citable |
| D: Budget = Rational Inattention | Sec 4.2 | Sims 2003 (T1, Nobel, 3500 cit) | A-citable |
| E: Active Forgetting migliora qualità | Experiments | Peng+ 2021, Sanati+ 2025 | A-citable |
| F: Spaced Repetition scheduling | Future Work | Gwern synthesis, Ebbinghaus 1885 | B-framing |

### Meta-science: 10 azioni per bulletproofing
1. **HIGH**: Sec 3 → 2pp (non 3), proof sketch, full proof in arXiv extended
2. **HIGH**: "duality/adjunction" nel paper, "Galois connection" solo in appendice formale
3. **HIGH**: Aggiungere Samyama a Related Work + riformulare claim
4. **HIGH**: Hedging "to the best of our knowledge" ovunque
5. **MEDIUM**: Aggiungere baseline "Naive-Incremental" (re-embed tutto senza priority)
6. **MEDIUM**: 1 esperimento su dataset esterno (Wikidata subset)
7. **MEDIUM**: Synthetic scale-up a 500K nodi
8. **MEDIUM**: Mann-Whitney U + effect sizes per confronti
9. **LOW**: Documentare search protocol per gap verification in appendice
10. **LOW**: Framing "longitudinal deployment study" non "production system"

## Timeline

```
Mar 2026  Apr       Mag       Giu       Lug       Ago       Set
|---------|---------|---------|---------|---------|---------|
[A: Baseline + Accumulo naturale 90gg ───────────────────]
[B: Scrittura Sec 2-3-4 ──]
          [C: GC algorithms + dedup ──]
                    [D: Esperimenti ────────]
                                        [E: Paper completo]
                                                  [F: arXiv]
```

---

## FASE A — Baseline + Accumulo (Mar-Giu 2026) ← QUESTA SESSIONE

### A1. pg_dump snapshot T=0
```bash
docker exec postgres pg_dump -U postgres -d embeddings --no-owner --no-privileges \
  | gzip > docs/papers/kore-gc/experiments/results/baseline-2026-03-23.sql.gz
```

### A2. Copiare report T=0
```bash
cp docs/kore-health/2026-03-23.json docs/papers/kore-gc/experiments/results/t0-health-report.json
```

### A3. Accumulation logger
**File**: `kindle/kore_accumulation_log.py`
Legge `latest.json` → appende riga CSV con: timestamp, CSCS, orphan_rate, oer, dnr, fragmentation_rate, en_ratio, totals.
**Output**: `experiments/results/accumulation-log.csv`

### A4. Aggiornare systemd service
`ExecStartPost=/usr/bin/python3 /data/massimiliano/kindle/kore_accumulation_log.py`

### A5. Nota T=0
**File**: `experiments/notes/t0-baseline.md` — dati annotati + contesto pipeline.

### Verifica A
- pg_dump > 100MB ✓ | CSV 1 riga ✓ | domenica 29/3: 2 righe | ~21/6: 13+ righe → Fig 5

---

## FASE B — Scrittura Sezioni Teoriche (Mar-Apr 2026)

Sec 2-3-4 = **6.5pp** (ridotto da 7.5: Sec 3 da 3pp→2pp per VLDB). Non dipendono da esperimenti.

### B0. Salvare report ricerca (prima di scrivere)
Scrivere 2 nuovi research report dalla ricerca di questa sessione:
- `research/07-rationalist-connections.md` — 6 angoli, 10 paper, testo concreto per sezione
- `research/08-gap-reverification-march-2026.md` — 15 ricerche, 5 nuovi paper, gap status
- `research/09-meta-science-rigor.md` — Galois connection, Samyama, benchmarking crimes, self-eval

### B1. Sec 2: Background (2pp)
- Def 1-3 (Graph-Vector Store, Consistency Invariant, Staleness)
- Table 1 (confronto approcci)
- **NUOVO**: Sec 2.3 — Lindy effect giustifica generational hypothesis (Ord 2023)
- **NUOVO**: Sec 2.3 — SHY: sleep as biological GC precedent (Tononi & Cirelli 2014)
- **Fonti**: `research/03`, `04`, `07-rationalist-connections.md`

### B2. Sec 3: Neural IVM Framework (**2pp**, ridotto da 3pp)
- Def 4-6 (S operator, R operator, GC cycle)
- Theorem 1 (S-R **duality**, non "Galois connection" nel main body)
- Theorem 2 (ACID), Theorem 3 (convergence)
- **Proof sketch** nel paper, full proof in extended arXiv version
- **NUOVO**: staleness come "loss of self-consistency" (Sanati+ 2025)
- **Fig 2**: S-R framework diagram — LA FIGURA del paper
- **Running example** concreto: un ciclo GC step-by-step

### B3. Sec 4: Algorithms (2.5pp)
- Alg 1: DETECT-STALENESS, Alg 2: PRIORITIZED-REFRESH, Alg 3: TRANSACTIONAL-GC-CYCLE
- **NUOVO** Sec 4.2: Budget come rational inattention capacity (Sims 2003, footnote)
- **NUOVO** Sec 4.2: Knowledge half-lives giustificano TTL (Arbesman 2012, de Solla Price 1965)
- Complexity analysis, **Fig 3** flow diagram

### B4. Espandere Sec 6 a 3.5pp (spazio recuperato da Sec 3)
- Aggiungere baseline "Naive-Incremental"
- Aggiungere scale-up sintetico 500K nodi
- Mann-Whitney U + effect sizes

**Format**: draft markdown in `paper/draft-sec{2,3,4}.md`, LaTeX in Fase E.

---

## FASE C — Implementazione GC + Dedup (Apr-Mag 2026)

### C1. `kindle/kore_gc.py` — Modulo GC
- **detect_staleness()**: hash-based staleness + orphan detection + graph propagation k-hop
- **prioritized_refresh()**: priority queue (staleness × degree), budget-constrained, Ollama re-embedding
- **transactional_gc_cycle()**: snapshot-based via MVCC, detect→prioritize→refresh→sweep→compact
- Pattern: riusa `get_pg_connection()`, `age_query_multi()` da `kore_health.py`

### C2. Wrapper + timer
- `shell-scripts/bin/kore-gc` + `kore-gc.timer` (notturno 03:00, budget limitato)

### C3. Author dedup (Fase 2 operativa)
- `kindle/kore_dedup_authors.py` — interattivo, propone merge, utente approva
- Mai eliminare automaticamente nodi domain=personal

### Verifica C
- `kore-gc --detect --dry-run` lista stale senza modifiche
- `kore-gc --refresh --budget 100` aggiorna 100 embedding
- `kore-gc --full-cycle` → CSCS migliora

---

## FASE D — Esperimenti (Mag-Lug 2026)

### D1. Exp 1: Natural Degradation
CSV Fase A (13+ settimane) → **Fig 5** degradation curves. Nessun codice nuovo.

### D2. Exp 2: GC Effectiveness
**5** strategie su snapshot T=90gg: No-GC, Full-Rebuild, Periodic-Batch, **Naive-Incremental**, KORE-GC.
Naive-Incremental = re-embed tutto il cambiato senza priority (mostra valore della teoria).
Metriche: CSCS recovery, nDCG@10. → **Fig 6** recovery curves, **Table 4** results.
**+ scale-up sintetico a 500K nodi** (duplicare domini con chiavi diverse).

### D3. Exp 3: Cost Analysis
Break-even: quando full rebuild < incremental GC? → **Table 5**, **Fig 7** cost curves.

### D4. Exp 4: ACID Advantage
Latenza artificiale (10/50/100/500ms) tra graph e vector ops.
→ anomaly rate, convergence time. Confronto transazionale vs distributed.

### D5. Test query sets
`experiments/queries/`: Tier 1 (50 gold), Tier 2 (500 synthetic), Tier 3 (200 LLM-judge).

### D6. Plotting
`kindle/kore_plot.py` — matplotlib/seaborn, 5 run, 95% CI, Cohen's d, Bonferroni.

### D7. Esperimento su dataset esterno (Wikidata subset)
1 esperimento di validità esterna: applicare GC algorithms a subset Wikidata con embedding.
Mostra generalizzazione oltre KORE.

### Verifica D
- 4+1 esperimenti × 5 run, 8 figure PDF, 5 tabelle, nDCG@10 improvement misurabile
- Mann-Whitney U + Cohen's d per ogni confronto pairwise
- Scalability: risultati a 50K e 500K nodi

---

## FASE E — Paper Completo (Lug-Ago 2026)

### Ordine scrittura (sezioni rimanenti)
1. **Sec 5: Implementation** (1.5pp) — Fig 4 architecture, Table 2 parameters
2. **Sec 6: Experiments** (3.5pp, espansa) — integra risultati D, 5 baselines, scale-up, Wikidata
3. **Sec 7: Related Work** (1.5pp) — 4 subsection:
   - 7.1 KG Maintenance (GraphRAG, LightRAG, CAGED, **Samyama**, CraniMem, Mem0)
   - 7.2 IVM (DBSP, F-IVM, LINVIEW)
   - 7.3 GC (Bacon 2004, persistent store GC, MVCC GC)
   - 7.4 **Active Forgetting & Memory** (Peng+ 2021, Sanati+ 2025, CLS, **Annam**, euRAG)
4. **Sec 1: Introduction** (1.5pp) — **ultima**. Hedging: "to the best of our knowledge"
5. **Sec 8-9: Discussion + Conclusion** (1pp):
   - GC as memory consolidation (McClelland+ 1995 CLS, Tononi SHY)
   - Spaced repetition scheduling as future GC (Gwern, Ebbinghaus)
   - Framing "longitudinal deployment study"
   - Limitazioni + generalizzazione

### LaTeX
- `paper/kore-gc.tex` (template VLDB/ACM)
- `paper/bibliography.bib` (~60 refs)
- Totale: 13-14 pagine

### Verifica E
- `pdflatex kore-gc.tex` compila ✓ | 13-14pp ✓ | no `[?]` ✓ | notazione consistente ✓

---

## FASE F — Submission (Ago-Set 2026)

### F1. arXiv preprint
- cs.DB + cs.IR cross-list
- Claim priority nel campo

### F2. VLDB 2027 preparation
- Deadline ~Mar 2027
- Iterare su feedback post-arXiv
- Template VLDB specifico

### F3. Companion
- Repo open-source: `kore_gc.py` + `kore_health.py` su Gitea/GitHub
- Export metriche anonimizzato

---

## Riferimento rapido

### Metriche CSCS
OER (orphan embedding) | SER (stale embedding) | DRR (dangling ref) | DNR (duplicate node) | SVR (schema violation)
CSCS = 1 - weighted_avg(OER, SER, DRR, DNR, SVR)

### Elementi formali
6 def + 3 theorem + 1 corollary (Sec 2-3) | 3 algorithms (Sec 4) | 7-8 figures | 5 tables | **~75 refs** (60 originali + 15 nuovi)

### File chiave
- Outline: `docs/papers/kore-gc/paper/outline.md`
- Research: `docs/papers/kore-gc/research/01-09*.md` (6 originali + 3 nuovi)
- Health: `kindle/kore_health.py` + `docs/kore-health/`
- GC (da creare): `kindle/kore_gc.py`
- Experiments: `docs/papers/kore-gc/experiments/`

### Nuovi paper da citare (dalla ricerca di oggi)
| Paper | Tier | Dove nel paper |
|-------|------|----------------|
| Ord 2023 (Lindy Effect, arXiv) | T2 | Sec 2.3 — giustifica generational |
| McClelland+ 1995 (CLS, Psych Rev, 4800 cit) | T1 | Discussion — GC = consolidation |
| Tononi & Cirelli 2014 (SHY, Neuron, 2500 cit) | T1 | Discussion — inesorabilità = SHY |
| Sims 2003 (Rational Inattention, Nobel, 3500 cit) | T1 | Sec 4.2 — budget = RI capacity |
| Peng+ 2021 (Active Forgetting, arXiv) | T2 | Related Work — forgetting as feature |
| Sanati+ 2025 (Forgetting is Everywhere, arXiv) | T2 | Sec 3 — self-consistency |
| Arbesman 2012 (Half-Life of Facts) | T5 | Sec 4.2 — knowledge half-lives |
| de Solla Price 1965 (Networks, Science, 3000+ cit) | T1 | Sec 4.2 — citation networks |
| Kirkpatrick+ 2017 (EWC, PNAS, 5800 cit) | T1 | Related Work — catastrophic forgetting |
| Matejka & McKay 2015 (RI Discrete, AER, 800 cit) | T1 | Sec 4.2 footnote |
| Samyama 2026 (Unified Graph-Vector DB) | T2 | Related Work — differenziare |
| CraniMem 2026 (Agent memory pruning) | T2 | Related Work — application-level |
| Annam 2026 (RAG freshness measurement) | T2 | Sec 1 — evidenza problema |
| Mem0 2025 (ECAI, 201 cit) | T1 | Related Work — demand |
| van der Kouwe+ 2018 (Benchmarking Crimes, 30 cit) | T2 | Methodology reference |

### Venue
| Venue | Deadline | Note |
|-------|----------|------|
| arXiv | Ago 2026 | Claim priority |
| VLDB 2027 | ~Mar 2027 | Target primario |
| SIGMOD 2027 Demo | ~Ott 2026 | Alternativa |
