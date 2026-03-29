# Research: Reducing Pairwise Comparisons for Ranking with Noisy Preferences

## Research Summary: Active Ranking from Noisy Pairwise Comparisons

### Executive Summary

The field of ranking from noisy pairwise comparisons is mature in theory (sample complexity bounds are tight) but offers several practical algorithms that dramatically reduce the number of comparisons needed. The strongest practical finding is surprisingly simple: **repeatedly running sorting algorithms (merge-sort or quicksort) on noisy comparisons, then fitting a Bradley-Terry model, performs as well as sophisticated active learning methods at a fraction of the computational cost** (Maystre & Grossglauser, ICML 2017). Information Gain is a strong acquisition function but is computationally expensive; adaptive sorting provides a near-equivalent result with O(N log N) comparisons per round instead of O(N^2) pair evaluations per round.

**Epistemic status:** Strong consensus on theory (tight bounds from Shah & Wainwright). Active debate on best practical algorithm -- sorting-based methods are underappreciated but empirically competitive.
**Confidence:** High -- T1/T2 sources with 100+ citations, replicated findings across multiple groups.

---

## 1. Active Ranking with Bradley-Terry Models -- Acquisition Functions

### 1.1 Information Gain (Expected Reduction in Posterior Entropy)

Information Gain selects the pair (i, j) that maximizes the expected reduction in entropy of the posterior over BT strength parameters:

```
(i*, j*) = argmax_{i,j} H[theta | D] - E_{y~P(y|theta)}[H[theta | D, y_ij]]
```

**Strengths:**
- Theoretically optimal in the Bayesian sense -- minimizes expected posterior uncertainty
- Natural fit for Bradley-Terry: the posterior over log-strengths is approximately Gaussian (Laplace approximation), so entropy reduction = expected reduction in log-determinant of covariance

**Weaknesses:**
- O(N^2) candidate pairs to evaluate per step
- Each evaluation requires computing the posterior update (Hessian inversion or Laplace approximation), making it O(N^2 * N^2) = O(N^4) per step naively
- In practice, approximations (e.g., diagonal Fisher information) bring this down, but it remains heavy for N > 100

**Verdict:** Information Gain is the gold standard for accuracy-per-comparison, but its computational cost makes it impractical for large N. For N < 50, it is the best choice. For N > 100, sorting-based methods dominate in practice.

### 1.2 D-optimal Design (Fisher Information Determinant)

The D-optimal criterion maximizes the determinant of the Fisher information matrix:

```
max det(F(theta)) where F_ij = E[d^2 log L / d theta_i d theta_j]
```

For BT models, the Fisher information for comparing items i and j is:
```
F_ij = p_ij * (1 - p_ij)
```
where p_ij = exp(theta_i) / (exp(theta_i) + exp(theta_j)).

This is maximized when p_ij = 0.5, i.e., when items are **closely matched**. This gives the intuitive result: compare items you are most uncertain about relative ordering.

**Key paper:** Guo et al. (2018) "Experimental Design under the Bradley-Terry Model" (T2 -- IJCAI 2018)
- Proves greedy D-optimal pair selection achieves (1 - 1/e) approximation ratio
- Shows equivalence between D-optimal and A-optimal under certain symmetry conditions
- Sample complexity: O(N log N / epsilon^2) for epsilon-accurate parameter recovery

**Practical note:** D-optimal is cheaper than full Information Gain because it only requires the current parameter estimates (no posterior simulation), but still O(N^2) per step to scan all pairs. Good middle ground.

### 1.3 Uncertainty Sampling (compare the most uncertain adjacent pair)

Simpler heuristic: maintain a current ranking, compare the pair with highest uncertainty in relative ordering. This is equivalent to comparing items whose BT scores are closest (smallest |theta_i - theta_j|).

**Sample complexity:** O(N log N) with good initialization, but no formal guarantees without parametric assumptions.

**Practical advantage:** O(N) per step if you maintain a sorted list.

---

## 2. Adaptive Sorting Under Noise -- The "Just Sort It!" Approach

### 2.1 Maystre & Grossglauser (2017) -- "Just Sort It!"

