# Deep Research: Neural Incremental View Maintenance for KORE-GC

## Research Summary: Vector Embeddings as Materialized Views of Knowledge Graphs

### Executive Summary

Classical IVM theory provides a rigorous algebraic framework for propagating deltas through view definitions, but it fundamentally assumes the view function is decomposable over algebraic operations (join, project, union, aggregate). Neural embedding models violate this assumption: they are non-linear, non-decomposable, and their "delta" cannot be computed without re-invoking the model. However, several active research threads -- approximate IVM, higher-order IVM, continual KG embedding, learned database components, and self-maintaining views -- collectively provide the building blocks for a "Neural IVM" theory. No single paper has formalized this; the KORE-GC paper would be among the first to do so explicitly.

**Epistemic status:** Active frontier -- synthesizing established IVM theory (T1, settled since 1990s) with emerging work on learned DB components and continual KG embeddings (T2, 2020-2024). No existing paper formalizes "neural materialized views" as such.

**Confidence:** Medium -- the individual theoretical pieces are solid (T1), but the proposed synthesis is novel and unvalidated.

---

## 1. Classical IVM Theory: Foundations

### 1.1 Seminal Papers

| Paper | Authors | Year | Venue | Key Contribution |
|-------|---------|------|-------|-----------------|
| Efficiently Updating Materialized Views | Blakeley, Larson, Tompa | 1986 | SIGMOD | First formal treatment: irrelevant update detection, differential algorithm for view re-evaluation. Necessary and sufficient conditions for filtering updates that cannot affect a view. (T1 -- ACM SIGMOD 1986) |
| Maintenance of Materialized Views: Problems, Techniques, and Applications | Gupta, Mumick | 1995 | IEEE Data Eng. Bulletin | Definitive survey. Classifies the problem space: view definition language, update types, information available for maintenance. Introduces the taxonomy that all subsequent work follows. (T1 -- IEEE 1995) |
| Data Integration Using Self-Maintainable Views | Gupta, Jagadish, Mumick | 1996 | EDBT | Formalizes **self-maintainable views**: views that can be maintained using only the view contents and the delta, without accessing base tables. Key theorem: a view is self-maintainable iff certain "auxiliary views" can be precomputed. (T1 -- EDBT 1996) |
| Materialized Views: Techniques, Implementations, and Applications | Gupta, Mumick (eds.) | 1999 | MIT Press | Book collecting the canonical results. (T1 -- MIT Press) |

### 1.2 The Formal Framework

Classical IVM assumes:
- A **base relation** R
- A **view definition** V = Q(R) where Q is an expression in relational algebra (or extensions: aggregation, recursion)
- An **update** delta_R to the base relation
- Goal: compute delta_V = Q(R + delta_R) - Q(R) **without** recomputing Q(R + delta_R) from scratch

The key insight is the **delta derivation rule**: for each relational operator op, there exists a delta operator d(op) such that:

```
delta(R1 join R2) = (delta_R1 join R2) union (R1 join delta_R2) union (delta_R1 join delta_R2)
```

This works because join (and select, project, union, difference, aggregation under certain conditions) are **algebraically decomposable**: the output change can be expressed as a function of the input change and existing state.

### 1.3 What Breaks for Neural Views

When the "view definition" is f_theta(x) where f is a neural embedding model:

1. **No algebraic decomposition**: f_theta is not a composition of relational operators. There is no general delta derivation rule for neural networks.
2. **Non-linearity**: Even if we could differentiate f (in the calculus sense), the embedding of a changed node is not the embedding of the old node plus some delta. f(x + dx) != f(x) + df(x) except locally (Jacobian approximation).
3. **Context sensitivity**: Embedding models often depend on broader context (e.g., graph neighborhood in GNNs, document context in transformers). Changing one node may affect the embeddings of neighboring nodes -- an "avalanche effect" analogous to what LINVIEW identified for linear algebra.
4. **Model opacity**: The view definition includes the model weights theta, which are themselves learned and may change (model versioning, fine-tuning). Classical IVM assumes the view definition is fixed.

**Critical observation**: The Jacobian/gradient *does* exist for neural networks (they are differentiable functions). The question is whether this mathematical differentiability can be exploited for practical IVM, even if it doesn't yield exact deltas.

---

## 2. Higher-Order and Generalized IVM

### 2.1 DBToaster: Higher-Order Delta Processing

