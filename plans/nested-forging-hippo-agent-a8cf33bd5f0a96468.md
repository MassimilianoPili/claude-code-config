# Research Report: Kagi Search — API, Pricing, Privacy, and Comparison with SearXNG

## Executive Summary

Kagi is a paid, privacy-focused search engine (SaaS-only, no self-hosting) with a well-documented API ecosystem offering search, enrichment, AI-augmented search (FastGPT), and summarization. Its API is prepaid per-query with separate pricing per endpoint. For your SOL infrastructure, Kagi could complement SearXNG as a higher-quality search backend for MCP tools, but at a recurring per-query cost and without self-hosting capability.

**Epistemic status:** Well-documented commercial product. Data sourced directly from Kagi's official docs (GitHub raw markdown, fetched 2026-03-23). No independent benchmarks found for search quality claims.

**Confidence:** High for API/pricing/privacy facts (primary source documentation). Medium for search quality comparisons (no rigorous independent benchmarks exist).

---

## 1. API Availability

Kagi offers **four distinct APIs**, all under base URL `https://kagi.com/api/v0/`:

| API | Status | Endpoint | Description |
|-----|--------|----------|-------------|
| **Search API** | Closed beta (invite-only) | `GET /search` | Full Kagi search results programmatically |
| **Enrichment API** | Public | `GET /enrich/web`, `GET /enrich/news` | Kagi's proprietary indexes (Teclis + TinyGem) |
| **FastGPT API** | Public | `POST /fastgpt` | LLM-powered Q&A with web search grounding |
| **Universal Summarizer API** | Public | `GET/POST /summarize` | Summarize any URL or text content |

### Authentication

All APIs use Bearer token auth:
```
Authorization: Bot <API_TOKEN>
```

Token generated at `https://kagi.com/settings/api` (requires Kagi account).

### Search API Details (closed beta)

- **Endpoint**: `GET /search?q=<query>&limit=<N>`
- **Response format**: JSON with `meta` (request ID, node, latency ms, API balance) + `data` array
- **Result objects**: type 0 = search result (url, title, snippet, published, thumbnail), type 1 = related searches
- **Parameters**: `q` (query string), `limit` (max results)
- **Personalization**: Inherits account settings (blocked/promoted sites, snippet length)
- **Rate limits**: Not documented explicitly; the beta status suggests they may be conservative
- **SDK**: Python via `kagiapi` package; unofficial clients in Go, Rust, Ruby, C#/.NET

### Enrichment API Details (public)

- **Endpoints**: `/enrich/web` (non-commercial web, "small web"), `/enrich/news` (non-mainstream news)
- **Parameters**: `q` (query string)
- **Response**: Same Search Object format as Search API
- **Key characteristic**: These are Kagi's own indexes (Teclis, TinyGem), not general search. Best for discovering non-commercial, indie web content. Bills only when non-zero results returned.

### FastGPT API Details (public)

- **Endpoint**: `POST /fastgpt`
- **Parameters**: `query` (string, required), `cache` (bool, default true), `web_search` (bool, default true -- currently MUST be true)
- **Response**: `output` (answer text), `references` (array of title/snippet/url), `tokens` (count)
- **Latency**: ~8 seconds per query (from example response `ms: 7943`)
- **Note**: `web_search=false` mode is currently **out of service**

### Universal Summarizer API Details (public)

- **Endpoint**: `GET/POST /summarize`
- **Parameters**: `url` or `text`, `engine` (cecil/agnes/muriel), `summary_type`, `cache`
- **Supported formats**: Web pages, PDF, PPTX, DOCX, MP3/WAV audio, YouTube URLs, scanned PDFs (OCR)
- **Unlimited token length** for input documents
- **Zapier integration** available

---

## 2. Pricing Model

### Consumer Plans (for web search UI)

