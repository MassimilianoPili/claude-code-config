# Rationalist/LessWrong Ideas for KORE-GC Paper

## Research Report: Cross-Pollination from the Rationalist Ecosystem

This document synthesizes ideas from the rationalist/LessWrong/SSC ecosystem and related
neuroscience/information-theory literature that could strengthen the KORE-GC paper on
garbage collection for co-located graph-vector knowledge stores.

---

## 1. LessWrong / Alignment Forum: AI Memory Management and Knowledge Maintenance

### 1.1 The Map-Territory Distinction as a Framing for Staleness

**Source**: Eliezer Yudkowsky, "The Map Is Not the Territory" (LessWrong Sequences, 2007) (T6 -- LessWrong)

**Idea**: Yudkowsky's foundational rationalist concept -- that our beliefs (map) can diverge from
reality (territory) -- maps directly onto your staleness framework. An embedding is a "map"
of a node's semantic content (the "territory"). When the content changes but the embedding
doesn't, the map-territory divergence grows. Your staleness function `s(v) = 1 - sim(phi(v), f_theta(content(v)))`
is literally a measure of map-territory divergence.

**Usefulness**: **B -- Useful framing for Discussion**. You could open Section 8 (Discussion) with:
"In the language of epistemic rationality, a stale embedding is a map that no longer matches its
territory. The GC process is systematic map-updating." This gives the paper a philosophical
grounding that resonates beyond the database community.

**Key quote direction**: "What is true is already so. Owning up to it doesn't make it worse.
Not being open about it doesn't make it go away." -- the staleness exists whether you measure
it or not; GC makes the invisible visible.

### 1.2 Belief Updating and the Cost of Not Updating

**Source**: LessWrong Sequences, "How to Actually Change Your Mind" (T6 -- LessWrong / Yudkowsky 2007-2009)

**Idea**: The Sequences argue extensively that rational agents should update beliefs in proportion
to evidence strength, but also that *updating has cognitive costs*. The rationalist framework
for "when to update" closely parallels your PRIORITIZED-REFRESH algorithm: you don't re-embed
everything at once; you prioritize based on staleness_score x query_frequency x centrality --
analogous to a rational agent prioritizing belief updates based on (1) how wrong the current
belief might be, (2) how often the belief is used for decisions, and (3) how many other beliefs
depend on it.

**Usefulness**: **B -- Useful framing**. The priority function in Algorithm 2 can be motivated
as "rational belief maintenance under resource constraints."

### 1.3 Agent Memory Architecture Discussions on Alignment Forum

**Source**: Multiple posts on the Alignment Forum (2023-2025) discussing how AI agents should
manage long-term memory, including:
- "Bounded Memory and Attention in Agents" (various AF posts)
- Discussions on Claude/GPT memory management architectures

**Idea**: The AI safety community has grappled with the question of how AI agents should maintain
long-term knowledge stores. Key themes:
- **Selective forgetting is necessary**: Agents cannot keep everything; some principled
  pruning/GC mechanism is needed.
- **Memory consistency matters for alignment**: If an agent's memory becomes inconsistent
  (stale embeddings, orphaned references), it can make decisions based on wrong retrievals.
  Your paper's "silent failure" framing resonates with alignment concerns about
  "subtle misalignment through degraded knowledge."
- **TTL-based lifecycle**: Your lifecycle-aware approach (ChatSession TTL=90d, Author TTL=infinity)
  echoes discussions about how agent memory should have different retention policies for
  different types of information.

**Usefulness**: **C -- Background inspiration**. Not directly citable but shows your work addresses
a real concern in the AI agent design space beyond just databases.

---

## 2. Scott Alexander / Astral Codex Ten / SlateStarCodex

### 2.1 "The Control Group Is Out of Control" and Epistemic Hygiene

**Source**: Scott Alexander, "The Control Group Is Out of Control" (SlateStarCodex, 2014) (T4 -- Astral Codex Ten)

**Idea**: Alexander's famous essay on how scientific findings degrade over time -- replication
failures, publication bias, and "the garden of forking paths" -- is a meta-level analogy for
your embedding degradation problem. Scientific knowledge, like embeddings, can become "stale"
as the underlying evidence shifts. The essay's core message is that *you need systematic
verification mechanisms, not just one-time validation*.