**Paper**: Koch, Ahmad, Kennedy et al. "DBToaster: Higher-order delta processing for dynamic, frequently fresh views." VLDB Journal 23, 253-278 (2014). (T1 -- VLDB Journal)

**Key idea**: Recursive application of finite differences. Instead of computing delta_V directly, compute delta of delta (second-order), and so on. For a degree-k polynomial query, the k-th order delta is a constant -- no data access needed.

**Relevance to neural views**: Neural networks are NOT polynomial, so the recursive delta approach does not terminate. However, the *principle* of pre-materializing auxiliary structures to speed up delta computation is directly applicable. For embeddings, the "auxiliary structures" could be intermediate activations, attention weights, or neighborhood aggregation results that can be cached and partially reused.

### 2.2 DBSP: Automatic IVM for Rich Query Languages

**Paper**: Budiu, McSherry, Ryzhyk, Tannen. "DBSP: Automatic Incremental View Maintenance for Rich Query Languages." PVLDB 16(7), 1601-1614 (2023). arXiv:2203.16684. (T1 -- VLDB)

**Key formalism**: Models computations as operators on **streams over Z-sets** (integer-weighted multisets). Defines two fundamental operators:
- **D** (differentiation): extracts the delta from a stream
- **I** (integration): accumulates deltas into state

The **incrementalization theorem**: For any stream operator T, there exists an incremental version D(T) that computes the output delta from the input delta. This is constructive and automatic for any operator expressible in DBSP.

**Relevance to neural views**: DBSP's framework is the most general existing IVM formalism. The question is: can a neural embedding function be expressed (or approximated) as a DBSP operator? If so, DBSP's incrementalization theorem would apply. The challenge: DBSP operators must be **linear** over Z-sets (distribute over addition). Neural networks are not linear over their inputs. However, if we treat the embedding as a **black-box operator** with known input-output pairs, we might define an approximate DBSP operator.

### 2.3 F-IVM: Factorized IVM

**Paper**: Nikolic, Olteanu. "Incremental View Maintenance with Triple Lock Factorization Benefits." SIGMOD 2018. (T1 -- ACM SIGMOD)

**Key idea**: Unifies IVM for diverse tasks (query evaluation, gradient computation for ML, matrix operations) by working over arbitrary **rings**. The "view" maps keys to payloads from a task-specific ring. For ML gradient computation, the ring is the real numbers with addition and multiplication.

**Relevance to neural views**: F-IVM already bridges IVM and ML by computing gradients incrementally. This is the closest existing work to "neural IVM." The embedding function could be treated as a view whose payload is a vector in R^d, with the ring being (R^d, +, dot). The question is whether the embedding computation can be factorized along the same key hierarchy as the data.

### 2.4 LINVIEW: IVM for Linear Algebra

**Paper**: Nikolic, Elseidy, Koch. "LINVIEW: Incremental View Maintenance for Complex Analytical Queries." SIGMOD 2014. (T1 -- ACM SIGMOD)

**Key insight**: Linear algebra operations cause **avalanche effects** -- local changes spread to all intermediate results. Sound familiar? This is exactly the problem with embeddings. LINVIEW's solution: use **matrix factorizations** to contain the spread. Low-rank updates (rank-1 or rank-k perturbations) can be propagated efficiently through matrix products.

**Relevance to neural views**: If the embedding model's forward pass can be decomposed into matrix operations (as in a feedforward network), LINVIEW's techniques for low-rank update propagation could apply to the weight matrices. This won't give exact IVM but could give **approximate IVM** for small input changes.

### 2.5 Recent IVM Survey

**Paper**: "Recent Increments in Incremental View Maintenance." PODS 2024 (Gems of PODS talk). arXiv:2404.17679. (T1 -- ACM PODS 2024)

Surveys fine-grained complexity results. Key concept: **q-hierarchical queries** admit constant-time updates and constant-delay enumeration. This provides complexity-theoretic lower bounds on what is achievable for different query classes. Neural "queries" would fall outside all known tractable classes.

---

## 3. Graph-Specific IVM

### 3.1 Szarnyas: IVM for Property Graph Queries

**Paper**: Szarnyas. "Incremental View Maintenance for Property Graph Queries." arXiv:1712.04108, published SIGMOD 2018. (T1 -- ACM SIGMOD 2018)

**Key contribution**: Property graph queries require operators outside standard relational algebra (path navigation, optional match, variable-length paths). Szarnyas reduces a subset of property graph queries to **nested relational algebra**, enabling classical IVM techniques.

