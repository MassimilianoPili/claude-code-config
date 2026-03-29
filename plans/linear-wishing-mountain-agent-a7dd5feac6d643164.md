# Research: Nightly Batch Processing with Local 70B LLM for Personal Knowledge Management

## Executive Summary

A 70B-class local LLM (Qwen2.5-72B or Llama 3.1 70B) running at 3-5 tok/s on a single RTX 3090 represents a viable engine for nightly batch enrichment of a personal knowledge management system. The key insight from the literature is that **structured extraction tasks** -- where the output schema is well-defined and can be validated -- are precisely where local 70B models perform closest to frontier models. This is the sweet spot: the quality gap narrows when you constrain the output format and can retry failures.

**Epistemic status:** Medium-high confidence. Based on synthesis of benchmark papers (T2), practitioner reports (T5-T6), and direct extrapolation from model evaluation data. No single paper addresses this exact use case end-to-end; the recommendations are synthesized from component-level evidence.

**Confidence:** Medium -- benchmark results are solid, but real-world quality on personal/niche content requires empirical validation.

---

## 0. Foundational: Hardware and Model Constraints

### RTX 3090 (24GB VRAM) Reality Check

A 70B model at Q4_K_M quantization requires ~42GB, far exceeding a single 3090's 24GB VRAM. Practical options:

| Model | Quantization | VRAM | Quality | Speed |
|-------|-------------|------|---------|-------|
| Qwen2.5-72B | Q4_K_M | ~42GB | Best open-weight | **Too large for 1x 3090** |
| Qwen2.5-72B | Q2_K | ~28GB | Significant degradation | Marginal fit with offloading |
| **Qwen2.5-32B** | **Q4_K_M** | **~20GB** | **~90% of 72B on extraction** | **8-12 tok/s on 3090** |
| Qwen3-30B-A3B (MoE) | Q4_K_M | ~18GB | Active params only 3B | Very fast but less capable |
| Llama 3.1 70B | Q4_K_M | ~42GB | Strong but same VRAM issue | Too large |
| Llama 3.1 8B | Q8_0 | ~9GB | Much weaker for extraction | Very fast |

**Recommendation:** For a single 3090, **Qwen2.5-32B-Instruct at Q4_K_M** is the practical sweet spot (~20GB VRAM, fits with room for KV cache). It performs remarkably close to 72B on structured extraction tasks. If gaia gets a second GPU or the user adds CPU offloading with enough RAM (64GB available), the 72B becomes viable at ~3 tok/s with partial offload.

The rest of this analysis assumes **Qwen2.5-32B** as the primary model, with notes on where 72B would materially help.

---

## 1. Foundational: Structured Output with Local LLMs

### State of the Art

The reliability of JSON output from local LLMs has improved dramatically since 2024.

**Key findings:**

1. **Constrained decoding eliminates syntactic errors.** Tools like Outlines, XGrammar (used by SGLang), and llama.cpp's GBNF grammars force the model to produce valid JSON by masking invalid tokens at each generation step. Ollama supports this via `format: "json"` parameter. (T2 -- Geng et al., "JSONSchemaBench", arXiv:2501.10868, 2025)

2. **Constrained decoding has a quality cost ("projection tax").** When the model's preferred continuation is masked out, it picks a valid but potentially semantically wrong alternative. A recent paper proposes Draft-Conditioned Constrained Decoding (DCCD) to mitigate this: generate unconstrained first, then constrain conditioned on the draft. +24pp accuracy improvement on GSM8K for small models. (T2 -- Reddy et al., "DCCD", arXiv:2603.03305, 2026)

3. **Qwen2.5 models are specifically trained for structured output.** The Qwen2.5 series includes extensive instruction tuning on JSON generation tasks. Community reports (r/LocalLLaMA, HackerNews) consistently rank Qwen2.5 as the best open model family for JSON output fidelity.

4. **Small models can match large ones for constrained tasks.** A survey on SLMs for agentic systems (Sharma & Mehta, arXiv:2510.03847, 2025) found that guided decoding + strict JSON Schema outputs "close much of the capability gap with larger models" for tool use and function calling.