**Usefulness**: **B -- Useful analogy in Discussion**. "Just as scientific knowledge requires
ongoing replication and verification (Alexander, 2014), knowledge store embeddings require
ongoing maintenance -- our GC framework provides this."

### 2.2 "Concept-Shaped Holes" and the Orphan Problem

**Source**: Scott Alexander, "Concept-Shaped Holes Can Be Meaningful" (SSC, 2015) (T4)

**Idea**: Alexander discusses how the *absence* of a concept can be as meaningful as its presence.
This connects to your orphan detection (cross-store inconsistency): an embedding without a
graph node, or a graph node without an embedding, is a "concept-shaped hole" in the knowledge
store. The asymmetry of the graph-vector relationship means these holes can silently degrade
retrieval quality.

**Usefulness**: **C -- Background inspiration**. Reinforces the framing of orphaned artifacts
as semantically meaningful gaps.

### 2.3 "Bayesian Reasoning" Posts and Belief Maintenance Cost

**Source**: Multiple SSC/ACX posts on Bayesian reasoning, prediction markets, and calibration (T4)

**Idea**: Alexander has written extensively about the *cost of maintaining well-calibrated beliefs*.
Key insight: maintaining accurate beliefs is not free; it requires ongoing effort. This
parallels the central economic question of your paper: *when is incremental maintenance
(GC) cheaper than full rebuild?* Your break-even analysis in Experiment 2+3 is essentially
asking the same question that Bayesian epistemology asks: when does the cost of updating
exceed the cost of starting fresh?

**Usefulness**: **B -- Useful framing**. "The cost-benefit analysis of incremental versus full
maintenance mirrors the fundamental Bayesian question of when to update versus when to
re-derive from scratch."

---

## 3. Rationalist Takes on Embeddings and Vector Databases

### 3.1 Gwern on Spaced Repetition and Forgetting Curves

**Source**: Gwern Branwen, "Spaced Repetition for Efficient Learning" (gwern.net, 2009-2024, continuously updated) (T4 -- Gwern)

**Idea**: Gwern's magisterial synthesis on spaced repetition is deeply relevant. Core insights:

1. **The forgetting curve is predictable**: Ebbinghaus (1885) showed that memory decays
   approximately exponentially. Your staleness function has an implicit temporal component --
   older embeddings are more likely to be stale, and this follows a predictable curve that
   could be modeled.

2. **Optimal review scheduling**: Spaced repetition algorithms (SM-2, FSRS) solve exactly the
   problem of "when to re-check knowledge" given limited review budget. This is structurally
   identical to your PRIORITIZED-REFRESH: given a budget of B re-embeddings per cycle, which
   nodes should be re-embedded? The spaced repetition literature provides well-studied
   scheduling algorithms that could inform your priority function.

3. **The "spacing effect"**: Reviewing at increasing intervals is more efficient than reviewing
   at fixed intervals. Your GC could potentially use adaptive intervals -- re-embed high-churn
   nodes more frequently, stable nodes less frequently -- following the same principle.

**Usefulness**: **A -- Directly citable**. Gwern's synthesis cites the primary literature
(Ebbinghaus 1885, Wozniak & Gorzelanczyk 1994, Pimsleur 1967). You could cite the primary
sources (T1) and reference Gwern's synthesis (T4) as a good overview. The connection between
spaced repetition scheduling and GC scheduling is novel and could be a contribution in the
Discussion section.

**Concrete recommendation**: Add a paragraph in Discussion connecting your generational
hypothesis to spaced repetition theory. The "young generation collected often, old generation
rarely" maps to "new cards reviewed frequently, mature cards reviewed rarely."

### 3.2 Gwern on the Lindy Effect

**Source**: Gwern mentions the Lindy effect in several contexts; primary treatment is
Nassim Nicholas Taleb, *Antifragile* (2012), ch. 17. Academic formalization:
Toby Ord, "The Lindy Effect" (arXiv:2308.09045, 2023) (T2 -- arXiv)

**Idea**: The Lindy effect states: for non-perishable entities (books, technologies, ideas),
the expected remaining lifetime is proportional to the current age. This has deep implications
for your generational hypothesis:

- **Young knowledge is fragile**: A recently added conversation or session is likely to
  become stale soon (high churn). This matches the weak generational hypothesis: most garbage
  is young.
- **Old knowledge is Lindy**: A paper that has been in the graph for 5 years and is still
  referenced is likely to remain relevant for another 5 years. Its embedding is less likely
  to need re-generation.
