# Self-Hosted Models for Anki Flashcard Processing (RTX 3090, March 2026)

## Research Summary

**Epistemic status:** Strong consensus on vision models; active debate on STT models
**Confidence:** Medium-High -- based on published benchmarks (T2), model cards, and community reports; not all combinations independently verified on RTX 3090

---

## Part 1: Vision OCR for Flashcard Images

### The Task

Process ~4000 Anki flashcard images nightly containing: mathematical formulas, diagrams, code snippets, geography maps/flags, and tables. Quality over speed. LaTeX output for math preferred. Must fit in 24GB VRAM.

### Model Comparison

| Model | Parameters | VRAM (fp16) | Ollama/vLLM | LaTeX output | OCR strength | Notes |
|-------|-----------|-------------|-------------|-------------|-------------|-------|
| **Qwen2.5-VL-7B** | 8.3B (7B LLM + 675M ViT) | ~16-18 GB | Yes (Ollama `qwen2.5vl`) | Via prompt | Excellent across the board | Best general VLM for OCR at this size |
| **Qwen3-VL-8B** | ~8B | ~16-18 GB | Not yet confirmed | Via prompt | Expected improvement over 2.5 | Released Q1 2026, may not be in Ollama yet |
| **GOT-OCR2.0** | 580M | ~2 GB | Community (not official) | Native TikZ/LaTeX/Markdown | Purpose-built OCR | Tiny, fast, but narrow |
| **MiniCPM-V 2.6** | 8B | ~16 GB | Yes (`minicpm-v`) | Via prompt | Good general VLM | Competitive but below Qwen2.5-VL on OCR benchmarks |
| **InternVL2-8B** | 8B | ~16-18 GB | Community | Via prompt | Strong document understanding | Good but ecosystem less mature for self-hosting |
| **HunyuanOCR** | 1B | ~3-4 GB | vLLM only (Nov 2025) | Native | SOTA for <3B on OCRBench | New entrant, OCR-specific, 1st place ICDAR 2025 |
| **PaddleOCR-VL-1.5** | Unknown | Unknown | No | Unknown | Not found in literature | Could not verify -- likely not a real model name |

### Detailed Analysis

#### Qwen2.5-VL-7B-Instruct -- RECOMMENDED

(T2 -- arXiv:2409.12191, Wang et al., 2024)

**Why it wins for this task:**

1. **Best-in-class OCR among 7-8B VLMs.** The Qwen2.5-VL blog (Jan 2025) explicitly highlights "Enhanced Text Recognition and Understanding" as a flagship capability. It handles vertical text, multilingual text, text spotting with bounding boxes, and structured extraction (invoices, forms, tables) natively.

2. **Structured output.** Can return JSON, markdown tables, and extracted key-value pairs from documents. This is directly useful for Anki card metadata extraction.

3. **Dynamic resolution.** Uses "Naive Dynamic Resolution" -- processes images at their native resolution rather than forcing resize to a fixed grid. This is critical for math formulas where fine details (subscripts, superscripts, fractions) matter.

4. **Multi-content-type handling.** Your flashcards contain heterogeneous content (math, maps, code, diagrams). A general VLM handles this diversity far better than a pure OCR model. You can prompt: "If this contains a mathematical formula, output it in LaTeX. If it contains a table, output it in markdown. If it contains a diagram, describe it."

5. **VRAM fits comfortably.** At fp16, the 7B model uses ~16 GB, leaving headroom on 24 GB. With 4-bit quantization (Q4_K_M via Ollama), it drops to ~6 GB, though at some quality cost for fine OCR.

6. **Mature Ollama support.** Available as `qwen2.5vl` in the Ollama library. Well-tested, stable.

**OCR benchmark performance (from Qwen blog):**
- Qwen2.5-VL-7B outperforms GPT-4o-mini on document understanding tasks
- Qwen2.5-VL-72B is competitive with GPT-4o and Claude 3.5 Sonnet on OCRBench
- The 7B model specifically outperforms the previous Qwen2-VL-7B by a large margin on text recognition

**VRAM estimate:** ~16 GB fp16, ~8 GB Q8, ~5-6 GB Q4_K_M

**Recommended quantization for your case:** Q8 or fp16. With 4000 images nightly (no real-time pressure), you can afford the slower fp16 inference for maximum OCR quality. At ~2-5 seconds per image on RTX 3090 fp16, the full batch would take 2-6 hours -- well within a nightly window.