**Relevance to KORE-GC**: Directly applicable as the "first layer" of IVM -- maintaining the graph query results that feed into the embedding model. In KORE-GC, the embedding input is typically a node's properties + neighborhood structure, which can be expressed as a property graph query. Szarnyas's approach gives IVM for this query; the remaining problem is propagating the query delta through the embedding function.

**Key insight for KORE-GC**: Decompose the neural materialized view into two stages:
1. **Graph query stage**: Extract the embedding input (node text, neighborhood) -- use Szarnyas-style IVM
2. **Neural stage**: Compute the embedding from the extracted input -- use approximate/heuristic IVM

This decomposition is novel and directly applicable to the paper.

---

## 4. Learned Database Components and Their Maintenance

### 4.1 The Case for Learned Index Structures

**Paper**: Kraska, Beutel, Chi, Dean, Polyzotis. "The Case for Learned Index Structures." SIGMOD 2018. arXiv:1712.01208. (T1 -- ACM SIGMOD 2018)

**Key idea**: Traditional index structures (B-trees, hash maps) are models that map keys to positions. These models can be replaced by neural networks that learn the data distribution. The learned model "approximates" the CDF of the key distribution.

**Maintenance problem**: When data changes, the learned model becomes stale. The original paper does not address this -- it assumes static data.

### 4.2 ALEX: Updatable Learned Indices

**Paper**: Ding et al. "ALEX: An Updatable Adaptive Learned Index." SIGMOD 2020. arXiv:1905.08898. (T1 -- ACM SIGMOD 2020)

**Key contribution**: Makes learned indices updatable by:
1. Using a **gapped array** structure to absorb inserts without retraining
2. **Adaptive retraining**: only retrain the affected sub-model when accuracy degrades below a threshold
3. **Structural adaptation**: split or merge nodes in the model tree when data distribution shifts

**Relevance to neural views**: ALEX demonstrates that learned components CAN be maintained incrementally by:
- Tolerating approximation (the model is always approximate, so small staleness is acceptable)
- Using **local retraining** instead of global retraining
- Defining a **staleness threshold** that triggers recomputation

This is the closest existing paradigm to "neural IVM for embeddings."

### 4.3 NeurDB: AI-Powered Autonomous Database

**Paper**: Zhao et al. "NeurDB: On the Design and Implementation of an AI-powered Autonomous Database." CIDR 2025. arXiv:2408.03013. (T2 -- CIDR 2025)

**Key contribution**: Integrates neural components (learned indices, learned query optimizers, in-database ML) as first-class database components with built-in maintenance. Uses **online adaptation** to handle data drift without full retraining.

**Relevance**: NeurDB treats learned components as objects that require maintenance, but does not provide a formal theory -- it uses heuristic adaptation. KORE-GC could cite this as an industrial precedent while providing the missing formal framework.

---

## 5. Differentiable Databases

### 5.1 TensorLog: Differentiable Deductive Database

**Paper**: Cohen. "TensorLog: A Differentiable Deductive Database." arXiv:1605.06523 (2016). (T2 -- arXiv preprint, heavily cited)

**Key idea**: Converts logical rules into factor graphs, then "unrolls" belief propagation into a differentiable function. This allows gradient-based learning of rule parameters while preserving database-style reasoning.

**Relevance**: TensorLog makes the database itself differentiable. If the entire knowledge graph + embedding pipeline were differentiable, one could (in principle) compute the gradient of the embedding output w.r.t. graph changes, which IS a form of delta computation. This is the theoretical bridge between calculus-based differentiation and database-style delta derivation.

### 5.2 Neural LP: Differentiable Rule Learning

**Paper**: Yang, Yang, Cohen. "Differentiable Learning of Logical Rules for Knowledge Base Reasoning." NeurIPS 2017. (T1 -- NeurIPS)

Extends TensorLog with an end-to-end differentiable approach to learning rule structure (not just parameters). Demonstrates that logical reasoning over knowledge bases can be made fully differentiable.

---

## 6. Continual Knowledge Graph Embedding

This is the most directly relevant body of work for "neural IVM."

### 6.1 FastKGE: Incremental LoRA for KG Embedding

**Paper**: Liu, Ke et al. "Fast and Continual Knowledge Graph Embedding via Incremental LoRA." IJCAI 2024. arXiv:2407.05705. (T1 -- IJCAI 2024)