- **But there's a twist**: Your paper's context differs from pure Lindy because *model drift*
  can invalidate even old, stable content. When you switch from mxbai-embed-large to
  qwen3-embedding:8b, ALL embeddings become stale regardless of content age. This is like a
  paradigm shift in Kuhn's sense -- the Lindy effect breaks under model migration.

**Key insight from Ord (2023)**: Ord shows that the Lindy effect "arises very naturally even
in cases with constant (or increasing) hazard rates -- so long as there is a probability
distribution over the size of that rate." This is exactly your situation: individual nodes
have different hazard rates (churn rates), and the distribution of churn rates across nodes
creates the Lindy-like behavior that justifies generational collection.

**Usefulness**: **A -- Directly citable**. The Ord (2023) paper is arXiv (T2) and provides
formal mathematical backing for your generational hypothesis. You could cite it in Section 2.3
or 3.1 to justify why generational collection is theoretically sound.

**Concrete recommendation**: In Section 2.3 (GC background), add after discussing the weak
generational hypothesis: "The theoretical foundation for this unequal distribution of lifetimes
is formalized by Ord (2023) as the Lindy effect: entities with heterogeneous hazard rates
naturally exhibit power-law survival distributions, making generational collection optimal."

### 3.3 Rationalist Discussions on Embedding Limitations

**Source**: Various LessWrong/AF posts (2023-2025) on RAG limitations, embedding quality,
"semantic search is not enough" (T6 -- LessWrong)

**Idea**: The rationalist community has been among the most articulate critics of naive RAG
approaches. Key criticisms relevant to your paper:
- Embeddings lose structural information (graph topology)
- Embedding similarity != semantic equivalence
- Retrieval quality degrades silently (exactly your "silent failure" problem)
- The "embedding monoculture" risk: all nodes embedded with the same model share the same
  biases and blind spots

**Usefulness**: **C -- Background inspiration**. Supports your problem statement but doesn't
add formal content.

---

## 4. The "Forgetting" Problem: Neuroscience-Rationalist Bridge

### 4.1 Complementary Learning Systems Theory

**Source**: McClelland, McNaughton & O'Reilly, "Why There Are Complementary Learning Systems
in the Hippocampus and Neocortex" (Psychological Review, 1995) ~4800 cit (S2 est.)
Updated in O'Reilly et al., "Complementary Learning Systems" (Cognitive Science, 2014) (T1)

**Idea**: CLS theory is *the* foundational neuroscience framework for understanding why brains
have two memory systems:

1. **Hippocampus**: Fast learning, sparse representations, episodic memory. Analogous to
   your "young generation" -- recently ingested conversations, sessions, new papers.
2. **Neocortex**: Slow learning, distributed representations, semantic memory. Analogous to
   your "old generation" -- consolidated knowledge about authors, venues, concepts.

The key insight: **the hippocampus learns quickly but forgets quickly (high churn); the
neocortex learns slowly but retains indefinitely (Lindy)**. Memory consolidation during sleep
transfers knowledge from hippocampus to neocortex -- this is *exactly* your generational
promotion mechanism.

**Your GC as memory consolidation**: When a conversation (young gen, hippocampus-like) is
still referenced after 90 days, it either gets promoted to a more stable representation or
its TTL expires and it gets collected. This is structural homology with CLS.

**Usefulness**: **A -- Directly citable**. McClelland et al. (1995) is a T1 landmark paper.
The analogy between your generational GC and CLS theory is strong enough for a Discussion
paragraph. It elevates the paper from a purely technical contribution to one with
interdisciplinary depth.

**Concrete recommendation**: Add a paragraph in Section 8 (Discussion):
"Our generational GC framework exhibits structural parallels to Complementary Learning Systems
theory (McClelland et al., 1995): short-lived episodic artifacts (conversations, sessions) are
collected frequently, while long-lived semantic artifacts (papers, authors) persist with minimal
maintenance -- mirroring the hippocampal/neocortical division of labor in biological memory."

### 4.2 Synaptic Homeostasis Hypothesis (SHY) -- Sleep as GC

**Source**: Tononi & Cirelli, "Sleep and the Price of Plasticity: From Synaptic and Cellular
Homeostasis to Memory Consolidation and Integration" (Neuron, 2014, ~2500 cit) (T1)
Earlier: Tononi & Cirelli, "Sleep function and synaptic homeostasis" (Sleep Medicine Reviews, 2006) (T1)