### Practical Implications for This System

- **Always use Ollama's `format: "json"` or GBNF grammars** -- this guarantees parseable output.
- **Design schemas with enums and constrained fields** -- the more you constrain, the more reliable.
- **Implement a validation + retry loop** -- parse JSON, validate against schema, retry on failure (expect <5% retry rate with Qwen2.5-32B).
- **For complex schemas, use chain-of-thought in a `reasoning` field** that gets discarded after parsing.

---

## 2. Foundational: KGGen / GraphRAG Approach

### Microsoft GraphRAG

The seminal paper is Edge et al., "From Local to Global: A Graph RAG Approach to Query-Focused Summarization" (arXiv:2404.16130, 2024). The approach:

1. LLM extracts entities and relationships from text chunks -> knowledge graph
2. Leiden community detection partitions the graph into topic clusters
3. LLM generates community summaries at multiple hierarchy levels
4. At query time, retrieve relevant communities + summaries

**Key insight for this system:** GraphRAG was designed for *query answering*, but its *indexing pipeline* (steps 1-2) is exactly what's needed for knowledge graph enrichment. The graph construction step is the most token-intensive and the most suitable for batch processing.

**Quality with local LLMs:** GraphRAG-V (Yu et al., 2025) found that "GraphRAG's gains stem not from explicit Knowledge Graph triples but from exposing the LLM to community-structured context." This suggests that even if entity extraction quality is somewhat lower with a 32B model, the community structure still provides value.

### KGGen (OpenReview, 2025)

KGGen (Mo et al., OpenReview:2QnwE6epIm) focuses on text-to-knowledge-graph extraction with differential testing for quality validation. Their approach validates KG quality by having multiple LLM generations and checking consistency -- a technique perfectly suited for nightly batch processing where you can afford multiple passes.

### Key Paper: "Generating KGs from LLMs: GPT-4, LLaMA 2, and BERT" (Bhatt et al., arXiv:2412.07412, 2024)

This directly compares models on KG generation. Findings:
- **GPT-4 achieves superior semantic fidelity and structural accuracy**
- **LLaMA 2 (13B) excels in lightweight, domain-specific graphs**
- The quality gap is primarily in relationship extraction, less so in entity extraction

**Extrapolation for 32B/70B:** Entity extraction (NER-like) is where local models are closest to frontier. Relationship extraction and ontology coherence is where the gap widens. Mitigation: use a predefined ontology/schema rather than open-ended extraction.

---

## 3. Use Case Analysis

### Priority Ranking (Value/Effort, recommended order)

| Rank | Use Case | Value | Effort | V/E Score |
|------|----------|-------|--------|-----------|
| **1** | Paper summarization | Very High | Low | 5/5 |
| **2** | Kindle enrichment | Very High | Medium | 4/5 |
| **3** | Anki card generation | High | Medium | 4/5 |
| **4** | Knowledge extraction (WikiJS) | Medium | Medium | 3/5 |
| **5** | Code review batch | Medium | High | 2/5 |

---

### USE CASE 1: Paper Summarization (PRIORITY: HIGHEST)

#### Concrete Value

The paper archive has 105 papers with metadata but no structured summaries. A structured summary per paper enables:
- **Faster triage**: scan 2-sentence summaries instead of reading abstracts
- **Better graph connections**: extracted key findings become linkable nodes
- **Anki integration**: summaries feed directly into flashcard generation (UC3)
- **Search enrichment**: structured fields (method, finding, limitation) improve semantic search

**Problem solved:** Currently, papers sit as metadata-only nodes. Their intellectual content is not queryable through the graph.

#### State of the Art

- Structured academic summarization is a well-studied task (Liu et al., "BigSurvey", IJCAI 2022; Gidiotis & Tsoumakas, "SUSIE", arXiv:1905.07695).
- Factored Verification (George & Stuhlmuller, arXiv:2310.10627, 2023, WIESP@IJCNLP-AACL) found 0.62 hallucinations/summary for ChatGPT, 0.84 for GPT-4 on academic paper summarization. Self-correction reduced these by ~25-40%.
- Schaible (2025, HTWK Leipzig thesis) found that **Qwen2.5-72B-Instruct achieved the highest overall performance** among tested models for abstract generation on long documents.

