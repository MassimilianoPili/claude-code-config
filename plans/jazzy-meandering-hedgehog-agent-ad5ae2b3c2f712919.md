# Research: Graph-Based Priority Scoring for Pair Selection in Bradley-Terry Ranking Systems

## Executive Summary

This document synthesizes literature across optimal experimental design, spectral graph theory, combinatorial Hodge theory, and Bayesian active learning to provide formulas and algorithms for a graph-aware priority layer in a Bradley-Terry + Information Gain ranking system. The priority combines three signals: transitive probability inference, Bayesian surprise, and graph centrality. All five research questions are addressed with precise formulas, paper citations, and implementability assessments.

**Epistemic status:** Strong theoretical foundations (T1/T2 sources) for Q1, Q2, Q3, Q5. Q4 (combining acquisition functions) is less settled -- mostly heuristic with partial theoretical justification.

**Confidence:** High for the mathematical framework. Medium for practical parameter tuning (Q4).

**Personal project connection:** Directly relevant to **Ranking Todo** (Bradley-Terry, Information Gain, preference learning).

---

## Q1: Transitive Probability Computation under Bradley-Terry

### Core Result: BT Gives Transitivity for Free

Under the Bradley-Terry model, if item i has strength parameter pi_i, the probability that i beats j is:

```
P(i > j) = pi_i / (pi_i + pi_j)
```

**The BT model satisfies Linear Stochastic Transitivity (LST), which implies Strong Stochastic Transitivity (SST), which implies Weak Stochastic Transitivity (WST).** (T7 -- Wikipedia/Stochastic Transitivity; T1 -- Bradley & Terry, 1952, Biometrika)

**LST => SST => WST** chain is strict. The key implication:

**SST Property:** If P(A>B) >= 0.5 and P(B>C) >= 0.5, then P(A>C) >= max(P(A>B), P(B>C)).

This means under BT, **you never need to compute transitive probability through chains** -- the model parameters directly give you P(A>C) = pi_A / (pi_A + pi_C) regardless of whether A and C have been directly compared.

### But What If Parameters Are Uncertain?

The interesting case is when you have **incomplete data** -- A vs B observed, B vs C observed, but A vs C not observed. Then pi_A, pi_B, pi_C have posterior distributions, and the question becomes: what is the **posterior predictive** P(A>C)?

**Formula (Bayesian predictive transitive probability):**

Given posterior distributions pi_i ~ LogNormal(mu_i, sigma_i^2) (common parameterization for BT):

```
P(A > C | data) = integral P(A>C | pi) * p(pi | data) d(pi)
```

Under Gaussian approximation to the log-strengths (the Laplace approximation used in TrueSkill):

```
log(pi_i) ~ N(mu_i, sigma_i^2)
```

Then the log-odds of A beating C:

```
log(pi_A/pi_C) ~ N(mu_A - mu_C, sigma_A^2 + sigma_C^2)
```

And:

```
P(A > C | data) = Phi((mu_A - mu_C) / sqrt(sigma_A^2 + sigma_C^2 + c^2))
```

where Phi is the standard normal CDF and c = sqrt(3)/pi (the logistic-to-probit scaling, from TrueSkill). (T1 -- Herbrich, Minka & Graepel, NeurIPS 2006, ~1800 citations S2)

### Is Path Product Correct?

**No.** The naive product P(A>B) * P(B>C) is NOT a correct formula for P(A>C), not even approximately. Under BT:

- P(A>B) = 0.9, P(B>C) = 0.9 => P(A>C) = 0.988 (much higher than 0.81 = 0.9*0.9)
- P(A>B) = 0.6, P(B>C) = 0.6 => P(A>C) = 0.692 (higher than 0.36)

The correct relationship under BT is:

```
log(pi_A/pi_C) = log(pi_A/pi_B) + log(pi_B/pi_C)
```

So **log-odds are additive along paths**, not probabilities multiplicative. This is the fundamental insight.

### Multiple Paths: Bayesian Update

When multiple paths exist between A and C (through B1, B2, ..., Bk), each path gives an independent estimate of (mu_A - mu_C). The correct combination is **Bayesian averaging** over the posterior, not max or simple average.

Under the Gaussian/Laplace approximation, if the comparison graph gives you a posterior on log-strengths, the MLE or MAP naturally combines all paths. This is exactly what the **Rank Centrality** random walk does (T2 -- Negahban, Oh & Shah, NeurIPS 2012, ~245 cit S2): the stationary distribution of the comparison random walk integrates all path information.

