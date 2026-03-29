# Source Routing Table

Maps (domain, topic) to the most relevant sources. Use this to decide which endpoints
and blog sources to consult for a given query, instead of searching everything.

## By Primary Domain

| Domain | Primary endpoints | Key blogs (T4-T5) | arXiv categories |
|--------|-------------------|-------------------|------------------|
| **Mathematics** | arXiv, S2, OEIS, Clay | Richard Elwes | `math.*`, `math-ph` |
| **Physics** | arXiv, S2, PubMed (biophysics) | Casey Handmer, Bartosz Ciechanowski | `hep-*`, `gr-qc`, `quant-ph`, `cond-mat.*`, `astro-ph.*` |
| **Economics** | NBER, SSRN, S2, arXiv | pseudoerasmus, Construction Physics, Market Monetarist, Ben Southwood, Bryan Caplan | `econ.*`, `q-fin.*` |
| **CS — Theory** | arXiv, S2, DBLP | Dan Luu, Paul Graham | `cs.CC`, `cs.DS`, `cs.IT`, `cs.LO` |
| **CS — ML/AI** | arXiv, S2, DBLP | Gwern, Zvi, Eliezer/AF | `cs.LG`, `cs.AI`, `cs.CL`, `stat.ML` |
| **CS — Systems** | arXiv, S2, DBLP | Dan Luu, Bits about Money | `cs.DC`, `cs.OS`, `cs.NI` |
| **CS — Security** | arXiv, S2, DBLP | — | `cs.CR` |
| **Biology/Medicine** | PubMed, arXiv (q-bio), S2 | Nintil, Otium, DYNOMIGHT | `q-bio.*` |
| **Statistics** | arXiv, S2, Ann. Rev. Statistics | DYNOMIGHT, Metaculus | `stat.*` |
| **Philosophy** | S2, WebSearch | Unstable Ontology, Reflective Disequilibrium, Melting Asphalt | — |
| **Social Science** | SSRN, S2, WebSearch | Works in Progress, Applied Divinity Studies, Matt Lakeman | — |
| **Tech Business** | WebSearch | Stratechery, Bits about Money, Eli Dourado | — |
| **AI Safety** | arXiv, S2, LessWrong | Zvi, Eliezer/AF, Astral Codex Ten | `cs.AI`, `cs.LG` |
| **Forecasting** | Metaculus, Manifold, WebSearch | Astral Codex Ten, Zvi | — |
| **Finance** | SSRN, NBER, S2 | Bayesian Investor, Bits about Money | `q-fin.*` |

## By Query Type

| Query type | Template | Priority sources |
|------------|----------|------------------|
| Broad survey | A | arXiv + S2 + 2-3 targeted blogs |
| Paper analysis | B | S2 (paper details) + DBLP (venue) + citations |
| Open problem | C | arXiv + Clay + S2 (recent preprints) |
| Concept explanation | D | S2 + Wikipedia (background) + 1 T4 blog if available |
| Causal claim | E | S2 + PubMed + NBER/SSRN + replication databases |
| Design validation | F | S2 + DBLP + OpenAlex (cross-check) |

## Validation-Specific Routing

| Task | Primary | Fallback |
|------|---------|----------|
| Venue verification | DBLP | S2 `venue` field |
| Citation count | S2 API | OpenAlex (for >500 cit cross-check) |
| Author verification | DBLP | S2 `authors` field |
| Paper existence | S2 by title | arXiv by ID, WebSearch |
| Multi-version tracking | DBLP (all versions) | S2 + arXiv |