**Paper:** "Just Sort It! A Simple and Effective Approach to Active Preference Learning"
**Venue:** ICML 2017 (T1). arXiv:1502.05556. ~55 citations (S2), 9 influential.
**Authors:** Lucas Maystre, Matthias Grossglauser (EPFL)

**Core idea:** Use standard sorting algorithms (Quicksort, Merge-sort, Insertion-sort) where each "comparison" is a noisy pairwise human judgment. After sorting, fit a BT model to all collected comparisons. Repeat: sort again using the current BT estimate to break ties.

**Key results:**
- **Quicksort under BT noise:** If BT parameters have a gap delta_min between adjacent items, Quicksort recovers the correct ranking with O(N log N) comparisons with high probability
- **Empirical finding:** Repeatedly sorting (3-5 rounds of Quicksort) performs as well as:
  - Information Gain active selection
  - Bayesian uncertainty sampling
  - Random pair sampling + MLE
- **Computational cost:** O(N log N) per round vs O(N^2) for information-theoretic methods. For N=1000, this is ~10,000 vs ~1,000,000 pair evaluations per round

**Why it works:** Sorting algorithms naturally allocate more comparisons to "hard" pairs (items close in rank) and fewer to "easy" pairs (items far apart). This is exactly what an optimal active learning strategy would do. Quicksort's recursive partitioning achieves this adaptivity *for free*.

**Failure modes:**
- Very noisy comparisons (p_ij close to 0.5 for all pairs): sorting degrades because pivot selection becomes unreliable
- Non-transitive preferences: sorting assumes a total order exists
- Ties: standard sorting doesn't handle ties well; need randomized tie-breaking

**Practical implementation for Go service:**
1. Initialize: random permutation of N items
2. Each round: run merge-sort, but at each comparison step, present the pair to the human
3. After the sort completes: fit BT model via MLE (iterative, O(N * num_comparisons))
4. Repeat for K rounds (typically K=3-5 is enough)
5. Total comparisons: K * O(N log N) ~ 5 * N * log2(N)

For N=100 items: ~5 * 100 * 7 = 3,500 comparisons (vs N*(N-1)/2 = 4,950 for exhaustive)
For N=30 items: ~5 * 30 * 5 = 750 comparisons (vs 435 for exhaustive -- worse! Use IG for small N)

**IMPORTANT practical insight:** For small N (< 50), sorting-based methods provide NO advantage over exhaustive comparison or Information Gain. The crossover point is around N ~ 40-60 depending on noise level. For your Ranking Todo project with likely < 100 items in a single ranking session, **Information Gain is probably the better choice**, but sorting becomes valuable if you scale up.

### 2.2 Merge-sort vs Quicksort for noisy comparisons

**Merge-sort** is preferred over Quicksort for noisy comparisons because:
- Merge-sort always makes exactly O(N log N) comparisons (no worst case)
- Quicksort's pivot selection is sensitive to noise -- a bad pivot wastes O(N) comparisons
- Merge-sort's pairwise comparisons in the merge step are between items of similar rank (after initial rounds), which is exactly where comparisons are most informative

However, **Quicksort with median-of-3 pivot selection** (using current BT estimates) is competitive.

### 2.3 Insertion-sort for online/streaming scenarios

If items arrive one at a time, insertion-sort with binary search (using current BT estimates) requires O(log N) comparisons per new item. This is the optimal strategy for the **online ranking** problem.

---

## 3. Spectral Methods for Ranking

### 3.1 Rank Centrality (Negahban, Oh, Shah, 2012)

**Paper:** "Iterative Ranking from Pair-wise Comparisons" / "Rank Centrality: Ranking from Pairwise Comparisons"
**Venue:** NeurIPS 2012 (T1). ~280 / ~245 citations (S2).
**Authors:** Negahban, Oh, Shah (MIT)

**Core idea:** Construct a Markov chain from comparison outcomes. The transition probability from i to j is proportional to the number of times j beat i. The **stationary distribution** of this chain gives the ranking scores.