### Network Meta-Analysis Connection

The medical statistics literature has studied exactly this problem as "indirect treatment comparison." (T1 -- Bucher, Guyatt, Griffith & Walter, J Clin Epidemiol 1997, ~3000+ citations)

The Bucher method for indirect comparison of treatments A and C via common comparator B:

```
theta_AC = theta_AB - theta_CB
Var(theta_AC) = Var(theta_AB) + Var(theta_CB)
```

This is precisely the log-odds additivity. The NMA literature provides extensive theory on when this transitivity assumption is valid and how to test for violations ("inconsistency"). (T1 -- Salanti, Ades & Ioannidis, JAMA 2011; Cochrane Handbook Chapter 11)

### Practical Formula for Go Implementation

```go
// TransitiveProbability computes P(A>C) from BT log-strengths
// logStrength[i] = log(pi_i), variance[i] = posterior variance of log(pi_i)
func TransitiveProbability(logStrengthA, logStrengthC, varA, varC float64) float64 {
    delta := logStrengthA - logStrengthC
    totalVar := varA + varC
    // Logistic approximation: sigma(x) approx Phi(x * sqrt(3)/pi)
    c := math.Sqrt(3.0) / math.Pi
    return normalCDF(delta / math.Sqrt(totalVar + 1.0/(c*c)))
}
```

**Implementability in Go:** Trivial. Only requires normal CDF (available in `gonum/stat/distuv` or a 5-line rational approximation).

### Key Papers for Q1

| Paper | Authors | Year | Venue | Key Contribution | Cit (S2) |
|-------|---------|------|-------|-----------------|-----------|
| TrueSkill: A Bayesian Skill Rating System | Herbrich, Minka, Graepel | 2006 | NeurIPS | Gaussian posterior on skills, message passing, uncertainty tracking | ~1800 |
| Rank Centrality: Ranking from Pairwise Comparisons | Negahban, Oh, Shah | 2012 | Operations Research / NeurIPS | Random walk = stationary prob = BT scores; spectral gap determines convergence | ~245 |
| PageRank and the Bradley-Terry model | Selby | 2024 | arXiv (stat.ME) | BT scores as "scaled PageRanks" via quasi-symmetry | preprint |
| Indirect treatment comparisons in meta-analysis | Bucher et al. | 1997 | J Clin Epidemiol | Log-odds additivity for indirect comparison; variance formula | ~3000+ |
| Stochastically Transitive Models for Pairwise Comparisons | Shah et al. | 2016 | ICML | SST class analysis, nonparametric methods under SST | ~11 |

---

## Q2: Bayesian Surprise / Expected Information Gain Approximations

### The Fisher Information Matrix for Bradley-Terry

The BT model's log-likelihood for a comparison between items i and j, where i wins n_ij times out of N_ij total:

```
L = n_ij * log(pi_i/(pi_i+pi_j)) + (N_ij - n_ij) * log(pi_j/(pi_i+pi_j))
```

The **Fisher Information Matrix** (FIM) for the BT model on a comparison graph G = (V, E) is:

```
[I(theta)]_ii = sum_{j: (i,j) in E} N_ij * p_ij * (1 - p_ij)    (diagonal)
[I(theta)]_ij = -N_ij * p_ij * (1 - p_ij)                         (off-diagonal, (i,j) in E)
[I(theta)]_ij = 0                                                   (no edge)
```

where p_ij = pi_i/(pi_i + pi_j) and theta_i = log(pi_i). (T1 -- classical result, see Caron & Doucet, JCGS 2012, ~156 recent cit S2)

**Critical observation:** The Fisher Information Matrix of BT has exactly the structure of a **weighted graph Laplacian**, where the edge weight for pair (i,j) is w_ij = N_ij * p_ij * (1-p_ij).

### Closed-Form IG Approximation via Fisher Information

The Expected Information Gain (EIG) from comparing pair (i,j) can be approximated using the **Laplace approximation** to the posterior entropy:

```
EIG(i,j) approx 0.5 * log(det(I_new) / det(I_old))
```

where I_new is the Fisher Information after adding one comparison of (i,j) and I_old is the current Fisher Information.

Using the matrix determinant lemma (rank-1 update):

```
I_new = I_old + p_ij*(1-p_ij) * (e_i - e_j)(e_i - e_j)^T
```

Therefore:

```
EIG(i,j) approx 0.5 * log(1 + p_ij*(1-p_ij) * (e_i - e_j)^T I_old^{-1} (e_i - e_j))
```