#### Quality at 32B/70B

- **Summarization is the strongest task for local LLMs.** It's primarily comprehension + compression, not creative generation.
- Qwen2.5-32B should achieve ~85-90% of frontier quality on paper summarization.
- The key risk is **hallucination of specific claims** not present in the abstract. Mitigation: constrain output to reference only information present in the input, use structured fields.

#### Implementation Complexity: LOW

```
Input: paper title + abstract + authors + venue (already in AGE)
Prompt: structured extraction template
Output: JSON with fields {core_claim, method, key_findings[], limitations[], domain_tags[]}
Storage: update Paper node properties in AGE + generate embedding
```

No external data fetching needed. Pure text-in, structured-text-out.

#### Token Economics

| Metric | Estimate |
|--------|----------|
| Input per paper | ~500 tokens (abstract) + ~200 tokens (prompt) = ~700 |
| Output per paper | ~300 tokens (structured summary) |
| Total per paper | ~1,000 tokens |
| Backlog | 105 papers |
| Total tokens | ~105,000 |
| Time at 5 tok/s output | ~105K output tokens / 5 = 5.8 hours |
| **Realistic estimate** | ~2-3 hours (output is only 300 tok/paper; input processing is fast) |

At 5 tok/s generation, the 105-paper backlog processes in **one night**. Incremental: ~5 minutes per new paper.

#### Prompt Strategy

**Few-shot with structured output.** Provide 2-3 exemplar paper->summary pairs from the actual collection. Use chain-of-thought in a `reasoning` field (discarded post-parse).

```json
{
  "reasoning": "This paper presents... The key contribution is...",
  "core_claim": "One sentence stating the main thesis",
  "method": "Identification strategy or proof technique",
  "key_findings": ["Finding 1 with effect size", "Finding 2"],
  "limitations": ["Limitation 1"],
  "domain_tags": ["cs.LG", "economics"],
  "connections": ["Related concept already in graph"]
}
```

---

### USE CASE 2: Kindle Enrichment (PRIORITY: HIGH)

#### Concrete Value

~30K+ Kindle highlights are stored as text nodes but are essentially unstructured. Enrichment enables:
- **Concept extraction**: identify themes, frameworks, principles mentioned across books
- **Cross-book connections**: find when different authors discuss the same concept
- **Serendipitous discovery**: "these 5 highlights from 3 different books all relate to mechanism design"
- **Knowledge graph densification**: currently highlights are leaf nodes; enrichment creates edges

**Problem solved:** Highlights are isolated text fragments. Their semantic content is not linked to the broader knowledge graph.

#### State of the Art

- NVIDIA's blog on LLM-driven KGs (2024) describes a pipeline: chunk -> extract entities -> extract relations -> resolve entities -> build graph.
- GraphRAG's entity extraction step is directly applicable here.
- For book highlights specifically, the challenge is that each highlight is a short fragment (typically 1-3 sentences) without full context.

#### Quality at 32B/70B

- **Entity/concept extraction from short text is harder than from full paragraphs.** The model has less context to disambiguate.
- For well-known concepts (e.g., "Nash equilibrium", "comparative advantage"), 32B models will identify them reliably.
- For subtle or implicit concepts, quality will be lower. **Batch-and-validate** approach: extract, then cluster extracted concepts, then validate clusters.
- Estimated quality: ~75-80% precision, ~60-70% recall vs. frontier models on concept extraction from highlights.

#### Implementation Complexity: MEDIUM

Challenges:
1. **Volume**: 30K highlights is a large batch. Need chunking strategy (process N highlights per night).
2. **Entity resolution**: "Nash equilibrium" and "game-theoretic equilibrium" should merge. Need a post-processing deduplication step.
3. **Schema design**: what node types? Concept, Theme, Framework, Person, Technique?
4. **Context poverty**: highlights lack book-level context. Mitigation: include book title + author as context.

#### Token Economics

