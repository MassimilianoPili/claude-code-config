# Research: Durable Task Queue + Bradley-Terry Preference Prioritization

## Research Summary: Integrating Pairwise Preference Ranking with Task Queue Scheduling

### Executive Summary

The integration of Bradley-Terry (BT) pairwise comparison models with task queue prioritization is a **novel combination of well-established components**. No existing system directly implements this exact pattern (BT-ranked durable task queue for agentic AI), but strong theoretical and practical foundations exist across crowdsourcing, RLHF reward modeling, agile project management, and active learning. The key design decisions center on: (1) hybrid scoring vs. override, (2) cold-start handling for new tasks, (3) SE-based scheduling confidence, and (4) sync frequency between the preference system and the queue.

**Epistemic status:** Strong foundations (BT model is T1-settled since 1952); integration pattern is novel (no direct precedent found)
**Confidence:** Medium-high -- individual components are well-understood, but their combination requires careful engineering

---

## Q1: Existing Systems Combining Task Queues with Human Preference Ranking

### What exists

**No direct precedent** was found for a system that combines a durable task queue with a full BT preference model. However, several adjacent systems use pairwise comparison for prioritization:

1. **Agile backlog stack ranking** (T7 -- Mountain Goat Software, Atlassian docs): Comparing each backlog item to every other item pairwise is a recognized prioritization technique. Limitation: it uses raw win counts, not a statistical model like BT. It's acknowledged as effective only for small backlogs (~20 items) because O(n^2) comparisons are impractical for large lists.

