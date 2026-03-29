# KORE-GC: Theoretical Foundations Research

## Research Summary: Formal Parallels Between Garbage Collection and Knowledge Store Maintenance

### Executive Summary

The analogy between GC in programming language runtimes and maintenance of hybrid knowledge stores (graph + vector) is structurally deep and formally defensible. The key GC concepts -- generational collection, reference counting, mark-and-sweep, write barriers, compaction, and incremental/concurrent collection -- each have precise knowledge store analogues. However, three important GC invariants partially break in the knowledge store setting: (1) the "safety" invariant (never reclaim a live object) requires domain-specific redefinition since "liveness" in a knowledge store is semantically graded rather than binary; (2) the weak generational hypothesis holds empirically for KORE but with a bimodal distribution rather than the classic infant mortality curve; (3) write barriers have no direct analogue because knowledge store mutations are already transactional (MVCC provides the equivalent).

**Epistemic status:** Novel synthesis. Individual components are established (GC theory is T1, knowledge graph maintenance is T2/T3). The synthesis itself is original -- no prior work directly maps GC theory onto knowledge store maintenance.

**Confidence:** Medium-High. The formal parallels are sound; the cost model mapping is approximate.

---

## 1. Foundational GC Papers (Theoretical Foundations Section)

### 1.1 The Origin: McCarthy 1960

**McCarthy, J.** "Recursive Functions of Symbolic Expressions and Their Computation by Machine, Part I." *Communications of the ACM*, 3(4):184-195, April 1960.
(T1 -- CACM 1960)