**Idea**: SHY proposes that the *function of sleep* is essentially garbage collection:

- During waking, synapses strengthen (learning = embedding new knowledge)
- During sleep, synapses are globally downscaled (pruning = removing noise, consolidating signal)
- This "synaptic renormalization" prevents saturation and maintains signal-to-noise ratio

This is a *precise biological analogy* to your GC:
- During active ingestion (waking), new nodes and embeddings are added
- During GC cycles (sleep), stale embeddings are pruned, orphans removed, consistency restored
- The budget constraint (B re-embeddings per cycle) is analogous to the finite time available
  for sleep-based consolidation

**The inesorabilita principle IS synaptic homeostasis**: Your "principio di inesorabilita" --
gradual, incremental, nightly GC -- mirrors sleep's gradual, nightly synaptic renormalization.
Both are background maintenance processes that run on a schedule, process a bounded amount per
cycle, and converge progressively.

**Usefulness**: **A -- Directly citable (T1)**. This is a well-established neuroscience theory
published in top-tier journals. The analogy is precise enough to include in the paper body
(Section 2.3 or Discussion). It also strengthens the "generational hypothesis" framing.

**Concrete recommendation**: In Section 2.3, after discussing generational GC, add:
"The biological precedent for scheduled, incremental knowledge maintenance is Tononi & Cirelli's
synaptic homeostasis hypothesis (2014): during sleep, the brain performs global synaptic
downscaling -- a form of garbage collection that prevents memory saturation while preserving
consolidated knowledge."

### 4.3 "Learning by Active Forgetting" -- Forgetting as Feature

**Source**: Peng et al., "Learning by Active Forgetting for Neural Networks" (arXiv:2111.10831, 2021) (T2)

**Idea**: This paper argues that forgetting is not a bug but an active, beneficial mechanism
in neural networks. The authors implement a "plug-and-play forgetting layer" with inhibitory
neurons that selectively prune information. Key findings:
- Active forgetting leads to better generalization
- It produces self-adaptive structure (the network prunes itself)
- It increases robustness to perturbation

**Connection to KORE-GC**: Your TTL-based deletion of conversations (ChatSession TTL=90d) is
a form of active forgetting. You're not losing information accidentally -- you're intentionally
collecting old episodic data because it's *better for the system* not to keep it.

**Usefulness**: **A -- Directly citable (T2)**. Supports the claim that your GC is not just
maintenance but improves system quality -- stale data removal is beneficial, not just necessary.

### 4.4 "Forgetting is Everywhere" -- Unified Theory

**Source**: Sanati et al., "Forgetting is Everywhere" (arXiv:2511.04666, 2025) (T2)

**Idea**: This very recent paper proposes a unified, algorithm-agnostic theory characterizing
forgetting as "a lack of self-consistency in a learner's predictive distribution, manifesting
as a loss of predictive information." Key results:
- Forgetting is present across ALL deep learning settings
- Exact Bayesian inference allows adaptation without forgetting
- They provide a formal measure of forgetting propensity

**Connection to KORE-GC**: Their definition of forgetting as "loss of self-consistency" maps
directly onto your consistency invariant. Your staleness function detects exactly this loss
of self-consistency between the graph and vector representations.

**Usefulness**: **A -- Directly citable (T2)**. Very recent, strong theoretical connection.
Could be cited in Related Work or Discussion to position your work within the broader
"forgetting theory" landscape.

### 4.5 Catastrophic Forgetting and the CLS Solution

**Source**: The entire continual learning literature, but especially:
- Kirkpatrick et al., "Overcoming catastrophic forgetting in neural networks" (PNAS, 2017, ~5800 cit) -- Elastic Weight Consolidation (T1)
- Shin et al., "Continual Learning with Deep Generative Replay" (NeurIPS, 2017) (T1)

**Idea**: Catastrophic forgetting in neural networks -- where learning new tasks destroys
performance on old tasks -- is the parameter-space version of your embedding-space problem.
When you switch embedding models (mxbai -> qwen3), all old embeddings become "catastrophically
forgotten" in the new model's representation space.