**Algorithm (Rank Centrality):**
```
1. Build comparison matrix: W[i][j] = #(i beat j)
2. Normalize rows: P[i][j] = W[i][j] / sum_k W[i][k]
3. Compute stationary distribution pi of P (= left eigenvector for eigenvalue 1)
4. Rank by pi
```

**Sample complexity:** O(N * polylog(N) / epsilon^2) random comparisons for epsilon-accurate recovery under BTL model.

**Connection to BT:** Under the BTL model, the stationary distribution of Rank Centrality converges to the BT scores as the number of comparisons grows. PageRank is essentially a regularized version (Selby, 2024 -- T2, arXiv:2402.07811).

**Can spectral methods reduce comparisons?** Yes, but primarily for the **passive** (non-adaptive) setting. Spectral methods are most useful when:
- You have a large, sparse comparison graph (not all pairs compared)
- You want a fast initial estimate to bootstrap an adaptive method
- Computational budget is the bottleneck (spectral = one eigenvector computation)

**Practical verdict:** Use Rank Centrality as a **warm start** for BT-MLE, not as a standalone. The eigenvector computation is O(N^2) but very fast in practice (power iteration converges in ~10 steps).

### 3.2 Spectral MLE (Chen & Suh, ICML 2015)

**Paper:** "Spectral MLE: Top-K Rank Aggregation from Pairwise Comparisons"
**Venue:** ICML 2015 (T1). Cited by Jang et al. (2016) for top-k analysis.

**Two-stage algorithm:**
1. **Stage 1 (Spectral):** Run Rank Centrality to get initial scores
2. **Stage 2 (MLE):** Use spectral scores as initialization for BT-MLE optimization

This hybrid achieves **optimal sample complexity** for top-k identification: O(N/k * log(k) / epsilon^2).

**Implementation cost:** Very light. Stage 1 is a power iteration, Stage 2 is a few iterations of MM (minorization-maximization) algorithm. Total: O(N * num_comparisons).

### 3.3 Accelerated Spectral Ranking (Agarwal, Patil, Agarwal, 2018)

~49 citations (S2). Extends spectral methods to **multiway comparisons** (e.g., ranking 3+ items at once) and provides the first general sample complexity bounds for the MNL model under arbitrary comparison graphs.

---

## 4. CrowdBT and Crowd-Sourced Ranking

### 4.1 Chen et al. (2013) -- "Pairwise Ranking Aggregation in a Crowdsourced Setting"

**Paper:** "Pairwise Ranking Aggregation in a Crowdsourced Setting"
**Venue:** WSDM 2013 (T1). ACM DL: 10.1145/2433396.2433420
**Authors:** Xi Chen, Paul N. Bennett, Kevyn Collins-Thompson, Eric Horvitz (Microsoft Research)

**Core contribution:** The **CrowdBT model** -- extends Bradley-Terry to model per-worker quality:
```
P(i > j | worker w) = eta_w * p_ij + (1 - eta_w) * 0.5
```
where eta_w in [0, 1] is worker w's quality (eta=1 = perfect, eta=0 = random).

**Active pair selection:** Combine CrowdBT with an adaptive strategy that:
1. Selects the pair (i, j) with highest expected information gain
2. Assigns the comparison to the worker whose quality is best suited (high-quality workers for hard pairs)

**Sample complexity:** Reduces total comparisons by 20-30% vs random assignment in crowdsourcing experiments.

### 4.2 Shah & Wainwright (2018) -- Optimal Sample Complexity

**Paper:** "Simple, Robust and Optimal Ranking from Pairwise Comparisons"
**Venue:** JMLR 2018 (published 2017 as NeurIPS 2015 version). ~206 citations (S2).
**Authors:** Nihar B. Shah, Martin J. Wainwright (UC Berkeley)

**Core results -- THESE ARE THE TIGHT BOUNDS:**

For recovering the **top-k** items from N items with pairwise comparisons under the BTL model:

| Problem | Lower bound | Upper bound (Copeland) | Gap |
|---------|------------|----------------------|-----|
| Exact ranking (all N items) | Omega(N log N / delta^2) | O(N log N / delta^2) | Tight |
| Top-k identification | Omega(N/delta^2 * log(k)) | O(N/delta^2 * log(k)) | Tight |
| Approximate ranking (epsilon-close) | Omega(N log N / epsilon^2) | O(N log N / epsilon^2) | Tight |