**Key idea**: When new triples are added to a KG, instead of retraining the full embedding model:
1. **Layer the new knowledge** by distance from existing graph
2. Use **incremental LoRA** (low-rank adaptation) for each layer
3. Adaptive rank allocation based on layer importance

Saves 34-49% training time vs. full retraining.

**Relevance to neural IVM**: This IS a form of approximate neural IVM, though not formalized as such. The "delta" (new triples) is processed through a low-rank perturbation of the existing model, which is analogous to LINVIEW's low-rank matrix update propagation. The KORE-GC paper could formalize FastKGE as an instance of neural IVM.

### 6.2 AIR: Adaptive Incremental Embedding Updating

**Paper**: AIR framework for dynamic KGs. Springer LNCS (2023). (T1 -- conference paper)

**Key idea**: Measures the **importance score** of each new triple to decide whether it requires embedding recomputation. Low-importance triples can be absorbed without updating embeddings.

**Relevance**: This is a form of **irrelevant update detection** for neural views -- directly analogous to Blakeley et al.'s 1986 result for relational views. The "importance score" serves the same role as the "irrelevance conditions" in classical IVM.

### 6.3 Incremental Distillation for KG Embedding

**Paper**: "Towards Continual Knowledge Graph Embedding via Incremental Distillation." AAAI 2024. arXiv:2405.04453. (T1 -- AAAI 2024)

**Key idea**: Use knowledge distillation to transfer old entity representations to the new model, preventing catastrophic forgetting. This is a **monotonic maintenance strategy** -- it never invalidates old embeddings, only adds to them.

### 6.4 Bayesian-Guided Continual KGE

**Paper**: "Learning to Evolve: Bayesian-Guided Continual Knowledge Graph Embedding." arXiv:2508.02426 (2025). (T2 -- preprint)

**Key idea**: Uses Bayesian posterior updating for embedding maintenance. The posterior naturally combines old knowledge (prior) with new evidence (likelihood from new triples). This provides a principled probabilistic framework for embedding updates.

**Relevance**: This is perhaps the most theoretically elegant approach. It suggests that neural IVM could be formalized as **Bayesian updating** of the embedding posterior, rather than as algebraic delta propagation.

---

## 7. Self-Maintaining Views and Staleness Detection

### 7.1 Classical Self-Maintainability

A view V = Q(R) is **self-maintainable** if delta_V can be computed from V and delta_R alone (without accessing R). Gupta, Jagadish, Mumick (1996) give necessary and sufficient conditions for specific query classes.

**For neural views**: An embedding is "self-maintainable" if, when a node's text changes (delta_R), the new embedding can be computed from the old embedding and the text delta alone, without re-processing the entire graph context. This is generally FALSE for transformer-based models (they need the full input), but could be TRUE for certain architectures:
- **Additive models**: If the embedding is a sum of component embeddings, changing one component only requires subtracting the old and adding the new.
- **LoRA-style models**: If the embedding change can be captured by a low-rank perturbation.

### 7.2 Stale View Cleaning

**Paper**: Krishnan, Wang, Franklin, Goldberg, Kraska. "Stale View Cleaning: Getting Fresh Answers from Stale Materialized Views." PVLDB 8(12), 1370-1381 (2015). (T1 -- VLDB 2015)

**Key idea**: Instead of maintaining the view exactly, **sample** from the stale view, clean the sample, and use it to estimate aggregate query results. The view is allowed to be stale, but query answers are corrected at query time.

**Relevance to neural views**: This is directly applicable to KORE-GC. Instead of maintaining all embeddings fresh, allow them to become stale, and apply a **correction at query time**:
- At query time, check if the retrieved nodes' source data has changed since embedding
- For changed nodes, recompute embeddings on-the-fly (or apply a correction factor)
- Use the freshness metadata (timestamp comparison) to estimate how stale the results are

This "lazy IVM" or "query-time correction" approach is highly practical and avoids the need for continuous maintenance.

### 7.3 Embedding Drift Detection

From the practitioner literature (T5 -- Evidently AI, Zilliz):

**Methods for detecting embedding staleness**:
1. **Cosine similarity monitoring**: Track average cosine similarity between new embeddings and a baseline. Drift threshold typically 0.001-0.2 depending on model.
2. **Distribution-based**: Population Stability Index (PSI), Maximum Mean Discrepancy (MMD) between embedding distributions.
3. **Cluster monitoring**: Track cluster centroids; if they shift significantly, embeddings are drifting.
4. **Per-embedding staleness**: Compare node's last-modified timestamp vs. embedding timestamp.