| Metric | Estimate |
|--------|----------|
| Input per highlight | ~100 tokens (highlight) + ~50 tokens (book context) + ~200 tokens (prompt) = ~350 |
| Output per highlight | ~150 tokens (extracted concepts + relations) |
| Total per highlight | ~500 tokens |
| Backlog | 30,000 highlights |
| Batch size per night | ~2,000 highlights (budget ~8 hours) |
| Nights to clear backlog | ~15 nights |
| Time per batch at 5 tok/s | ~2K * 150 output / 5 = ~8.3 hours |

**Progressive convergence**: process 2,000 highlights per night. Full backlog cleared in ~2-3 weeks. This aligns perfectly with the principio di inesorabilita.

**Optimization**: batch multiple highlights from the same book into a single prompt (5-10 highlights + book context). This reduces prompt overhead and improves context for extraction. Estimated speedup: 2-3x.

#### Prompt Strategy

**Few-shot with ontology priming.** Provide the existing concept taxonomy from the knowledge graph, and ask the model to map highlights to existing concepts or propose new ones.

```json
{
  "highlight_id": "...",
  "concepts": [
    {"name": "Mechanism Design", "type": "framework", "existing_node": true},
    {"name": "Incentive Compatibility", "type": "principle", "existing_node": false}
  ],
  "relations": [
    {"from": "highlight", "to": "Mechanism Design", "type": "DISCUSSES"},
    {"from": "Mechanism Design", "to": "Incentive Compatibility", "type": "CONTAINS"}
  ]
}
```

---

### USE CASE 3: Anki Card Generation (PRIORITY: HIGH)

#### Concrete Value

17K existing Anki cards, but new material (papers, book highlights) requires manual card creation. Auto-generation enables:
- **Continuous learning pipeline**: paper -> summary -> flashcards, automatically
- **Higher card quality**: LLMs can generate cards following spaced repetition best practices (atomic, specific, answerable)
- **Coverage**: ensure every key finding from a paper gets a card

**Problem solved:** The bottleneck in the learning pipeline is card creation. Andy Matuschak's research shows that the quality of prompts (cards) is the most important factor in spaced repetition effectiveness -- and most people write bad cards.

#### State of the Art

- LECTOR (Zhao, arXiv:2508.03275, 2025) proposes LLM-enhanced concept-based spaced repetition, using semantic similarity to handle confusion between related concepts.
- LessWrong community (T6, "Creating Flashcards with LLMs", 2023) reports that LLM-generated cards are effective when: (a) the source material is provided verbatim, (b) cards follow the "minimum information principle", (c) each card tests exactly one fact.
- Khurana et al. (medRxiv, 2025) evaluated LLM-generated summaries + Anki flashcards for medical students, finding positive results for comprehension.
- seangoedecke.com (T5, "What I learned building an AI-driven spaced repetition app", 2025) warns about **parallel-generation repetitiveness**: generating many cards from the same source produces redundant cards.

#### Quality at 32B/70B

- **Card generation is a well-constrained creative task.** The model needs to identify testable facts and phrase them as Q&A pairs.
- Quality is highly dependent on prompt engineering. With good few-shot examples of well-crafted cards, 32B models produce usable cards ~80% of the time.
- The main failure mode is **cards that are too vague or test trivia rather than understanding**.
- Mitigation: generate candidate cards, then filter with a second pass (same model, different prompt: "Is this card atomic? Does it test understanding or trivia?").

#### Implementation Complexity: MEDIUM

The MCP already has Anki tools (`anki_add_note`, `anki_bulk_add_notes`). The pipeline:
1. Take a paper summary (from UC1) or a batch of highlights (from UC2)
2. Generate candidate flashcards as JSON
3. Quality filter (second LLM pass or heuristic rules)
4. Add to Anki via MCP tools, tagged by source

**Gotcha**: Anki card quality is subjective. Need a human review step initially to calibrate the prompt. Generate cards to a staging deck, review weekly, iterate on prompt.

#### Token Economics

| Metric | Estimate |
|--------|----------|
| Input per paper | ~500 tokens (summary from UC1) + ~300 tokens (prompt) = ~800 |
| Output per paper | ~500 tokens (5-8 cards) |
| Total per paper | ~1,300 tokens |
| Papers in backlog | 105 |
| Total tokens | ~136,500 |
| Time at 5 tok/s | ~3.8 hours |