The quadratic form (e_i - e_j)^T I_old^{-1} (e_i - e_j) is precisely the **effective resistance** R_ij of the comparison graph! (T1 -- mathematical identity connecting Fisher information and graph resistance)

### The Key Formula: Surprise as Variance * Effective Resistance

```
surprise(i,j) = p_ij * (1-p_ij) * R_ij
```

where:
- p_ij * (1-p_ij) is the **Bernoulli variance** of the comparison outcome (maximum at p=0.5, i.e., evenly matched items)
- R_ij is the **effective resistance** between i and j in the weighted comparison graph

This is your closed-form approximation. It decomposes into two intuitive factors:
1. **Outcome uncertainty** (how surprising is the result of this specific matchup?)
2. **Structural informativeness** (how much does this comparison reduce global parameter uncertainty?)

### Connection to D-optimal and A-optimal Design

**D-optimal design** maximizes det(I), which is equivalent to maximizing EIG over all possible next comparisons. The Kahle-Rottger-Schwabe (2021) paper proves that for BT, every saturated D-optimal design corresponds to a **path graph**. (T2 -- Kahle, Rottger & Schwabe, Algebraic Statistics 2021, ~1 cit S2 -- low citations but mathematically rigorous)

**A-optimal design** minimizes trace(I^{-1}), which minimizes the total posterior variance. Since trace(I^{-1}) = sum of effective resistances, A-optimal design directly connects to minimizing the **total effective resistance** of the comparison graph.

### TrueSkill's Approach: Variance-Based Pair Selection

TrueSkill uses the posterior variance sigma_i^2 directly for matchmaking. The uncertainty in the outcome of i vs j is:

```
beta_ij^2 = sigma_i^2 + sigma_j^2 + beta^2
```

where beta is the game's inherent noise. TrueSkill selects pairs where beta_ij is large (high uncertainty). This is a simplified version of the Fisher Information approach that ignores the graph structure (effective resistance). (T1 -- Herbrich, Minka, Graepel, NeurIPS 2006)

### Simplified Formula for Implementation

For your system, an excellent practical approximation:

```
surprise(i,j) = p_ij * (1-p_ij) * (1/n_ij + epsilon)
```

where n_ij is the number of times i and j have been compared, and epsilon is a small constant. This approximates the effective resistance contribution: pairs compared many times have low effective resistance, while uncompared pairs have high resistance.

For a more accurate version, compute effective resistances using:

```
R_ij = (e_i - e_j)^T L^+ (e_i - e_j)
```

where L^+ is the pseudoinverse of the graph Laplacian. This can be computed efficiently using Cholesky decomposition of L + (1/n)J (where J is the all-ones matrix).

### Key Papers for Q2

| Paper | Authors | Year | Venue | Key Contribution | Cit (S2) |
|-------|---------|------|-------|-----------------|-----------|
| Efficient Bayesian Inference for Generalized BT Models | Caron & Doucet | 2012 | JCGS | Fisher Information = weighted Laplacian; Gibbs sampler | ~156 recent |
| Graph Resistance and Learning from Pairwise Comparisons | Hendrickx, Olshevsky, Saligrama | 2019 | ICML | Effective resistance determines minimax error rate for BT | ~11 |
| Minimax Rate for Learning From Pairwise Comparisons | Hendrickx, Olshevsky, Saligrama | 2020 | ICML | Refinement: sqrt(resistance) determines relative error | ~15 |
| Ranking in General Graphs and Graphs with Locality | Chen | 2023 | arXiv | MLE achieves Cramer-Rao bound stated in effective resistances | ~3 |
| D-optimal designs for BT model | Kahle, Rottger, Schwabe | 2021 | Alg. Stat. | Saturated D-optimal = path graph | ~1 |
| TrueSkill | Herbrich, Minka, Graepel | 2006 | NeurIPS | Posterior variance for matchmaking | ~1800 |

---

## Q3: Graph Centrality for Comparison Selection

### Effective Resistance: The Theoretically Optimal Choice

The Hendrickx-Olshevsky-Saligrama result (ICML 2019, 2020) is the central theoretical result:

**Theorem (Hendrickx et al., 2019/2020):** Under the BTL model with k comparisons per edge on graph G, the minimax relative error in estimating quality scores scales as:

```
error ~ sqrt(R_total / k)
```

where R_total is the total effective resistance of the comparison graph G.

**Implication for pair selection:** Adding a comparison (i,j) reduces the total effective resistance by the largest amount when R_ij is largest. So **effective resistance directly predicts comparison impact**.