| Plan | Price/month | Searches | AI Access |
|------|-------------|----------|-----------|
| **Trial** | Free | 100 total (one-time) | 100 AI interactions, standard models |
| **Starter** | $5 | 300/month | 300 AI interactions, standard models |
| **Professional** | $10 | Unlimited | Unlimited, standard models |
| **Ultimate** | $25 | Unlimited | Unlimited, premium models (30+ LLMs) |

Annual pricing: 10% discount. Family/Duo plans available. Team plans for organizations.

**Fair pricing policy**: If you don't use any searches/AI in a billing month, full credit is applied to next cycle.

### API Pricing (prepaid credits, separate from subscription)

| API | Cost | Per-unit |
|-----|------|----------|
| **Search API** | $25 / 1,000 queries | **$0.025 per search** |
| **Enrichment API** | $2 / 1,000 queries | **$0.002 per search** (billed only on non-zero results) |
| **FastGPT API** | $15 / 1,000 queries | **$0.015 per query** (with web_search=true) |
| **Summarizer (Cecil/Agnes)** | $0.030 / 1,000 tokens | $0.025 for Ultimate subscribers; max 10K tokens billed per request |
| **Summarizer (Muriel)** | $1.00 flat per summary | Regardless of length |

**Important**: API credits are **prepaid and separate** from the subscription plan. You need both a Kagi account AND topped-up API credits. Cached responses are free across all APIs. Volume discounts available for Enrichment API (contact support).

### Cost Estimation for MCP Usage

If you replaced SearXNG with Kagi Search API as `MCP_WEBSEARCH_URL` backend:
- At 100 searches/day: ~$75/month (Search API)
- At 100 searches/day using Enrichment API: ~$6/month (but limited to "small web" results)
- At 100 FastGPT queries/day: ~$45/month

---

## 3. Search Quality

### Kagi's Architecture

Kagi aggregates results from multiple sources:
- **Google** and **Bing** results (licensed)
- **Teclis**: Kagi's own web index (non-commercial, "small web" focus)
- **TinyGem**: Kagi's news index (non-mainstream sources)
- Custom ranking that **deprioritizes SEO-optimized commercial content**

### Quality Claims (unverified by independent benchmarks)

Kagi claims superior results through:
1. **No ads** -- results are not influenced by advertising
2. **User personalization** -- block/promote specific domains
3. **Lenses** -- filtered search views (e.g., academic, forums, recipes)
4. **De-SEO-ification** -- downranking content farms and SEO-optimized pages
5. **Small Web boost** -- surfacing indie blogs and personal sites

### Independent Evidence

- **No rigorous academic benchmarks** comparing Kagi to Google/Bing search quality exist (T7 -- web discussions only)
- Hacker News and Reddit discussions (T7) are generally positive among power users, particularly for technical/programming queries
- The "small web" indexing (Teclis) is genuinely unique -- no other search engine systematically indexes and surfaces small personal websites
- **Caveat**: Kagi still depends on Google/Bing for most results; its differentiation is in ranking, filtering, and supplementation rather than index independence

---

## 4. Self-Hosting

**Kagi cannot be self-hosted.** It is a fully SaaS product.

- The search engine infrastructure, indexes (Teclis, TinyGem), and LLM backends are proprietary and cloud-hosted
- The API documentation, client libraries, and some tooling are open-source on GitHub (`kagisearch/kagi-docs`)
- The Orion browser (macOS) is a separate Kagi product, also not self-hostable
- There is **no on-premise or Docker deployment option**

This is a fundamental architectural difference from SearXNG.

---

## 5. Privacy

### Policy Summary (from official docs + privacy page)

| Aspect | Kagi's Stance |
|--------|---------------|
| **Search logging** | "We do not log searches or in any way tie them to an account" |
| **Account data** | Only email address stored (can be any email) |
| **Business model** | Subscription-funded, no ad revenue |
| **Data sale** | No selling of user data |
| **Summarizer data** | Content "flows through" infrastructure; set `cache=false` for sensitive documents |
| **Incentive alignment** | "We simply have no incentive to [log searches]. Our business model is to sell subscriptions, not user data." |

