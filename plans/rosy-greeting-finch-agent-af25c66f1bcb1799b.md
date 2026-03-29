# Research Report: Local LLMs for Entity Extraction and Knowledge Graph Construction

## Executive Summary

The field of LLM-driven knowledge graph construction reached production maturity in 2024-2025, with well-established pipelines for entity extraction, relationship mining, and graph-augmented retrieval. A 27B parameter model at Q8 quantization on an RTX 3090 with CPU offload is a viable but throughput-constrained setup: expect ~15-25 tok/s generation speed (extrapolated from Q4_K benchmarks of ~33 tok/s on 3090 for Qwen3.5-27B, with Q8 being ~30GB and requiring partial CPU offload). For overnight batch processing of a few hundred documents, this is adequate. Multi-pass extraction with validation demonstrably reduces hallucinated edges by 50-77% (CoVe results). Graph+vector hybrid retrieval outperforms vector-only RAG by 24-42 percentage points on complex reasoning tasks.

**Epistemic status:** Active research area, rapidly maturing. Core techniques (structured extraction, self-verification, graph-augmented RAG) have strong empirical support from multiple independent groups. Specific throughput numbers are hardware-dependent estimates.

**Confidence:** Medium-High -- T1/T2 sources for core claims, T5/T7 for hardware benchmarks.

---

## 1. LLM-Based Entity/Relationship Extraction

### Schema-Constrained vs Free-Form Extraction

**The state of the art favors schema-constrained generation**, but with important nuances.

**Constrained decoding** (JSON mode, grammar-based decoding) guarantees syntactically valid output by modifying logits at each generation step to exclude tokens that would violate the schema (T2 -- Geng et al., "JSONSchemaBench", arXiv:2501.10868). Six frameworks were benchmarked: Guidance, Outlines, llama.cpp grammar, XGrammar, OpenAI, and Gemini. Key finding: constrained decoding eliminates format errors entirely but **may slightly degrade task performance** due to the restrictive nature of constraints, and **increases inference latency** (T2 -- Geng et al. 2025).

**Free-form extraction** with post-hoc JSON parsing is more flexible but unreliable: LLMs may insert comments, omit quotes, or produce malformed structures. In production pipelines, this requires retry logic and error handling that negates the speed advantage.

**Recommended approach for your pipeline:** Use llama.cpp's grammar-constrained generation with a JSON schema defining your entity/relationship types. For Qwen3.5-27B via Ollama, use the `format: json` option or define a response schema. The latency overhead of constrained decoding is negligible for batch processing where throughput matters more than per-token latency.

### Prompting Strategies for Structured Extraction

The LLM-empowered KG construction survey (T2 -- arXiv:2510.20345, comprehensive survey) identifies several effective strategies:

1. **Two-stage sequential extraction** (best empirical results): First extract entities, then extract relations given the entities. KGGen (T1 -- NeurIPS 2025, arXiv:2502.09956) "decomposed extraction into two sequential LLM invocations -- first detecting entities, then generating relations -- to reduce cognitive load." This achieved **18% absolute improvement over GraphRAG's extraction** and **36% lift over OpenIE** on the MINE benchmark.

2. **Few-shot prompting with domain exemplars**: The EDC framework uses "few-shot prompting to generate comprehensive natural-language triples" (T2 -- survey arXiv:2510.20345).

3. **Context-aware dynamic prompting**: ODKE+ employs "dynamically selected ontology subsets to construct context-aware prompts tailored to specific entities" (T2 -- survey).

4. **Multi-turn dialogue extraction**: ChatIE "reformulated extraction as a multi-turn dialogue process" with iterative refinement (T2 -- survey).

5. **Retrieval-augmented prompting**: Enriching the context window with semantically related exemplars from previously extracted entities improves consistency (T2 -- survey).

### Quality Scaling with Model Size

Direct NER/extraction benchmarks across model sizes are sparse in the literature, but convergent evidence suggests:

- **GLiNER** (a 300M parameter bidirectional transformer) achieves NER performance **comparable to 13B UniNER** despite being 140x smaller, and the largest GLiNER variant **outperforms GoLLIE and USM** (T1 -- NAACL 2024). This suggests that for pure NER, small specialized models can match general LLMs.