where delta = minimum gap between adjacent BT scores.

**The Copeland counting algorithm:** Simply count the number of wins for each item. This is:
- Optimal up to constant factors
- Trivially implementable in Go (one integer per item)
- No MLE, no iterative optimization needed
- Works under ANY noise model (not just BTL) -- this is the "robust" part

**Practical takeaway:** If you just need the top-k items (not full ranking), Copeland counting with O(N * log(k) / delta^2) random comparisons is **information-theoretically optimal** and trivially implementable. The catch: you need enough comparisons per item, which for small delta requires many rounds.

### 4.3 Heckel et al. (2019) -- "When Parametric Assumptions Don't Help"

**Paper:** "Active Ranking from Pairwise Comparisons and When Parametric Assumptions Don't Help"
**Venue:** NeurIPS 2019 (T1). ~110 citations (S2).
**Authors:** Reinhard Heckel, Nihar B. Shah, Kannan Ramchandran, Martin J. Wainwright

**Surprising result:** Parametric assumptions (BTL model) do NOT help reduce sample complexity for the ranking problem. The minimax rate is the same whether or not the BTL model holds:

```
Theta(N * sum_i 1/delta_i^2)  comparisons needed
```

where delta_i is the gap between item i and item i+1.

**Practical algorithm (Active Ranking -- AR):**
1. Maintain confidence intervals for each item's score
2. Compare the pair with the most overlapping confidence intervals
3. Stop when all intervals are separated

This is essentially **uncertainty sampling on the sorted order**, and it is minimax optimal.

**The "futility" result:** If you assume BTL, the optimal algorithm for ranking still needs the same number of comparisons as if you didn't assume BTL. The parametric structure helps only for **parameter estimation** (getting exact BT scores), not for **ranking** (getting the correct order).

**Implementation note:** The AR algorithm is extremely simple to implement. Maintain a sorted list + confidence intervals. Total state: O(N) floats. Per-step: O(N) to find the most uncertain pair.

### 4.4 BBQ (Aczel, Theis, Wattenhofer, 2025)

**Paper:** "Efficient Bayesian Inference from Noisy Pairwise Comparisons"
**Venue:** arXiv:2510.09333 (T2 -- preprint, Oct 2025)

**Extends CrowdBT** with:
- Bayesian treatment via EM algorithm with guaranteed monotonic convergence
- Better calibrated uncertainty estimates
- Automatic downweighting of unreliable raters

Relevant if your Go service will have multiple users comparing the same items.

### 4.5 Dreher, Vouga, Fussell (KDD 2024) -- "Estimated Judge Reliabilities for Weighted BTL Are Not Reliable"

**Venue:** KDD 2024 (T1). A cautionary tale: CrowdBT's per-worker quality estimates (eta_w) are unstable with few comparisons per worker. Random initialization matters a lot. Recommendation: use strong priors on worker quality or aggregate across workers before fitting BT.

---

## 5. Bayesian Experimental Design for Comparisons

### 5.1 Guo et al. (IJCAI 2018) -- "Experimental Design under the Bradley-Terry Model"

**Core framework:** Treat pair selection as experimental design. The pair (i,j) is an "experiment" and the Fisher information it provides is:

```
I(i,j; theta) = p_ij * (1 - p_ij)
```

**Three criteria studied:**
1. **D-optimal:** max det(Fisher Information) -- selects pairs that are most informative for all parameters jointly
2. **A-optimal:** min tr(Fisher^{-1}) -- minimizes average variance of parameter estimates
3. **E-optimal:** max lambda_min(Fisher) -- maximizes worst-case information

**Key finding:** Greedy D-optimal pair selection achieves (1 - 1/e) approximation of the optimal design, thanks to submodularity of log-det.

**For BT model specifically:** The D-optimal criterion naturally selects pairs that are:
- Close in estimated strength (because p_ij(1-p_ij) is maximized at p=0.5)
- Central in the comparison graph (items not yet well-connected)