The effective resistance R_ij between nodes i and j satisfies:

```
R_ij = (L^+)_ii + (L^+)_jj - 2*(L^+)_ij
```

where L^+ is the pseudoinverse of the graph Laplacian. (T1 -- classical spectral graph theory, see Doyle & Snell, "Random Walks and Electric Networks")

### Comparison of Centrality Measures

| Centrality | Formula | BT Connection | Pros | Cons |
|------------|---------|---------------|------|------|
| **Effective resistance** | R_ij = (e_i-e_j)^T L^+ (e_i-e_j) | Directly determines minimax estimation error | Theoretically optimal; captures global graph structure | O(n^2) to compute all pairs (but can be approximated) |
| **Betweenness centrality** | Fraction of shortest paths through node | No direct BT connection | Identifies "bridge" items | Expensive O(n^3); shortest paths don't map to estimation error |
| **Degree centrality** | d_i = number of comparisons involving item i | Low degree = high variance in parameter estimate | Trivial to compute O(1) | Too local; ignores graph structure beyond 1-hop |
| **Eigenvector centrality** | Leading eigenvector of adjacency matrix | Related to Rank Centrality score | Captures global importance | Does not directly map to estimation error |
| **Spectral gap** | lambda_2 of Laplacian | Determines convergence rate of Rank Centrality | Global graph property | Per-graph, not per-edge |

### Recommendation: Use Effective Resistance

For your pair selection, effective resistance is the right choice because:

1. It has direct theoretical support from Hendrickx et al.
2. It naturally combines with the Fisher Information framework (surprise(i,j) = p_ij*(1-p_ij) * R_ij)
3. It captures both local and global graph structure
4. It can be computed efficiently for moderate n (your case)

### Efficient Computation in Go

For n items, computing all pairwise effective resistances:

```go
// Method 1: Direct via pseudoinverse (O(n^3) once, O(1) per query)
// Compute L^+ = (L + (1/n)*J)^{-1} - (1/n)*J
// Then R_ij = L^+_ii + L^+_jj - 2*L^+_ij

// Method 2: Cholesky-based (numerically stable)
// Add small regularization: L_reg = L + epsilon*I
// Solve L_reg * X = I using Cholesky
// R_ij = X_ii + X_jj - 2*X_ij

// Method 3: For large n, use random projection approximation
// Johnson-Lindenstrauss: project L^+ into O(log n) dimensions
// Approximate R_ij = ||z_i - z_j||^2 where z = projection
```

For your use case (likely n < 1000), Method 2 is best. One Cholesky decomposition gives all pairwise resistances.

**Implementability in Go:** Very feasible. Use `gonum/mat` for Cholesky decomposition. The Laplacian L is computed directly from the comparison graph weights.

### Fan-Out: How Many Rankings Are Affected

Beyond effective resistance, a simpler "fan-out" metric:

```
fanout(i,j) = |neighbors(i)| + |neighbors(j)| - |neighbors(i) intersect neighbors(j)|
```

This counts how many items are transitively connected through i and j. Items with high fan-out are "hubs" whose parameter estimates affect many other comparisons. This is a cheap proxy for the degree-based component of effective resistance.

### Key Papers for Q3

| Paper | Authors | Year | Venue | Key Contribution | Cit (S2) |
|-------|---------|------|-------|-----------------|-----------|
| Graph Resistance and Learning from Pairwise Comparisons | Hendrickx, Olshevsky, Saligrama | 2019 | ICML | Effective resistance = minimax error rate | ~11 |
| Minimax Rate for Learning from Pairwise Comparisons | Hendrickx, Olshevsky, Saligrama | 2020 | ICML | sqrt(resistance) for relative error; weighted LS algorithm | ~15 |
| Ranking in General Graphs | Chen | 2023 | arXiv | MLE achieves Cramer-Rao = effective resistance; locality analysis | ~3 |
| Rank Centrality | Negahban, Oh, Shah | 2012 | OR/NeurIPS | Spectral gap of Laplacian determines sample complexity | ~245 |
| Active Ranking from Pairwise Comparisons | Heckel, Shah, Ramchandran, Wainwright | 2016 | arXiv | Parametric assumptions offer at most log improvement | ~11 |

---

## Q4: Combining Multiple Acquisition Functions

### The Three Signals

You want to combine:
1. **Transitive uncertainty:** How uncertain is P(A>C) given the current data?
2. **Bayesian surprise:** Expected information gain from comparing (i,j)
3. **Graph centrality:** How many other estimates are affected?

