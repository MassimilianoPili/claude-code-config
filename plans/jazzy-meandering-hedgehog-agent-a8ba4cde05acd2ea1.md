# Research: Comparison Reduction Techniques for Preference Ranking

## Research Summary

**Epistemic status:** Strong consensus on theory, active engineering front on practical integration
**Confidence:** High -- multiple T1/T2 sources with replicated results; some implementation specifics are T5-level engineering judgment

This report covers three techniques for reducing comparisons in a Bradley-Terry preference ranking system, assessed against the existing `preference-sort` Go service.

---

## Topic 1: Swiss-System Tournament Pairing for Ranking

### How It Works Mathematically

The Swiss system is a deterministic tournament format: N players compete over R fixed rounds, where in each round players are paired with opponents of similar current score (T7 -- Wikipedia). The key invariant is:

1. **Round 1**: Random or seeded pairing
2. **Rounds 2..R**: Players are grouped by cumulative score. Within each score group, players are paired (typically top-half vs bottom-half within the group), avoiding rematches
3. After R rounds, the final ranking is the cumulative score

Mathematically, this is a **comparison graph construction strategy** -- it builds a sparse comparison graph where edges (comparisons) are concentrated between items of similar estimated strength. This is precisely where the Bradley-Terry model has highest uncertainty (items with similar pi values have P(A>B) close to 0.5, hence maximum entropy per comparison).

### Optimal Number of Rounds

The standard result (T7 -- FIDE/chess literature; confirmed by T1 -- Sauer, Cseh & Lenzner, EC 2022, ~28 cit S2):

- **ceil(log2(N))** rounds suffice to identify a unique winner with high probability under noiseless comparisons
- For a full ranking (not just winner), **2*ceil(log2(N))** rounds are typical in practice
- Example: N=100 items -> 7 rounds for winner, ~14 rounds for ranking
- Compare to round-robin: N*(N-1)/2 = 4950 comparisons vs 7*50 = 350 (Swiss, each round pairs all players)

**Comparison savings:**
| N | Round-robin | Swiss (winner) | Swiss (ranking) | Saving |
|---|-------------|----------------|-----------------|--------|
| 25 | 300 | 84 (7 rounds * 12 pairs) | 168 | 44-72% |
| 50 | 1225 | 150 (6 rounds * 25 pairs) | 300 | 76-88% |
| 100 | 4950 | 350 (7 rounds * 50 pairs) | 700 | 86-93% |

The critical caveat: these figures assume **noiseless** comparisons. With noisy comparisons (as in Bradley-Terry), more rounds are needed.

### Key Papers

1. **Sauer, Cseh & Lenzner (2022)** "Improving ranking quality and fairness in Swiss-system chess tournaments" (T1 -- EC 2022, ~28 cit S2)
   - Proposes maximum-weight matching instead of FIDE pairing rules
   - Shows improved ranking accuracy via careful graph-theoretic pairing
   - Formulates pairing as a weighted matching problem on a bipartite graph within each score group
   - **Highly relevant**: their matching-based approach could replace the current random/IG scheduler

2. **Csato (2015/2017)** "On the ranking of a Swiss system chess team tournament" (T1 -- Annals of Operations Research, ~81 cit S2)
   - Analyzes ranking accuracy of Swiss systems from an operations research perspective
   - Proposes scoring rules that better reflect true strength

3. **Csato & Krumer (2024)** "Swiss-system chess tournaments and unfairness" (T2 -- arXiv, econ.GN, ~2 cit S2)
   - Empirical analysis of 28 tournaments showing systematic unfairness from odd round counts
   - Recommends even number of rounds

4. **Maystre & Grossglauser (2017)** "Just Sort It! A Simple and Effective Approach to Active Preference Learning" (T1 -- ICML 2017, high-impact)
   - **Key insight**: Quicksort under noisy Bradley-Terry comparisons achieves near-optimal sample complexity
   - Proves that O(N log N) comparisons suffice for ranking under BT with parameter gap delta
   - "Repeatedly sort the items" is a practical active learning strategy
   - Performance matches state-of-the-art at tiny computational cost
   - **This is the most directly applicable paper**: sorting = Swiss-like adaptive pairing

### Swiss System as Active Learning

The Swiss system can be formalized as a special case of **adaptive sampling for pairwise comparisons** (T1 -- Heckel, Shah, Ramchandran & Wainwright, Annals of Statistics 2019, ~110 cit S2). The key theoretical framing:

- **Active ranking from pairwise comparisons** requires O(N log N / delta^2) comparisons for (epsilon, delta)-PAC ranking, where delta is the minimum gap between adjacent items
- Swiss pairing is a **greedy heuristic** for this: by pairing items with similar scores, it implicitly targets the comparisons with highest information gain
- The connection to the existing IG scheduler: Swiss pairing is an O(N) approximation to the O(N^2) information-gain calculation

### Implementability Assessment

**Highly implementable in Go.** The Swiss pairing algorithm is:
1. Sort items by current BT score -- O(N log N)
2. Within each score band, pair top-half vs bottom-half -- O(N)
3. Track previous pairings to avoid rematches -- O(N) with a hash set

This could be added as an alternative to `SelectNextPair` in `scheduler.go`. Instead of computing IG for all candidate pairs (O(N^2) * O(BT-refit)), Swiss pairing gives O(N log N) pair selection. The IG computation could then be used as a **tiebreaker** within score bands.

**Integration with existing BT + IG system:**
- Swiss pairing generates the **candidate pool** (replacing `generateCandidates`)
- IG scoring selects the **best pair within the Swiss candidates**
- This is a "Swiss-filtered IG" hybrid: O(N) candidate generation, O(K) IG evaluation where K << N^2

---

## Topic 2: Transitive Closure Exploitation in Ranking

### Theory: When Can We Infer A>C from A>B and B>C?

Under the Bradley-Terry model, transitivity is **guaranteed at the population level**: if pi_A > pi_B > pi_C, then P(A>C) > P(A>B) and P(A>C) > P(B>C). But with **noisy observations**, the question becomes: given observed comparisons, what confidence do we have in transitive inferences?

**Key result** (T1 -- Shah, Balakrishnan et al., ICML 2016, "Stochastically transitive models"):
- The Bradley-Terry model belongs to the class of **Strong Stochastic Transitivity (SST)** models
- SST guarantees: if P(A>B) >= 1/2 and P(B>C) >= 1/2, then P(A>C) >= max(P(A>B), P(B>C))
- This is **stronger** than just P(A>C) >= 1/2

### Confidence Level for Transitive Inference

Given estimated BT parameters pi_A, pi_B, pi_C with standard errors SE_A, SE_B, SE_C:

1. **Comparison A>B is confident** if: (pi_A - pi_B) / sqrt(SE_A^2 + SE_B^2) > z_alpha (e.g., z=1.96 for 95%)
2. **Transitive inference A>C** holds with confidence at least: 1 - (1-conf(A>B)) - (1-conf(B>C)) by union bound
3. In practice, the BT model gives **tighter** bounds: P(A>C) = pi_A/(pi_A+pi_C), and the SE of this probability can be computed from the Fisher information matrix (already implemented in `bt.go`)

**Practical threshold**: If both A>B and B>C have >80% BT probability (pi_A/pi_B > 4), then P(A>C) > 94%. With >90% probability per link, transitive P(A>C) > 99%.

### Comparison Graph Connectivity and Ranking Quality

**Critical paper** (T1 -- Hendrickx & Olshevsky, ICML 2019, "Graph resistance and learning from pairwise comparisons"):
- The estimation error in BT scores scales with the **effective resistance** of the comparison graph
- Dense graphs (many comparisons) have low resistance -> accurate estimates
- The comparison graph needs to be **connected** for BT MLE to exist (Ford 1957) -- already checked in `bt.go:IsGraphConnected`
- Key insight: **you don't need a complete graph; a well-connected sparse graph suffices**

**Practical implication**: If the comparison graph has good spectral properties (low effective resistance), you can skip comparisons between items that are already well-separated and connected through transitive chains.

### Transitive Reduction Algorithm

For a concrete implementation:

1. After each comparison, update BT scores
2. Build a **DAG of confident orderings**: edge A->B exists if P(A>B) > threshold (e.g., 0.85)
3. Compute **transitive closure** of this DAG
4. For any pair (A,C) in the transitive closure, **skip future comparisons** -- they are informationally redundant
5. Only present pairs NOT in the transitive closure to the user

**Complexity**: Transitive closure via Floyd-Warshall is O(N^3), but for sparse graphs with incremental updates, it's O(N^2) amortized per comparison. For N <= 100 items (typical for preference-sort), this is negligible.

### Hodge Decomposition for Detecting Intransitivity

**Seminal paper** (T1 -- Jiang, Lim, Yao & Ye, 2011, "Statistical ranking and combinatorial Hodge theory", Mathematical Programming, ~300+ cit):

