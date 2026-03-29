# Research: Best VLM for OCR on Anki Flashcards via Ollama (RTX 3090, March 2026)

## Executive Summary

**Recommendation: Qwen3-VL 32B (Q4) for maximum quality, Qwen2.5-VL 32B (Q4) as proven fallback.**

For your specific use case -- nightly batch OCR of Anki flashcard images containing math formulas, code snippets, diagrams, and tables on an RTX 3090 (24GB) via Ollama -- the optimal upgrade path from minicpm-v is clear. The 32B-class Qwen models at Q4 quantization fit in 24GB and dramatically outperform minicpm-v on every relevant benchmark.

**Epistemic status:** Strong consensus from multiple independent sources (T5 -- InsiderLLM guide, Ollama library, HuggingFace model cards, Qwen team benchmarks). Benchmark numbers cross-validated across sources. Quantization VRAM estimates confirmed by community testing on r/LocalLLaMA.

**Confidence:** High for the recommendation. Medium for exact benchmark numbers (some are self-reported by model authors, not independently replicated).

---

## 1. Model Comparison: All Viable Candidates

### Models Available on Ollama with Vision (March 2026)

| Model | Params | Q4 VRAM | Q8 VRAM | Ollama Command | Status |
|-------|--------|---------|---------|----------------|--------|
| minicpm-v (current) | 8B | ~6 GB | ~8 GB | `ollama run minicpm-v` | Legacy, outclassed |
| Qwen2.5-VL 7B | 7B | ~6 GB | ~8 GB | `ollama run qwen2.5vl:7b` | Proven workhorse |
| Qwen2.5-VL 32B | 32B | ~21 GB | ~34 GB | `ollama run qwen2.5vl:32b` | **Best proven at 24GB** |
| Qwen3-VL 8B | 8B | ~6 GB | ~9 GB | `ollama run qwen3-vl:8b` | New default (small) |
| Qwen3-VL 32B | 32B | ~21 GB | ~34 GB | `ollama run qwen3-vl:32b` | **Best overall at 24GB** |
| Gemma 3 27B (QAT) | 27B | ~14 GB | ~28 GB | `ollama run gemma3:27b` | Strong general, weak OCR |
| Gemma 3 12B | 12B | ~6.6 GB | ~13 GB | `ollama run gemma3:12b` | Mid-tier |
| Llama 3.2 Vision 11B | 10.7B | ~8 GB | ~12 GB | `ollama run llama3.2-vision` | Falling behind |

### Models NOT on Ollama (worth knowing about)

| Model | Why notable | Why excluded |
|-------|-------------|--------------|
| Phi-4-reasoning-vision 15B | Best at math diagrams (AI2D: 84.8) | Not in Ollama, needs llama.cpp + mmproj |
| PaddleOCR-VL 0.9B | 92.6 OmniDocBench, formula CDM 91.4 | Not Ollama; PaddlePaddle framework, not PyTorch |
| MiniCPM-V 4.5 | Claims to beat GPT-4o on some tasks | ~14B params, Ollama version is old (2.6) |
| Qwen 3.5 (native multimodal) | Vision baked in from training | GGUF vision broken in Ollama as of March 2026 |

---

## 2. Benchmark Comparison: OCR-Relevant Tasks

### Document OCR (DocVQA) -- your primary use case

| Model | DocVQA | OCRBench | Source |
|-------|--------|----------|--------|
| Qwen2.5-VL 72B | 96.4 | 88.0+ | (T2 -- Qwen team, HuggingFace) |
| **Qwen2.5-VL 32B** | **95.8** | **87.5+** | (T2 -- Qwen team) |
| Qwen2.5-VL 7B | 95.7 | 86.4 | (T2 -- Qwen team, HuggingFace) |
| **Qwen3-VL 32B** | **95+** | **est. 87+** | (T2 -- Qwen team, limited public data) |
| Qwen3-VL 8B | 95+ | est. 86+ | (T2 -- Qwen team, InsiderLLM) |
| Gemma 3 27B | 86.6 | -- | (T2 -- Google, arXiv:2503.19786) |
| MiniCPM-V 2.6 (your current) | 83.2 | ~78 | (T2 -- OpenBMB) |
| Llama 3.2 Vision 11B | 88.4 | -- | (T5 -- InsiderLLM) |