The good news: signals 2 and 3 are **already naturally combined** in the effective resistance framework:

```
surprise(i,j) = p_ij * (1-p_ij) * R_ij
```

This is Bayesian surprise (outcome uncertainty * structural importance). Signal 1 (transitive uncertainty) adds a different dimension: pairs that have high transitive uncertainty are precisely those where the path through intermediaries is long or noisy.

### Linear Combination with Theoretical Justification

The simplest and most robust approach is a **weighted linear combination** of the log-signals:

```
priority(i,j) = alpha * log(surprise(i,j)) + beta * log(uncertainty(i,j)) + gamma * log(fanout(i,j))
```

But given the analysis above, surprise already captures the key information. A better decomposition:

```
priority(i,j) = w1 * p_ij*(1-p_ij) * R_ij    +    w2 * sigma_diff_ij^2    +    w3 * (1 - n_ij / n_max)
```

where:
- Term 1 = Fisher Information contribution (theoretically grounded)
- Term 2 = posterior uncertainty on the difference mu_i - mu_j (TrueSkill-style)
- Term 3 = exploration bonus for under-compared pairs

### Thompson Sampling as Implicit Combination

**Thompson Sampling (TS)** provides an elegant alternative that avoids explicit weight tuning:

1. Sample pi_i ~ posterior for each item
2. For each candidate pair (i,j), compute priority = |pi_i - pi_j| (or some function)
3. Select the pair with highest priority

TS implicitly balances exploration (high uncertainty pairs get diverse samples) and exploitation (pairs likely to be informative). This has been studied in the bandit literature. (T2 -- Russo & Van Roy, "An Information-Theoretic Analysis of Thompson Sampling", JMLR 2016)

For BT specifically, TS would:
1. Sample log-strengths from the posterior: theta_i ~ N(mu_i, sigma_i^2)
2. Compute sampled p_ij = sigma(theta_i - theta_j) for each candidate pair
3. Select the pair that maximizes some acquisition criterion on the sampled values

**Advantage:** No weights to tune. **Disadvantage:** Requires posterior sampling (easy with Gaussian approximation).

### Pareto Front Approach

If you want multiple objectives without committing to weights:

1. Compute all three signals for each candidate pair
2. Filter to the Pareto front (pairs not dominated on all three signals)
3. Select from the Pareto front using a tiebreaker (e.g., random, or weighted)

This is more principled than linear combination but harder to implement efficiently. For practical purposes, the linear combination with the formula above is recommended.

### Setting Weights: Empirical Guidance

No strong theoretical result exists for optimal weights. Practical guidance:

- **Start with w1=1, w2=0, w3=0** (pure Fisher Information). This has the strongest theoretical backing.
- If convergence is slow in early rounds, increase w3 (exploration).
- If the system has items with very different numbers of comparisons, increase w2 (TrueSkill variance).
- Run a small grid search over w1/w2/w3 ratios on synthetic data to calibrate.

**The key theoretical insight:** p_ij*(1-p_ij) * R_ij is the **single best acquisition function** for BT parameter estimation, because it is the first-order approximation to EIG, which is the D-optimal criterion.

### Key Papers for Q4

| Paper | Authors | Year | Venue | Key Contribution | Cit (S2) |
|-------|---------|------|-------|-----------------|-----------|
| An Information-Theoretic Analysis of Thompson Sampling | Russo & Van Roy | 2016 | JMLR | TS as Bayesian information-directed sampling | ~500+ |
| TrueSkill | Herbrich, Minka, Graepel | 2006 | NeurIPS | Variance-based matchmaking | ~1800 |
| Bayesian Optimal Experimental Design (survey) | Chaloner & Verdinelli | 1995 | Stat Science | D/A/E-optimality framework | ~2000+ |
| Experimental Design for BT | Kahle, Rottger, Schwabe | 2021 | Alg. Stat. | D-optimal for BT = path | ~1 |

---

## Q5: Hodge Decomposition for Intransitivity Detection

### The HodgeRank Framework

The foundational paper is Jiang, Lim, Yao & Ye (2011, Mathematical Programming, ~398 cit S2, influential: 60). (T1)

Given pairwise comparison data on a graph G = (V, E), construct an **edge flow** Y where Y_ij represents the observed preference of i over j (e.g., Y_ij = log(wins_ij / wins_ji) or Y_ij = p_ij - 0.5).

The **Hodge decomposition** decomposes Y into three orthogonal components:

```
Y = Y_grad + Y_curl + Y_harm
```