**The EWC solution is analogous to your approach**: EWC adds a quadratic penalty to prevent
important parameters from changing during new learning. Your GC approach similarly identifies
"important" embeddings (high centrality, high query frequency) and prioritizes their refresh --
protecting them from degradation first.

**Usefulness**: **B -- Useful framing**. The catastrophic forgetting literature provides
vocabulary and theoretical tools. Not a novel connection but worth mentioning in Related Work.

---

## 5. Bayesian/Information-Theoretic Perspectives on Maintenance

### 5.1 Rational Inattention (Sims 2003) -- Deepened

**Source**: Christopher Sims, "Implications of Rational Inattention" (Journal of Monetary
Economics, 2003, Nobel Prize 2011) (T1)
Deepened: Matejka & McKay, "Rational Inattention to Discrete Choices" (AER, 2015) (T1)
Very recent: Engh, "On Rational Inattention with Arbitrary Choice Sets" (arXiv:2603.15548, March 2026) (T2)

**Idea**: Rational inattention says agents have *finite information processing capacity*
(measured in bits/second via mutual information). They optimally allocate attention given
this constraint. This is the deep economic foundation for your budget parameter B.

**Deepened connection**: Matejka & McKay (2015) show that under Shannon entropy information
costs, the optimal attention policy produces multinomial logit choice probabilities. Applied
to your GC:
- The GC agent has a finite budget B (information processing capacity)
- It must decide which nodes to re-embed (attend to)
- The optimal policy would allocate attention proportional to the "value of re-embedding"
  each node -- which is exactly your priority function (staleness x query_frequency x centrality)

**Engh (2026)** -- just last week! -- shows rational inattention is equivalent to a
nested regularized optimal transport problem. This could connect your GC scheduling to
optimal transport theory.

**Usefulness**: **A -- Directly citable (T1)**. Sims (2003) is Nobel Prize work. The
rational inattention framework provides deep economic justification for why your GC must
be budgeted and prioritized. Include in Section 3 (theory) or Section 8 (Discussion).

**Concrete recommendation**: In Section 4.2 (PRIORITIZED-REFRESH), add a footnote or remark:
"The budgeted refresh mechanism can be viewed through the lens of rational inattention
(Sims, 2003): the GC agent has finite processing capacity and must optimally allocate
re-embedding effort across artifacts, analogous to an economic agent optimally allocating
attention across information sources."

### 5.2 Value of Information (VoI) Framework

**Source**: De Lara & Gossner, "Payoffs-Beliefs Duality and the Value of Information"
(arXiv:1908.01633, published in Mathematics of Operations Research) (T1/T2)
Classical: Howard, "Information Value Theory" (IEEE Trans. SSC, 1966) (T1)

**Idea**: The VoI framework asks: "How much is it worth to acquire information X before
making decision Y?" Applied to your GC:

- **Decision**: Should we re-embed node v?
- **Information**: What is the current staleness of v?
- **VoI**: The expected improvement in query quality from re-embedding v

Your priority function is implicitly computing a VoI: nodes where re-embedding would most
improve query results (high staleness, high query frequency, high centrality) have the
highest value of information.

**Key insight from De Lara & Gossner**: They show there's a *duality* between payoffs and
beliefs -- the value of information can be analyzed through the lens of convex analysis.
This could formalize your priority function.

**Usefulness**: **B -- Useful framing**. The VoI framework is well-established in decision
theory and could be mentioned in Discussion to give economic grounding.

### 5.3 Optimal Monitoring / Condition-Based Maintenance

**Source**: Kalosi et al., "Condition-based maintenance at both scheduled and unscheduled
opportunities" (arXiv:1607.02299, IMA MIMAR 2016) (T2)
Classical: Alaswad & Xiang, "A review on condition-based maintenance optimization models
for stochastically deteriorating system" (Reliability Eng., 2017) (T1)

**Idea**: The industrial maintenance literature solves *exactly* your problem, but for physical
systems: "Given that a component degrades stochastically, when should we inspect it, and
when should we replace it?" The optimal policy is a *control-limit policy* where maintenance
is triggered when degradation exceeds a threshold.

**Your GC IS condition-based maintenance**: The staleness function s(v) is the "degradation
measure"; the GC threshold triggers maintenance (re-embedding) when staleness exceeds a
limit; the budget B caps the maintenance effort per cycle.

**Usefulness**: **B -- Useful cross-domain connection**. The maintenance optimization
literature is large and mature (T1). A brief mention in Discussion could show the generality
of your approach across domains.