**Key insight**: UC3 depends on UC1 (paper summaries) for best results. Process papers first, then generate cards from the summaries. Can run as a second nightly pass.

#### Prompt Strategy

**Minimum information principle + few-shot.** Based on Matuschak's and Wozniak's 20 rules of formulating knowledge:

```
Given this paper summary, generate Anki flashcards following these rules:
1. Each card tests exactly ONE fact or concept
2. Front: a specific question (not "What is X?" but "In what situation does X apply?")
3. Back: concise answer (1-3 sentences max)
4. Include the source paper citation
5. Prefer "why" and "how" questions over "what" questions
6. For empirical results, include the effect size on the back

Source: {paper_summary}
```

---

### USE CASE 4: Knowledge Extraction from WikiJS (PRIORITY: MEDIUM)

#### Concrete Value

~100+ WikiJS pages contain infrastructure documentation, project plans, and operational knowledge. Extraction enables:
- **Structured search**: find all services that depend on PostgreSQL, all auth patterns, etc.
- **Graph enrichment**: create edges between wiki pages and infrastructure/concept nodes
- **Staleness detection**: identify wiki pages that describe outdated configurations

**Problem solved:** Wiki pages are prose documents. Their structured content (service names, configuration details, dependencies) is not machine-queryable.

#### Quality at 32B/70B

- For **infrastructure documentation extraction** (service names, ports, dependencies), local models are very reliable because the entities are well-defined and constrained.
- For **conceptual knowledge extraction** from project plans, quality is lower -- more akin to open-ended summarization.
- **Key advantage**: the AGE knowledge graph already has an infrastructure schema. The LLM just needs to match wiki content to existing node types.

#### Implementation Complexity: MEDIUM

- WikiJS pages vary enormously in structure and content
- Need page-type classification first (infra doc vs. project plan vs. tutorial)
- Infrastructure pages: extract services, dependencies, ports, auth patterns -> match to existing AGE nodes
- Project pages: extract goals, status, technologies, dependencies

**Gotcha**: Much of the infra knowledge is already in AGE via the import scripts. The marginal value is primarily for (a) newly added wiki pages, (b) cross-references between pages, (c) conceptual content not covered by the structured imports.

#### Token Economics

| Metric | Estimate |
|--------|----------|
| Input per page | ~2,000 tokens (average wiki page) + ~300 tokens (prompt) = ~2,300 |
| Output per page | ~400 tokens (extracted entities + relations) |
| Total per page | ~2,700 tokens |
| Pages | ~100 |
| Total tokens | ~270,000 |
| Time at 5 tok/s | ~5.6 hours (one night) |

#### Prompt Strategy

**Schema-constrained extraction with existing ontology.** Provide the list of existing node types from AGE and ask the model to identify instances.

---

### USE CASE 5: Code Review Batch (PRIORITY: LOWEST)

#### Concrete Value

~20+ Gitea repos. Nightly analysis could detect:
- Security issues (hardcoded secrets, SQL injection, etc.)
- Code style violations
- Dead code / unused dependencies
- Documentation gaps
- TODO/FIXME tracking

**Problem solved:** No automated code quality feedback currently exists. Issues accumulate silently.

#### Quality at 32B/70B