---

## 8. Synthesis: Toward a "Neural IVM" Theory for KORE-GC

### 8.1 The Formal Model

I propose the following formalization for the KORE-GC paper:

**Definition (Neural Materialized View):**
Let G = (V, E, P) be a property graph with vertices V, edges E, and property function P. Let f_theta: V -> R^d be an embedding function parameterized by theta, where f_theta(v) depends on P(v) and the local neighborhood N(v) in G. The **neural materialized view** is:

```
M = {(v, f_theta(v)) | v in V}
```

This is a materialized view of G under the "view definition" f_theta.

**Definition (Neural Delta):**
Given an update delta_G = (delta_V, delta_E, delta_P), the neural delta is:

```
delta_M = {(v, f_theta(v; G + delta_G) - f_theta(v; G)) | v in affected(delta_G)}
```

where affected(delta_G) is the set of vertices whose embeddings may change.

**The fundamental problem**: Computing delta_M requires invoking f_theta, so it is not cheaper than recomputation -- UNLESS we can bound or approximate affected(delta_G) and/or the magnitude of embedding changes.

### 8.2 Three Maintenance Strategies (Theoretical Contribution)

**Strategy 1: Scope Bounding (analogous to irrelevant update detection)**

Theorem sketch: For a GNN-based embedding model with k layers, a graph update delta_G only affects embeddings of vertices within k-hop distance of the modified element. All other embeddings are **exactly** unchanged.

This is the neural analog of Blakeley et al.'s irrelevant update detection. The proof follows from the locality of message passing in GNNs.

For transformer-based embeddings of node text, the scope is the node itself (text-only models) or the node + its described relations (context-augmented models).