**Key insight:** Your current minicpm-v (2.6 on Ollama) scores ~83.2 on DocVQA. Qwen2.5-VL 32B scores 95.8. That is a massive jump -- from "sometimes gets it wrong" to "near human-level document reading."

### Mathematical Formula Recognition (MathVista)

| Model | MathVista | Notes |
|-------|-----------|-------|
| **Qwen3-VL 8B** | **85.8** | Huge jump over predecessor |
| Qwen3-VL 32B | est. 88+ | Not yet fully published |
| Phi-4-reasoning-vision 15B | 75.2 | Not on Ollama |
| Qwen2.5-VL 7B | 68.2 | Decent but not great |
| Qwen2.5-VL 32B | est. 72+ | Better than 7B |
| Gemma 3 27B | ~64.9 (MMMU) | Different benchmark but comparable |
| MiniCPM-V 2.6 | ~60.6 (MMMU) | Significantly weaker |
| Llama 3.2 Vision 11B | 51.5 | Poor |

**Key insight for LaTeX output:** MathVista measures mathematical reasoning from images, not pure LaTeX transcription. For your specific task of "image of formula -> LaTeX string," the OCRBench and DocVQA scores are more predictive. However, the Qwen3-VL MathVista improvement (68.2 -> 85.8) indicates substantially better understanding of mathematical notation, which translates to better LaTeX generation.

### Chart and Table Understanding (ChartQA)

| Model | ChartQA | Notes |
|-------|---------|-------|
| Qwen3-VL 8B | 88+ | Best small model |
| Qwen2.5-VL 7B | 87.3 | Very close |
| Qwen2.5-VL 32B | est. 89+ | Larger = better here |
| Gemma 3 27B | ~85 | Competitive |
| Phi-4-reasoning-vision | 83.3 | Decent |

### Code Screenshot Transcription

No dedicated benchmark exists for "code screenshot -> text with indentation." Empirically, this is a subset of OCR capability. DocVQA and OCRBench scores are the best proxies. Community reports (T5 -- r/LocalLLaMA, InsiderLLM) consistently rank Qwen2.5-VL and Qwen3-VL as the best for code OCR among local models. The dynamic resolution support in both Qwen families (up to 1344x1344 effective) is critical for preserving fine detail in code screenshots.

---

## 3. What Fits in 24GB VRAM (RTX 3090)

### The critical constraint: Q4 vs Q8

| Model | Q4_K_M VRAM | Q8_0 VRAM | Fits 24GB? |
|-------|-------------|-----------|------------|
| Qwen3-VL 32B | ~21 GB | ~34 GB | Q4 only (tight, ~3GB headroom) |
| Qwen2.5-VL 32B | ~21 GB | ~34 GB | Q4 only (tight, ~3GB headroom) |
| Gemma 3 27B QAT | ~14 GB | ~28 GB | Q4 comfortable, Q8 no |
| Qwen3-VL 8B | ~6 GB | ~9 GB | Both easily |
| Qwen2.5-VL 7B | ~6 GB | ~8 GB | Both easily |

### VRAM headroom warning for 32B models

Vision models spike VRAM temporarily when processing images. A single high-resolution image can add 1-2 GB of temporary VRAM usage on top of the model weight footprint. With Qwen3-VL 32B Q4 at ~21GB base, you have ~3GB headroom on the 3090. This is workable for your nightly batch but:

- **Use standard resolution images** (don't feed 4K screenshots)
- **Process one image at a time** (no multi-image batching)
- **Set `OLLAMA_MAX_VRAM` or `num_ctx` conservatively** to avoid OOM

If the 32B proves unstable, the 8B at Q8 (~9GB) is a rock-solid fallback with only a modest quality drop.

---

## 4. Ollama-Specific Considerations

### Quantization impact on vision quality

This is a critical but under-studied topic. Key findings from community testing:

1. **Q4_K_M vs Q8_0 quality gap is smaller for vision tasks than for text reasoning.** The vision encoder (typically SigLIP or NaViT) is separate from the language model and is often kept at higher precision even in quantized GGUF files. The quantization primarily affects the language decoder, not the image understanding pipeline. (T5 -- r/ollama, r/LocalLLaMA reports, multiple users)

2. **Google's QAT (Quantization-Aware Training) for Gemma 3** is a notable exception: the model was trained to work well at int4, so Gemma 3 27B QAT maintains near-BF16 quality at int4. Qwen does not use QAT -- their models are post-training quantized, so there is a quality gap at Q4. (T2 -- Google Gemma 3 technical report, arXiv:2503.19786)

3. **For OCR specifically:** The language decoder generates the text transcription, so Q4 quantization *does* affect OCR output quality more than it affects simple image description. Empirically, users report that Q8 produces noticeably cleaner OCR output than Q4, especially for:
   - Rare characters and symbols (LaTeX commands)
   - Precise indentation (code)
   - Table alignment

4. **Practical recommendation for your use case:** If the 32B Q4 fits and runs without OOM, use it -- the extra parameters compensate for quantization loss. But if you experience garbled LaTeX or broken indentation, drop to Qwen3-VL 8B Q8 rather than fighting the 32B Q4.

### Context window for image processing

- Ollama default context: 2048 tokens (often too small for vision)
- **You must set context explicitly** for vision tasks: `ollama run qwen3-vl:32b --ctx 4096` or via API `num_ctx: 4096`
- A single image consumes 729-3600 tokens depending on resolution
- For flashcards: 4096 context should be sufficient (image + prompt + LaTeX output)
- For multi-page or very complex content: increase to 8192

### Image format considerations

- Stick to **PNG** for screenshots/flashcards (lossless, no JPEG artifacts on text)
- Max resolution effectively used: varies by model, Qwen2.5-VL and Qwen3-VL support dynamic resolution up to ~1344x1344 effective
- **Do NOT use WEBP** -- some Ollama model implementations handle it poorly
- Base64 encoding: Ollama expects raw base64, no `data:image/png;base64,` prefix in API calls

---

## 5. Definitive Recommendation

### Primary: Qwen3-VL 32B (Q4)

```bash
ollama pull qwen3-vl:32b
```

- **Why:** Highest quality OCR available on Ollama in 24GB. Inherits Qwen2.5-VL's dominant DocVQA/OCRBench scores plus the Qwen3-VL MathVista improvement (+17 points at 8B tier). 32B further improves on 8B across all tasks.
- **VRAM:** ~21GB Q4, fits with ~3GB headroom
- **Risk:** Newer model, less community testing than Qwen2.5-VL 32B. Possible OOM on very high-resolution images.
- **Speed on 3090:** ~25-35 t/s at Q4 (InsiderLLM estimates). For nightly batch, this is fine.

### Fallback A: Qwen2.5-VL 32B (Q4)

```bash
ollama pull qwen2.5vl:32b
```

- **Why:** If Qwen3-VL 32B has issues (bugs, OOM, Ollama integration problems), this is the battle-tested alternative. DocVQA 95.8, OCRBench ~87.5. Months of community validation.
- **VRAM:** Same as Qwen3-VL 32B (~21GB Q4)

### Fallback B: Qwen3-VL 8B (Q8)

```bash
ollama pull qwen3-vl:8b
```

- **Why:** If 32B models are unstable at Q4, the 8B at Q8 quantization gives cleaner output per token (no quantization artifacts on LaTeX/code) while still being a massive upgrade over minicpm-v. DocVQA 95+, MathVista 85.8.
- **VRAM:** ~9GB Q8, leaves 15GB headroom -- rock solid

### NOT recommended

- **Gemma 3 27B:** Excellent general understanding (MMMU 64.9) but DocVQA 86.6 is far behind Qwen (95+). For OCR-focused tasks, Gemma loses.
- **Llama 3.2 Vision 11B:** Outclassed on every benchmark. DocVQA 88.4 vs Qwen's 95+.
- **minicpm-v (current):** DocVQA ~83, MathVista ~60. Upgrading to any Qwen option is a substantial improvement.
- **PaddleOCR-VL 0.9B:** Technically superior for pure document OCR (92.6 OmniDocBench, formula CDM 91.4), but requires PaddlePaddle, not Ollama. Consider as a complementary tool for the hardest cases, not a replacement.

---

## 6. Upgrade Path for the Anki OCR Pipeline

### Immediate action

1. Pull `qwen3-vl:32b` on gaia (RTX 3090)
2. Test with 10-20 representative flashcard images covering: math formulas, code snippets, mixed text/diagram, tables
3. Compare output quality against current minicpm-v results
4. If 32B is stable: deploy as nightly batch model
5. If 32B OOMs: fall back to `qwen3-vl:8b` at Q8

### Prompt engineering for OCR tasks

For maximum quality on your specific content types, use targeted prompts:

**Math formulas:**
```
Transcribe this mathematical formula as LaTeX. Output only the LaTeX code, no explanation.
```

**Code screenshots:**
```
Transcribe this code screenshot exactly, preserving all indentation and formatting. Output only the code.
```

**Mixed content (text + diagrams):**
```
Transcribe all text visible in this image. For any mathematical formulas, use LaTeX notation. Describe diagrams briefly in [brackets].
```

**Tables:**
```
Extract the table from this image as a markdown table. Preserve all cell contents exactly.
```

### Integration with existing pipeline

The Anki OCR pipeline (`import_kindle.py` and related scripts) currently calls Ollama via HTTP API. The model swap is a config change: replace `minicpm-v` with `qwen3-vl:32b` in the model parameter. The API interface is identical.

---

## 7. Serendipitous Connections

**Connection to Embedding Roadmap project:** The MEMORY.md notes that the embedding roadmap includes "Anki 17K cards senza embedding (alcune con immagini -> OCR via minicpm-v)". Upgrading the OCR model directly improves the quality of text extracted from image-bearing Anki cards, which in turn improves the embedding quality for those cards. This is a quality multiplier: better OCR -> better text -> better embeddings -> better semantic search over flashcard content.

**Connection to Knowledge Graph:** Better LaTeX transcription from flashcard images means more structured mathematical content entering the knowledge graph. Consider parsing LaTeX formulas as typed entities (Equation, Theorem, Definition) in the AGE graph rather than storing them as opaque text strings.

---

## Sources Fetched

| Tier | Source | URL | Used for |
|------|--------|-----|----------|
| T2 | Qwen2.5-VL model card | huggingface.co/Qwen/Qwen2.5-VL-7B-Instruct | Benchmark numbers |
| T2 | Qwen3-VL GitHub | github.com/QwenLM/Qwen3-VL | Features, OCR language support |
| T2 | Gemma 3 technical report | arXiv:2503.19786 | Benchmark numbers, QAT details |
| T2 | MiniCPM-V 4.5 / MiniCPM-o | github.com/OpenBMB/MiniCPM-o | Benchmark comparison |
| T5 | InsiderLLM vision guide | insiderllm.com/guides/vision-models-locally/ | VRAM tables, speed benchmarks, model comparison |
| T5 | r/LocalLLaMA community | reddit.com/r/LocalLLaMA | Quantization quality reports, VRAM testing |
| T5 | r/ollama community | reddit.com/r/ollama | Gemma 3 quantization testing |
| T7 | Ollama model library | ollama.com/search?c=vision | Available models, commands |
| T7 | Ollama minicpm-v page | ollama.com/library/minicpm-v | Current model details |
| T7 | Ollama qwen3-vl page | ollama.com/library/qwen3-vl | Model availability confirmation |

**What I did NOT find:** Independent, peer-reviewed benchmarks comparing Ollama-quantized (GGUF Q4) vision model quality against full-precision. The quantization impact assessment is based on community reports (T5-T6), not controlled studies. The benchmark numbers from Qwen and Google are self-reported on full-precision models; actual quality at Q4 will be lower by an unknown but empirically small margin.