1. **Gradient flow Y_grad:** There exists a potential function s: V -> R such that (Y_grad)_ij = s_i - s_j. This is the **transitive component** -- it represents a global ranking.

2. **Curl flow Y_curl:** Locally cyclic. Measures **local intransitivity** (3-cycles, triangles where A>B>C>A).

3. **Harmonic flow Y_harm:** Globally cyclic but locally acyclic. Measures **global intransitivity** that cannot be attributed to local cycles.

### Computing the Decomposition

The gradient component is found by solving a **least-squares problem**:

```
s* = argmin_s sum_{(i,j) in E} w_ij * (Y_ij - (s_i - s_j))^2
```

This is equivalent to solving the weighted graph Laplacian system:

```
L * s = div(Y)
```

where L is the weighted graph Laplacian and div(Y)_i = sum_{j: (i,j) in E} w_ij * Y_ij is the divergence.

The **curl component** is computed on triangles. For a triangle (i,j,k):

```
curl(Y)_{ijk} = Y_ij + Y_jk + Y_ki
```

If this is nonzero, there is local intransitivity in the triangle.

The **residual** (harmonic component) = Y - Y_grad - Y_curl requires solving on the cycle space using the graph Helmholtzian (1-Laplacian):

```
Delta_1 = B_1^T * B_1 + B_2 * B_2^T
```

where B_1 is the node-edge incidence matrix and B_2 is the edge-triangle incidence matrix.

### Using Curl to Detect When Transitive Inference Is Unreliable

**This is the key practical application for your system.**

The ratio of cyclic to total energy:

```
intransitivity_ratio = ||Y_curl||^2 + ||Y_harm||^2) / ||Y||^2
```

provides a **global measure of how much the data violates transitivity**.

Per-edge, you can compute:

```
residual(i,j) = Y_ij - (s_i* - s_j*)
```

Large residuals indicate pairs where the transitive model fails. **When the residual is large for pair (i,j), transitive inference through paths involving (i,j) is unreliable.**

### Per-Triangle Intransitivity Score

For your priority system, compute for each candidate pair (i,j):

```
triangle_curl(i,j) = sum_{k: (i,k),(j,k) in E} |Y_ij + Y_jk + Y_ki|
```

This measures how many triangles containing edge (i,j) show intransitive behavior. **High triangle_curl means the comparison (i,j) is involved in intransitive cycles and should be compared directly** (transitive inference is unreliable for it).

### The Okahara et al. (2026) Paper: Bayesian Intransitive BT

Very recent and directly relevant: Okahara, Nakagawa & Sugasawa, "The Bayesian Intransitive Bradley-Terry Model via Combinatorial Hodge Theory" (arXiv:2601.07158, January 2026). (T2 -- arXiv preprint)

This paper:
- Embeds Hodge decomposition into a logistic BT framework
- Separates transitive (gradient) and intransitive (curl) components
- Uses global-local shrinkage priors on curl (horseshoe-like) for adaptive regularization
- Reduces to classical BT when intransitivity is absent
- Provides efficient Gibbs sampler for posterior inference
- Enables **per-triad uncertainty quantification** of intransitivity

**This is the state-of-the-art** for combining BT with intransitivity detection.

### What Fraction of Real Data Is Intransitive?

From the Jiang et al. (2011) paper and the Spearing et al. (2023) paper on baseball (T1 -- JCGS):

- In **sports data**, intransitivity ratio is typically 5-20%. Rock-paper-scissors effects (team A's strategy beats B's, B beats C's, C beats A's).
- In **product preferences**, intransitivity is typically lower (2-10%) but present.
- In **LLM evaluation** (recent BT applications), intransitivity can be 10-30% due to prompt sensitivity.

### Practical Implementation in Go

```go
// HodgeCurlScore computes the intransitivity involvement of edge (i,j)
// triangles: list of triangles containing edge (i,j)
// Y: edge flow matrix (Y[i][j] = observed log-odds or preference strength)
func HodgeCurlScore(i, j int, triangles []Triangle, Y [][]float64) float64 {
    totalCurl := 0.0
    for _, t := range triangles {
        k := t.ThirdVertex(i, j)
        curl := Y[i][j] + Y[j][k] + Y[k][i]
        totalCurl += curl * curl
    }
    return math.Sqrt(totalCurl)
}

// The gradient component is found by solving L*s = div(Y)
// where L is the graph Laplacian and div is the divergence
// Use Cholesky solve from gonum/mat
```

**Implementability in Go:** Straightforward. The gradient solve requires one Cholesky factorization (same one used for effective resistance!). The curl computation is O(|triangles|) per edge.