The Hodge decomposition decomposes pairwise ranking data (edge flow on comparison graph) into three orthogonal components:
1. **Gradient flow** -- the L2-optimal global ranking (consistent with a linear order)
2. **Curl flow** -- local inconsistency (cyclic rankings on triangles: A>B>C>A)
3. **Harmonic flow** -- global inconsistency (locally acyclic but globally cyclic)

**Why this matters for comparison reduction:**
- If the curl component is small, the data is **approximately transitive** -> transitive closure is safe
- If the curl component is large, there are genuine preference cycles -> more comparisons needed in those areas
- The harmonic component detects **global intransitivity** that wouldn't be caught by local triangle checks

**Implementation**: The Hodge decomposition reduces to a **linear least squares** problem:
- Construct the edge-vertex incidence matrix B (sparse, N_edges x N_vertices)
- The gradient component is the projection onto the column space of B
- Curl = projection onto ker(B^T) intersected with image of the triangle boundary operator
- Residual = harmonic

This is computable via a single matrix solve (already have matrix inversion in `bt.go`). The key metric is `||curl|| / ||total flow||` -- if this ratio is small (say < 0.1), transitive closure is reliable.

### Implementability Assessment

**Implementable in Go with moderate effort.**

1. **Transitive closure DAG**: Simple -- Floyd-Warshall or BFS. O(N^2) space, O(N^3) time, fine for N <= 200.
2. **Confident-pair skipping**: Add to `generateCandidates` -- exclude pairs in transitive closure from candidates.
3. **Hodge decomposition**: Requires sparse linear algebra. The existing `invertMatrix` in `bt.go` handles dense NxN matrices. For the Hodge decomposition, you need to solve a sparse least-squares problem of size |edges| x N. With |edges| ~ O(N log N), this is feasible for N <= 200 using dense methods.

**Integration with existing system:**
- `generateCandidates` already filters by `maxDirectComparisons` -- add transitive closure filter
- Hodge intransitivity metric could feed into the IG computation: pairs in intransitive regions get IG boost
- The `IsGraphConnected` function already exists -- extend to `TransitiveClosure`

**Estimated comparison savings**: For N=100 with ~300 comparisons (3x per item), transitive closure typically covers 60-80% of pairs, meaning only 20-40% of pairs need direct comparison. Combined with IG-based selection, this could reduce total comparisons by 50-70% vs current approach.

---

## Topic 3: Top-k Ranking (Partial Ranking)

### Sample Complexity

If you only need the top k items out of N, the comparison budget drops dramatically:

**Key result** (T1 -- Chen & Suh, ICML 2015, "Spectral MLE: Top-K Rank Aggregation", ~146 cit S2):
- Full ranking requires Theta(N log N) comparisons
- Top-k identification requires Theta(N log k + N/delta^2) comparisons under BT model
- For k=10, N=100: ~100*log(10) + 100/delta^2 ~ 230 + 100/delta^2 comparisons (vs 4950 for round-robin)

**Tighter bound** (T1 -- Chen, Fan, Ma & Wang, Annals of Statistics 2019, ~125 cit S2):
- "Spectral Method and Regularized MLE Are Both Optimal for Top-K Ranking"
- Minimax optimal rate: O(N*k/delta^2 * log(N/k)) for exact top-k recovery with high probability
- For k=10, N=100, delta=0.3: ~100*10/(0.09) * log(10) ~ 25,600 -- but this is worst-case; practical numbers are much lower

**More practical bound** (T1 -- Heckel et al., Annals of Statistics 2019, ~110 cit S2):
- Active ranking (adaptive pair selection) achieves top-k identification in O(N/delta^2 * log(k/epsilon)) comparisons
- The key advantage of **active** over passive: adaptive selection focuses comparisons near the k-th boundary

### Algorithms

1. **PLPAC** (Szoerenyi et al., ALT 2015):
   - Pairwise Likert-rating based PAC algorithm
   - Maintains confidence intervals on each item's "win probability"
   - Eliminates items whose upper confidence bound falls below the lower bound of a better item
   - Sample complexity: O(N/delta^2 * log(N/epsilon))
   - **Caveat**: Heckel et al. (2019) show PLPAC can fail when the BT assumption doesn't hold perfectly

