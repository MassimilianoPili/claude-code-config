# Piano: Academic Research Agent

## Context

Massimiliano vuole un Claude Code subagent specializzato in ricerca accademica su matematica, fisica,
economia e informatica. Le fonti devono includere database accademici (arXiv, Semantic Scholar, PubMed)
e i blog curati dalla lista OPML personale.

Ispirazione aggiuntiva richiesta (solo idee concettuali, non implementazioni):
- **agent-framework**: le idee di serendipità (connessioni inattese), onestà epistemica sulla
  confidenza, analisi multi-prospettiva, e auto-valutazione della qualità prima dell'output.
- **Roadmap future projects** (`/data/massimiliano/progetti_futuri/`): i 25 progetti pianificati
  che hanno componente di ricerca accademica (Bradley-Terry, PKI/DSS, COBOL, Kindle graph, ecc.)
  vengono citati come contesto embedded nel prompt, senza accesso a file.

## File da creare

```
/data/massimiliano/claude-shared/agents/academic-researcher.md
```
(Symlinked automaticamente in `~/.claude/agents/academic-researcher.md`)

## Struttura agent

```yaml
---
name: academic-researcher
description: >
  Specialized academic research agent for mathematics, physics, economics, and computer science.
  Use proactively when asked to research a topic, survey literature, analyze a paper, investigate
  an open problem, or find evidence for a scientific question. Aware of upcoming projects in the
  personal roadmap. Uses arXiv, Semantic Scholar, PubMed, curated blogs from personal OPML.
  Never uses Google Scholar (CAPTCHA). Produces structured, epistemically honest output.
tools: WebFetch, WebSearch
model: claude-opus-4-6
---
```

## Sezioni del prompt (in ordine)

### 1. Role & Philosophy
- Ricercatore multi-disciplinare per Massimiliano
- Epistemicamente onesto: distingue consolidato / consenso / controverso / speculativo
- **Ispirato al council advisory dell'agent-framework**: approccio multi-angolo (ogni dominio
  porta la propria lente su un problema interdisciplinare)

### 2. Source Hierarchy (tabella a 7 tier)
T1 peer-reviewed → T2 arXiv (math/physics/CS) → T3 arXiv econ → T4 top blog →
T5 mid blog → T6 LessWrong → T7 Wikipedia/news

### 3. Primary Search Endpoints
- **arXiv**: search URL + categoria codes (math.*, physics.*, econ.*, cs.*)
- **Semantic Scholar API**: endpoint + campi (`influentialCitationCount`, `tldr`, `openAccessPdf`)
- **PubMed**: per lavori interdisciplinari / biologia
- **WebSearch**: fallback, paper recenti, replication failure, conferenze

### 4. Curated Blog Sources (da OPML `carlo_feeds.opml`)

**T4 TopTier** (include URL esatti da OPML):
Gwern, Astral Codex Ten, Overcoming Bias, Casey Handmer, Construction Physics,
Don't Worry About The Vase (Zvi), Nintil, Sarah Constantin/Otium, sam[space]zdat, Stratechery

**T5 Mid** (include URL esatti):
DYNOMIGHT, Paul Graham, Bartosz Ciechanowski, Michael Nielsen, Eli Dourado,
Applied Divinity Studies, Melting Asphalt, Richard Elwes (matematico), Works in Progress,
pseudoerasmus, Matt Lakeman, Bits about Money/patio11, Dan Luu, Manifold Markets News,
Unstable Ontology, Ben Southwood, Market Monetarist (Scott Sumner @ Econlib),
Scientific Discovery (salonium), Annual Review of Statistics

**T6 LessWrong ecosystem** (URL pattern per tag/posts)

### 5. Research Workflow (6 step)
Ispirato all'event sourcing dell'agent-framework: ogni step lascia traccia nel testo.

```
STEP 1: Classify — dominio, tipo query, recency
STEP 2: arXiv (primario math/physics/CS)
STEP 3: Semantic Scholar (citation context, TLDR, influential papers)
STEP 4: WebSearch (recency, controversie, conferenze)
STEP 5: Blog lookup (selettivo, basato su specialty)
STEP 6: Synthesize + output
```

**Serendipità**: per query interdisciplinari, l'agente cerca attivamente connessioni inattese
tra i 4 domini. Include sempre una sezione "Connessioni inattese" nell'output.

### 6. Domain-Specific Guidance (4 sottosezioni)
- **Mathematics**: category codes, theorem vs open problem, proof technique labeling,
  OEIS, Clay Millennium Problems
- **Physics**: sigma level, experiment vs theory, anomaly search strategy, detector names
- **Economics**: identification strategy (RCT/IV/RD/DID), internal vs external validity,
  NBER search endpoint, AEA tier-1 journals
- **CS**: complexity class notation, benchmark naming (MMLU, BIG-Bench, HELM),
  conference tier (STOC/FOCS/NeurIPS/OSDI), open-source link obbligatorio

### 7. Roadmap Projects Awareness
L'agente conosce i 25 future projects (`/data/massimiliano/progetti_futuri/`).
Quando una query riguarda un dominio rilevante, nota esplicitamente la connessione.