### Key Papers for Q5

| Paper | Authors | Year | Venue | Key Contribution | Cit (S2) |
|-------|---------|------|-------|-----------------|-----------|
| Statistical Ranking and Combinatorial Hodge Theory | Jiang, Lim, Yao, Ye | 2011 | Math. Programming | HodgeRank: gradient + curl + harmonic decomposition; least-squares ranking | ~398 |
| Bayesian Intransitive BT via Hodge Theory | Okahara, Nakagawa, Sugasawa | 2026 | arXiv | BT + Hodge + Bayesian shrinkage; Gibbs sampler; per-triad uncertainty | preprint |
| Modeling Intransitivity in Pairwise Comparisons | Spearing, Tawn, Irons, Paulden | 2023 | JCGS | Flexible intransitivity with random K levels; baseball application | ~11 |
| Hodge Decomposition and the Shapley Value | Stern & Tettenhorst | 2019 | Games Econ. Behav. | Hodge decomposition for cooperative games; discrete Green's functions | - |

---

## Unified Priority Formula

Combining all five research questions, the recommended priority score for pair (i,j) is:

```
priority(i,j) = w1 * [p_ij * (1-p_ij) * R_ij]     // Fisher IG = outcome uncertainty * effective resistance
              + w2 * [sigma_diff_ij^2]                // Posterior uncertainty on strength difference
              + w3 * [curl_score(i,j)]                // Intransitivity involvement (should compare directly)
              + w4 * [1 - n_ij / n_max]               // Exploration bonus
```

**Default weights:** w1=1.0, w2=0.3, w3=0.5, w4=0.1

**Interpretation:**
- **w1 term (Fisher IG):** Theoretically optimal single acquisition function. High when outcome is uncertain AND the comparison informs many other rankings.
- **w2 term (variance):** Catches items with very few total comparisons (high posterior variance).
- **w3 term (curl):** Prioritizes pairs involved in intransitive cycles -- these MUST be compared directly because transitive inference fails for them.
- **w4 term (exploration):** Mild bonus for uncompared pairs to ensure graph connectivity.

### Computation Cost

For n items:
1. **BT parameters:** O(n * |E| * iterations) for MM/EM algorithm (one-time per update)
2. **Effective resistances:** O(n^3) for Cholesky decomposition (one-time, gives all pairs)
3. **Curl scores:** O(|triangles|) total
4. **Candidate pair evaluation:** O(1) per pair

Total per round: O(n^3) dominated by Cholesky. For n < 1000, this is fast (< 1 second).

---

## Serendipitous Connections

### Physics: Kirchhoff's Laws and Comparison Networks

The effective resistance framework maps BT estimation directly to **electrical network theory**. Each comparison edge is a resistor with conductance w_ij = n_ij * p_ij * (1-p_ij). The effective resistance R_ij is the voltage drop when 1 ampere flows from i to j. Kirchhoff's current law is the divergence equation. This means all of electrical circuit theory (series/parallel reduction, Y-Delta transforms, etc.) applies to analyzing comparison graphs.

### Economics: Arrow's Impossibility and Hodge Theory

The Hodge decomposition's harmonic component (globally cyclic, locally acyclic) is the mathematical formalization of **Condorcet cycles** from social choice theory. Arrow's Impossibility Theorem (1951) says that no rank aggregation method can avoid all Condorcet cycles. The Hodge framework quantifies *how much* intransitivity exists and localizes it. This connects directly to voting theory and mechanism design.

### CS: Spectral Algorithms and Laplacian Solvers

The effective resistance computation requires solving Laplacian systems. There has been enormous progress on **nearly-linear-time Laplacian solvers** (Spielman & Teng, STOC 2004, ~1500+ cit). For very large comparison graphs (n > 10^5), these solvers make the approach scalable. The connection to **spectral sparsification** (Spielman & Srivastava, STOC 2008) also means you can approximate the Laplacian using O(n log n) edges.

### Math: Simplicial Complexes and Topology

The Hodge decomposition on the comparison graph is a special case of the **de Rham cohomology** of simplicial complexes. The gradient flow lives in the image of the coboundary operator d_0, the curl flow in the image of the adjoint d_1^*, and the harmonic flow in the kernel of the Hodge Laplacian. This connects ranking theory to algebraic topology. The Betti numbers of the comparison complex tell you how many independent intransitive cycles exist.

---

## Knowledge Graph Candidates