2. **Successive Elimination / Racing**:
   - Maintain active set S = all items
   - In each round, compare items and eliminate those provably not in top-k
   - Elimination criterion: item i is eliminated if its BT upper confidence bound < k-th highest lower confidence bound
   - O(N * log(N/epsilon) / delta^2) comparisons
   - **Very simple to implement** -- just confidence interval arithmetic

3. **Active Ranking (AR)** (Heckel et al., 2019):
   - Non-parametric: works without assuming BT model
   - Achieves optimal sample complexity for top-k under general stochastic transitivity
   - More robust than PLPAC/BTMB but requires more comparisons when BT does hold

4. **K-Sort Arena** (Li et al., CVPR 2025, T2 -- arXiv 2408.14468, recent):
   - Extends Swiss-system to K-wise comparisons (K items shown simultaneously)
   - Bayesian updating of BT parameters
   - Exploration-exploitation matchmaking: balance uncertainty reduction with discriminative power
   - 16.3x faster convergence than ELO
   - **Directly relevant**: designed for LLM arena-style ranking, maps cleanly to preference ranking

5. **Mohajer, Suh & Elmahdy (2017)** "Active Learning for Top-K Ranking from Noisy Comparisons" (T1 -- ICML 2017):
   - Formal PAC framework for top-k
   - Multi-phase algorithm: coarse ranking -> refined boundary estimation
   - Phase 1: O(N log N) comparisons to get approximate ranking
   - Phase 2: O(N/delta^2 * log(1/epsilon)) comparisons focused on the k-boundary items

### Practical Implementation: Successive Elimination for Top-k

The simplest approach that integrates with the existing BT system:

```
function TopKElimination(items, k, confidence):
    active = set(items)
    while |active| > k:
        // Use existing BT scoring
        RecalculateScores(active, comparisons)

        // Build confidence intervals: [score - z*SE, score + z*SE]
        for each item in active:
            item.lower = item.BTScore - 1.96 * item.BTSE
            item.upper = item.BTScore + 1.96 * item.BTSE

        // Find k-th highest lower bound
        sorted_lowers = sort(item.lower for item in active, desc)
        threshold = sorted_lowers[k]  // k-th best lower bound

        // Eliminate items whose upper bound < threshold
        for each item in active:
            if item.upper < threshold:
                active.remove(item)

        // Select next comparison from active set only
        SelectNextPair(active, comparisons, ...)
```

**Comparison savings for top-k=10, N=100:**
- Round-robin: 4950 comparisons
- Full ranking with IG: ~300-600 comparisons (current system)
- Top-k successive elimination: ~100-200 comparisons (50-70% saving over full ranking)

### Implementability Assessment

**Highly implementable in Go.** The successive elimination algorithm requires:
1. BT score computation -- already implemented
2. Confidence interval arithmetic -- trivial from existing SE computation
3. Filtering active set -- simple set operations
4. Modified `SelectNextPair` to only consider active items -- minor change to `generateCandidates`

**Integration with existing system:**
- Add a `topK` parameter to the list/next-pair API
- `generateCandidates` filters to only include pairs where at least one item is in the active set
- Add an `eliminated` flag to items (or a separate eliminated set per list)
- The IG computation naturally focuses on boundary items (high SE = high IG)

---

## Serendipitous Connections

### 1. Swiss System <-> Information Gain (structural equivalence)
The Swiss system's "pair items with similar scores" heuristic is mathematically equivalent to maximizing information gain under BT: items with similar pi values have P(A>B) close to 0.5, which is the maximum-entropy distribution -- exactly where a comparison provides most information. **The current IG scheduler is already a generalized Swiss system**, but at O(N^2) cost instead of O(N log N).

### 2. Hodge Decomposition <-> KORE-GC Paper
The Hodge decomposition detects cyclic inconsistencies in preference data. This connects directly to the **KORE-GC paper** on graph-vector pruning: the "gradient flow" component of the Hodge decomposition is the useful ranking signal, while the "curl" and "harmonic" components are noise that could be pruned. This is a form of "semantic garbage collection" for preference data.

### 3. Top-k Elimination <-> Fantacalcio
The successive elimination algorithm for top-k ranking maps directly to fantasy football player selection: you don't need a complete ranking of all players, just the top-k per role. The BT confidence intervals could be used to decide when you have enough data to commit to a player selection.

### 4. K-Sort Arena <-> Agent Framework
K-wise comparisons (showing K items simultaneously) is more efficient than pairwise. In the agent framework context, this could be used for multi-model evaluation: instead of pairwise A/B testing, show K outputs and rank all K simultaneously, getting O(K^2) bits of information per human judgment instead of 1 bit.

