# Raccomandazioni Modelli per KORE: Embedding, Reranker, Entity Extraction

## Contesto

Server SOL, 16 GB RAM, no GPU. Ollama come runtime di inferenza.
Attualmente in uso: `mxbai-embed-large` (1024 dim) via Ollama per embeddings pgvector.
Pipeline Kindle Graph Enrichment: import highlights -> AGE knowledge graph.
KORE: ~14768 chunk, ~1955 file, pgvector 1024 dim.

I tre casi d'uso valutati:
1. **Embedding model** -- generazione vettori per ricerca semantica (pgvector)
2. **Reranker model** -- ri-ordinamento risultati dopo retrieval vettoriale
3. **LLM per entity extraction** -- estrazione entita strutturate (NER) per il knowledge graph

---

## 1. EMBEDDING MODEL

### Stato attuale

`mxbai-embed-large` (mixedbread.ai, 335M parametri, 1024 dim, max 512 token).
MTEB English v1 overall: ~54.39 (T7 -- ACM DL 2025). Retrieval nDCG@10: ~54.39.
Modello solido, ben supportato da Ollama, licenza Apache 2.0.

### Candidati valutati

| Modello | Parametri | Dim | Max seq | MTEB Eng | MMTEB | Ollama | Licenza | RAM stimata |
|---------|-----------|-----|---------|----------|-------|--------|---------|-------------|
| **mxbai-embed-large** (attuale) | 335M | 1024 | 512 | ~54 | n/d | Si | Apache 2.0 | ~700 MB |
| **Qwen3-Embedding-0.6B** | 0.6B | 1024 | 32K | ~70.70 (v2) | 64.33 | Si (`qwen3-embedding:0.6b`) | Apache 2.0 | ~1.2 GB |
| **Qwen3-Embedding-4B** | 4B | 2560 | 32K | migliore | 69.60 | Si | Apache 2.0 | ~4-5 GB |
| **nomic-embed-text** | 137M | 768 | 8192 | ~62 (v1) | n/d | Si | Apache 2.0 | ~300 MB |
| **Qwen3-Embedding-8B** | 8B | 4096 | 32K | **70.58** (#1 MTEB multilingual) | **70.58** | Si | Apache 2.0 | ~8-10 GB |

(T2 -- arXiv:2506.05176, Qwen Team 2025; T7 -- Emergent Mind, MTEB leaderboard)

### Analisi

**Qwen3-Embedding-0.6B** e il candidato ideale per SOL:
- **Salto qualitativo enorme**: MTEB English v2 = 70.70 vs ~54 di mxbai-embed-large. Delta di ~16 punti -- non marginale, trasformativo.
- **Stessa dimensione**: 1024 dim, quindi **nessuna migrazione pgvector necessaria** (colonna gia a 1024).
- **Context window 32K** vs 512 di mxbai: permette embedding di chunk molto piu lunghi, migliorando la qualita del retrieval per documenti strutturati.
- **MRL (Matryoshka Representation Learning)**: supporta dimensioni custom (es. 512, 256) se in futuro servisse comprimere.
- **Instruction-aware**: si puo specificare l'istruzione per task (retrieval, classificazione, clustering), migliorando la pertinenza.
- **RAM**: ~1.2 GB quantizzato, perfettamente gestibile su SOL (16 GB).
- **Rischio GGUF**: un thread Reddit (luglio 2025) segnala che le versioni GGUF di Qwen3-Embedding producono risultati peggiori rispetto al modello FP16/BF16 in llama.cpp. Ollama usa GGUF internamente -- verificare con test empirico prima di migrare in produzione.

**Qwen3-Embedding-4B** sarebbe ancora meglio (MMTEB 69.60), ma il costo RAM (4-5 GB) e l'embedding dimension 2560 richiederebbero una migrazione pgvector. Non giustificato per il volume attuale.

**Qwen3-Embedding-8B** e il #1 MTEB assoluto (70.58) ma consuma 8-10 GB RAM -- troppo per SOL senza GPU, dove deve coesistere con Ollama, PostgreSQL, e ~41 container Docker.

### Avvertenza: GGUF quality degradation

Il thread r/LocalLLaMA "Are Qwen3 Embedding GGUF faulty?" (luglio 2025, T7) riporta che i GGUF quantizzati di Qwen3-Embedding producono risultati "much worse" rispetto ai pesi originali in llama.cpp. Questo e un rischio concreto per Ollama che usa GGUF.

**Mitigazione**: prima della migrazione, eseguire un test A/B su un campione di query KORE reali (es. 50 query), confrontando recall@10 tra mxbai-embed-large e qwen3-embedding:0.6b. Se la qualita GGUF e degradata, considerare di servire il modello FP16 via vLLM su Gaia (3090, 24 GB VRAM) e chiamarlo via API da SOL.

### Raccomandazione Embedding

**Sostituire `mxbai-embed-large` con `Qwen3-Embedding-0.6B`**, ma con test empirico preventivo.

Piano di migrazione:
1. `ollama pull qwen3-embedding:0.6b`
2. Test A/B su 50 query KORE: confrontare cosine similarity e recall@10
3. Se OK: re-indicizzare progressivamente (principio di inesorabilita) via `embeddings_reindex`
4. Se GGUF degradato: deploy FP16 su Gaia via vLLM, esporre endpoint API

**Nessuna migrazione schema pgvector necessaria** (entrambi 1024 dim).

---

## 2. RERANKER MODEL

### Stato attuale

Nessun reranker in uso. Il retrieval KORE e puramente vettoriale (cosine similarity pgvector).

### Candidati valutati

Benchmark dal paper Qwen3-Embedding (T2 -- arXiv:2506.05176). Tutti i punteggi su top-100 candidati recuperati da Qwen3-Embedding-0.6B:

| Modello | Param | MTEB-R (eng) | CMTEB-R (cmn) | MMTEB-R (multi) | MTEB-Code | RAM stimata |
|---------|-------|-------------|---------------|----------------|-----------|-------------|
| **Qwen3-Reranker-0.6B** | 0.6B | **65.80** | 71.31 | **66.36** | 73.42 | ~1.2 GB |
| BGE-reranker-v2-m3 | 0.6B | 57.03 | 72.16 | 58.36 | 41.38 | ~1.2 GB |
| Jina-multilingual-reranker-v2-base | 0.3B | 58.22 | 63.37 | 63.73 | 58.98 | ~600 MB |
| gte-multilingual-reranker-base | 0.3B | 59.51 | **74.08** | 59.44 | 54.18 | ~600 MB |
| Qwen3-Embedding-0.6B (usato come reranker) | 0.6B | 61.82 | 71.02 | 64.64 | 75.41 | ~1.2 GB |
| Qwen3-Reranker-4B | 4B | **69.76** | 75.94 | **72.74** | **81.20** | ~4-5 GB |
| Qwen3-Reranker-8B | 8B | 69.02 | **77.45** | 72.94 | 81.22 | ~8-10 GB |

### Problema critico: Ollama NON supporta reranking

**Ollama non ha un endpoint `/api/rerank`** (T7 -- GitHub issue #3368, aperta marzo 2024, ancora aperta a marzo 2026; issue #10467 chiusa come duplicato aprile 2025 con "Ollama doesn't currently support ranking models").

Il reranking richiede un **cross-encoder** che prende una coppia (query, document) e produce uno score di rilevanza. Questo e architetturalmente diverso dall'embedding (dual-encoder). Ollama supporta solo:
- `/api/generate` (LLM text generation)
- `/api/embeddings` (embedding generation)
- `/api/chat` (chat completion)

Il reranker Qwen3 funziona internamente come un LLM che risponde "yes"/"no" alla domanda "il documento e rilevante per la query?", con lo score derivato da `P(yes) / (P(yes) + P(no))`. Teoricamente si potrebbe usare l'endpoint `/api/generate` con logprobs, ma:
- Ollama non espone logprobs nell'API standard
- L'overhead di una chiamata LLM per ogni coppia (query, doc) e enorme per il reranking di 100 candidati

### Alternative praticabili

1. **vLLM su Gaia** (3090): espone l'endpoint `/rerank` nativo OpenAI-compatible. Un paper arXiv (2602.17826) usa esattamente "Qwen3-Reranker-0.6B via vLLM pooling endpoint". Questa e la soluzione pulita.

2. **llama.cpp server**: il server llama.cpp espone `/api/v1/reranking` (T7 -- Lemonade Server docs). Si potrebbe compilare llama.cpp su SOL (CPU) o Gaia (GPU) e usare il Qwen3-Reranker-0.6B direttamente.

3. **Implementazione custom nel MCP**: dato che il reranker Qwen3 e basato su yes/no classification, si potrebbe implementare il reranking come tool MCP che:
   - Prende i top-100 risultati dall'embedding search
   - Per ciascuno, chiama Ollama `/api/generate` con il prompt template del reranker
   - Estrae P(yes) dalla risposta (il modello risponde "yes" o "no")
   - Ri-ordina per score

   Problema: lento (~100 chiamate sequenziali per query). Ma per KORE i volumi sono bassi.

4. **Rinviare al deploy di Gaia**: il reranker e un miglioramento incrementale. La pipeline attuale (embedding-only) funziona. Il reranker diventa critico quando il corpus cresce oltre ~50K chunk o quando la precision@10 non e sufficiente.

### Raccomandazione Reranker

**Fase 0 (ora)**: non implementare. L'embedding upgrade (mxbai -> Qwen3-Embedding-0.6B) dara un boost maggiore della stessa magnitudine di un reranker sullo stesso retrieval.

**Fase 1 (quando Gaia e operativo)**: deploy Qwen3-Reranker-0.6B su Gaia via vLLM o llama.cpp server, esporre come endpoint HTTP, integrare nel MCP come step post-retrieval.

**Fase 2 (se serve)**: upgrade a Qwen3-Reranker-4B su Gaia (la 3090 con 24 GB lo gestisce comodamente in FP16).

---

## 3. LLM PER ENTITY EXTRACTION

### Stato attuale

L'estrazione entita per il knowledge graph (Kindle Graph Enrichment) usa script Python (`import_kindle.py` e simili) con logica regex/rule-based. Non c'e un LLM locale per NER/structured extraction.

### Requisiti specifici

- Estrarre: Concept, Author, Theme, Framework, Principle, Technique, Metaphor
- Output strutturato (JSON) per import in AGE knowledge graph
- Lingue: italiano + inglese (highlight Kindle sono misti)
- Deve girare su SOL (CPU only, 16 GB RAM) o Gaia (GPU, 24 GB VRAM)
- Volume: batch offline, non real-time (principio di inesorabilita)

### Candidati valutati

| Modello | Param | Structured output | Multilingue | RAM (Q4) | Ollama | Note |
|---------|-------|------------------|-------------|----------|--------|------|
| **Qwen3-4B** | 4B | Eccellente (hybrid thinking) | 100+ lingue | ~3 GB | Si | Thinking mode per task complessi |
| **Qwen3-1.7B** | 1.7B | Buono | 100+ lingue | ~1.5 GB | Si | Piu leggero, sufficiente per NER semplice |
| **Phi-4-mini (3.8B)** | 3.8B | Molto buono | EN-centrico | ~2.5 GB | Si | Forte su reasoning/struttura, debole multilingue |
| **Gemma 3 4B** | 4B | Buono | ~40 lingue | ~3 GB | Si | Vision + text, ma NER non e il suo forte |
| **Qwen3-8B** | 8B | Eccellente | 100+ lingue | ~5 GB | Si | Migliore qualita ma piu pesante |
| **Llama 3.1 8B** | 8B | Buono (tool calling) | EN-centrico | ~5 GB | Si | Forte su inglese, debole su italiano |

(T2 -- arXiv:2505.09388 Qwen3 Technical Report; T7 -- benchmarks da Ollama/HuggingFace model cards)

### Analisi

Per entity extraction da highlight Kindle (tipicamente frasi brevi, 1-3 paragrafi), il task e relativamente semplice per un LLM moderno. I fattori discriminanti sono:

1. **Output strutturato affidabile**: il modello deve produrre JSON valido con costanza. Qwen3 eccelle qui grazie al "hybrid thinking" mode (si puo disattivare il thinking per output deterministico).

2. **Multilingue IT+EN**: esclude Phi-4-mini e Llama 3.1 che sono EN-centrici. Qwen3 e Gemma 3 sono i migliori multilingual.

3. **RAM su SOL (CPU)**: il modello gira in batch notturno, puo coesistere con gli altri servizi se caricato on-demand. Qwen3-4B a ~3 GB e gestibile.

4. **Qualita NER**: un paper recente (arXiv:2602.14743, feb 2026, T2) su "Benchmarking LLM Structured Data Extraction" mostra che i modelli 4B+ sono sufficienti per NER su testo breve quando il prompt e ben strutturato.

### Raccomandazione Entity Extraction

**Qwen3-4B** (con thinking mode disattivato per output deterministico).

Motivazioni:
- Stessa famiglia di Qwen3-Embedding: coerenza nell'ecosistema
- 100+ lingue con qualita alta su italiano
- Hybrid thinking: si puo abilitare per estrazioni complesse (es. inferire temi impliciti), disabilitare per NER semplice
- 3 GB RAM in Q4: gestibile su SOL in batch notturno
- Gia disponibile su Ollama: `ollama pull qwen3:4b`

**Alternativa se la qualita non basta**: Qwen3-8B su Gaia (GPU), chiamato via API proxy (`proxy-ai` gia configurato per multi-provider).

**Schema prompt consigliato**:

```
Extract entities from the following text highlight. Return ONLY valid JSON.
Language of text: {detected_language}

Categories:
- concept: key ideas or theories
- author: persons mentioned or implied
- theme: overarching topics
- framework: structured models or systems
- principle: rules or guidelines
- technique: methods or approaches
- metaphor: figurative comparisons

Text: "{highlight_text}"
Source: "{book_title}" by {book_author}

Output format:
{"entities": [{"name": "...", "type": "concept|author|theme|...", "confidence": 0.0-1.0}], "relationships": [{"from": "...", "to": "...", "type": "relates_to|exemplifies|contradicts|..."}]}
```

---

## Tabella Riepilogativa Decisioni

| Caso d'uso | Modello attuale | Raccomandazione | Quando | Impatto stimato |
|------------|----------------|-----------------|--------|-----------------|
| **Embedding** | mxbai-embed-large (335M) | **Qwen3-Embedding-0.6B** | Immediato (con test A/B) | MTEB +16 punti, stessa dim 1024 |
| **Reranker** | Nessuno | **Qwen3-Reranker-0.6B** | Dopo deploy Gaia | +4-8 punti nDCG@10 su retrieval |
| **Entity Extraction** | Rule-based Python | **Qwen3-4B** (thinking off) | Immediato | Estrazione semantica vs pattern matching |

## Connessioni ai Progetti Personali

- **Kindle Graph Enrichment**: il caso d'uso principale per entity extraction. Qwen3-4B sostituirebbe la logica rule-based di `import_kindle.py`.
- **Ranking Todo** (Preference Sort): il reranker potrebbe essere usato per ri-ordinare le alternative in fase di comparazione Bradley-Terry, ma e un use case secondario.
- **Agent Framework**: l'embedding upgrade migliora direttamente `embeddings_search_docs` e `embeddings_search_conversations` usati dagli agenti.

## Serendipitous Connections

L'architettura Qwen3-Embedding+Reranker e un caso concreto del paradigma **bi-encoder + cross-encoder** teorizzato da Humeau et al. (2019, "Poly-encoders", T2 -- ICLR 2020). La stessa dualita appare nella Information Retrieval classica come **recall-oriented first stage + precision-oriented re-ranking** (Robertson & Zaragoza, 2009, "The Probabilistic Relevance Framework: BM25 and Beyond", T1 -- Foundations and Trends in IR). Il fatto che Qwen3-Embedding-0.6B usato come reranker (61.82 MTEB-R) sia inferiore a Qwen3-Reranker-0.6B (65.80 MTEB-R) conferma empiricamente che cross-encoder > bi-encoder per precision, anche a parita di parametri -- un risultato atteso dalla teoria ma raramente quantificato su modelli della stessa famiglia.

## Fonti consultate

- (T2) Qwen Team, "Qwen3 Embedding: Advancing Text Embedding and Reranking Through Foundation Models", arXiv:2506.05176, giugno 2025
- (T2) Qwen Team, "Qwen3 Technical Report", arXiv:2505.09388, maggio 2025
- (T7) Qwen Blog, qwenlm.github.io/blog/qwen3-embedding/, giugno 2025 -- benchmark tables
- (T7) GitHub ollama/ollama#3368, "Reranking models", aperta marzo 2024, ancora aperta
- (T7) GitHub ollama/ollama#10467, "what is the endpoint of rerank", chiusa come duplicato aprile 2025
- (T7) Reddit r/LocalLLaMA, "Are Qwen3 Embedding GGUF faulty?", luglio 2025
- (T7) Reddit r/LLMDevs, "Qwen3-Embedding-0.6B is fast, high quality", luglio 2025
- (T7) Emergent Mind, "Dense Qwen3-0.6B Overview" -- MTEB scores
- (T7) Karanprasad.com, "Perplexity PPLX Embed" -- Qwen3-Embedding-4B MMTEB 69.60
- (T7) ACM DL, "Applied Domain Adaptation" -- mxbai-embed-large MTEB 54.39
- (T7) CEUR-WS, "Combining Embedding Models" -- mxbai-embed-large-v1 score 76.80 (diverso benchmark)
- (T2) arXiv:2602.14743, "Benchmarking LLM Structured Data Extraction", febbraio 2026
- (T7) Apidog blog, "Run Qwen3 Embedding & Reranker Locally with Ollama"
- (T7) arXiv:2602.17826, "Ontology-Guided Neuro-Symbolic Inference" -- usa Qwen3-Reranker-0.6B via vLLM

**Epistemic status**: Strong consensus sui benchmark MTEB (risultati riproducibili, leaderboard pubblico). Rischio GGUF quality degradation segnalato ma non sistematicamente quantificato. Entity extraction LLM e best-practice community, non peer-reviewed per il caso specifico Kindle highlights.

**Confidence**: Alta per embedding (dati MTEB solidi). Media per reranker (dipende da deploy Gaia). Media per entity extraction (non testato su dati KORE reali).