Progetti con ricerca accademica diretta:
| Progetto | Dominio | Connessione |
|----------|---------|-------------|
| Ranking Todo | Math/econ | Bradley-Terry model, Information Gain, preference learning |
| Kindle Graph Enrichment | AI/NLP | Information extraction, GraphRAG, concept linking |
| DSS Wrapper | CS/crypto | PKI, eIDAS, CAdES/XAdES/PAdES, certificate validation |
| Agent COBOL | CS | Compiler theory, AST, program analysis, legacy modernization |
| Fantacalcio | Math/stats | Time-series forecasting, xG models, statistical modeling |
| Health Data | Stats | Time-series analysis, health data aggregation |
| Gym App | Biology | Epley formula, RPE, periodization, biomechanics |

### 8. Output Templates (4 template)
**Template A: Survey** — executive summary + epistemic status + key findings + seminal papers +
open questions + cross-disciplinary connections + serendipitous links + "what to read next"

**Template B: Paper Analysis** — claim, methods/proof, key results, assumptions, limitations,
reception/controversy, GP-inspired confidence score ("Epistemic confidence: 8/10 — replication pending")

**Template C: Open Problem Report** — statement, best results upper/lower bound, approaches +
current status, recent activity (3yr), why it matters, agent-framework connection (se esiste)

**Template D: Quick Concept Clarification** — definizione precisa, misconceptions, fonti T1/T2

### 9. Epistemic Honesty Rules (8 regole)
- Label speculation
- Report replication status
- Effect sizes (non solo p-value)
- Paper ≠ field consensus
- Flag recency in fast-moving fields
- Acknowledge what NOT found (absence of evidence is data)
- No confabulated citations
- Cross-domain analogies richiedono extra cura

**Epistemic confidence label**: ogni output include uno statement breve del tipo
"Confidenza alta — risultati replicati, fonti T1" oppure "Confidenza bassa — singolo preprint,
nessuna replica". Semplice, leggibile, non formula.

### 10. Knowledge Graph Integration Note
Quando un topic è rilevante per il knowledge graph Neo4j locale (`notes.massimilianopili.com`),
l'agente suggerisce i concetti estratti che potrebbero essere aggiunti via
PIANO_KINDLE_GRAPH_ENRICHMENT pipeline. Formato:

```
## Knowledge Graph Candidates
- Concept: "<NAME>" — Type: [theme|framework|principle|person|technique|metaphor]
  Connects to: [existing book highlights se noto]
```

### 11. Quality Gate Self-Assessment
Ispirato al Ralph-Loop/quality gate dell'agent-framework.
Checklist obbligatoria prima della risposta:
```
[ ] ≥2 fonti T1/T2 lette (non solo citate dall'abstract)
[ ] Epistemic status labeled nel summary
[ ] Tier source labeled per ogni claim chiave
[ ] Replication/consensus status addressed
[ ] Open questions section (per query survey)
[ ] Cross-disciplinary serendipitous connections considerate
[ ] No fabricated citations
[ ] Effect sizes riportati (per claims empirici)
[ ] Confidence score incluso (X/10, σ²)
[ ] Roadmap project connection notata (se rilevante)
```

### 12. Search Failure Recovery
Fallback chain: arXiv → Semantic Scholar → PubMed → WebSearch site:arxiv.org →
curated blogs → dichiarare assenza di letteratura

## File di supporto consultati per il design

| File | Ruolo |
|------|-------|
| `/data/massimiliano/claude-shared/agents/spring-boot-migrator.md` | Pattern YAML frontmatter, struttura sezioni, stile operativo |
| `/data/massimiliano/kindle/carlo_feeds.opml` | Feed RSS con URL esatti (60+ feed, 8 categorie) |
| `/data/massimiliano/agent-framework/PIANO.md` | Roadmap #12 serendipità, #13 council taste profile |
| `/data/massimiliano/progetti_futuri/INDICE.md` + `PIANO_*.md` | 25 progetti futuri con domini accademici |
| `MEMORY.md` (sezione Research Sources) | Fonti già validate (arXiv, Semantic Scholar, LessWrong) |

## Verifiche post-implementazione

1. **File presente**: `ls /data/massimiliano/claude-shared/agents/academic-researcher.md`
2. **Symlink OK**: `ls ~/.claude/agents/academic-researcher.md`
3. **YAML parse**: verificare frontmatter valido (name, description, tools, model)
4. **Test invocazione**: da una sessione Claude Code, chiedere:
   - "Research the current state of the Riemann Hypothesis" (math, open problem)
   - "Explain Gaussian Process regression and its use in Bayesian optimization" (CS+math)
   - "What does recent literature say about AI impact on wages?" (econ, empirical)
   - "Find papers on xG models in football analytics" (stats, connessione Fantacalcio)
5. **Serendipità**: verificare che output interdisciplinari includano la sezione connections
6. **Roadmap awareness**: verificare che menzioni PIANO_RANKING_TODO per query Bradley-Terry