- **NuNER** (125M parameters) competes with "much larger LLMs" for NER in few-shot regimes (T2 -- arXiv:2402.15343).

- For **relationship extraction** (more complex than NER), model size matters more. The survey notes that GPT-4 class models "approach the quality of novice human modelers" for ontology construction, while smaller models require more structured prompting (T2 -- survey arXiv:2510.20345).

- **General scaling curves** for language understanding plateau at ~13B parameters (N^0.25 scaling), while reasoning scales at N^0.4 with plateau at ~70B (T5 -- multiple sources). Relationship extraction involves reasoning about entity interactions, so **27B should sit in a productive sweet spot** -- well above the language understanding plateau but below the reasoning plateau.

- **COMEM** demonstrates "cascading smaller and larger LLMs in a multi-stage pipeline" achieves "substantial efficiency gains" without sacrificing "semantic accuracy in large-scale fusion tasks" (T2 -- survey). This suggests using the 27B model for the hard extraction pass and potentially a smaller model for simpler preprocessing.

**Practical recommendation:** For your Kindle Graph Enrichment pipeline, 27B is well-positioned for entity extraction + relationship extraction from book highlights. The text chunks are short (typical Kindle highlight: 1-5 sentences), which limits the context window pressure and keeps extraction quality high even at lower quantization.

---

## 2. Triple Validation Passes

### Empirical Evidence for Self-Verification

**Chain-of-Verification (CoVe)** (T1 -- Dhuliawala et al., ACL Findings 2024, arXiv:2309.11495) is the strongest empirical result for self-verification:

- **List-based QA (Wikidata)**: Hallucinated answers reduced from 2.95 to 0.68 per query -- a **77% reduction**
- **Closed-book MultiSpanQA**: F1 improved by **23%** (0.39 to 0.48)
- **Long-form generation**: FACTSCORE increased by **28%** (55.9 to higher)
- Overall: **50-70% reduction** in factual hallucinations across task types

The CoVe method has four steps: (1) draft initial response, (2) plan verification questions, (3) answer verification questions independently (so answers are not biased by the draft), (4) generate final verified response.

### Application to Triple Validation

Your proposed second pass -- "Is [Entity A] -> [relationship] -> [Entity B] supported by this text?" -- is a simplified version of CoVe applied to information extraction. This is well-supported by the literature:

- **Graphiti/Zep** (T2 -- Rasmussen et al., arXiv:2501.13956) employs exactly this pattern: after entity and fact extraction, "an LLM [compares] new edges against semantically related existing edges to identify potential contradictions." Their extraction also uses "a reflection technique inspired by reflexion to minimize hallucinations and enhance extraction coverage."

- **EntGPT** introduces "a two-phase refinement pipeline" applying "targeted reasoning for final selection" (T2 -- survey arXiv:2510.20345).

- **VaLiK** includes "a cross-modal verification module to filter noise" (T2 -- survey).

- **Self-consistency** approaches (sampling multiple extraction passes and taking the intersection/majority vote) are a complementary technique (T2 -- survey on hallucination, arXiv:2510.06265).

**Expected reduction in hallucinated edges:** Based on CoVe's 50-77% reduction and Graphiti's reflection approach, a verification pass should eliminate **50-70% of spurious triples**. The exact reduction depends on the base hallucination rate of the extraction model; at 27B with good prompting, the base rate should be lower than with 7B models, so the absolute number of removed hallucinations may be smaller but the relative improvement still substantial.

**Practical recommendation:** Implement two variants of the verification prompt:
1. **Support check**: "Given this text: [chunk]. Is the claim '[Entity A] [relationship] [Entity B]' directly supported? Answer YES/NO with a brief justification."
2. **Contradiction check**: "Given these existing edges for [Entity A]: [...]. Does the new edge '[Entity A] [relationship] [Entity B]' contradict any existing knowledge?"

The second variant (Graphiti-style) is more expensive but catches temporal contradictions and entity confusion.

---