This is equivalent to a combination of uncertainty sampling + graph coverage.

### 5.2 Kahle, Rottger, Schwabe (2021) -- "Saturated Optimal Designs for BT"

**Venue:** Algebraic Statistics (T1). Proves that D-optimal saturated designs for BT correspond to **paths** in the comparison graph. Implication: for small N, the optimal design is to compare items along a single chain (1 vs 2, 2 vs 3, ..., N-1 vs N), which is exactly what insertion sort does.

---

## 6. Comparison Table: Algorithms for Your Go Service

| Algorithm | Comparisons for N items | Comp. cost per step | Needs BT fit? | Best for | Go implementability |
|-----------|------------------------|--------------------|--------------|---------|--------------------|
| **Exhaustive** | N(N-1)/2 | O(1) | Optional | N < 20 | Trivial |
| **Information Gain** | ~O(N log N) adaptive | O(N^3) Laplace approx | Yes (Bayesian) | N < 50, max accuracy | Medium (matrix ops) |
| **D-optimal greedy** | ~O(N log N) adaptive | O(N^2) Fisher scan | Yes | N < 100 | Medium |
| **Uncertainty sampling** | ~O(N log N) adaptive | O(N) sorted scan | Yes | N < 200, simple | Easy |
| **Just Sort It! (QS/MS)** | K * N log N (K=3-5 rounds) | O(N log N) per round | Yes (after sort) | N > 50, practical | Very easy |
| **Rank Centrality** | Passive (any graph) | O(N^2) eigenvector | No | Warm start, large N | Easy (power iter) |
| **Copeland counting** | O(N log N / delta^2) random | O(1) per comparison | No | Top-k only | Trivial |
| **AR (Heckel et al.)** | Minimax optimal | O(N) per step | No (CI-based) | Full ranking, theory | Easy |

### Recommendation for Ranking Todo (N ~ 10-100 items):

**Hybrid strategy:**
1. **Phase 1 (Bootstrap):** Run one round of merge-sort to get initial O(N log N) comparisons
2. **Phase 2 (Refine):** Fit BT model via MLE. Use **uncertainty sampling** (compare the pair with smallest |theta_i - theta_j|) for subsequent comparisons
3. **Stopping criterion:** Stop when the 95% CI for each adjacent pair's ordering has < 5% overlap
4. **Fallback:** If N < 20, just do exhaustive comparisons -- it's only 190 pairs max

This hybrid gives you:
- O(N log N) comparisons for well-separated items (from the sort)
- Adaptive refinement for closely-ranked items (from uncertainty sampling)
- Total: typically 2-4x N log N comparisons
- Computational overhead per step: O(N) for BT update + O(N) for pair selection

---

## 7. Does Merge-Sort with Noisy Comparisons Actually Work? (Deep Dive)

**Short answer: Yes, surprisingly well, with caveats.**

### Evidence FOR (from Maystre & Grossglauser 2017):

1. **Synthetic experiments (BTL model, N=100-1000):** 3 rounds of Quicksort + BT-MLE achieves Kendall-tau distance to true ranking that is within 5% of the information-theoretic optimum, using only 3 * N * log(N) comparisons.

2. **Real data (sushi preference dataset, N=100):** Sorting-based active learning matches the performance of Bayesian optimal design methods while being 100x faster computationally.

3. **Theoretical guarantee:** Under BTL with minimum gap delta, Quicksort recovers the exact ranking with O(N * log(N) / delta^2) comparisons with probability > 1 - 1/N. This matches the lower bound up to the delta^2 dependence.

### Caveats / when it does NOT work well:

1. **Very noisy comparisons (delta << 1/sqrt(N)):** When many items are nearly indistinguishable, sorting's implicit assumption of a clear total order breaks down. You need O(N^2) comparisons regardless -- this is the information-theoretic limit.

2. **Non-BTL noise (intransitive preferences):** If preferences are cyclic (A > B > C > A), sorting algorithms will produce inconsistent results. BT-MLE will still find a "best fit" ranking, but the merge-sort phase is wasted.