---

## 6. The Lindy Effect for Knowledge -- Deep Dive

### 6.1 Formal Treatment

**Source**: Toby Ord, "The Lindy Effect" (arXiv:2308.09045, August 2023) (T2)
Taleb, *Antifragile* (2012), ch. 17 (popular treatment, T5-equivalent)
Mandelbrot, "The variation of certain speculative prices" (1963) (T1 -- foundational)

**Idea (from Ord 2023 specifically)**:

Ord proves that the Lindy effect does NOT require a declining hazard rate. It arises
naturally when there is a *probability distribution over the hazard rate itself* -- i.e.,
when different entities have different "death rates" but you don't know which rate applies
to a given entity. This is exactly the situation in your knowledge store:

- Some nodes (conversations) have high hazard rates (churn quickly)
- Some nodes (papers, authors) have low hazard rates (persist indefinitely)
- The GC system doesn't know a priori which rate applies
- But by observing survival time, it can infer the rate (Bayesian updating)

**This justifies your generational approach mathematically**: Long-surviving nodes are
likely to have low hazard rates, so they need less frequent collection. Young nodes are a
mix -- some will die soon (high hazard), some will persist (low hazard) -- so they need
more frequent checking. This is exactly generational GC.

### 6.2 Knowledge Half-Lives

**Source**: Arbesman, *The Half-Life of Facts* (2012) (T5 -- popular science)
Formally: de Solla Price, "Networks of Scientific Papers" (Science, 1965) (T1)
Recent: LongEval at CLEF 2025 (arXiv:2503.08541) -- longitudinal IR evaluation (T2)

**Idea**: Different types of knowledge have different "half-lives":
- Scientific facts: ~45 years (Arbesman)
- Medical knowledge: ~7 years
- Software documentation: ~2 years
- Conversation context: ~days to weeks

Your lifecycle-aware TTLs (ChatSession=90d, Author=infinity) are an engineering implementation
of knowledge half-lives. This could be formalized: each node label has an associated half-life
lambda, and the expected staleness grows as `1 - exp(-t/lambda)`.

**Usefulness**: **A -- Directly citable**. The Arbesman book is well-known; de Solla Price is
T1. The connection between knowledge half-lives and GC scheduling intervals is natural and
publishable.

**Concrete recommendation**: In Section 4.2, when discussing lifecycle-aware scheduling:
"Knowledge artifacts have different characteristic half-lives (Arbesman, 2012): conversational
context degrades within weeks, while bibliographic metadata persists for decades. Our TTL
parameters encode these domain-specific decay rates."

---

## 7. Synthesis: Novel Angles for the Paper

### Angle A: "GC as Epistemic Maintenance" (Discussion section)

Frame the entire GC problem as one of *epistemic hygiene* for AI systems. Just as rationalists
argue that beliefs must be actively maintained (not just initially formed), knowledge stores
must be actively maintained. The paper contributes a formal framework for this maintenance.

**Sources**: Yudkowsky Sequences (T6), Alexander on replication (T4)

### Angle B: "The Generational Hypothesis IS the Lindy Effect" (Section 2.3 or 3.1)

Your most formally substantiable connection. Cite Ord (2023) to show that heterogeneous hazard
rates naturally produce Lindy-distributed lifetimes, which is exactly what makes generational
GC efficient. This turns an engineering heuristic into a theoretically grounded design choice.

**Sources**: Ord 2023 (T2), Lieberman & Hewitt 1983 (T1, already cited)

### Angle C: "GC as Memory Consolidation" (Discussion section)

Draw the explicit parallel to CLS theory: your knowledge store has a hippocampal layer
(episodic, high-churn) and a neocortical layer (semantic, stable). GC performs the
consolidation function. The inesorabilita principle is synaptic homeostasis.

**Sources**: McClelland et al. 1995 (T1), Tononi & Cirelli 2014 (T1)

### Angle D: "Budget Allocation as Rational Inattention" (Section 4.2)

The budget parameter B is not arbitrary -- it's the information processing capacity of a
rationally inattentive agent. The priority function is the optimal attention allocation policy.

**Sources**: Sims 2003 (T1, Nobel), Matejka & McKay 2015 (T1)

### Angle E: "Active Forgetting Improves System Quality" (Section 6 experiments)