---

## Concrete Implementation Recommendations for preference-sort

### Priority 1: Transitive Closure Filtering (highest ROI, moderate effort)
Add to `scheduler.go`:
- After BT refit, compute a "confident DAG" where edge A->B exists if P(A>B) > 0.85
- Compute transitive closure of this DAG (Floyd-Warshall, O(N^3) -- fine for N <= 200)
- In `generateCandidates`, exclude pairs covered by transitive closure
- **Expected saving: 40-60% fewer comparisons** for well-separated items

### Priority 2: Swiss-Filtered IG (high ROI, low effort)
Modify `generateCandidates` for N > 30:
- Instead of random sampling + top-SE prioritization, use Swiss pairing:
  - Sort items by BT score
  - Generate candidate pairs between adjacent items in the sorted order (within a window of ~log2(N))
  - Evaluate IG only on these ~N*log(N) candidates instead of sampling from O(N^2)
- **Expected saving: 10x speedup in pair selection** for N > 50, plus slightly better convergence

### Priority 3: Top-k Mode (moderate ROI, low effort)
Add optional `topK` parameter:
- Track an "active set" of items not yet eliminated
- Eliminate items whose BT upper confidence bound < k-th best lower confidence bound
- `SelectNextPair` only considers pairs in the active set
- Return early when |active set| = k
- **Expected saving: 50-70% fewer comparisons** when only top-k matters

### Priority 4: Hodge Intransitivity Metric (low immediate ROI, interesting diagnostic)
Add a `HodgeDecomposition` function:
- Decompose the comparison flow into gradient + curl + harmonic
- Report `intransitivity_ratio = ||curl|| / ||total||` as a diagnostic
- If ratio > 0.2, warn that preferences may be genuinely cyclic (no consistent ranking exists)
- This integrates with the existing convergence diagnostics (IG threshold)

---

## Sources

### T1 (Peer-reviewed)
- Sauer, Cseh & Lenzner (2022). "Improving ranking quality and fairness in Swiss-system chess tournaments." EC 2022. ~28 cit (S2).
- Csato (2015). "On the ranking of a Swiss system chess team tournament." Annals of Operations Research. ~81 cit (S2).
- Maystre & Grossglauser (2017). "Just Sort It!" ICML 2017. High-impact.
- Heckel, Shah, Ramchandran & Wainwright (2019). "Active ranking from pairwise comparisons and when parametric assumptions don't help." Annals of Statistics. ~110 cit (S2).
- Shah, Balakrishnan et al. (2016). "Stochastically transitive models for pairwise comparisons." ICML 2016.
- Jiang, Lim, Yao & Ye (2011). "Statistical ranking and combinatorial Hodge theory." Mathematical Programming. ~300+ cit.
- Chen & Suh (2015). "Spectral MLE: Top-K Rank Aggregation from Pairwise Comparisons." ICML 2015. ~146 cit (S2).
- Chen, Fan, Ma & Wang (2019). "Spectral Method and Regularized MLE Are Both Optimal for Top-K Ranking." Annals of Statistics. ~125 cit (S2).
- Hendrickx & Olshevsky (2019). "Graph resistance and learning from pairwise comparisons." ICML 2019.
- Ailon (2012). "An Active Learning Algorithm for Ranking from Pairwise Preferences with Almost Optimal Query Complexity." JMLR.
- Mohajer, Suh & Elmahdy (2017). "Active Learning for Top-K Ranking from Noisy Comparisons." ICML 2017.
- Ren, Liu & Shroff (2018). "PAC Ranking from Pairwise and Listwise Queries." arXiv/NeurIPS.
- Li, Mantiuk et al. (2018). "Hybrid-MST: A hybrid active sampling strategy for pairwise preference aggregation." NeurIPS 2018.

### T2 (arXiv preprints with strong venue trajectory)
- Li et al. (2024/2025). "K-Sort Arena: Efficient and Reliable Benchmarking." CVPR 2025. arXiv:2408.14468.
- Csato & Krumer (2024). "Swiss-system chess tournaments and unfairness." arXiv:2410.19333.
- El Ferchichi, Lerasle & Perchet (2024). "Active ranking and matchmaking, with perfect matchings." ICML 2024.
- Morel-Balbi & Kirkley (2025). "Estimation of partial rankings from sparse, noisy comparisons." Communications Physics.

### T7 (Background)
- Wikipedia: Swiss-system tournament; Bradley-Terry model.