2. **Crowdsourced medical triage** (T1 -- described in BT prioritization literature): Workers on Amazon Mechanical Turk performed pairwise patient prioritization, with BT MLE used to derive a ranking. This is the closest precedent -- human preference judgments feeding a BT model to order a queue of actions (treatments). Citation: referenced in [MDPI Mathematics 2020](https://www.mdpi.com/2227-7390/8/2/276).

3. **Multi-objective combinatorial optimization with CPE** (T2 -- Defresne, Mandi, Guns, arXiv:2503.11435, 2025): Uses BT MLE + active learning acquisition function for preference elicitation in scheduling-like problems (PC configuration, routing). The user makes pairwise comparisons; the system learns objective weights via BT and selects the next most informative pair. Directly applicable pattern.

4. **RLHF reward models** (T1/T2 -- widely established): The entire RLHF pipeline is essentially "BT model over pairwise human preferences -> score -> use score to rank/schedule model outputs." The BT reward model assigns scores that determine which outputs get reinforced. This is structurally identical to "BT scores -> task priority." Key paper: Azar et al., "A General Theoretical Paradigm to Understand Learning from Human Preferences" (T2, cited ~50 times).

5. **1000minds and Prioneer** (commercial tools): Web-based pairwise ranking tools for decision-making. 1000minds uses PAPRIKA method (a constrained pairwise comparison approach). Neither integrates with a task queue, but they demonstrate the UX pattern.

6. **Active Preference Optimization** (T2 -- 2024, ~50 citations S2, 11 influential): Reformulates preference learning as a "contextual preference bandit" -- directly relevant to the idea of scheduling based on uncertain preference scores.

### Key insight

The RLHF pipeline is the best structural analogy: `human comparisons -> BT model -> reward score -> scheduling policy`. Your system replaces "LLM output ranking" with "task ranking" and "RL policy" with "task queue ordering." The difference is that RLHF operates on millions of comparisons while your system has ~10-50 tasks with sparse human input, making active learning (Information Gain pair selection) critical.

---

## Q2: Optimal Re-ranking Strategy -- BT Scores vs. Numeric Priority

### Three approaches analyzed

**Approach A: Full override** -- BT score replaces the 1-10 priority entirely.
- Pro: Clean, single source of truth. No conflation of scales.
- Con: Loses the quick-set initial priority. Requires sufficient comparisons before the ranking is meaningful.
- When to use: Mature list with >3 comparisons per item on average.

**Approach B: Weighted hybrid** -- `effective_priority = alpha * normalized_bt_score + (1-alpha) * numeric_priority`
- Pro: Graceful degradation -- new items with no comparisons fall back to numeric priority.
- Con: Two scales to maintain; alpha tuning is arbitrary without empirical calibration.
- Literature support: Hybrid models that "incorporate additional contextual information" are a recognized BT extension (T7 -- EmergentMind BT survey). The neural BT rating (NBTR) does exactly this: combines feature-based scores with BT structure.

**Approach C: BT with numeric prior (RECOMMENDED)** -- Use the numeric priority as a Bayesian prior for the BT parameter, then update via comparisons.
- Pro: Mathematically principled. The numeric priority is the prior belief; comparisons are the likelihood. As comparisons accumulate, the prior is washed out. New items have well-defined initial position.
- Con: Requires Bayesian BT implementation (slightly more complex than MLE).
- Literature support: Caron & Doucet, "Efficient Bayesian Inference for Generalized Bradley-Terry Models" (T1 -- Oxford Statistics, JRSS). Gamma priors on BT parameters are conjugate and well-studied. Also: the Elo system (equivalent to online BT) uses exactly this pattern -- initial rating = prior, K-factor = learning rate.

### Recommendation for your system

**Approach C is ideal** but may be over-engineered for the current scale. A pragmatic middle ground:

1. Store both `numeric_priority` (1-10, user-set) and `bt_score` (from Preference Sort API) in `claude_tasks`.
2. Compute `effective_priority` as:
   ```
   IF comparisons_count >= threshold THEN bt_score
   ELSE numeric_priority * decay + bt_score * (1 - decay)
   WHERE decay = exp(-comparisons_count / tau)
   ```
   With `tau = 3` (after ~9 comparisons, the numeric priority contributes <5%).
3. This is equivalent to Approach C (exponential prior washout) without requiring a full Bayesian implementation.

The key parameter is `tau` -- how many comparisons before BT dominates. With Information Gain pair selection, ~3-5 comparisons per item should suffice for stable ranking (see Q5).

---

## Q3: Cold-Start Problem for New Tasks

### The problem

When a new task is added to an existing ranked list of N items, it has:
- No BT score (no comparisons yet)
- A numeric priority (1-10) set by the user or agent
- The existing items have well-calibrated BT scores from multiple comparisons

### What the literature says

1. **Information Gain pair selection** (which your Preference Sort API already implements) naturally addresses this: new items have maximum uncertainty, so they will be selected first for comparison. This is the standard active learning approach (T2 -- Mikhailiuk et al., "Active Sampling for Pairwise Comparisons via Approximate Message Passing and Information Gain Maximization", 2021).

2. **PCA-based pseudo-labels for cold start** (T2 -- Fayaz-Bakhsh et al., arXiv:2508.05090, 2025): For items with feature vectors, PCA can generate initial pseudo-labels. In your case, task metadata (category, estimated complexity, deadline) could serve as features.

3. **Elo new-player initialization** (T7 -- Wikipedia, chess.com): Initialize at the population mean (1500 in chess). Use a higher K-factor (update rate) for new items so they converge faster. This is directly applicable.

4. **Contextual BT models** (T2 -- Bergstrom et al., arXiv:2405.03059, 2024): Use item attributes to predict BT scores for unseen items. "The contextual attribute approach enables generalization beyond the training set."

### Recommended cold-start strategy

1. **Initial placement**: Map numeric priority (1-10) to the BT score scale. If existing items have BT scores in range [a, b], place the new item at `a + (numeric_priority / 10) * (b - a)`. This gives an informed starting position rather than the population mean.

2. **Accelerated convergence**: The Information Gain criterion will naturally prioritize comparing the new item. But additionally, consider a "fast-track" mode: present 3-5 comparisons involving the new task immediately upon creation (compare it against items at the 25th, 50th, and 75th percentile of current rankings -- a binary-search-like strategy).

3. **Confidence flag**: Mark tasks with `comparisons_count < 3` as "provisional ranking" in the TUI. The agent should treat these as less reliable for scheduling.

4. **Batch insertion**: When multiple tasks arrive simultaneously (e.g., agent spawns 5 subtasks), compare them against each other first (cheap: only 10 pairs for 5 items) before integrating with the main list.

---

## Q4: Preference-Aware Scheduling in Multi-Agent / Agentic AI Systems

### Direct literature

**Sparse but growing.** The exact phrase "preference-aware scheduling" in agentic AI yields no established literature. However:

1. **RLHF as implicit preference-aware scheduling** (T1/T2 -- Lambert, "RLHF Book", 2024-2025): The RLHF pipeline is structurally a preference-aware scheduling system: human preferences -> BT reward model -> PPO/DPO policy that "schedules" which outputs to reinforce. The connection to task scheduling is direct but has not been explicitly made in the literature.

2. **Contextual preference bandits** (T2 -- Active Preference Optimization, 2024, ~50 cit S2): Reformulates preference learning as a bandit problem where the agent must decide which actions to take (schedule) based on uncertain preference estimates. The key insight: "active sampling for uncertain contexts" -- schedule tasks where the preference is least certain to gather more information (exploration) vs. schedule the highest-ranked task (exploitation).

3. **Multi-agent task allocation** (T1 -- Nature Scientific Reports, 2025): Decentralized adaptive task allocation uses "recursive regression to predict task parameters and selectively broadcast tasks to agents based on relevance and availability." This uses RL-based priority scores but not pairwise preferences.

4. **AOI: Context-Aware Multi-Agent Operations** (T2 -- arXiv:2512.13956, 2025): Dynamic scheduling with hierarchical memory compression for multi-agent systems. Uses priority-based scheduling but with context-aware dynamic priority adjustment, not pairwise comparison.

5. **Preference elicitation for combinatorial optimization** (T2 -- Defresne et al., 2025): The most directly relevant -- uses BT + active learning to learn user preferences for scheduling/optimization decisions.

### The gap

No one has published a system that does exactly: `agentic task queue + BT pairwise ranking + human-in-the-loop preference elicitation`. This is a **novel integration pattern**. The closest systems are:
- RLHF (pairwise preferences -> scheduling policy, but for LLM outputs, not tasks)
- Crowdsourced triage (pairwise preferences -> BT ranking -> queue ordering, but for medical patients, not agent tasks)
- Multi-objective optimization with CPE (pairwise preferences -> BT -> combinatorial scheduling, but for one-shot optimization, not a persistent queue)

### Opportunity

This is genuinely novel and publishable. The key contribution would be: **preference-aware scheduling with active elicitation for human-agent task management**, combining:
- Durable task queue (persistence, crash recovery)
- BT model (principled ranking from sparse pairwise data)
- Information Gain pair selection (efficient use of human attention)
- Agent integration (tasks generated and consumed by AI agents)

---

## Q5: BT Standard Error and Scheduling Confidence

### The mathematics

In the BT model, the MLE estimates parameters theta_i for each item. The standard error of theta_i is derived from the Fisher Information Matrix:

```
SE(theta_i) = sqrt([I^(-1)]_ii)
```

where I is the observed Fisher information matrix:

```
I_ij = -d^2 l(theta) / d(theta_i) d(theta_j)
```

For the BT model specifically:
- **Diagonal entries**: `I_ii = sum_{j != i} n_ij * p_ij * (1 - p_ij)` where n_ij is the number of comparisons between i and j, and p_ij is the model probability.
- **Off-diagonal**: `I_ij = -n_ij * p_ij * (1 - p_ij)`

**Key relationship**: SE decreases as `O(1/sqrt(n))` where n is the number of comparisons involving item i. Items compared more often have tighter confidence intervals.

### Confidence interval for ranking

A 95% confidence interval for item i's strength parameter is:
```
theta_i +/- 1.96 * SE(theta_i)
```

Two items i and j can be confidently distinguished when their confidence intervals do not overlap, i.e.:
```
|theta_i - theta_j| > 1.96 * sqrt(SE(theta_i)^2 + SE(theta_j)^2)
```

### Practical application to scheduling

**Use SE to decide when to schedule vs. when to ask for more comparisons:**

1. **Schedule-readiness criterion**: An item is "schedule-ready" when its SE is below a threshold relative to the gap between adjacent items. Specifically:
   ```
   schedule_ready(i) = SE(theta_i) < gamma * min_gap(i)
   ```
   where `min_gap(i) = min(|theta_i - theta_{i-1}|, |theta_i - theta_{i+1}|)` is the gap to the nearest-ranked neighbor, and `gamma` is a tolerance parameter (suggested: 0.5).

2. **When gamma = 0.5**: An item is schedule-ready when its SE is less than half the gap to its nearest neighbor. This means we're 95% confident it's correctly positioned relative to adjacent items.

3. **Exploration trigger**: If the top-ranked item is NOT schedule-ready, ask for more comparisons before scheduling it. This prevents scheduling a task that might not actually be highest priority.

4. **Practical thresholds** (estimated from BT properties):
   - 0 comparisons: SE = infinity (undefined)
   - 1-2 comparisons: SE is very high, ranking unreliable
   - 3-5 comparisons: SE drops to ~0.5-1.0 (adequate for rough ordering)
   - 7-10 comparisons: SE drops to ~0.2-0.3 (confident ranking)
   - 15+ comparisons: diminishing returns

5. **Decision rule for the agent**:
   ```
   IF top_task.se < 0.5 * gap_to_second THEN
     schedule top_task
   ELSE IF pending_comparisons_budget > 0 THEN
     present comparison (Information Gain selects the pair)
   ELSE
     schedule top_task anyway (with confidence warning)
   ```

### Connection to Information Gain

Your Preference Sort API's Information Gain criterion naturally selects pairs that maximize reduction in entropy -- which is equivalent to maximizing expected reduction in SE for the most uncertain items. So the system is self-correcting: Information Gain will prioritize comparisons that reduce SE for the items that need it most.

**Key insight from the literature** (T2 -- Hybrid-MST, 2018, ~40 cit S2): A hybrid strategy combining minimum spanning tree coverage with uncertainty-based pair selection outperforms pure Information Gain for recovering ratings from sparse comparisons. This suggests your Information Gain approach could be augmented with a "coverage" component that ensures every item has been compared at least once.

---

## Serendipitous Connections

1. **RLHF <-> Task scheduling**: The RLHF pipeline is structurally identical to this system. The BT reward model is the preference model; PPO is the "scheduler." The key difference is that RLHF has millions of data points while your system has tens. This means your system is in the **small-data regime** where active learning matters most -- exactly where Information Gain shines.

2. **Elo rating convergence <-> Task queue stabilization**: The Elo system (online BT) has proven convergence to the true ranking with rate `O(1/sqrt(n))`. Your task queue will stabilize in the same way. The "K-factor" in Elo (how much each comparison changes ratings) maps directly to how quickly new tasks affect the queue ordering.

3. **Explore-exploit tradeoff**: The decision "schedule highest-ranked task" vs. "ask for more comparisons" is a classic bandit problem. The SE-based criterion above is a form of Upper Confidence Bound (UCB) -- schedule the task with the highest lower bound of its confidence interval. This connects to: Thompson sampling, which would sample a BT score from each item's posterior and schedule the highest sample. Thompson sampling is known to be near-optimal for this type of problem (T1 -- Russo et al., "A Tutorial on Thompson Sampling", 2018, ~600 citations).

4. **Personal project connection -- Ranking Todo**: This research directly feeds the Ranking Todo project. The cold-start strategy (Q3) and SE-based scheduling (Q5) are the missing pieces for making BT-ranked task management practical. The Preference Sort API at :8093 already has the backend; this research provides the integration architecture.

5. **Personal project connection -- Agent Framework**: The multi-agent orchestration in `/data/massimiliano/agent-framework/` could use preference-aware scheduling as its task allocation mechanism. When multiple agents compete for tasks, the BT ranking provides a principled ordering that incorporates human judgment, not just numeric heuristics.

---

## Practical Integration Architecture

Based on the research, here is the recommended architecture for your system:

### Data flow

```
claude_tasks (PG)                Preference Sort API (:8093)
+------------------+             +----------------------+
| id               |  sync -->   | list_id              |
| title            |             | items[]              |
| priority (1-10)  |             |   - bt_score         |
| bt_score         |  <-- sync   |   - se               |
| bt_se            |             |   - comparisons_count |
| comparisons_count|             | next_pair (IG)       |
| status           |             +----------------------+
+------------------+
         |
         v
    Scheduling Decision
    (SE-aware, UCB-like)
```

### Sync protocol

1. **Task -> PreferenceSort**: On task creation, POST to Preference Sort API to add item. Map `priority` to initial BT score.
2. **PreferenceSort -> Task**: After each comparison, fetch updated BT scores + SE and write back to `claude_tasks`.
3. **Sync trigger**: After each comparison OR on-demand before scheduling.
4. **Conflict resolution**: Preference Sort is source of truth for ranking; `claude_tasks` is source of truth for task metadata.

### TUI workflow

```
rank-tui (or new tui)
  1. Fetch pending tasks from claude_tasks
  2. Sync to Preference Sort list
  3. Show pairwise comparison (IG-selected pair)
  4. User picks winner
  5. Repeat N times (or until top item is schedule-ready)
  6. Display final ranking with confidence indicators
  7. Agent picks top task(s) to execute
```

### Suggested new columns for claude_tasks

```sql
ALTER TABLE claude_tasks ADD COLUMN bt_score DOUBLE PRECISION;
ALTER TABLE claude_tasks ADD COLUMN bt_se DOUBLE PRECISION;
ALTER TABLE claude_tasks ADD COLUMN comparisons_count INTEGER DEFAULT 0;
ALTER TABLE claude_tasks ADD COLUMN prefsort_list_id UUID;
ALTER TABLE claude_tasks ADD COLUMN prefsort_item_id UUID;
```

---

## Open Questions (for design phase)

1. **Separate list per context?** Should there be one Preference Sort list for all pending tasks, or separate lists per agent/project? One list is simpler and allows cross-project prioritization. Separate lists avoid comparing apples to oranges.

2. **Comparison decay**: Should old comparisons lose weight over time? A task compared 2 weeks ago may have changed in urgency. The BT model is static; adding time-decay requires either periodically resetting comparisons or using a dynamic BT variant.

3. **Agent-generated comparisons**: Could the AI agent itself provide pairwise preferences (based on task descriptions) as a "warm start" before human review? This connects to RLHF -- the agent acts as a noisy annotator.

4. **Batch scheduling**: When the agent can execute multiple tasks in parallel, should it take the top-K by BT score, or should it diversify (e.g., pick tasks with non-overlapping resource needs)?

---

## Seminal Papers

| Paper | Authors | Year | Cit. (S2) | Contribution |
|-------|---------|------|-----------|-------------|
| [Rank Analysis of Incomplete Block Designs](https://en.wikipedia.org/wiki/Bradley%E2%80%93Terry_model) | Bradley & Terry | 1952 | ~3000+ | Original BT model (T1) |
| [Active Preference Optimization for Sample Efficient RLHF](https://arxiv.org/abs/2402.08114) | Mehta et al. | 2024 | ~50, 11 inf | Contextual preference bandits (T2) |
| [Hybrid-MST: Active Sampling for Pairwise Preference Aggregation](https://api.semanticscholar.org/graph/v1/paper/search?query=Hybrid-MST) | Maystre & Grossglauser | 2018 | ~40 | Hybrid coverage + uncertainty sampling (T2) |
| [Preference Elicitation for Multi-objective Combinatorial Optimization](https://arxiv.org/abs/2503.11435) | Defresne, Mandi, Guns | 2025 | 0 (new) | BT + active learning for scheduling (T2) |
| [Active Preference Learning for Ordering Items In- and Out-of-sample](https://arxiv.org/abs/2405.03059) | Bergstrom et al. | 2024 | ~new | Contextual BT for cold-start (T2) |
| [Cold-Start Active Preference Learning](https://arxiv.org/abs/2508.05090) | Fayaz-Bakhsh et al. | 2025 | ~new | PCA-based cold start for BT (T2) |
| [Rethinking BT Models in Preference-Based Reward Modeling](https://arxiv.org/abs/2411.04991) | Authors | 2024 | ~new | BT limitations and alternatives (T2) |
| [Uncertainty Quantification in BTL Model](https://academic.oup.com/imaiai/article/12/2/1073/7017369) | Chen et al. | 2023 | ~? | SE and CI for BT parameters (T1 -- IMA) |
| [A Tutorial on Thompson Sampling](https://arxiv.org/abs/1707.02038) | Russo et al. | 2018 | ~600+ | Explore-exploit theory (T1) |
| [Efficient Bayesian Inference for Generalized BT Models](https://www.stats.ox.ac.uk/~doucet/caron_doucet_bayesianbradleyterry.pdf) | Caron & Doucet | 2012 | ~200+ | Bayesian BT with conjugate priors (T1) |

---

## What to Read Next

1. **Defresne et al. (2025)** -- Most directly applicable: BT + active learning for optimization with user-in-the-loop. Read sections on acquisition function design.
2. **Bergstrom et al. (2024)** -- Best treatment of the cold-start problem with contextual attributes.
3. **Active Preference Optimization (2024)** -- For the explore-exploit angle and how to decide when to schedule vs. when to ask for more comparisons.

## Sources

All URLs fetched during research:
- [Bradley-Terry Wikipedia](https://en.wikipedia.org/wiki/Bradley%E2%80%93Terry_model) (T7)
- [BT for BSC Prioritization, MDPI 2020](https://www.mdpi.com/2227-7390/8/2/276) (T1)
- [Rethinking BT in Reward Modeling, arXiv:2411.04991](https://arxiv.org/abs/2411.04991) (T2)
- [Cold-Start Active Preference Learning, arXiv:2508.05090](https://arxiv.org/abs/2508.05090) (T2)
- [Preference Elicitation for Multi-objective Optimization, arXiv:2503.11435](https://arxiv.org/abs/2503.11435) (T2)
- [Active Preference Learning for Ordering Items, arXiv:2405.03059](https://arxiv.org/abs/2405.03059) (T2)
- [Active Preference Learning for LLMs, arXiv:2402.08114](https://arxiv.org/abs/2402.08114) (T2)
- [Decentralized Task Allocation, Nature Scientific Reports 2025](https://www.nature.com/articles/s41598-025-21709-9) (T1)
- [AOI Multi-Agent Scheduling, arXiv:2512.13956](https://arxiv.org/abs/2512.13956) (T2)
- [Elo Rating System Wikipedia](https://en.wikipedia.org/wiki/Elo_rating_system) (T7)
- [Stanford BT Lecture Notes](https://web.stanford.edu/class/archive/stats/stats200/stats200.1172/Lecture24.pdf) (T7)
- [BT Uncertainty Quantification, IMA Journal 2023](https://academic.oup.com/imaiai/article/12/2/1073/7017369) (T1)
- [Bayesian BT, Caron & Doucet](https://www.stats.ox.ac.uk/~doucet/caron_doucet_bayesianbradleyterry.pdf) (T1)
- [RLHF Book, Nathan Lambert](https://rlhfbook.com/c/07-reward-models) (T5)
- [Semantic Scholar API results](https://api.semanticscholar.org/) (multiple queries)
- [Mountain Goat Software -- Backlog Prioritization](https://www.mountaingoatsoftware.com/blog/needs-wants-and-wishes-on-your-product-backlog) (T7)
- [Atlassian Prioritization Frameworks](https://www.atlassian.com/agile/product-management/prioritization-framework) (T7)
- [EmergentMind BT Survey](https://www.emergentmind.com/topics/bradley-terry-ranking-system) (T7)