#### GOT-OCR2.0 -- Strong Alternative for Pure OCR

(T2 -- arXiv:2409.01704, Wei et al., StepFun, 2024)

**Strengths:**
- Only 580M parameters -- extremely lightweight (~2 GB VRAM)
- Purpose-built for OCR with native output formats: plain text, markdown, TikZ (LaTeX), SMILES (molecular), kern (music)
- Handles: plain text, math/molecular formulas, tables, charts, sheet music, geometric shapes
- Supports both scene-text and document-style images
- Region-level recognition via coordinates or color prompts
- Dynamic resolution and multi-page OCR

**Weaknesses:**
- Not a general VLM -- cannot describe diagrams, identify geography, or reason about images
- Not in official Ollama library (community GGUFs exist)
- Less actively maintained ecosystem than Qwen
- For your mixed content (maps, flags, diagrams), it will only extract text, not understand the image

**Verdict:** Excellent if your flashcards are primarily text/formula/table. Falls short on geography maps, flags, and diagrams where you need *description* not just text extraction.

#### HunyuanOCR -- Notable New Entrant

(T2 -- arXiv:2511.19575, Tencent, Nov 2025)

- 1B parameters, SOTA on OCRBench among <3B models
- Won 1st place at ICDAR 2025 DIMT Challenge (Small Model Track)
- Outperforms Qwen3-VL-4B on OCR tasks despite being much smaller
- Supports vLLM deployment
- Uses reinforcement learning for OCR -- first demonstrated RL gains for OCR
- End-to-end: no separate layout analysis needed

**Limitation:** OCR-specific like GOT-OCR2.0. Cannot reason about non-text image content.

#### MiniCPM-V 2.6

- 8B parameters, good general VLM from OpenBMB
- Available in Ollama as `minicpm-v`
- Decent OCR but consistently benchmarks below Qwen2.5-VL-7B on document understanding
- Lower community traction for OCR-specific use cases

#### Qwen3-VL

- Released early 2026, likely improves on Qwen2.5-VL
- The Qwen3-VL-Embedding/Reranker paper (arXiv:2601.04720) confirms the 2B and 8B sizes exist
- Ollama availability uncertain as of March 2026
- If available, would be the default recommendation over Qwen2.5-VL

#### PaddleOCR-VL-1.5

- **Could not verify this model exists.** PaddleOCR is Baidu's traditional OCR toolkit (not a VLM). There may be a "PP-OCRv4" or similar, but "PaddleOCR-VL-1.5" does not appear in literature or model repositories. Likely a confusion with PaddlePaddle's traditional OCR pipeline, which is not a vision-language model.

### Vision OCR Recommendation

**Primary: Qwen2.5-VL-7B-Instruct via Ollama (fp16 or Q8)**

Reasoning:
1. Handles ALL your content types (math, diagrams, code, maps, tables) -- not just text
2. Best OCR quality among 7-8B open VLMs as of March 2026
3. Native LaTeX output via prompting ("Output any mathematical formulas in LaTeX notation")
4. Structured JSON output for tables and forms
5. Mature Ollama support, well-tested
6. Fits in 24 GB with room to spare

**Fallback: GOT-OCR2.0 as a secondary pass** for flashcards where you specifically need TikZ/LaTeX formatted math output. At 580M params, you could even run it alongside Qwen2.5-VL.

**If Qwen3-VL-8B becomes available in Ollama:** switch to it. Expected to be strictly better.

---

## Part 2: Speech-to-Text for Flashcard Audio

### The Task

Transcribe Anki flashcard audio clips, mostly language learning (German, French sentences, some English and Italian). CPU inference on the host. Quality over speed. Multilingual required.

### Model Comparison

