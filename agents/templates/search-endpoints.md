# Primary Search Endpoints

**IMPORTANT**: For paper validation, use `research_validate_paper` (S2+DBLP+OpenAlex server-side, cached 24h).
For API fetches, ALWAYS use `web_fetch(url, extract=...)` — never raw fetch. Results are cached + queued for KORE.

## arXiv

arXiv API (XML, use `extract="arxiv"` with web_fetch):
```
https://export.arxiv.org/api/query?search_query=<QUERY>&max_results=5
```

Abstract fetch: `https://arxiv.org/abs/<ID>`

**DO NOT use** `https://arxiv.org/search/` (HTML page — wastes tokens parsing HTML).

**Category codes by domain:**

| Domain | Key categories |
|--------|---------------|
| Mathematics | `math.NT` number theory - `math.CO` combinatorics - `math.PR` probability - `math.ST` statistics theory - `math.LO` logic - `math.AG` algebraic geometry - `math.DG` differential geometry - `math.AP` analysis of PDEs - `math.GR` group theory - `math.CT` category theory - `math-ph` mathematical physics |
| Physics | `hep-th` high-energy theory - `hep-ph` phenomenology - `gr-qc` general relativity & quantum cosmology - `quant-ph` quantum physics - `cond-mat.str-el` strongly correlated systems - `astro-ph.CO` cosmology - `hep-ex` experiments |
| Economics | `econ.TH` economic theory - `econ.EM` econometrics - `econ.GN` general - `q-fin` quantitative finance |
| CS | `cs.LG` machine learning - `cs.AI` artificial intelligence - `cs.CC` computational complexity - `cs.DS` data structures & algorithms - `cs.CR` cryptography - `cs.IT` information theory - `cs.CL` computation & language - `stat.ML` |
| Biology / Medicine | `q-bio.QM` quantitative methods - `q-bio.NC` neurons & cognition - `q-bio.PE` populations & evolution - `q-bio.GN` genomics |
| Applied Statistics | `stat.AP` applications - `stat.ME` methodology - `stat.CO` computation |

To filter by category, search `cat:math.NT AND <QUERY>` in the query field.

## Semantic Scholar Graph API

Paper search with rich metadata (**always use `extract="semantic_scholar"`**):
```
web_fetch("https://api.semanticscholar.org/graph/v1/paper/search?query=<QUERY>&fields=title,authors,year,abstract,citationCount,influentialCitationCount,openAccessPdf,tldr&limit=10", extract="semantic_scholar")
```

Specific paper by arXiv ID:
```
web_fetch("https://api.semanticscholar.org/graph/v1/paper/arXiv:<ID>?fields=title,authors,year,abstract,citationCount,influentialCitationCount,tldr", extract="semantic_scholar")
```

Results are cached 24h in Redis + queued for KORE ingest. Use `influentialCitationCount` as quality proxy.
If you get HTTP 429, switch to OpenAlex immediately (NO retry).

## PubMed

For interdisciplinary or biology-adjacent topics:
```
https://pubmed.ncbi.nlm.nih.gov/?term=<QUERY>&sort=relevance
```

## NBER Working Papers (economics)

```
https://www.nber.org/search?q=<QUERY>&working_page=1
```

## SSRN (economics, finance, law, social science)

For working papers not yet on NBER — broader coverage of econometrics, finance, legal studies:
```
https://papers.ssrn.com/sol3/results.cfm?txtkey=<QUERY>
```

Prefer NBER for macro/applied econ; prefer SSRN for finance, law, and interdisciplinary social science.

## DBLP (venue & author verification)

**PRIMARY**: `research_validate_paper` already includes DBLP cross-check. Use it instead of manual DBLP fetches.

DBLP JSON API (if you must fetch manually — emergency fallback only):
```
https://dblp.org/search/publ/api?q=<PAPER+TITLE>&format=json&h=3
```

**DO NOT use** `https://dblp.org/search?q=...` (HTML page — wastes tokens parsing HTML).
The JSON API returns structured data that's much easier to process.

## OpenAlex (bulk metadata, open access)

Paper search with rich metadata (**always use `extract="openalex"`**):
```
web_fetch("https://api.openalex.org/works?search=<QUERY>&per_page=10", extract="openalex")
```

Specific paper by DOI:
```
web_fetch("https://api.openalex.org/works/doi:<DOI>", extract="openalex")
```

OpenAlex has **no rate limits** (polite pool with mailto header). Results cached 24h + KORE ingest.
Use as primary fallback when S2 returns 429. Particularly useful for older papers and non-CS venues.

## WebSearch

Use for: results from the last 6 months not yet in academic DBs, specific blog posts,
replication failures and controversies, conference proceedings (NeurIPS, ICML, STOC, FOCS, AEA).