**Strategy 2: Approximate Delta (analogous to LINVIEW's low-rank propagation)**

When a node v's properties change by delta_P(v), the embedding change can be approximated:

```
f_theta(v + delta_v) approx f_theta(v) + J_v * delta_v
```

where J_v is the Jacobian of f_theta at v. This first-order approximation is valid when ||delta_v|| is small (small text edits, minor property changes). The Jacobian can be pre-computed or approximated via finite differences on a few samples.

This connects to LINVIEW's insight that low-rank perturbations propagate efficiently. If the Jacobian is low-rank (which it often is for overparameterized models -- see the lottery ticket hypothesis and intrinsic dimensionality literature), the update is cheap.

**Strategy 3: Deferred Maintenance with Staleness Bounds (analogous to Stale View Cleaning)**

Instead of maintaining embeddings eagerly, use a **staleness-aware query** approach:

1. Track `last_modified(v)` and `last_embedded(v)` for each vertex
2. At query time, compute `staleness(v) = last_modified(v) - last_embedded(v)`
3. For the top-k results of a similarity query, re-embed any result with `staleness > tau`
4. The threshold tau is tunable: tau = 0 means eager maintenance; tau = infinity means never re-embed

The key theoretical result: bound the **query error** as a function of tau and the data change rate. Under Lipschitz assumptions on f_theta, if the input changes by at most epsilon in time tau, the embedding error is at most L * epsilon where L is the Lipschitz constant.

### 8.3 Mapping to Classical IVM Concepts

| Classical IVM Concept | Neural IVM Analog | Source for formalization |
|----------------------|-------------------|------------------------|
| View definition Q | Embedding model f_theta | -- |
| Base relation R | Knowledge graph G = (V, E, P) | -- |
| Delta derivation d(Q) | Jacobian J_theta or incremental LoRA | LINVIEW + FastKGE |
| Irrelevant update detection | k-hop scope bounding for GNNs | Blakeley 1986 + GNN locality |
| Self-maintainable view | Additive embedding models | Gupta 1996 |
| Deferred maintenance | Staleness-aware query with threshold tau | Stale View Cleaning (Krishnan 2015) |
| Higher-order deltas | Higher-order gradient information (Hessian) | DBToaster + second-order optimization |
| Z-sets (DBSP) | Weighted embedding differences | DBSP (Budiu 2023) |
| Algebraic decomposition | Model factorization (attention heads, layers) | F-IVM ring formalism |
| Query-time correction | Re-embed stale results at retrieval time | Stale View Cleaning |

### 8.4 What Existing Theorems Can Be Cited or Extended

1. **Blakeley-Larson-Tompa (1986) irrelevant update theorem**: Can be extended to prove that GNN embeddings with k message-passing layers are unaffected by graph changes beyond k hops. This is a direct generalization with the same necessary-and-sufficient structure.

2. **DBSP incrementalization theorem (Budiu 2023)**: Could be extended if the embedding function is approximated as a composition of DBSP-compatible operators. The approximation error would need to be bounded.

3. **LINVIEW low-rank update propagation (Nikolic 2014)**: Directly applicable to the linear layers within neural networks. The embedding change from a rank-r input perturbation propagates as a rank-r (or lower) perturbation through each linear layer.

4. **Gupta-Mumick self-maintainability conditions (1996)**: Can be reframed for neural views: an embedding is "self-maintainable" iff it can be updated from the old embedding vector and the input delta, without accessing the full graph context. This gives a clean characterization of which embedding architectures support efficient IVM.

5. **Krishnan et al. Stale View Cleaning (2015)**: The sampling-based correction approach directly applies to stale embeddings. The error bounds can be re-derived for vector similarity queries instead of aggregate SQL queries.

### 8.5 Novel Contributions KORE-GC Could Claim

1. **First formal definition of Neural Materialized View** -- explicitly connecting the database MV literature to the vector store literature.

2. **Scope Bounding Theorem for GNN-based embeddings** -- proving the k-hop locality property as an IVM result rather than a GNN property.

3. **Lipschitz Staleness Bound** -- relating embedding error to data change magnitude via the model's Lipschitz constant, giving a theoretical basis for the staleness threshold tau.

4. **Two-Phase IVM Decomposition** -- separating graph query IVM (Szarnyas-style, exact) from neural IVM (approximate), with a clean interface between the two phases.

5. **Practical co-location advantage** -- showing that co-locating graph and vectors in the same PostgreSQL enables the trigger-based staleness tracking that the theoretical framework requires (instead of cross-system change data capture).

---

## 9. Serendipitous Connections

### 9.1 Physics: Renormalization Group and Coarse-Graining

The embedding function f_theta is conceptually a **coarse-graining** operation: it maps a high-dimensional structured object (a graph node with properties and relations) to a low-dimensional representation. This is structurally analogous to the **renormalization group** in physics, where microscopic degrees of freedom are integrated out to produce effective theories at larger scales.

The "neural IVM" problem -- how does the coarse-grained representation change when the microscopic data changes -- is analogous to the question of how effective field theory parameters change under RG flow when the UV cutoff is modified. The Jacobian approach (Strategy 2) is analogous to computing the **beta function** of the RG flow.

### 9.2 Economics: Rational Inattention and Optimal Recomputation

The staleness threshold tau in Strategy 3 is an instance of **rational inattention** (Sims, 2003 -- Nobel Prize in Economics 2011). An agent with limited computational bandwidth must decide which information to process. The optimal tau balances the cost of recomputation against the value of fresh embeddings -- a classic information acquisition problem.

The formal connection: define the **value of freshness** V(tau) = (query accuracy with staleness < tau) - (query accuracy with current staleness), and the **cost of freshness** C(tau) = (computational cost of re-embedding all nodes with staleness > tau). The optimal threshold minimizes C(tau) - V(tau). This gives KORE-GC an economic interpretation.

### 9.3 Mathematics: Lipschitz Continuity and Approximation Theory

The Lipschitz bound in Strategy 2/3 connects to **approximation theory** in functional analysis. The question "how much does the embedding change when the input changes by epsilon?" is a question about the modulus of continuity of f_theta. For neural networks, there is a rich literature on Lipschitz bounds (spectral norms of weight matrices, etc.) that can be directly imported.

---

## 10. Papers to Cite (Organized by Role in Argument)

### Foundations (must cite)
1. Blakeley, Larson, Tompa (1986) -- SIGMOD -- irrelevant updates
2. Gupta, Mumick (1995) -- IEEE Data Eng. Bulletin -- survey/taxonomy
3. Gupta, Jagadish, Mumick (1996) -- EDBT -- self-maintainable views
4. Koch et al. (2014) -- VLDB Journal -- DBToaster, higher-order IVM
5. Budiu, McSherry et al. (2023) -- VLDB -- DBSP, most general IVM framework

### Graph-specific IVM (must cite)
6. Szarnyas (2018) -- SIGMOD -- IVM for property graph queries

### Bridge to ML (must cite)
7. Nikolic, Olteanu (2018) -- SIGMOD -- F-IVM (unifies IVM and ML gradient computation)
8. Nikolic, Elseidy, Koch (2014) -- SIGMOD -- LINVIEW (IVM for linear algebra, avalanche effect)

### Learned DB components (should cite)
9. Kraska et al. (2018) -- SIGMOD -- learned index structures
10. Ding et al. (2020) -- SIGMOD -- ALEX (updatable learned index)
11. NeurDB (2024/2025) -- CIDR -- neural database with learned component maintenance

### Continual KG embedding (should cite)
12. FastKGE / Incremental LoRA (2024) -- IJCAI -- incremental KG embedding update
13. AIR framework (2023) -- importance-based adaptive embedding update
14. Incremental Distillation for KGE (2024) -- AAAI

### Staleness and approximation (should cite)
15. Krishnan et al. (2015) -- VLDB -- Stale View Cleaning
16. "Recent Increments in Incremental View Maintenance" (2024) -- PODS survey

### Differentiable databases (optional cite)
17. Cohen (2016) -- TensorLog
18. Yang et al. (2017) -- NeurIPS -- Neural LP

---

## 11. Open Questions and Gaps

1. **No formal proof of Lipschitz staleness bound for specific embedding models** (e.g., sentence-transformers, GNNs). This would be a valuable contribution -- compute or empirically estimate L for common models.

2. **No complexity-theoretic characterization** of when neural IVM is tractable. The PODS 2024 survey characterizes tractable IVM for conjunctive queries; an analogous result for neural views is wide open.

3. **No benchmark** for neural IVM. There is no standard way to measure the cost-quality tradeoff of different neural IVM strategies on knowledge graphs.

4. **Model versioning is unaddressed**: When theta changes (model upgrade), ALL embeddings are invalidated. Classical IVM has no analog -- it's as if the view definition itself changed. This connects to the **schema evolution** literature in databases.

5. **Multi-hop effects**: For graph-aware embeddings, a single node change can cascade through the graph. The scope bounding theorem limits this to k hops, but the NUMBER of affected nodes within k hops can be very large in dense graphs. Practical strategies for prioritizing which nodes to re-embed are needed.

---

## 12. Recommended Reading Order

1. **Gupta & Mumick (1995)** -- get the classical IVM taxonomy
2. **DBSP (Budiu 2023)** -- understand the most general modern framework
3. **Szarnyas (2018)** -- graph-specific IVM
4. **F-IVM (Nikolic 2018)** -- bridge to ML
5. **LINVIEW (Nikolic 2014)** -- avalanche effect and low-rank propagation
6. **Krishnan et al. (2015)** -- stale view cleaning
7. **FastKGE (2024)** -- practical continual KG embedding
8. **ALEX (Ding 2020)** -- updatable learned components

---

## Quality Checklist

- [x] At least 2 primary sources (T1 or T2) actually fetched and read
- [x] Epistemic status and confidence label included
- [x] Source tier labeled for every key claim
- [x] Open questions section present
- [x] Serendipitous connections considered (3 found: physics RG, economics rational inattention, math approximation theory)
- [x] No fabricated citations -- all URLs actually fetched or verified via search results
- [x] Personal project connection: directly relevant to KORE (knowledge graph + pgvector system)
- [x] Venue names verified via search results (SIGMOD, VLDB, IJCAI, AAAI, NeurIPS, EDBT, PODS confirmed)
- [x] Publication types noted (journal > conference > workshop > preprint hierarchy followed)

---

## Sources Fetched

- arXiv: 1712.04108 (Szarnyas), 2203.16684 (DBSP), 1403.6968 (LINVIEW), 1703.07484 (F-IVM), 1605.06523 (TensorLog), 1905.08898 (ALEX), 2407.05705 (FastKGE), 2408.03013 (NeurDB), 2404.17679 (IVM survey), 1509.07454 (Stale View Cleaning)
- Semantic Scholar: searched for IVM foundations, learned index maintenance, KG embedding updates
- ACM DL: Blakeley 1986, Gupta/Mumick 1995, Koch 2014 (DBToaster), Nikolic/Olteanu 2018 (F-IVM)
- Web: Feldera/Materialize IVM blog, embedding drift detection (Evidently AI, Zilliz), Airtable embedding system, feature store literature