| Model | Parameters | CPU inference | Multilingual | German WER | French WER | Notes |
|-------|-----------|-------------|-------------|-----------|-----------|-------|
| **faster-whisper large-v3** | 1.55B | Yes (CTranslate2) | 99 languages | ~5-8% (clean) | ~6-9% (clean) | Gold standard for self-hosted STT |
| **faster-whisper medium** | 769M | Yes | 99 languages | ~8-12% | ~9-13% | Good accuracy/speed tradeoff |
| **faster-whisper small** | 244M | Yes | 99 languages | ~12-18% | ~13-19% | Too much quality loss |
| **whisper.cpp large-v3** | 1.55B | Yes (GGML) | 99 languages | Same as above | Same as above | Same model, different runtime |
| **Canary-1B** | ~1B | Difficult | EN, DE, FR, ES | ~5-7% | ~6-8% | NeMo framework, GPU-oriented |
| **whisper-large-v3-turbo** | 809M | Yes | 99 languages | ~6-10% | ~7-11% | Distilled, 2x faster, slight quality drop |

### Detailed Analysis

#### faster-whisper large-v3 -- RECOMMENDED

**What it is:** faster-whisper is a CTranslate2-based reimplementation of OpenAI's Whisper models. It runs the same weights (Whisper large-v3, 1.55B parameters) but with 4x faster inference and lower memory usage through INT8/FP16 quantization and efficient batching.

**Why it wins:**

1. **Best accuracy for European languages on CPU.** Whisper large-v3 was trained on 1M+ hours of multilingual data. German and French are among the best-represented languages. Published WER benchmarks (T2 -- OpenAI Whisper paper, Radford et al., 2023; various community benchmarks):
   - German (CommonVoice): ~5-8% WER
   - French (CommonVoice): ~6-9% WER
   - English: ~3-5% WER
   - Italian: ~6-9% WER

2. **CPU inference works well.** CTranslate2 has excellent CPU optimization (AVX2/AVX-512, INT8 quantization). On a modern CPU (like the Ryzen 7 3700X in your setup), expect:
   - INT8 quantized: ~0.5-1x realtime (a 5-second clip takes 5-10 seconds)
   - For short flashcard clips (typically 2-10 seconds), this is very practical
   - 4000 clips x avg 5 seconds = ~20,000 seconds of audio = ~5-10 hours processing at 1x realtime on CPU

3. **Trivial to install and use.**
   ```bash
   pip install faster-whisper
   ```
   ```python
   from faster_whisper import WhisperModel
   model = WhisperModel("large-v3", device="cpu", compute_type="int8")
   segments, info = model.transcribe("audio.mp3", language="de")
   ```

4. **Language detection is automatic.** If you don't know which language a clip is in, Whisper will detect it. Or you can specify `language="de"` for better accuracy when you know.

5. **Memory usage on CPU:** ~3-4 GB RAM for INT8 large-v3. No GPU needed.

#### whisper.cpp large-v3 -- Equivalent Alternative

**What it is:** A C/C++ port of Whisper using GGML tensors. Same model weights, different runtime.

**Comparison with faster-whisper:**
- Same underlying model (large-v3) = same accuracy
- whisper.cpp is slightly faster on pure CPU for some architectures (better SIMD optimization)
- faster-whisper has a much better Python API and is easier to integrate
- whisper.cpp is better if you want a standalone CLI binary

**Verdict:** For your use case (Python integration with Anki processing pipeline), faster-whisper is more practical. If you prefer a CLI tool, whisper.cpp is equivalent.

#### NVIDIA Canary-1B -- Not Recommended for This Use Case

**What it is:** A ~1B parameter encoder-decoder ASR model from NVIDIA's NeMo toolkit. Supports EN, DE, FR, ES with competitive accuracy.

**Why not:**
1. **GPU-oriented.** Canary-1B is designed for NVIDIA GPU inference via NeMo/ONNX. CPU inference requires exporting to ONNX and running through ONNX Runtime, which is poorly documented and slow.
2. **Limited language support.** Only 4 languages (EN, DE, FR, ES). You need Italian.
3. **Complex setup.** Requires NeMo toolkit installation, which pulls in PyTorch, Numba, and many NVIDIA-specific dependencies. Overkill for short flashcard clips.
4. **Accuracy is competitive but not clearly better** than Whisper large-v3 for German/French.

#### faster-whisper medium -- Budget Alternative

If CPU processing time is a concern (large-v3 may take 5-10 hours for 4000 clips), the medium model offers:
- ~2x faster inference
- ~3-5% higher WER (more errors)
- ~1.5 GB RAM

For language learning flashcards where accuracy is paramount (you want exact transcription of educational content), the quality gap matters. Stick with large-v3.

#### whisper-large-v3-turbo -- Speed Compromise