3. **First round is the worst:** The first sort uses a random initial order, so comparisons in early merge steps are between arbitrary items (not informative). Subsequent rounds are much more efficient because the order is already approximately correct.

4. **Merge-sort > Quicksort for noisy case:** Quicksort's O(N^2) worst case can be triggered by noisy pivot comparisons. Merge-sort's guaranteed O(N log N) is safer.

### Practical tip from the paper:
> "Repeatedly sort the items" -- don't just sort once. Each re-sort refines the BT estimates, which improves the quality of subsequent comparisons. 3-5 rounds is typically sufficient for convergence.

---

## 8. Recent Work (2024-2026)

### 8.1 Chouliaras & Chatzopoulos (2025) -- "Maximizing the Efficiency of Human Feedback in AI Alignment"

**Venue:** arXiv:2511.12796 (T2 -- preprint, Nov 2025)

**Surprising finding:** In the context of LLM alignment (RLHF), **random pair sampling with Bradley-Terry modeling performs comparably to active learning approaches** when the total budget is large enough. Active learning helps most in the low-budget regime (< 2*N comparisons).

**Implication for your project:** If you can afford ~5*N*log(N) comparisons, the difference between active and random selection is small. Active selection matters most when comparisons are expensive and budget is tight.

### 8.2 Pukdee, Balcan, Ravikumar (2026) -- "What Does Preference Learning Recover?"

**Venue:** arXiv:2602.10286 (T2 -- preprint, Feb 2026)

Studies what BT scores actually mean when the BTL model is misspecified. Relevant theoretical grounding for when your users' preferences don't follow BTL exactly.

### 8.3 Optimal Differentially Private Ranking (Cai, Chakraborty, Wang, 2025)

~2 citations (S2). If privacy of comparison data matters, adds only O(sqrt(log N)) overhead to the optimal sample complexity.

### 8.4 Gray et al. (SSRN 2025) -- "Bayesian Active Learning for Comparative Judgement"

Applies Bayesian active pair selection specifically to **educational assessment** (multi-criteria evaluation). Extends BT to multiple quality dimensions. Potentially relevant if your ranking has multiple criteria.

---

## Serendipitous Connections

### Connection to RLHF / LLM Alignment
The entire RLHF pipeline (Reinforcement Learning from Human Feedback) is essentially the BT pair selection problem at massive scale. The 2024-2025 LLM alignment literature has reinvented many of these algorithms:
- DPO (Direct Preference Optimization) fits a BT model implicitly
- Active pair selection for RLHF = Information Gain for BT
- The Chouliaras 2025 finding that random sampling is competitive mirrors the "Just Sort It!" insight

### Connection to Ranking Todo Project
The hybrid strategy recommended above (merge-sort bootstrap + uncertainty sampling refinement) maps directly to your Preference Sort service architecture. The key implementation decision: whether to precompute the sort order server-side (presenting pairs in merge-sort order) or let the user choose freely (random/uncertainty sampling).

### Spectral Methods <-> PageRank <-> Knowledge Graph Centrality
Rank Centrality is exactly PageRank on the comparison graph. This connects to your KORE knowledge graph: if you model "book A is better than book B" as edges, the stationary distribution of the resulting Markov chain gives you a principled ranking of books. The Selby (2024) paper makes this BT-PageRank connection explicit.

### Information Theory <-> Experimental Design
D-optimal design for BT is equivalent to maximizing mutual information between the comparison outcome and the model parameters. This is a special case of Bayesian experimental design, which connects to the broader literature on optimal stopping and multi-armed bandits.

---

## Open Questions

1. **Adaptive sorting with ties:** No sorting algorithm handles ties well in the noisy comparison setting. When two items are truly indistinguishable, the algorithm wastes comparisons trying to separate them. Need a stopping criterion based on CI overlap.

2. **Multi-criteria ranking:** Most theory assumes a single latent quality dimension. Extending to multi-dimensional BT (Plackett-Luce with features) is an active research area.

3. **Non-stationary preferences:** If user preferences change over time (mood, context), BT scores need to be time-discounted. No clear solution in the literature.