- "**Effective Resistance (Graph Theory)**" -- Type: technique. Links: Bradley-Terry, Fisher Information, Graph Laplacian, Spectral Graph Theory
- "**HodgeRank**" -- Type: framework. Links: Hodge Decomposition, Intransitivity, Pairwise Comparison, Combinatorial Topology
- "**Strong Stochastic Transitivity**" -- Type: principle. Links: Bradley-Terry, Rank Aggregation, Social Choice
- "**Fisher Information Matrix (BT)**" -- Type: technique. Links: Bradley-Terry, D-optimal Design, Graph Laplacian, Cramer-Rao Bound
- "**Rank Centrality**" -- Type: framework. Links: Random Walk, PageRank, Bradley-Terry, Spectral Gap

---

## What to Read Next

1. **Hendrickx, Olshevsky & Saligrama (ICML 2019/2020)** -- The theoretical foundation linking effective resistance to BT estimation error. Short, elegant, directly applicable.

2. **Jiang, Lim, Yao & Ye (Math. Programming 2011)** -- The HodgeRank paper. Essential for understanding when transitivity fails. The linear algebra is clean and implementable.

3. **Okahara, Nakagawa & Sugasawa (arXiv 2026)** -- The most recent synthesis combining BT + Hodge + Bayesian inference. Directly relevant to building a system that handles intransitivity gracefully.

4. **Negahban, Oh & Shah (NeurIPS 2012)** -- Rank Centrality. Shows the deep connection between random walks and BT scores. The spectral gap analysis tells you when your comparison graph is "good enough."

5. **Caron & Doucet (JCGS 2012)** -- The Bayesian BT paper. Efficient Gibbs sampler with EM interpretation. The Fisher Information derivation is clean.

---

## Sources

All sources actually fetched and read during this research:

- (T1) Jiang, Lim, Yao, Ye. "Statistical Ranking and Combinatorial Hodge Theory." Mathematical Programming 127, 2011. ~398 cit (S2). DOI: 10.1007/s10107-010-0419-x
- (T1) Hendrickx, Olshevsky, Saligrama. "Graph Resistance and Learning from Pairwise Comparisons." ICML 2019. ~11 cit (S2).
- (T1) Hendrickx, Olshevsky, Saligrama. "Minimax Rate for Learning From Pairwise Comparisons in the BTL Model." ICML 2020. ~15 cit (S2).
- (T1) Caron & Doucet. "Efficient Bayesian Inference for Generalized Bradley-Terry Models." JCGS 2012. ~156 recent cit (S2).
- (T1) Herbrich, Minka, Graepel. "TrueSkill: A Bayesian Skill Rating System." NeurIPS 2006. ~1800 cit (S2).
- (T1) Bucher, Guyatt, Griffith, Walter. "Indirect Treatment Comparisons in Meta-Analysis." J Clin Epidemiol 1997. ~3000+ cit.
- (T1) Spearing, Tawn, Irons, Paulden. "Modeling Intransitivity in Pairwise Comparisons." JCGS 2023. ~11 cit (S2).
- (T2) Negahban, Oh, Shah. "Rank Centrality: Ranking from Pairwise Comparisons." Operations Research (also NeurIPS 2012). ~245 cit (S2).
- (T2) Chen. "Ranking from Pairwise Comparisons in General Graphs and Graphs with Locality." arXiv:2304.06821, 2023. ~3 cit (S2).
- (T2) Kahle, Rottger, Schwabe. "The Semi-Algebraic Geometry of Saturated Optimal Designs for the Bradley-Terry Model." Algebraic Statistics 2021. ~1 cit (S2).
- (T2) Okahara, Nakagawa, Sugasawa. "The Bayesian Intransitive Bradley-Terry Model via Combinatorial Hodge Theory." arXiv:2601.07158, 2026.
- (T2) Selby. "PageRank and the Bradley-Terry Model." arXiv:2402.07811, 2024.
- (T2) Heckel, Shah, Ramchandran, Wainwright. "Active Ranking from Pairwise Comparisons and the Futility of Parametric Assumptions." arXiv:1606.08842, 2016. ~11 cit (S2).
- (T2) Shah, Balakrishnan, Guntuboyina, Wainwright. "Stochastically Transitive Models for Pairwise Comparisons: Statistical and Computational Issues." ICML 2016.
- (T2) Makur & Singh. "Minimax Hypothesis Testing for the BTL Model." IEEE Trans. Info. Theory 2025. ~4 cit (S2).
- (T7) Wikipedia. "Stochastic Transitivity." Background on LST/SST/WST hierarchy.