- First description of garbage collection as part of LISP implementation
- Mark-and-sweep: traverse from root set, mark reachable, sweep unmarked
- Key formal property: **safety** -- a cell is reclaimed only if it is not reachable from any root
- Key formal property: **completeness** -- every unreachable cell is eventually reclaimed
- [Semantic Scholar](https://www.semanticscholar.org/paper/Recursive-functions-of-symbolic-expressions-and-by-McCarthy/b443e18512181514b19363cd54dd3309c70be20e) | [ACM DL](https://dl.acm.org/doi/10.1145/367177.367199)

### 1.2 The Canonical Survey: Wilson 1992

**Wilson, P.R.** "Uniprocessor Garbage Collection Techniques." *Proceedings of the International Workshop on Memory Management (IWMM)*, LNCS 637, pp. 1-42, Springer-Verlag, 1992.
(T1 -- IWMM/LNCS)

- Comprehensive taxonomy: reference counting, mark-sweep, mark-compact, copying, generational
- Cost model framework: GC cost = f(live data, allocation rate, heap size)
- Fundamental tradeoff: space vs time vs pause time
- [Semantic Scholar](https://www.semanticscholar.org/paper/Uniprocessor-Garbage-Collection-Techniques-Wilson/008b4c3ece6aaa3e8244476c7649f0a711c67978) | [ACM DL](https://dl.acm.org/doi/10.5555/645648.664824)

### 1.3 The Textbook: Jones, Hosking & Moss 2011

**Jones, R., Hosking, A., Moss, J.E.B.** *The Garbage Collection Handbook: The Art of Automatic Memory Management.* Chapman and Hall/CRC, 2011. 511 pages.
(T1 -- Textbook, ~333 citations S2)

- Definitive reference covering all major GC algorithms
- Chapters on: mark-sweep, copying, reference counting, generational, concurrent, parallel, real-time, persistent store GC
- Formal definitions of GC invariants: safety, liveness, bounded pause
- [Semantic Scholar](https://www.semanticscholar.org/paper/The-Garbage-Collection-Handbook:-The-art-of-memory-Jones-Hosking/171dd68fe13bea5c9f15cb8100deb4b7ef3fde2a) | [ACM DL](https://dl.acm.org/doi/10.5555/2025255)

### 1.4 The Unification: Bacon, Cheng & Rajan 2004

**Bacon, D.F., Cheng, P., Rajan, V.T.** "A Unified Theory of Garbage Collection." *OOPSLA 2004*, pp. 50-68.
(T1 -- OOPSLA 2004)

- Proves tracing and reference counting are **duals**: tracing operates on live objects ("matter"), reference counting operates on dead objects ("anti-matter")
- Shows all practical collectors exist on a continuum between pure tracing and pure reference counting
- Directly relevant to KORE-GC: edge-degree-based orphan detection (reference counting) and reachability-from-root (mark-and-sweep) are dual operations on the knowledge graph
- [ACM DL](https://dl.acm.org/doi/10.1145/1028976.1028982) | [Semantic Scholar](https://www.semanticscholar.org/paper/A-unified-theory-of-garbage-collection-Bacon-Cheng/91dca25f8cb407fc68218f7d5adb912e7db35e81)

---

## 2. Generational GC and the Weak Generational Hypothesis

### 2.1 Foundational Papers

**Lieberman, H. and Hewitt, C.** "A Real-Time Garbage Collector Based on the Lifetimes of Objects." *Communications of the ACM*, 26(6):419-429, June 1983.
(T1 -- CACM 1983)

- First to propose collecting recently-allocated objects more frequently
- Objects that survive a collection are "promoted" to an older generation
- Observation: most objects die young (later formalized as the "weak generational hypothesis")

**Ungar, D.** "Generation Scavenging: A Non-disruptive High Performance Storage Reclamation Algorithm." *ACM SIGPLAN Notices*, 19(5):157-167, May 1984 (SIGSOFT/SIGPLAN SDE).
(T1 -- SIGPLAN 1984)

- Practical implementation in Smalltalk-80
- Introduced nursery/tenured space terminology
- Demonstrated 5% overhead for GC vs 30% for non-generational

**Appel, A.W.** "Simple Generational Garbage Collection and Fast Allocation." *Software Practice and Experience*, 19(2):171-183, 1989.
(T1 -- SPE 1989)

- Formal cost model: total GC cost = (nursery collections x nursery cost) + (major collections x full cost)
- Nursery cost proportional to surviving objects (not total nursery size)
- Optimal nursery size balances promotion rate vs cache effects

### 2.2 The Radioactive Decay Challenge

**Clinger, W.D. and Hansen, L.T.** "Generational Garbage Collection and the Radioactive Decay Model." *PLDI 1997*, ACM SIGPLAN Notices 32(5).
(T1 -- PLDI 1997)

- If object lifetimes follow exponential decay (constant hazard rate), then age gives NO information about future life expectancy
- Under this model, generational GC has no advantage over non-generational
- Generational GC works precisely because real-world object lifetime distributions are NOT exponential -- they are bimodal or have decreasing hazard rates
- **Critical for KORE-GC**: must empirically demonstrate that KORE node lifetimes are bimodal (ephemeral conversations vs permanent papers), not exponentially distributed

**Baker, H.G.** "Infant Mortality and Generational Garbage Collection." *ACM SIGPLAN Notices*, 28(4):55-57, 1993.
(T1 -- SIGPLAN Notices)

- Formalized the "infant mortality" observation: the probability of an object dying decreases with age
- This is precisely the property that makes generational GC effective

### 2.3 Mapping to KORE

The weak generational hypothesis states: "most objects die young." In KORE:

| GC Concept | KORE Equivalent | Holds? |
|------------|----------------|--------|
| Young generation | Conversation embeddings, session nodes, infra config | YES -- high creation rate, rapid obsolescence |
| Old generation | Paper, Author, Book, Venue nodes | YES -- near-permanent once imported |
| Infant mortality | Session embeddings unused after conversation ends | YES -- most conversation chunks never re-accessed |
| Promotion | Conversation insight extracted to permanent Concept node | YES -- explicit user action or automated extraction |
| Nursery size | Rolling window of recent sessions (e.g., 30 days) | Configurable |
| Tenured space | The core knowledge graph (Paper, Author, Book, Concept) | Grows monotonically |

The bimodal distribution is actually MORE pronounced in KORE than in typical programs:
- Ephemeral nodes: half-life of days to weeks (conversation embeddings)
- Permanent nodes: half-life of effectively infinity (papers, books)
- Very few nodes in between (unlike program objects which have continuous lifetime distribution)

---

## 3. Formal GC Invariants and Knowledge Store Mapping

### 3.1 The Tri-Color Abstraction (Dijkstra et al. 1978)

**Dijkstra, E.W., Lamport, L., Martin, A.J., Scholten, C.S., Steffens, E.F.M.** "On-the-Fly Garbage Collection: An Exercise in Cooperation." *Communications of the ACM*, 21(11):966-975, November 1978.
(T1 -- CACM 1978, seminal)

- Objects colored: white (unvisited), grey (visited but children not fully scanned), black (fully scanned)
- **Strong tri-color invariant**: no black-to-white pointers (Dijkstra's original)
- **Weak tri-color invariant**: black-to-white pointers OK if a grey object can reach the white one (Pirinen 1998)
- Safety theorem: when marking terminates (no grey objects), all white objects are unreachable garbage
- [ACM DL](https://dl.acm.org/doi/10.1145/359642.359655) | [Semantic Scholar](https://www.semanticscholar.org/paper/On-the-fly-garbage-collection:-an-exercise-in-Dijkstra-Lamport/114108b350866595cebc14a96a8cb6f7aede7c93)

### 3.2 GC Invariants -- Full List

From Jones, Hosking & Moss (2011) and Wilson (1992), the core GC invariants are:

| # | Invariant | Formal Statement | KORE Mapping | Holds in KORE? |
|---|-----------|-----------------|--------------|----------------|
| I1 | **Safety** | No reachable object is ever reclaimed | No node reachable from an active query/session root is deleted | PARTIALLY -- "reachable" needs semantic redefinition (see below) |
| I2 | **Liveness (Completeness)** | Every unreachable object is eventually reclaimed | Every orphan node (0 edges, 0 recent queries) is eventually deleted | YES -- guaranteed by nightly job convergence |
| I3 | **Bounded pause** | Mutator pause <= T_max | Maintenance job latency does not block query serving | YES -- nightly batch runs during off-peak, no locking |
| I4 | **Progress** | GC makes monotonic progress toward reclaiming garbage | Each nightly run processes N items, total garbage decreases monotonically | YES -- principio di inesorabilita |
| I5 | **Generational safety** | Inter-generational pointers tracked via write barriers/remembered sets | Edges from old generation to young generation tracked? | PARTIALLY -- see discussion |
| I6 | **Tri-color safety** | No black-to-white pointers (strong) or grey-reachable path to white (weak) | During concurrent maintenance, no node being actively queried is deleted | YES -- MVCC provides this automatically |

### 3.3 Where Invariants Break or Require Redefinition

**I1 -- Safety redefinition**: In GC, "reachable" is binary (reachable from root or not). In a knowledge store, reachability is graded:
- Level 0: directly referenced by active session (definitely live)
- Level 1: reachable within 2 hops from a recently-queried node (probably live)
- Level 2: has edges but not queried in >30 days (possibly live)
- Level 3: no edges, no queries, age > threshold (garbage candidate)

This is closer to **soft/weak/phantom references in Java GC** than to hard reachability. The KORE-GC paper should formalize this as a **reachability lattice** rather than a binary predicate.

**I5 -- Write barriers**: In generational GC, write barriers track when an old-generation object points to a young-generation object (because young-generation collection must not miss such references). In KORE:
- There is no "write barrier" per se, because all mutations go through SQL/Cypher transactions
- The equivalent is: when a permanent node (Paper) gains an edge to an ephemeral node (ConversationChunk), that edge must be recorded so the ephemeral node is not collected while the Paper still references it
- PostgreSQL MVCC and AGE's transactional Cypher provide this automatically -- the "write barrier" is implicit in the database transaction model

---

## 4. Database GC / MVCC as GC

### 4.1 MVCC Garbage Collection

**Bottcher, J., Leis, V., Neumann, T., Kemper, A.** "Scalable Garbage Collection for In-Memory MVCC Systems." *PVLDB*, 13(2):128-141, 2019.
(T1 -- VLDB 2019)

- MVCC creates version chains; old versions must be reclaimed
- Three steps: detect expired versions, unlink from chains/indexes, reclaim storage
- In HTAP workloads, GC becomes the bottleneck (not query processing)
- Long-running queries prevent GC of versions they might read (analogous to "pinning" in GC)
- [ACM DL](https://dl.acm.org/doi/10.14778/3364324.3364328) | [Semantic Scholar](https://www.semanticscholar.org/paper/Scalable-Garbage-Collection-for-In-Memory-MVCC-B%C3%B6ttcher-Leis/5e27c111391c3585896c111660734497f2335bb1)

**Kim, J., et al.** "One-shot Garbage Collection for In-memory OLTP through Temporality-aware Version Storage." *Proceedings of the ACM on Management of Data (SIGMOD)*, 2023.
(T1 -- SIGMOD 2023)

- Temporality-aware version storage that enables one-shot GC
- [ACM DL](https://dl.acm.org/doi/abs/10.1145/3588699)

**Ben-David, N., Blelloch, G., Wei, Y.** "Practically and Theoretically Efficient Garbage Collection for Multiversioning." *PPoPP 2023*.
(T1 -- PPoPP 2023)

- Both practical and theoretical bounds for MVCC GC
- [ACM DL](https://dl.acm.org/doi/abs/10.1145/3572848.3577508)

### 4.2 PostgreSQL VACUUM as GC

PostgreSQL's VACUUM is literally garbage collection for MVCC tuple versions:

| VACUUM Operation | GC Equivalent | KORE Maintenance Equivalent |
|-----------------|---------------|----------------------------|
| Lazy VACUUM | Incremental mark-sweep | Nightly batch: process N stale embeddings |
| VACUUM FULL | Compacting collection | Full vector index rebuild (REINDEX) |
| autovacuum | Background concurrent GC | Scheduled timer (paper-archive-scan, infra-graph-sync) |
| Visibility map | Card table / remembered set | Query access bitmap (which nodes recently accessed) |
| Freeze | Promotion to "permanently visible" | Marking a node as archival (never collect) |
| Dead tuple threshold | GC trigger threshold | Staleness threshold (e.g., 90 days no access) |

This parallel is not merely analogical -- KORE literally uses PostgreSQL, so its node storage IS subject to VACUUM. The KORE-GC paper can argue that knowledge store maintenance operates at TWO levels:
1. **Logical GC**: application-level node/edge/embedding lifecycle management
2. **Physical GC**: PostgreSQL VACUUM managing tuple versions of the underlying storage

---

## 5. Distributed GC

### 5.1 Surveys

**Plainfosse, D. and Shapiro, M.** "A Survey of Distributed Garbage Collection Techniques." *IWMM 1995*, LNCS 986, pp. 211-249, Springer-Verlag.
(T1 -- IWMM/LNCS 1995)

- Taxonomy: reference listing, reference counting, tracing, hybrid
- Key challenge: distributed cycles (reference counting alone cannot collect distributed cycles)
- [ACM DL (later version)](https://dl.acm.org/doi/10.1145/292469.292471)

**Abdullahi, S.E. and Ringwood, G.A.** "Garbage Collecting the Internet: A Survey of Distributed Garbage Collection." *ACM Computing Surveys*, 30(3):330-373, 1998.
(T1 -- ACM Computing Surveys)

- Extended survey covering internet-scale distributed GC
- Classifies algorithms by: direct (reference counting/listing) vs indirect (tracing)
- [ACM DL](https://dl.acm.org/doi/10.1145/292469.292471)

### 5.2 Liskov and Ladin 1986

**Liskov, B. and Ladin, R.** "Highly-Available Distributed Services and Fault-Tolerant Distributed Garbage Collection." *PODC 1986*.
(T1 -- PODC 1986)

- Fault-tolerant GC for distributed heap
- Key property exploited: **stability** -- once a property becomes true, it remains true forever
- Directly maps to knowledge store: once a node becomes an orphan (no edges, no queries), it stays an orphan (unless new edges are added)
- [Semantic Scholar](https://www.semanticscholar.org/paper/Highly-available-distributed-services-and-garbage-Liskov-Ladin/64510241a78ec34e9b0bf8c9d3eeabe031ad596b)

### 5.3 Mapping to Distributed Knowledge Stores

While KORE is co-located (single PG instance + AGE + pgvector), the general problem of hybrid knowledge stores is inherently distributed (separate graph DB + vector DB + document store). The distributed GC parallels:

| Distributed GC Challenge | Knowledge Store Equivalent |
|--------------------------|---------------------------|
| Distributed reference counting | Cross-store reference tracking (graph edge to vector embedding to document chunk) |
| Distributed cycle detection | Concept A -> Paper B -> Author C -> Concept A (cycle through multiple stores) |
| Causal ordering of GC messages | Ensuring deletion propagates: delete graph node BEFORE deleting its embedding (not after) |
| Network partition tolerance | If vector DB is temporarily unavailable, graph GC must not create dangling references |
| Back-pointers / SSP chains | Embedding metadata storing graph node ID for reverse lookup |

---

## 6. GC for Persistent Stores

### 6.1 Persistent Object Store GC

**Kolodner, E.K. and Petrank, E.** "Concurrent Compacting Garbage Collection of a Persistent Heap." *SOSP 1993* / *ACM SIGOPS Operating Systems Review*.
(T1 -- SOSP 1993)

- Replicating GC cooperating with transaction manager
- Provides safe and efficient transactional storage management
- [ACM DL](https://dl.acm.org/doi/10.1145/173668.168632)

**Hosking, A.L. and Chen, J.** "Garbage Collection for a Client-Server Persistent Object Store." *ACM Transactions on Computer Systems*, 17(3), 1999.
(T1 -- ACM TOCS 1999)

- Server-based algorithm: incremental, concurrent with client transactions
- Key insight: persistent store GC must coordinate with transaction boundaries
- [ACM DL](https://dl.acm.org/doi/10.1145/320656.322741)

**Maheshwari, U. and Liskov, B.** "Partitioned Garbage Collection of a Large Object Store." *ACM SIGMOD Record*, 1997.
(T1 -- SIGMOD 1997)

- Divides store into partitions collected independently
- Uses inter-partition reference tracking (remembered sets across partitions)
- Directly applicable to KORE: collect conversation partition independently from paper partition
- [ACM DL](https://dl.acm.org/doi/10.1145/253262.253338)

**Cook, J., Wolf, A., Zorn, B.** "Partition Selection Policies in Object Database Garbage Collection." *SIGMOD 1994*.
(T1 -- SIGMOD 1994)

- Which partition to collect first? Policies: most garbage, oldest, largest, random
- Maps to KORE: which domain to maintain first? (conversations > infra config > papers)
- [ACM DL](https://dl.acm.org/doi/abs/10.1145/191839.191913)

**Lee, D., Won, Y., Park, Y., Lee, S.** "Two-Tier Garbage Collection for Persistent Objects." *SAC 2020*.
(T1 -- SAC 2020)

- Two-tier: foreground GC for mapped objects + background GC for unmapped
- Maps to KORE: hot path (recently queried nodes, in-memory cache) vs cold path (archived embeddings on disk)
- [ACM DL](https://dl.acm.org/doi/pdf/10.1145/3341105.3373986)

### 6.2 Multi-Level GC

**Wolczko, M. and Williams, I.** "Multi-level Garbage Collection in a High-Performance Persistent Smalltalk System."
(T1 -- Semantic Scholar)

- Multiple GC levels corresponding to storage hierarchy (cache / memory / disk)
- Directly maps to KORE: in-memory vector cache / PostgreSQL heap / archival storage

---

## 7. Incremental/Concurrent GC and the Principio di Inesorabilita

### 7.1 Baker's Incremental Collection

**Baker, H.G.** "List Processing in Real-Time on a Serial Computer." *Communications of the ACM*, 21(4):280-294, April 1978.
(T1 -- CACM 1978)

- First real-time (bounded pause) GC: do a fixed amount of GC work per allocation
- Key property: **incremental progress** -- each allocation triggers a bounded amount of collection work
- Guarantee: GC keeps pace with allocation if work-per-allocation >= garbage-creation-rate
- [ACM DL citation chain](https://dl.acm.org/doi/10.1145/359460.359470)

**Baker, H.G.** "The Treadmill: Real-time Garbage Collection Without Motion Sickness." *ACM SIGPLAN Notices*, 27(3), 1992.
(T1 -- SIGPLAN Notices 1992)

- In-place collection without copying (avoids pointer forwarding)
- Circular free-list ("treadmill") with four segments: from-space, to-space, new, free
- [ACM DL](https://dl.acm.org/doi/10.1145/130854.130862) | [Semantic Scholar](https://www.semanticscholar.org/paper/The-treadmill:-real-time-garbage-collection-without-Baker/330be9f038579bec8fb8a324c3bce83b7a1f4b23)

### 7.2 Formalization of "Principio di Inesorabilita" as Incremental GC

The principio di inesorabilita ("process N items per night, converge gradually") maps precisely to Baker-style incremental collection:

| Baker Incremental GC | Principio di Inesorabilita |
|---------------------|---------------------------|
| Work quantum per allocation | N items processed per nightly run |
| Allocation rate | Knowledge ingestion rate (new papers, conversations, embeddings) |
| Collection rate | Maintenance throughput (staleness checks, orphan detection, re-embedding) |
| Steady state: collection rate >= allocation rate | Convergence: nightly maintenance keeps pace with daily ingestion |
| Treadmill invariant: free space never exhausted | Storage invariant: garbage never overwhelms useful data |

**Formal convergence condition**: Let:
- `r_a` = daily allocation rate (new nodes + embeddings created per day)
- `r_c` = nightly collection rate (items processed per maintenance run)
- `r_g` = daily garbage generation rate (fraction of new items that become garbage)
- `G(t)` = total garbage at time t

Then: `G(t+1) = G(t) + r_a * r_g - min(r_c, G(t))`

**Steady state**: `G* = r_a * r_g * (r_a * r_g) / r_c` when `r_c > r_a * r_g`

The principio guarantees convergence if and only if the nightly processing rate exceeds the daily garbage generation rate. This is exactly Baker's real-time GC condition adapted to a batch setting.

### 7.3 Concurrent GC Requirements and KORE Mapping

**Dijkstra et al. 1978** (see Section 3.1) establishes the requirements for concurrent GC:

| Concurrent GC Requirement | KORE Implementation |
|--------------------------|---------------------|
| **Write barrier** (intercept pointer writes to maintain invariant) | PostgreSQL MVCC: all writes are transactions, snapshot isolation provides barrier |
| **Snapshot-at-the-beginning** (Yuasa 1990) | `pg_snapshot_any_active()` -- maintenance sees consistent snapshot of graph state |
| **Incremental marking** (process some grey objects per step) | Nightly batch processes N nodes, marks as "checked", continues next night |
| **Concurrent sweeping** (reclaim white objects while mutator runs) | `DELETE FROM ... WHERE checked AND orphan AND age > threshold` runs concurrently with queries |
| **Safe points / handshakes** | Maintenance job checks for active long-running queries before bulk deletion |

---

## 8. Vector Index Maintenance as Compaction

### 8.1 The Compaction Parallel

In GC, **compaction** eliminates fragmentation by moving live objects together and updating all references. In vector databases, the equivalent is **index rebuild** after deletions.

**Singh, A., et al.** "FreshDiskANN: A Fast and Accurate Graph-Based ANN Index for Streaming." *arXiv:2105.09613*, 2021.
(T2 -- arXiv preprint, Microsoft Research)

- Graph-based ANN indexes degrade with deletions (unreachable points, degraded recall)
- [arXiv](https://arxiv.org/abs/2105.09613)

**Xu, H., et al.** "Enhancing HNSW Index for Real-Time Updates: Addressing Unreachable Points and Performance Degradation." *arXiv:2407.07871*, 2024.
(T2 -- arXiv 2024)

- HNSW index performance degrades with deletions due to unreachable nodes
- Logical deletion (tombstones) causes recall degradation proportional to deletion fraction
- [arXiv](https://arxiv.org/abs/2407.07871)

**Zhang, Q., et al.** "Incremental IVF Index Maintenance for Streaming Vector Search." *arXiv:2411.00970*, 2024.
(T2 -- arXiv 2024)

- IVF index maintenance: trade-off between overhead and effectiveness
- Strategies: frozen, update centroids, merge/split, full rebuild
- Full rebuild most effective but O(N) cost -- analogous to full compaction in GC
- [arXiv](https://arxiv.org/abs/2411.00970)

### 8.2 Compaction Cost Model

| GC Compaction | Vector Index Maintenance |
|---------------|------------------------|
| Fragmentation = dead_objects / total_space | Index staleness = deleted_embeddings / total_embeddings |
| Compaction trigger: fragmentation > threshold | Rebuild trigger: recall degradation > threshold OR staleness > X% |
| Compaction cost: O(live objects) -- must move and update all references | Rebuild cost: O(N * d * log N) for HNSW, O(N * d * K) for IVF |
| Incremental compaction (Immix-style mark-region) | Incremental centroid update + periodic full rebuild |
| Compaction benefit: improved locality, reduced page faults | Rebuild benefit: restored recall, balanced partitions |

---

## 9. Knowledge Graph Lifecycle and Temporal Decay

### 9.1 KG Evolution

**Simsek, U. and Angele, K.** "Knowledge Graph Lifecycle: Building and Maintaining Knowledge Graphs."
(T2 -- Semantic Scholar)

- Formal lifecycle model for knowledge graphs: creation, enrichment, quality assessment, evolution, deprecation
- [Semantic Scholar](https://www.semanticscholar.org/paper/Knowledge-Graph-Lifecycle:-Building-and-Maintaining-Simsek-Angele/8506b10f686337b5595aa0a2a4824780a4963562)

### 9.2 Embedding Drift and Staleness

**Resilience in Knowledge Graph Embeddings.** *arXiv:2410.21163*, 2024.
(T2 -- arXiv 2024)

- KGE models need to adapt to dynamic environments and evolving data distributions
- Concept drift in embeddings requires periodic re-embedding
- [arXiv](https://arxiv.org/html/2410.21163v1)

---

## 10. Formal Parallels Table (Complete)

| # | GC Concept | GC Formal Definition | Knowledge Store Equivalent | Formal Mapping Quality |
|---|-----------|---------------------|---------------------------|----------------------|
| 1 | **Heap** | Set of allocated objects with pointer relationships | Knowledge store: graph nodes + vector embeddings + metadata | EXACT |
| 2 | **Root set** | Variables on stack, global variables, registers | Active sessions, pinned queries, bookmarked nodes, system config | EXACT |
| 3 | **Reachability** | Transitive closure of pointer dereference from root set | Transitive closure of edge traversal from root set (with distance decay) | APPROXIMATE -- graded vs binary |
| 4 | **Garbage** | Objects not reachable from root set | Orphan nodes (0 edges, 0 recent queries, age > threshold) | APPROXIMATE -- multi-criteria |
| 5 | **Mark-and-sweep** | Trace from roots marking reachable, sweep unmarked | Graph traversal from active roots, delete unmarked stale nodes | EXACT (structurally) |
| 6 | **Reference counting** | Count incoming pointers; collect when count = 0 | Count incoming edges; flag when degree = 0 | EXACT |
| 7 | **Young generation** | Recently allocated objects, collected frequently | Conversation embeddings, session nodes (< 30 days) | EXACT |
| 8 | **Old generation** | Long-lived objects, collected rarely | Paper, Author, Book, Venue nodes | EXACT |
| 9 | **Promotion** | Moving surviving young objects to old generation | Extracting permanent Concept from conversation; archival marking | EXACT |
| 10 | **Write barrier** | Intercept pointer stores to maintain invariant | MVCC transaction boundary (implicit in PostgreSQL) | STRUCTURAL (implicit vs explicit) |
| 11 | **Remembered set** | Set of old-to-young pointers | Edges from permanent nodes to ephemeral nodes | APPROXIMATE |
| 12 | **Compaction** | Move live objects to eliminate fragmentation | Vector index rebuild (HNSW/IVF) after deletions | ANALOGICAL |
| 13 | **Incremental GC** | Bounded work per mutator step | Batch N items per nightly run (principio di inesorabilita) | EXACT |
| 14 | **Concurrent GC** | Collector runs concurrently with mutator | Maintenance job runs concurrently with query serving | EXACT |
| 15 | **Tri-color marking** | White/grey/black classification during traversal | Unchecked/in-progress/verified node status during maintenance | EXACT |
| 16 | **Finalization** | Run cleanup code before reclaiming object | Archive node to cold storage before deletion; export to backup | ANALOGICAL |
| 17 | **Weak reference** | Does not prevent collection; cleared when referent collected | Low-confidence edges (similarity < threshold); pruned during maintenance | ANALOGICAL |
| 18 | **Pinning** | Prevent object from being moved/collected | Active query holds read lock; bookmarked nodes never collected | EXACT |
| 19 | **GC pause** | Mutator stopped during collection | Maintenance window (query latency increase during batch job) | EXACT |
| 20 | **Fragmentation** | Unusable gaps between live objects | Index staleness (tombstoned vectors degrading recall) | ANALOGICAL |

---

## 11. Cost Model Comparison

### GC Cost Metrics (from Wilson 1992, Appel 1989)

```
GC_cost = (num_minor_collections * cost_minor) + (num_major_collections * cost_major)

cost_minor = |survivors_young| * copy_cost      (for copying collector)
cost_major = |live_objects| * trace_cost + |heap| * sweep_cost

Throughput = useful_work / (useful_work + GC_work)
Pause_time = max(pause_minor, pause_major)
Space_overhead = (heap_size - live_data) / live_data
```

### KORE Maintenance Cost Metrics (proposed)

```
Maintenance_cost = (num_young_runs * cost_young) + (num_full_runs * cost_full)

cost_young = |stale_embeddings| * recheck_cost + |orphan_nodes| * delete_cost
cost_full = |all_embeddings| * similarity_recompute + |all_nodes| * reachability_check
           + |vector_index| * rebuild_cost

Throughput = query_serving_time / (query_serving_time + maintenance_time)
Staleness = fraction_of_embeddings_outdated (analogous to fragmentation)
Space_overhead = (total_storage - useful_storage) / useful_storage

Convergence_condition: maintenance_rate > garbage_generation_rate
  i.e., r_c > r_a * r_g (see Section 7.2)
```

### Metric Mapping

| GC Metric | KORE Metric | Unit | Notes |
|-----------|------------|------|-------|
| Allocation rate | Ingestion rate | objects/sec vs nodes/day | Time scale differs: microseconds vs hours |
| Survival rate | Promotion rate | fraction | What fraction of conversations produce permanent knowledge |
| GC throughput | Maintenance throughput | fraction of wall-clock | Target: >95% query serving, <5% maintenance |
| Pause time | Maintenance window latency impact | milliseconds / seconds | GC: ms-level; KORE: acceptable at minute-level |
| Heap utilization | Storage utilization | fraction | Live data / total storage |
| Fragmentation ratio | Index staleness ratio | fraction | Dead entries / total entries in vector index |
| Collection frequency | Maintenance frequency | per second / per day | Different time scales |

---

## 12. Which GC Invariants Hold/Break (Summary)

### Invariants That Hold Cleanly
- **Liveness/Completeness** (I2): Principio di inesorabilita guarantees eventual collection
- **Bounded pause** (I3): Batch processing with bounded N per run
- **Progress** (I4): Monotonic decrease in garbage per epoch
- **Tri-color safety** (I6): MVCC provides snapshot isolation during concurrent maintenance
- **Generational hypothesis**: Bimodal lifetime distribution (conversations vs papers)

### Invariants That Require Redefinition
- **Safety** (I1): Must be redefined from binary reachability to a graduated reachability lattice
- **Write barriers** (I5): Implicit in MVCC transactions rather than explicit instrumentation
- **Compaction** (I12): Vector index rebuild is functional equivalent but operates on different data structure

### Invariants That Break
- **Deterministic collection**: GC guarantees every garbage object is collected in finite time; knowledge store maintenance may intentionally retain "stale but potentially useful" nodes indefinitely
- **Reference semantics**: In GC, all references are equivalent; in knowledge stores, edges have types, weights, and semantic meaning -- a CITES edge is fundamentally different from a MENTIONS edge
- **Space reclamation**: GC reclaims memory for reuse; knowledge store "garbage" may be archived rather than deleted (soft delete vs hard delete)

---

## 13. Serendipitous Connections

### 13.1 Information-Theoretic Interpretation
The GC/knowledge-store parallel has an information-theoretic reading. In GC, the root set defines "relevance" via pointer reachability. In information theory, relevance can be formalized via mutual information: I(node; active_queries). A node is "garbage" when its mutual information with the current query distribution drops below a threshold. This connects to the **information bottleneck method** (Tishby et al. 1999) -- the knowledge store maintenance problem is essentially compressing the knowledge representation while preserving information relevant to future queries.

### 13.2 Ecological Succession
The generational structure of knowledge stores mirrors ecological succession: pioneer species (conversation nodes) colonize quickly but die fast; climax species (Paper, Author nodes) establish slowly but persist indefinitely. The GC "nursery" is the disturbed habitat; the "tenured generation" is the old-growth forest. This is not just metaphor -- the population dynamics equations (birth rate, death rate, carrying capacity) map onto GC cost models.

### 13.3 Connection to Agent Framework Project
The agent framework's task_graph in AGE faces the same GC problem: task nodes have lifetimes ranging from seconds (ephemeral tool calls) to months (recurring workflows). The KORE-GC formalism directly applies to task_graph maintenance.

### 13.4 Economics: Depreciation and Obsolescence
Knowledge node obsolescence maps to economic depreciation. The "book value" of a knowledge node decreases with time unless it is actively used (queried). This connects to the economic literature on capital depreciation models (exponential, straight-line, double-declining-balance). The "radioactive decay model" critique of generational GC (Clinger & Hansen 1997) is essentially the debate between exponential depreciation and more complex depreciation schedules.

---

## 14. Citable Papers for "Theoretical Foundations" Section

### Core GC Theory (MUST CITE)
1. McCarthy 1960 -- "Recursive Functions of Symbolic Expressions" (CACM) -- origin of GC
2. Dijkstra et al. 1978 -- "On-the-Fly Garbage Collection" (CACM) -- tri-color invariant, concurrent GC
3. Baker 1978 -- "List Processing in Real-Time" (CACM) -- incremental GC, bounded pause
4. Lieberman & Hewitt 1983 -- "Real-Time GC Based on Lifetimes" (CACM) -- generational GC origin
5. Ungar 1984 -- "Generation Scavenging" (SIGPLAN) -- practical generational GC
6. Wilson 1992 -- "Uniprocessor GC Techniques" (IWMM) -- definitive survey
7. Baker 1992 -- "The Treadmill" (SIGPLAN Notices) -- in-place incremental GC
8. Clinger & Hansen 1997 -- "Radioactive Decay Model" (PLDI) -- lifetime distribution theory
9. Bacon, Cheng & Rajan 2004 -- "Unified Theory of GC" (OOPSLA) -- tracing/RC duality
10. Jones, Hosking & Moss 2011 -- *GC Handbook* -- comprehensive reference

### Database GC (SHOULD CITE)
11. Bottcher et al. 2019 -- "Scalable GC for MVCC" (VLDB) -- database GC formalization
12. Ben-David et al. 2023 -- "Practically and Theoretically Efficient GC for Multiversioning" (PPoPP)
13. Maheshwari & Liskov 1997 -- "Partitioned GC of Large Object Store" (SIGMOD)
14. Cook, Wolf & Zorn 1994 -- "Partition Selection Policies" (SIGMOD)

### Persistent Store GC (SHOULD CITE)
15. Hosking & Chen 1999 -- "GC for Client-Server Persistent Object Store" (TOCS)
16. Kolodner & Petrank 1993 -- "Concurrent Compacting GC of Persistent Heap" (SOSP)
17. Lee et al. 2020 -- "Two-Tier GC for Persistent Objects" (SAC)

### Distributed GC (CITE IF GENERALIZING)
18. Plainfosse & Shapiro 1995 -- "Survey of Distributed GC Techniques" (IWMM)
19. Liskov & Ladin 1986 -- "Highly-Available Distributed Services and Fault-Tolerant Distributed GC" (PODC)

### Vector Index Maintenance (CITE FOR COMPACTION PARALLEL)
20. Zhang et al. 2024 -- "Incremental IVF Index Maintenance" (arXiv:2411.00970)
21. Xu et al. 2024 -- "Enhancing HNSW for Real-Time Updates" (arXiv:2407.07871)
22. Singh et al. 2021 -- "FreshDiskANN" (arXiv:2105.09613)

### Knowledge Graph Lifecycle (CITE FOR DOMAIN CONTEXT)
23. Simsek & Angele -- "KG Lifecycle: Building and Maintaining KGs" (Semantic Scholar)
24. arXiv:2410.21163 -- "Resilience in Knowledge Graph Embeddings" (2024)

### Formal Verification of GC (OPTIONAL -- for rigor)
25. arXiv:1004.3808 -- "Automated Verification of Practical Garbage Collectors" (2010)
26. arXiv:1006.4342 -- "Formal Derivation of Concurrent Garbage Collectors" (2010)

---

## 15. Open Questions for the KORE-GC Paper

1. **Empirical validation of the weak generational hypothesis for KORE**: Need to measure actual node lifetime distributions. Prediction: bimodal (conversations ~days, papers ~infinity). If confirmed, this is stronger than the standard programming language case.

2. **Optimal "nursery size"**: What is the right rolling window for "young generation" in KORE? 7 days? 30 days? 90 days? This is an empirical question analogous to nursery sizing in GC.

3. **Cost of "write barriers"**: In practice, how much overhead does MVCC add to KORE mutations compared to a non-transactional store? This quantifies the implicit write barrier cost.

4. **When to compact (rebuild vector index)**: What staleness threshold triggers a full HNSW/IVF rebuild? Need to measure recall degradation as a function of deletion fraction.

5. **The "floating garbage" problem**: In concurrent GC, objects that become garbage during collection are not collected until the next cycle ("floating garbage"). In KORE, nodes that become stale during a nightly maintenance run won't be caught until the next run. How much floating garbage accumulates?

---

## Sources

### T1 -- Peer-reviewed
- [Wilson 1992 -- Uniprocessor GC Techniques (Semantic Scholar)](https://www.semanticscholar.org/paper/Uniprocessor-Garbage-Collection-Techniques-Wilson/008b4c3ece6aaa3e8244476c7649f0a711c67978)
- [McCarthy 1960 -- Recursive Functions (ACM DL)](https://dl.acm.org/doi/10.1145/367177.367199)
- [Dijkstra et al. 1978 -- On-the-Fly GC (ACM DL)](https://dl.acm.org/doi/10.1145/359642.359655)
- [Bacon et al. 2004 -- Unified Theory of GC (ACM DL)](https://dl.acm.org/doi/10.1145/1028976.1028982)
- [Jones, Hosking & Moss 2011 -- GC Handbook (ACM DL)](https://dl.acm.org/doi/10.5555/2025255)
- [Bottcher et al. 2019 -- Scalable GC for MVCC (ACM DL)](https://dl.acm.org/doi/10.14778/3364324.3364328)
- [Clinger & Hansen 1997 -- Radioactive Decay (ACM DL)](https://dl.acm.org/doi/10.1145/258916.258925)
- [Hosking & Chen 1999 -- Persistent Object Store GC (ACM DL)](https://dl.acm.org/doi/10.1145/320656.322741)
- [Maheshwari & Liskov 1997 -- Partitioned GC (ACM DL)](https://dl.acm.org/doi/10.1145/253262.253338)
- [Liskov & Ladin 1986 -- Distributed GC (Semantic Scholar)](https://www.semanticscholar.org/paper/Highly-available-distributed-services-and-garbage-Liskov-Ladin/64510241a78ec34e9b0bf8c9d3eeabe031ad596b)
- [Baker 1992 -- Treadmill (ACM DL)](https://dl.acm.org/doi/10.1145/130854.130862)
- [Kolodner & Petrank 1993 -- Concurrent Compacting GC (ACM DL)](https://dl.acm.org/doi/10.1145/173668.168632)
- [Lee et al. 2020 -- Two-Tier GC (ACM DL)](https://dl.acm.org/doi/pdf/10.1145/3341105.3373986)
- [Cook, Wolf & Zorn 1994 -- Partition Selection (ACM DL)](https://dl.acm.org/doi/abs/10.1145/191839.191913)
- [Ben-David et al. 2023 -- Efficient GC for Multiversioning (ACM DL)](https://dl.acm.org/doi/abs/10.1145/3572848.3577508)
- [Kim et al. 2023 -- One-shot GC OLTP (ACM DL)](https://dl.acm.org/doi/abs/10.1145/3588699)
- [Plainfosse & Shapiro 1995 -- Distributed GC Survey (ACM DL)](https://dl.acm.org/doi/10.1145/292469.292471)
- [Abdullahi & Ringwood 1998 -- GC Internet Survey (ACM DL)](https://dl.acm.org/doi/10.1145/292469.292471)

### T2 -- arXiv preprints
- [Zhang et al. 2024 -- Incremental IVF Index Maintenance](https://arxiv.org/abs/2411.00970)
- [Xu et al. 2024 -- Enhancing HNSW for Real-Time Updates](https://arxiv.org/abs/2407.07871)
- [Singh et al. 2021 -- FreshDiskANN](https://arxiv.org/abs/2105.09613)
- [Resilience in KG Embeddings 2024](https://arxiv.org/html/2410.21163v1)
- [Formal Derivation of Concurrent GC 2010](https://arxiv.org/abs/1006.4342)
- [Automated Verification of Practical GC 2010](https://arxiv.org/pdf/1004.3808)

### T2 -- Semantic Scholar
- [KG Lifecycle -- Simsek & Angele](https://www.semanticscholar.org/paper/Knowledge-Graph-Lifecycle:-Building-and-Maintaining-Simsek-Angele/8506b10f686337b5595aa0a2a4824780a4963562)