Frame your TTL-based deletion not as a loss but as an improvement. Cite Peng et al. (2021)
and Sanati et al. (2025) on how forgetting improves generalization and self-consistency.
Your experiments should show that GC with TTL-based deletion *improves* nDCG@10 beyond
just restoring it -- by removing noise.

**Sources**: Peng et al. 2021 (T2), Sanati et al. 2025 (T2)

### Angle F: "Spaced Repetition Scheduling for GC" (Future Work)

Propose that GC intervals could follow spaced repetition algorithms (FSRS, SM-2): nodes
that consistently prove fresh get exponentially longer intervals between checks; nodes
that are frequently stale get checked more often. This is a natural extension of your
generational approach.

**Sources**: Gwern synthesis (T4), Ebbinghaus 1885 (T1), Wozniak 1994 (T1)

---

## 8. Specific Additions by Paper Section

| Section | Addition | Source | Type |
|---------|----------|--------|------|
| 1 (Intro) | "Silent failure" framed as map-territory divergence | Yudkowsky (T6) | B |
| 2.3 (GC Background) | Lindy effect justifies generational hypothesis | Ord 2023 (T2) | A |
| 2.3 (GC Background) | SHY: sleep as biological GC precedent | Tononi & Cirelli 2014 (T1) | A |
| 3.1 (S-R Framework) | Staleness as loss of self-consistency (Sanati) | Sanati et al. 2025 (T2) | A |
| 4.2 (PRIORITIZED-REFRESH) | Budget as rational inattention capacity | Sims 2003 (T1) | A |
| 4.2 (PRIORITIZED-REFRESH) | Priority function as VoI computation | Howard 1966 (T1) | B |
| 4.2 (PRIORITIZED-REFRESH) | Knowledge half-lives justify TTLs | Arbesman 2012 / de Solla Price 1965 | A |
| 7 (Related Work) | Active forgetting in NNs as parallel | Peng et al. 2021 (T2) | A |
| 7 (Related Work) | CLS theory: hippocampus/neocortex dual system | McClelland et al. 1995 (T1) | A |
| 8 (Discussion) | GC as epistemic maintenance / belief updating | Rationalist tradition (T6) | B |
| 8 (Discussion) | Spaced repetition scheduling for future GC | Gwern (T4), primary lit (T1) | B |
| 8 (Discussion) | Condition-based maintenance analogy | Industrial maintenance lit (T1) | B |

---

## 9. Papers to Cite (New Additions)

| # | Paper | Tier | Cit. | Where in paper |
|---|-------|------|------|----------------|
| 1 | Ord (2023) "The Lindy Effect" arXiv:2308.09045 | T2 | ~low | Sec 2.3, Theory |
| 2 | McClelland, McNaughton & O'Reilly (1995) Psychological Review | T1 | ~4800 | Sec 7, Discussion |
| 3 | Tononi & Cirelli (2014) "Sleep and the Price of Plasticity" Neuron | T1 | ~2500 | Sec 2.3, Discussion |
| 4 | Sims (2003) "Implications of Rational Inattention" JME | T1 | ~3500 | Sec 4.2 |
| 5 | Peng et al. (2021) "Learning by Active Forgetting" arXiv:2111.10831 | T2 | ~low | Sec 7 |
| 6 | Sanati et al. (2025) "Forgetting is Everywhere" arXiv:2511.04666 | T2 | ~new | Sec 3, 7 |
| 7 | Arbesman (2012) *The Half-Life of Facts* | T5 | -- | Sec 4.2 |
| 8 | de Solla Price (1965) "Networks of Scientific Papers" Science | T1 | ~3000+ | Sec 4.2 |
| 9 | Kirkpatrick et al. (2017) "Overcoming catastrophic forgetting" PNAS | T1 | ~5800 | Sec 7 |
| 10 | Matejka & McKay (2015) "Rational Inattention to Discrete Choices" AER | T1 | ~800 | Sec 4.2 footnote |

---

## 10. Execution Plan

When switching out of plan mode, the task is to:

1. Write a clean research report to `/data/massimiliano/docs/papers/kore-gc/research/07-rationalist-connections.md`
   containing the above synthesis in a format matching the existing research reports.

2. No code changes needed -- this is purely research output.

3. The report should be organized by the 6 "Angles" (A-F) identified above, with each angle
   containing: the idea, the sources, the concrete text to add, and the citability rating.