OpenAI's distilled version of large-v3:
- 809M params (roughly half)
- ~2x faster than large-v3
- ~1-2% higher WER on average
- Good middle ground if large-v3 is too slow on CPU

### STT Recommendation

**Primary: faster-whisper with large-v3 model, INT8 quantization, CPU inference**

```python
from faster_whisper import WhisperModel

model = WhisperModel("large-v3", device="cpu", compute_type="int8")

# For German flashcard
segments, info = model.transcribe("card_audio.mp3", language="de")
text = " ".join(s.text for s in segments)

# For auto-detection
segments, info = model.transcribe("card_audio.mp3")
print(f"Detected: {info.language} ({info.language_probability:.0%})")
```

**If too slow:** Switch to `large-v3-turbo` for ~2x speedup with minimal quality loss.

**Do NOT use:** Canary-1B (wrong platform, missing Italian), faster-whisper small (too much quality loss).

---

## Serendipitous Connections

**Connection to Anki project in personal projects table:** This research directly serves the "Embedding Roadmap" where 17K Anki cards lack embeddings, some with images requiring OCR via minicpm-v. The recommendation here upgrades from minicpm-v to Qwen2.5-VL-7B for significantly better OCR quality. The MEMORY.md already mentions `minicpm-v` for OCR -- this research suggests replacing it.

**Connection to KORE knowledge graph:** Both OCR outputs and STT transcriptions feed into the embedding pipeline (pgvector). The structured JSON output from Qwen2.5-VL could be ingested directly into AGE as enriched card metadata.

**Dual-model pipeline insight:** GOT-OCR2.0 (580M) + Qwen2.5-VL-7B could run as a two-pass pipeline: GOT-OCR first extracts raw text/LaTeX efficiently, then Qwen2.5-VL handles the non-text images (diagrams, maps). This exploits the 24 GB VRAM budget (both fit simultaneously at ~18 GB combined).

---

## Summary of Recommendations

| Task | Model | Size | Runtime | VRAM/RAM | Quantization |
|------|-------|------|---------|----------|-------------|
| **Vision OCR** | Qwen2.5-VL-7B-Instruct | 8.3B | Ollama (GPU) | ~16 GB VRAM | fp16 preferred |
| **STT** | faster-whisper large-v3 | 1.55B | CTranslate2 (CPU) | ~3-4 GB RAM | INT8 |

---

## Sources

- (T2) Qwen2-VL paper: arXiv:2409.12191, Wang et al., 2024 -- Qwen2-VL architecture and benchmarks
- (T2) GOT-OCR2.0 paper: arXiv:2409.01704, Wei et al., StepFun, 2024 -- General OCR Theory
- (T2) HunyuanOCR: arXiv:2511.19575, Tencent, Nov 2025 -- 1B OCR-specific VLM, ICDAR 2025 winner
- (T2) Qwen2.5-VL blog: qwenlm.github.io/blog/qwen2.5-vl/, Jan 2025 -- benchmark tables and capabilities
- (T2) Qwen3-VL-Embedding: arXiv:2601.04720, Jan 2026 -- confirms Qwen3-VL model family exists
- (T2) Whisper: arXiv:2212.04356, Radford et al., OpenAI, 2023 -- Whisper architecture and multilingual benchmarks
- (T7) E-ARMOR benchmark: arXiv:2509.03615, Sep 2025 -- comparative OCR evaluation showing Qwen leading in precision
- (T5) faster-whisper GitHub: SYSTRAN/faster-whisper -- CTranslate2 reimplementation
- (T5) Ollama model library: ollama.com -- model availability verification
- Model card: nvidia/canary-1b on HuggingFace -- language support and architecture details
- Model card: stepfun-ai/GOT-OCR-2.0-hf on HuggingFace -- GOT-OCR2.0 details

**What I did NOT find:**
- "PaddleOCR-VL-1.5" does not appear to exist as a VLM. PaddleOCR is a traditional OCR toolkit.
- Qwen3-VL-8B Ollama availability could not be confirmed as of March 2026.
- Direct head-to-head benchmarks of all 6 vision models on the exact same OCR test set are not available (each paper uses different benchmarks).
- Canary-1B WER numbers for German/French on short utterances (flashcard-length) specifically -- published benchmarks use longer utterances.