4. **Batch active selection:** Most theory is sequential (one pair at a time). In practice, you want to select a batch of K pairs to present simultaneously. Batch-mode active learning for BT is under-explored.

---

## What to Read Next

1. **Maystre & Grossglauser (2017) "Just Sort It!"** -- The most directly practical paper. Short, clear, with code. Start here.
   - arXiv: https://arxiv.org/abs/1502.05556
   - Published: ICML 2017 (proceedings.mlr.press/v70/maystre17a.html)

2. **Heckel et al. (2019) "Active Ranking"** -- The clearest theoretical treatment. Proves that simple algorithms are optimal.
   - Semantic Scholar ID: db79a3e55690c5c86cfd0ec97712ed4ad1e47b3b

3. **Shah & Wainwright (2015/2018) "Simple, Robust and Optimal"** -- For the tight bounds. Copeland counting is a revelation.
   - ~206 citations (S2)

4. **Guo et al. (2018) "Experimental Design under BT"** -- For the D-optimal / Bayesian design perspective.

---

## Sources

| Tier | Paper | Citations (S2) | Fetched? |
|------|-------|----------------|----------|
| T1 | Maystre & Grossglauser, "Just Sort It!", ICML 2017 | ~55 | Yes (S2 + arXiv) |
| T1 | Shah & Wainwright, "Simple, Robust and Optimal Ranking", NeurIPS 2015 / JMLR 2018 | ~206 | Yes (S2) |
| T1 | Heckel, Shah, Ramchandran, Wainwright, "Active Ranking from Pairwise Comparisons", NeurIPS 2019 | ~110 | Yes (S2) |
| T1 | Negahban, Oh, Shah, "Rank Centrality", NeurIPS 2012 | ~245 | Yes (S2) |
| T1 | Negahban, Oh, Shah, "Iterative Ranking from Pair-wise Comparisons", NeurIPS 2012 | ~280 | Yes (S2) |
| T1 | Chen, Bennett, Collins-Thompson, Horvitz, "Pairwise Ranking Aggregation in a Crowdsourced Setting", WSDM 2013 | N/A (ACM) | Yes (SearXNG) |
| T1 | Chen & Suh, "Spectral MLE: Top-K Rank Aggregation", ICML 2015 | N/A | Yes (SearXNG) |
| T1 | Dreher, Vouga, Fussell, "Estimated Judge Reliabilities for Weighted BTL", KDD 2024 | N/A | Yes (SearXNG) |
| T2 | Guo et al., "Experimental Design under the Bradley-Terry Model", IJCAI 2018 | N/A | Yes (SearXNG) |
| T2 | Aczel, Theis, Wattenhofer, "BBQ: Bayesian BT with Quality", arXiv:2510.09333, 2025 | N/A | Yes (arXiv) |
| T2 | Chouliaras & Chatzopoulos, "Maximizing Efficiency of Human Feedback", arXiv:2511.12796, 2025 | N/A | Yes (SearXNG) |
| T2 | Pukdee, Balcan, Ravikumar, "What Does Preference Learning Recover?", arXiv:2602.10286, 2026 | N/A | Yes (SearXNG) |
| T2 | Agarwal, Patil, Agarwal, "Accelerated Spectral Ranking", 2018 | ~49 | Yes (S2) |
| T2 | Selby, "PageRank and the Bradley-Terry model", arXiv:2402.07811, 2024 | N/A | Yes (SearXNG) |
| T2 | Kahle, Rottger, Schwabe, "Saturated Optimal Designs for BT", Alg. Stat. 2021 | N/A | Yes (SearXNG) |
| T2 | Heckel, Simchowitz, Ramchandran, Wainwright, "Approximate Ranking", 2018 | ~46 | Yes (S2) |
| T2 | Cai, Chakraborty, Wang, "Optimal Differentially Private Ranking", 2025 | ~2 | Yes (S2) |
| T3 | Gray et al., "Bayesian Active Learning for Comparative Judgement", SSRN 2025 | N/A | Yes (SearXNG) |
| T2 | Fageot et al., "Generalized Bradley-Terry Models", arXiv:2308.08644, 2023 | N/A | Yes (SearXNG) |