## 3. Provenance Tracking on Knowledge Graph Edges

### Best Practices from the Literature

**Graphiti/Zep** (T2 -- arXiv:2501.13956) provides the most detailed production architecture for provenance:

- **Bidirectional indexing**: "Episodes and their derived semantic edges maintain bidirectional indices that track the relationships between edges and their source episodes." This enables "both forward and backward traversal: semantic artifacts can be traced to their sources for citation or quotation."
- **Non-lossy episodic storage**: The episodic subgraph preserves original source text, so you never lose the raw data even after semantic abstraction.
- **Bi-temporal model**: Every edge carries `t_valid` (when the fact became true) and `t_invalid` (when it was superseded), plus ingestion timestamps.

**Uncertainty Management in KG Construction** (T2 -- Jarnac et al., arXiv:2405.16929) surveys the field systematically:
- Confidence scores should be stored as **triple metadata alongside provenance information**
- For conflicting information, the recommended approach (used by Facebook's KG) is: "remove information if the associated confidence is low, otherwise integrate conflicting information with its provenance and estimated confidence"
- Manual curation is "highly accurate, but costly and time-consuming" -- automated pipelines need provenance to enable selective human review

**Managing Provenance in KG Management Platforms** (T1 -- Springer, Datenbank-Spektrum 2023) emphasizes that provenance management is "essential to understand where certain information in a KG stems from" and "plays an important role in increasing trust and supporting open science principles."

### Recommended Edge Schema for Neo4j/AGE

Based on the literature, each edge should carry:

```
{
  source_document: "book_title / chapter",
  chunk_id: "uuid of the source chunk",
  chunk_text: "the exact text span supporting this triple",
  confidence: 0.0-1.0,  // from the extraction model
  verified: boolean,      // did it pass validation pass?
  extraction_model: "qwen3.5-27b-q8",
  extracted_at: timestamp,
  t_valid: timestamp,     // when this fact became known
  t_invalid: null,        // set when superseded
  extraction_method: "two-pass" | "single-pass"
}
```

### Impact on Downstream Retrieval Quality

Provenance-aware edges enable:
1. **Confidence-weighted retrieval**: When querying the graph, prioritize edges with high confidence and verification status
2. **Source citation**: Any claim can be traced back to the exact text that supports it
3. **Selective re-extraction**: When the extraction model improves, re-process only low-confidence edges
4. **Conflict resolution**: When two edges contradict, the one with higher confidence and more recent `t_valid` wins
5. **Audit trail**: Critical for the Kindle Graph Enrichment pipeline where you want to trace insights back to specific book passages

---

## 4. Multi-Pass Extraction Pipelines

### Empirical Comparison: Multi-Pass vs Single-Pass

The survey (T2 -- arXiv:2510.20345) provides the strongest evidence:

**KGGen** (T1 -- NeurIPS 2025, arXiv:2502.09956): Two sequential LLM invocations (entities first, then relations) achieved:
- **18% absolute improvement** over Microsoft GraphRAG's single-pass extraction
- **36% lift** over OpenIE
- Better graph density (fewer singleton nodes)
- Reduced semantic redundancy
- Evaluated on the MINE benchmark (100 articles, 1500 facts)

**LINK-KG** (T2 -- arXiv:2510.26486): Three-phase pipeline for legal text:
- Phase 1: NER-LLM extracts type-specific entities
- Phase 2: Mapping-LLM iteratively updates a prompt cache for consistency
- Phase 3: Resolve-LLM performs coreference resolution

**ChatIE**: Multi-turn dialogue extraction with iterative refinement (T2 -- survey).

**COMEM**: Cascading smaller and larger LLMs in multi-stage pipeline for efficiency (T2 -- survey).

**CREFT** (T2 -- arXiv:2505.24553): Sequential multi-agent framework where each agent refines distinct aspects -- character composition, explicit/implicit relation extraction, role identification.

### Recommended Pipeline for Your Use Case

Based on the evidence, a 4-pass pipeline optimized for the Kindle Graph Enrichment scenario:

```
Pass 1: Entity Extraction
  Input: text chunk
  Output: [{name, type, description}]
  Strategy: JSON-constrained generation, few-shot examples from your domain

Pass 2: Coreference Resolution + Entity Deduplication
  Input: entities from pass 1 + existing graph entities (via embedding similarity search)
  Output: deduplicated entity list with canonical names
  Strategy: Graphiti-style hybrid search (embedding + full-text) + LLM comparison
  Note: This is where the 27B model's reasoning capability pays off

Pass 3: Relationship Extraction
  Input: text chunk + resolved entities from pass 2
  Output: [{source_entity, target_entity, relationship_type, description}]
  Strategy: Constrained to the resolved entity set, reducing hallucination surface

Pass 4: Validation
  Input: extracted triples + source text
  Output: validated triples with confidence scores
  Strategy: CoVe-inspired verification questions
```

This is 4 LLM calls per chunk. For a typical book with ~200 highlights, that is ~800 LLM calls. At ~500 tokens per call (input + output) and ~20 tok/s generation, each call takes ~10-15 seconds. Total: ~3-4 hours per book. This fits comfortably in an overnight batch.

---

## 5. Graph-Augmented RAG (GraphRAG)

### Microsoft GraphRAG

**"From Local to Global: A Graph RAG Approach to Query-Focused Summarization"** (T2 -- Edge et al., arXiv:2404.16130, revised Feb 2025):

- Constructs an entity knowledge graph from source documents using an LLM
- Pre-generates community summaries for groups of closely related entities (using Leiden community detection)
- At query time, each community summary generates partial responses that are consolidated
- Showed "substantial improvements over a conventional RAG baseline for both the comprehensiveness and diversity of generated answers" on datasets ~1M tokens
- Designed for **global questions** ("What are the main themes?") where vector-only RAG fundamentally fails

### LightRAG

**"LightRAG: Simple and Fast Retrieval-Augmented Generation"** (T1 -- EMNLP 2025 Findings, arXiv:2410.05779):

- Dual-level retrieval: low-level (specific entities/relationships) + high-level (themes/concepts)
- Retrieves entities and relationships instead of text chunks -- reduces retrieval overhead
- More efficient than GraphRAG's community-based traversal
- Open source: github.com/HKUDS/LightRAG

### GraphRAG-Bench: When Does Graph Help?

**"When to use Graphs in RAG"** (T1 -- ICLR 2026, GraphRAG-Bench):

Key quantitative results comparing GraphRAG vs Vector RAG:
- **Overall accuracy**: GraphRAG 81.67% vs VectorRAG 57.50% (24 percentage point advantage)
- **Including acceptable responses**: GraphRAG >90% vs VectorRAG ~70%
- **Numerical reasoning**: GraphRAG achieves **100% correct** vs VectorRAG significantly lower
- **Temporal reasoning**: GraphRAG 83.35%
- **Complex cross-referencing**: GraphRAG clearly superior

**When graph structure helps most:**
- Multi-hop reasoning (traversing multiple connected nodes)
- Questions requiring cross-referencing information
- Temporal reasoning
- Structured knowledge representation

**When graph may not help:**
- Simple factual recall (vector retrieval is sufficient and faster)
- Very short, focused queries with a single answer entity

### Graphiti/Zep: Production Hybrid System

**Zep** (T2 -- Rasmussen et al., arXiv:2501.13956) combines semantic embeddings, BM25, and graph traversal:

- 94.8% accuracy on Deep Memory Retrieval benchmark (vs MemGPT 93.4%)
- Up to **18.5% improvement** on LongMemEval
- **90% latency reduction** vs baseline (context reduced from 115k to 1.6k tokens)
- **Temporal reasoning**: +38.4% improvement
- **Multi-session queries**: +30.7% improvement
- P95 retrieval latency: 300ms

### Relevance to Your Pipeline

For the Kindle Graph Enrichment project, the evidence strongly supports a graph+vector hybrid approach. Your existing Neo4j + pgvector infrastructure is well-positioned. The key insight from the benchmarks: **graph structure provides the largest advantage on multi-hop and cross-reference queries** -- exactly the kind of questions you'd ask across a personal knowledge graph ("How do concepts in Book A relate to ideas in Book B?").

---

## 6. VRAM/Memory Considerations and Throughput

### Qwen3.5-27B on RTX 3090 (24GB VRAM + 64GB RAM)

**VRAM requirements by quantization** (T5 -- InsiderLLM benchmarks):

| Quantization | File Size | Memory Needed | Fits 3090? |
|---|---|---|---|
| Q4_K_M | 16.5 GB | ~18 GB | Yes, fully on GPU |
| Q5_K_M | 19.4 GB | ~21 GB | Yes, fully on GPU |
| Q6_K | 22.7 GB | ~24 GB | Barely (tight with KV cache) |
| **Q8_0** | **28.6 GB** | **~30 GB** | **No -- requires ~6GB CPU offload** |
| BF16 | 53.8 GB | ~54 GB | No -- heavy CPU offload |

**Measured throughput on RTX 3090** (T5 -- InsiderLLM):
- **Q4_K at 4K context**: 33.5 tok/s
- **Q4_K at 86K context**: 27.5 tok/s

**Estimated Q8_0 with partial CPU offload**: Based on the data:
- Q8 requires ~30GB, 3090 has 24GB, so ~20% of layers on CPU
- CPU-offloaded layers run at memory bandwidth speed (~50 GB/s DDR4 vs ~936 GB/s GDDR6X)
- **Realistic estimate: 15-22 tok/s** for generation (roughly 50-65% of Q4_K speed)
- Prompt processing (prefill) will be less affected since it's compute-bound

### Quantization Impact on Extraction Quality

**General findings** (T2 -- Kurt, arXiv:2601.14277; T5 -- multiple benchmarks):

- **Q8_0**: Retains **~99%** of FP16 performance on reasoning and knowledge benchmarks. Essentially lossless for extraction tasks.
- **Q5_K_M**: Retains **~95-97%** of FP16 performance. The practical sweet spot for most tasks.
- **Q4_K_M**: Retains **~90-95%** of FP16 performance. "Introduces unacceptable losses for production-level deployments, especially in tasks like C-Eval and IFEval" (T5 -- multiple sources). Instruction-following and multilingual tasks most vulnerable.
- **Q3 and below**: Significant degradation, not recommended for extraction.

**For extraction specifically**: No dedicated extraction-quality-at-different-quants benchmark exists in the literature (gap identified). However, extraction quality depends on:
1. **Instruction following** (degraded at Q4, fine at Q8)
2. **JSON format adherence** (constrained decoding mitigates quant-induced format errors)
3. **Entity name accuracy** (character-level precision, sensitive to quant noise at Q3-Q4)

### Throughput Estimation for Overnight Batch

Assumptions:
- ~200 book highlights per book, ~5-10 books in queue
- 4-pass pipeline: ~800-4000 LLM calls per batch
- Average ~500 tokens per call (input prompt ~400, output ~100)
- Generation speed at Q8 with partial offload: ~18 tok/s
- Each call: ~100 output tokens / 18 tok/s = ~5.5 seconds generation + ~2 seconds prefill = ~7.5 seconds

| Batch size | LLM calls | Time estimate |
|---|---|---|
| 1 book (200 highlights) | 800 | ~1.7 hours |
| 5 books (1000 highlights) | 4000 | ~8.3 hours |
| 10 books (2000 highlights) | 8000 | ~16.7 hours |

**5 books per night is comfortable.** 10 books pushes into 16+ hours, which may exceed an overnight window but works for a weekend batch.

### Alternative: Use Q5_K_M Instead of Q8

Q5_K_M at ~21GB fits entirely on the 3090 GPU:
- **No CPU offload needed** -- all layers on GPU
- Expected throughput: **~28-30 tok/s** (extrapolated from Q4_K benchmarks)
- Quality: ~95-97% of FP16, likely imperceptible for extraction
- **Batch throughput roughly doubles** compared to Q8 with offload

This may be the better tradeoff for batch extraction where marginal quality gains from Q8 don't justify halving throughput.

---

## Serendipitous Connections

### Preference Sort + Knowledge Graph Extraction

The **Bradley-Terry model** from your Ranking Todo project has a natural connection to extraction confidence scoring. When multiple extraction passes disagree on whether a triple is valid, you can model the "quality" of each extraction as a latent variable and use pairwise comparison (pass A says yes, pass B says no) to estimate triple quality -- exactly the Bradley-Terry framework. This is analogous to how RLHF uses pairwise preference to estimate reward.

### Fantacalcio + Entity Extraction Pipeline

The xG model pipeline for Fantacalcio shares the same batch-overnight-extraction architecture. Both involve: (1) ingest data, (2) extract structured features, (3) store in graph/DB, (4) query for downstream predictions. The infrastructure built for Kindle graph extraction (Ollama batch scheduling, provenance tracking, validation passes) could be reused for sports data extraction.

### DSS Wrapper + Provenance

The digital signature provenance chain (CAdES/XAdES timestamps, certificate validation) is structurally isomorphic to the knowledge graph provenance model: both track "who claimed what, when, based on what evidence." The trust model for DSS (certificate chain -> root CA) maps to the source hierarchy in KG provenance (raw text -> extracted triple -> validated triple -> graph entity).

---

## Open Questions

1. **No extraction-specific quantization benchmark exists.** The impact of Q4 vs Q8 on entity name accuracy, relationship type precision, and JSON format compliance has not been systematically measured. This is a gap in the literature.

2. **Optimal chunk size for extraction is under-studied.** KGGen uses ~1000-word articles; Graphiti processes conversation turns. For book highlights (1-5 sentences), the extraction context may be too sparse for reliable relationship extraction without surrounding context.

3. **Local model extraction quality vs API models.** Most KG construction papers use GPT-4 or Claude. Systematic comparison of 27B open-weight models against API models for extraction is lacking. The COMEM cascading approach (small model for easy extractions, large model for hard ones) could be adapted to use a local 27B model for most work and an API call for low-confidence cases.

4. **Entity resolution across books.** When the same concept appears in multiple books with different terminology, coreference resolution becomes cross-document. Graphiti handles this via embedding similarity + LLM comparison, but the quality at 27B model size is unknown.

---

## What to Read Next

1. **KGGen paper** (arXiv:2502.09956) -- The most directly relevant paper for your pipeline. NeurIPS 2025, open source (`pip install kg-gen`), includes the MINE benchmark for evaluating your own extraction quality. Read the methodology section for the two-pass extraction approach.

2. **Zep/Graphiti paper** (arXiv:2501.13956) -- Best production architecture for provenance-aware temporal knowledge graphs. The extraction pipeline section is directly applicable to your system design. The bidirectional indexing approach is what you should implement for chunk-to-edge traceability.

3. **LLM-empowered KG Construction Survey** (arXiv:2510.20345) -- Comprehensive survey covering all major approaches. Read sections on schema-based vs schema-free and multi-pass pipelines.

4. **GraphRAG-Bench** (ICLR 2026) -- Empirical evidence for when graph structure helps retrieval. Key for deciding which queries should use graph traversal vs vector similarity in your hybrid Neo4j + pgvector setup.

5. **Chain-of-Verification** (arXiv:2309.11495, ACL Findings 2024) -- Foundation paper for your validation pass. The 77% hallucination reduction result is the strongest empirical justification for the two-pass approach.

---

## Knowledge Graph Candidates

- "**KGGen**" -- Type: technique. Possible links: Knowledge Graph, Entity Extraction, NeurIPS
- "**Chain-of-Verification (CoVe)**" -- Type: technique. Possible links: Hallucination, Self-Verification, Information Extraction
- "**GraphRAG**" -- Type: framework. Possible links: RAG, Knowledge Graph, Microsoft Research
- "**LightRAG**" -- Type: framework. Possible links: RAG, Knowledge Graph, Graph Retrieval
- "**Graphiti/Zep**" -- Type: framework. Possible links: Temporal Knowledge Graph, Agent Memory, Provenance
- "**MINE Benchmark**" -- Type: technique. Possible links: KGGen, Evaluation, Knowledge Graph Quality
- "**Constrained Decoding**" -- Type: technique. Possible links: JSON Schema, Structured Output, Grammar
- "**Entity Resolution**" -- Type: technique. Possible links: Coreference Resolution, Knowledge Graph, Deduplication

---

## Sources (All Actually Fetched)

### T1 -- Peer-Reviewed
- [KGGen: Extracting Knowledge Graphs from Plain Text with Language Models](https://arxiv.org/abs/2502.09956) -- NeurIPS 2025
- [GLiNER: Generalist Model for NER using Bidirectional Transformer](https://aclanthology.org/2024.naacl-long.300/) -- NAACL 2024
- [Chain-of-Verification Reduces Hallucination in Large Language Models](https://aclanthology.org/2024.findings-acl.212/) -- ACL Findings 2024
- [LightRAG: Simple and Fast Retrieval-Augmented Generation](https://aclanthology.org/2025.findings-emnlp.568.pdf) -- EMNLP 2025 Findings
- [When to use Graphs in RAG: A Comprehensive Analysis](https://openreview.net/forum?id=i9q9xDMjG7) -- ICLR 2026
- [Managing Provenance Data in Knowledge Graph Management Platforms](https://link.springer.com/article/10.1007/s13222-023-00463-0) -- Datenbank-Spektrum 2023

### T2 -- arXiv Preprints
- [From Local to Global: A Graph RAG Approach to Query-Focused Summarization](https://arxiv.org/abs/2404.16130) -- Edge et al. (Microsoft), 2024
- [Graph Retrieval-Augmented Generation: A Survey](https://arxiv.org/abs/2408.08921) -- Peng et al., 2024 (ACM TOIS accepted)
- [Zep: A Temporal Knowledge Graph Architecture for Agent Memory](https://arxiv.org/abs/2501.13956) -- Rasmussen et al., 2025
- [LLM-empowered Knowledge Graph Construction: A Survey](https://arxiv.org/abs/2510.20345) -- 2025
- [Uncertainty Management in the Construction of Knowledge Graphs: A Survey](https://arxiv.org/abs/2405.16929) -- Jarnac et al., 2024
- [JSONSchemaBench: Structured Output Generation Benchmark](https://arxiv.org/abs/2501.10868) -- Geng et al., 2025
- [Which Quantization Should I Use? A Unified Evaluation](https://arxiv.org/abs/2601.14277) -- Kurt, 2026
- [NuNER: Entity Recognition Encoder Pre-training via LLM-Annotated Data](https://arxiv.org/abs/2402.15343) -- 2024
- [LINK-KG: LLM-Driven Coreference-Resolved Knowledge Graphs](https://arxiv.org/abs/2510.26486) -- 2025
- [CREFT: Sequential Multi-Agent LLM for Character Relation Extraction](https://arxiv.org/abs/2505.24553) -- 2025

### T5 -- Engineering Blogs / Benchmarks
- [Best Qwen 3.5 Models Ranked: Every Size, Every GPU, Every Quant](https://insiderllm.com/guides/qwen-3-5-local-guide/) -- InsiderLLM
- [LLM Quantization Tests](https://big-stupid-jellyfish.github.io/GFMath/pages/llm-quants) -- GFMath
- [llama.cpp Performance Testing](https://johannesgaessler.github.io/llamacpp_performance) -- Gaessler
- [Graphiti GitHub Repository](https://github.com/getzep/graphiti) -- Zep
- [KGGen GitHub Repository](https://github.com/stair-lab/kg-gen) -- Stanford
- [Neo4j: Building Knowledge Graphs with LLM Graph Transformer](https://medium.com/data-science/building-knowledge-graphs-with-llm-graph-transformer-a91045c49b59) -- Bratanic

### T7 -- Reference
- [GraphRAG Project Page (Microsoft Research)](https://www.microsoft.com/en-us/research/project/graphrag/)
- [GraphRAG GitHub](https://github.com/microsoft/graphrag)
- [Awesome-GraphRAG curated list](https://github.com/DEEP-PolyU/Awesome-GraphRAG)