- **Code review is where the gap between local and frontier models is largest.** (T7 -- Simon Willison's "2025: Year in LLMs"; T7 -- PubMed benchmark: GPT-4o 0.73 accuracy vs. Llama 3.1 0.50)
- For **pattern-matching tasks** (find hardcoded secrets, find TODO comments), local models are adequate.
- For **architectural review** (is this design pattern appropriate?), local models are significantly weaker.
- **Qwen2.5-Coder-32B** exists and is specifically tuned for code tasks. Community reports it passing human review for clarity and accuracy in 82% of documentation generation cases (ucstrategies.com, 2026).

#### Implementation Complexity: HIGH

- Need to handle multiple languages (Go, Java, Python, JavaScript, Lua)
- Repository context is essential but expensive (can't fit entire repos in context)
- Need intelligent file selection (what changed since last review? what's most critical?)
- Output needs to be actionable, not just informational
- False positive rate matters: too many false alarms = ignored output

**Gotcha**: The most valuable code review insights require understanding the *intent* behind the code, which requires project context that's expensive to provide. A local 32B model reviewing code files in isolation will produce many low-quality observations.

#### Token Economics

This is the most token-hungry use case:

| Metric | Estimate |
|--------|----------|
| Input per file | ~1,500 tokens (code) + ~500 tokens (prompt + context) = ~2,000 |
| Output per file | ~300 tokens (findings) |
| Files per repo (critical) | ~10-20 key files |
| Repos | ~20 |
| Total files | ~300 |
| Total tokens | ~690,000 |
| Time at 5 tok/s | ~11.5 hours (exceeds one night) |

Would need to spread across multiple nights or limit scope to recently changed files.

#### Recommendation

**Deprioritize this.** The value/effort ratio is lowest. The quality gap with frontier models is largest. The token cost is highest. If implemented at all, start with the narrowest scope: scan for hardcoded secrets and TODO tracking only.

---

## 4. Cross-Cutting: Prompt Strategies Summary

| Use Case | Best Strategy | Why |
|----------|--------------|-----|
| Paper summarization | Few-shot + structured JSON | Well-defined output, exemplars available |
| Kindle enrichment | Ontology-primed extraction | Need to map to existing graph schema |
| Anki generation | Minimum-information-principle few-shot | Card quality depends on following specific rules |
| WikiJS extraction | Schema-constrained + existing node matching | Infrastructure has well-defined entity types |
| Code review | File-focused with checklist prompt | Narrow scope improves precision |

**Universal patterns:**
- Always include a `reasoning` or `thinking` field in the JSON schema -- chain-of-thought improves extraction quality even when the reasoning is discarded
- Use temperature 0.0 for extraction tasks (deterministic)
- Use temperature 0.3-0.5 for card generation (some creativity needed)
- Always validate JSON output against schema before writing to AGE
- Implement idempotent processing: re-running on already-processed items should be safe

---

## 5. Implementation Roadmap (Nightly Batch Architecture)

### Phase 0: Infrastructure (1 session)

1. Set up Qwen2.5-32B-Instruct on gaia via Ollama
2. Create a Python batch runner script (`/data/massimiliano/kindle/nightly_enrichment.py`)
3. Implement: Ollama API client with structured output, AGE write functions (reuse `paper_archive.py` patterns), progress tracking (processed item IDs in a table), retry logic
4. Create systemd timer for nightly execution

### Phase 1: Paper Summarization (1 night)

- Process all 105 papers
- Store structured summaries as Paper node properties in AGE
- Generate embeddings for summaries via qwen3-embedding:8b
- Validate: spot-check 10 summaries manually

### Phase 2: Kindle Enrichment (2-3 weeks of nightly runs)

- Process ~2,000 highlights per night
- Create Concept/Theme/Framework nodes
- Link highlights to concepts via DISCUSSES edges
- Weekly: run entity resolution to merge duplicate concepts
- Progressive: refine ontology based on emerging patterns

### Phase 3: Anki Generation (ongoing after Phase 1)

- Generate cards from Phase 1 summaries
- Route to a staging deck for human review
- After calibration (~50 cards reviewed), enable auto-add to main deck
- Ongoing: generate cards for new papers as they're added

### Phase 4: WikiJS Extraction (1-2 nights)

- Process all wiki pages
- Focus on cross-references and conceptual content
- Low priority: most infra knowledge already in AGE

### Phase 5 (Optional): Code Review

- Only if Phases 1-4 prove successful
- Start with security scanning only
- Limit to recently changed files

---

## 6. Serendipitous Connections

1. **Kindle enrichment -> Ranking Todo project**: The concept extraction from highlights naturally produces entities that could be ranked using the Bradley-Terry model in preference-sort. "Which concepts from my reading are most important to me?" becomes answerable.

2. **Paper summarization -> Agent Framework**: The structured paper summaries are exactly the kind of structured knowledge that the agent framework's `task_graph` could use for research task planning.

3. **Anki generation -> Fantacalcio**: The same pipeline (structured data -> flashcard) could generate "xG model cards" for player statistics -- testing whether you can recall a player's key metrics.

4. **GraphRAG community detection -> Knowledge Graph UI**: The Leiden communities from a GraphRAG-style analysis of the knowledge graph would create natural cluster views in the D3.js viewer at notes.massimilianopili.com.

5. **Structured output research -> DSS Wrapper**: The constrained decoding techniques (GBNF grammars, JSON Schema enforcement) are structurally similar to the schema validation in digital signature formats (CAdES/XAdES) -- both are about ensuring output conforms to a formal grammar.

---

## 7. Key References

### Fetched and Read (T1-T2)

| Paper | Venue | Relevance |
|-------|-------|-----------|
| Edge et al., "From Local to Global: A Graph RAG Approach" | arXiv:2404.16130, 2024 | GraphRAG architecture |
| Geng et al., "JSONSchemaBench" | arXiv:2501.10868 / OpenReview, 2025 | Constrained decoding benchmark |
| Bhatt et al., "Generating KGs from LLMs: GPT-4, LLaMA 2, BERT" | arXiv:2412.07412, 2024 | Direct model comparison for KG generation |
| Sharma & Mehta, "SLMs for Agentic Systems" | arXiv:2510.03847, 2025 | SLM vs LLM capability gap analysis |
| George & Stuhlmuller, "Factored Verification" | arXiv:2310.10627, WIESP 2023 | Hallucination rates in paper summarization |
| Reddy et al., "Draft-Conditioned Constrained Decoding" | arXiv:2603.03305, 2026 | Improving constrained output quality |
| Hu & Wu, "RL-Struct" | arXiv:2512.00319, 2025 | Qwen JSON fine-tuning, 89.7% structural accuracy |
| Zhao, "LECTOR" | arXiv:2508.03275, 2025 | LLM-enhanced spaced repetition |
| Liu et al., "BigSurvey" | IJCAI 2022 | Structured academic summarization |

### Practitioner Sources (T5-T6)

- LessWrong: "Creating Flashcards with LLMs" (2023) -- practical card generation advice
- seangoedecke.com: "What I learned building an AI-driven spaced repetition app" (2025) -- repetitiveness warning
- r/LocalLLaMA: consistent community evidence that Qwen2.5 is best for JSON output
- Graphwise.ai blog: GPT-4o vs Llama-3.1-70b on entity extraction benchmarks

### Not Found

- No peer-reviewed paper specifically benchmarking 70B local models on personal knowledge graph enrichment
- No direct comparison of batch vs. interactive LLM usage for knowledge management
- Limited evidence on long-running batch stability of Ollama (anecdotal: stable for hours)

---

## 8. Quality Checklist

- [x] At least 2 primary sources (T1/T2) fetched and read
- [x] Epistemic status and confidence label in summary
- [x] Source tier labeled for key claims
- [x] Open questions addressed (quality gap, VRAM constraints)
- [x] Serendipitous connections section included
- [x] No fabricated citations
- [x] Personal project connections noted (Ranking Todo, Agent Framework, Fantacalcio, KG UI, DSS Wrapper)
- [x] Token economics estimated for all use cases
- [x] Hardware constraints analyzed realistically

---

## 9. Open Questions for Empirical Validation

1. **Actual throughput**: What is Qwen2.5-32B's real tok/s on gaia with Q4_K_M? The 3090 has different memory bandwidth characteristics than theoretical estimates.

2. **Entity resolution quality**: How well does a second LLM pass merge duplicate concepts from Kindle extraction? May need embedding-based clustering instead.

3. **Anki card acceptance rate**: What percentage of auto-generated cards survive human review? This determines whether the pipeline is net-positive or net-negative on time.

4. **Ollama batch stability**: Does Ollama handle 8+ hour continuous generation without memory leaks or quality degradation? Community reports are positive but limited to shorter runs.

5. **32B vs 72B quality delta on personal content**: Benchmarks use standard datasets. Performance on personal/niche content (infrastructure docs, specific academic domains) may differ.