### Privacy Assessment

**Strengths**:
- Clear economic incentive alignment (paid model eliminates ad-driven data harvesting)
- Minimal data collection by design
- Option to use anonymous email for account
- `cache=false` option for Summarizer API

**Weaknesses / Trust considerations**:
- You must **trust Kagi's claims** -- there is no way to verify server-side behavior (unlike SearXNG which you run yourself)
- Kagi still proxies queries through Google/Bing APIs, meaning those providers see aggregated query patterns (though not tied to individual Kagi users)
- US-based company subject to US legal jurisdiction (FISA warrants, NSLs)
- No independent security audit publicly available

---

## 6. API Features

### Category/Type Filtering

The Search API does **not** expose explicit category parameters (news, science, images, etc.) in the API. However:
- **Enrichment API** separates `/enrich/web` from `/enrich/news`
- **Lenses** (academic, forums, etc.) are available in the web UI but **not documented as API parameters**
- **Result personalization** (blocked/promoted domains) is inherited from account settings

### Language Filtering

Not documented as an API parameter. The web UI supports region/language settings that the API may inherit from account settings, but there is no explicit `lang` or `region` parameter in the API docs.

### Result Count Control

- `limit` parameter available on Search API to cap result count
- No pagination documented (no offset/page parameter)

### Missing Features (compared to SearXNG)

- No explicit `categories` parameter (general/science/news/it/images)
- No `language` parameter
- No `time_range` parameter (recent results filtering)
- No `safesearch` parameter
- No pagination
- No engine selection

---

## 7. Kagi FastGPT / Universal Summarizer (AI Features)

### FastGPT

- LLM-powered search: sends query to search engine, feeds results to LLM, returns synthesized answer with references
- Equivalent to Perplexity AI or Google AI Overview, but via API
- **$0.015 per query** with web search
- Returns structured references (title, snippet, URL) alongside the answer
- ~8s latency
- **MCP integration exists**: `mcpmarket.com` lists a Kagi MCP server with `ask_fastgpt`, `enrich_web`, `enrich_news` tools

### Universal Summarizer

- Summarize any content type (web, PDF, DOCX, audio, YouTube)
- Three engines: Cecil (basic), Agnes (mid), Muriel (enterprise, $1/summary)
- Unlimited input length
- OCR support for scanned documents
- Particularly useful for research workflows

### Kagi Assistant (web UI only, not API)

- Access to 30+ LLMs (OpenAI, Anthropic, Google, Mistral, Grok, etc.) through a single interface
- Included in Ultimate plan ($25/month)
- **Not available via API** -- web UI only

---

## 8. Comparison: Kagi vs SearXNG

| Dimension | **Kagi** | **SearXNG** (your current setup) |
|-----------|----------|----------------------------------|
| **Deployment** | SaaS only | Self-hosted (Docker on SOL) |
| **Cost** | $0.025/search (API) + subscription | Free (you pay only for hosting) |
| **Privacy** | Trust-based (no logging claim) | Verifiable (you control the server) |
| **Search quality** | High (Google+Bing+own indexes, curated ranking) | Variable (meta-search, depends on upstream engines) |
| **Own indexes** | Yes (Teclis, TinyGem -- "small web") | No (pure meta-search) |
| **API maturity** | v0 beta, limited params | Mature JSON API, full params |
| **Categories** | Limited (web/news enrichment only) | Extensive (general, science, it, news, images, etc.) |
| **Language filter** | Not in API | Yes (`language` param) |
| **Rate limits** | Prepaid credits (no hard rate limit) | Self-managed (your server capacity) |
| **Upstream dependency** | Google, Bing (licensed) | Google, Bing, DuckDuckGo, Brave, etc. (scraped) |
| **AI features** | FastGPT, Summarizer (via API) | None built-in |
| **Resilience** | Depends on Kagi servers | Depends on your server + upstream engines |
| **Customization** | Limited (account settings) | Full (settings.yml, engine selection) |
| **Bot protection issues** | None (licensed access) | Frequent CAPTCHAs from upstream engines |

### Key Trade-offs for Your Infrastructure

**Arguments for adding Kagi API alongside SearXNG**:
1. **Enrichment API** ($0.002/search) could supplement SearXNG with "small web" results at very low cost
2. **FastGPT** provides AI-grounded search without needing to build your own RAG pipeline
3. **No CAPTCHA issues** -- Kagi has licensed agreements with Google/Bing, unlike SearXNG which scrapes and gets blocked (you saw `google: access denied`, `duckduckgo: CAPTCHA`, `startpage: CAPTCHA` in this very session)
4. **Universal Summarizer** could enhance the `web_ingest` pipeline

**Arguments against replacing SearXNG with Kagi**:
1. **Cost**: At scale, Kagi API gets expensive ($0.025/search adds up)
2. **No self-hosting**: Single point of failure, vendor dependency
3. **API limitations**: No categories, language, time_range, pagination
4. **Search API is invite-only beta**: Not guaranteed stable access
5. **SearXNG is free and under your control**: Aligns with self-hosted infrastructure philosophy
6. **SearXNG `science` category**: Aggregates Semantic Scholar, CrossRef, arXiv, OpenAlex, PubMed -- Kagi has nothing equivalent for academic search

### Recommendation

**Hybrid approach**: Keep SearXNG as primary `MCP_WEBSEARCH_URL` (free, self-hosted, full control, academic `science` category). Consider adding Kagi as a **supplementary source** for specific use cases:
- `enrich/web` for "small web" discovery ($0.002/query -- very cheap)
- `fastgpt` for AI-grounded quick answers in MCP research workflows
- `summarize` for long-document summarization in `web_ingest` pipeline

This could be implemented as additional MCP tools (`kagi_enrich_web`, `kagi_fastgpt`, `kagi_summarize`) without replacing the existing SearXNG-based `web_search`.

---

## Serendipitous Connections

- **Kagi Enrichment API + Knowledge Graph**: The Teclis "small web" index surfaces personal blogs and indie sites that are often missing from mainstream search. This could be a valuable source for enriching the KORE knowledge graph with non-mainstream perspectives, particularly for the rationalist blog sources listed in the research agent system prompt (Gwern, ACX, etc.).
- **Kagi MCP Server**: An official Kagi MCP server already exists on mcpmarket.com with `ask_fastgpt`, `enrich_web`, `enrich_news` tools. This could be integrated directly into the `simoge-mcp` tool ecosystem.
- **Personal Project -- Ranking Todo**: The Kagi result personalization (block/promote domains) is conceptually similar to the Bradley-Terry preference learning in the Preference Sort project. Kagi's approach is binary (block/promote), while yours is continuous (pairwise comparison). A hybrid could be interesting.

---

## Sources

All sources fetched directly on 2026-03-23:

1. Kagi Search API docs: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/api/search.md` (T7 -- official docs)
2. Kagi API Overview: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/api/overview.md` (T7)
3. Kagi Enrichment API: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/api/enrich.md` (T7)
4. Kagi FastGPT API: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/api/fastgpt.md` (T7)
5. Kagi Universal Summarizer API: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/api/summarizer.md` (T7)
6. Kagi Plan Types: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/plans/plan-types.md` (T7)
7. Kagi Privacy Protection: `https://raw.githubusercontent.com/kagisearch/kagi-docs/main/docs/kagi/privacy/privacy-protection.md` (T7)
8. Kagi Privacy Policy page: `https://kagi.com/privacy` (T7)
9. Web search results for Kagi API pricing (SearXNG, 2026-03-23)
