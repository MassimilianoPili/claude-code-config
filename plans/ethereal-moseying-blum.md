# Piano: Miglioramento qualità ricerca accademica — v2 + v3

## Context

Dalla validazione S29 (Fase 20, 10 item, ~30 paper verificati, ~60 nuovi trovati) emergono 3 pattern sistematici di errore che l'agent `academic-researcher.md` (v1, 802 righe) non previene nonostante abbia istruzioni per farlo:

1. **Citazioni inaffidabili**: delta -74% (Spinellis) a +196% (Self-Refine). L'agente dice "always use Semantic Scholar" ma continua a riportare conteggi da memoria/training data
2. **Venue errate**: Voyager (TMLR non NeurIPS), Promptbreeder (ICML 2024 non arXiv-only), AgentSpec autori sbagliati (Wang non Zhou). DBLP cross-check raccomandato solo per "casi ambigui" — dovrebbe essere obbligatorio
3. **Algoritmi inappropriati**: ETO richiede fine-tuning (incompatibile con API LLM), BOCPD assume i.i.d. (KPI hanno trend), CP assume spazio discreto (RE ha spazio aperto). Solo 4 esempi nel checklist attuale

**Root cause**: le istruzioni sono SOFT guidelines, non HARD gates. L'agente le interpreta come raccomandazioni, non come requisiti bloccanti.

## Strategia a 3 livelli

| Livello | Cosa | Enforcement | File |
|---------|------|-------------|------|
| **v1** (attuale) | Prompt con soft guidelines | Semantico — l'agente "dovrebbe" fare le verifiche | `academic-researcher.md` (802 righe) |
| **v2** (prompt) | Prompt con hard gates, tassonomie, Known Confusions | Semantico rafforzato — formato obbligatorio, anti-pattern espliciti | `academic-researcher.md` (~950 righe) |
| **v3** (infrastruttura) | MCP tool `research_validate_paper` + hook PostToolUse | **Deterministico** — MCP fa la fetch, hook blocca report incompleti | `ResearchValidationTools.java` + `validate-research-report.sh` |

**Principio**: v2 rende facile fare la cosa giusta, v3 rende impossibile fare la cosa sbagliata.

### Infrastruttura esistente sfruttata

- **MCP**: `web_fetch(url, extract="semantic_scholar"|"arxiv"|"openalex")` già in `WebSearchTools.java` — fa fetch S2/DBLP/OpenAlex con estrazione strutturata
- **Hooks**: `settings-hooks.json` + bash scripts in `/data/massimiliano/claude-code-config/hooks/` — PreToolUse (exit 2 = block), PostToolUse (validazione)
- **AGE ingestion**: `web_ingest_from_extract` già archivia paper nel knowledge graph
- **Pattern**: stessa architettura di `block-dangerous-commands.sh` (regex su stdin JSON) e `protect-sensitive-files.sh` (path matching)

## Diagnosi per categoria

### A. Citazioni (delta -74% → +196%)

**Stato attuale** (righe 239-244 di `academic-researcher.md`):
- "Always use Semantic Scholar citationCount — never Google Scholar, never guess"
- "Report as ~N (S2) to indicate the source"
- "Flag discrepancies > 30% from claimed counts"

**Perché fallisce**: l'agente spesso riporta citazioni senza effettivamente fare la fetch S2. La regola "never guess" non è enforce tramite formato.

**Fix**: rendere il formato obbligatorio — ogni paper DEVE avere una riga `Citazioni | ~N_claimed | ~N_verified (S2, fetched YYYY-MM-DD)` nella tabella di validazione. Se la fetch fallisce, scrivere `FETCH FAILED — non riportare conteggi`.

### B. Venue (TMLR vs NeurIPS, ICML vs arXiv)

**Stato attuale** (righe 228-237):
- Fetch da S2, confronta venue field
- "For ambiguous cases, cross-check with DBLP"

**Perché fallisce**: "ambiguous cases" è discrezionale — l'agente decide che non è ambiguo e salta DBLP. Inoltre manca il pattern "multi-version tracking" (arXiv → workshop → conference → journal).

**Fix**: DBLP obbligatorio per ogni paper CS. Aggiungere regola: "Se esiste versione conferenza/journal, citare quella, non l'arXiv preprint". Aggiungere lista "Known LLM Confusions" con errori ricorrenti.

### C. Algoritmi (precondizioni non verificate)

**Stato attuale** (righe 246-253): solo 4 esempi specifici:
- Aho-Corasick: exact vs subsequence
- Holt-Winters: richiede stagionalità
- Redis pub/sub: fire-and-forget
- BFS/DFS: struttura grafo

**Perché fallisce**: 4 esempi non coprono la varietà di precondizioni. Manca una tassonomia strutturata delle precondizioni da verificare.

**Fix**: espandere a una tassonomia di 8+ categorie di precondizioni, ciascuna con 2-3 esempi concreti dalle correzioni S29.

## Modifiche pianificate

### File da modificare

`/data/massimiliano/claude-shared/agents/academic-researcher.md` — l'unico file da modificare

### Modifica 1: Sezione CITATION COUNT VERIFICATION (righe 239-244)

Riscrivere da soft recommendation a hard format requirement:

```markdown
### Citation Count Verification — HARD GATE
1. **NEVER report citation counts from memory or training data.** Every count MUST come from an actual S2 API fetch
2. In the validation table, the Citations row MUST include:
   - `~N_claimed` (what the design document says)
   - `~N_verified (S2, YYYY-MM-DD)` (what S2 returns today)
   - If fetch fails: write `S2 FETCH FAILED — DO NOT report any count`
3. Flag as **Correzione** if |claimed - verified| > 30%
4. Cross-reference with OpenAlex for papers with >500 citations (sanity check)
5. Use `influentialCitationCount` as quality proxy (more stable than raw count)

**Anti-pattern**: DO NOT write "~1000 citations" without an S2 URL fetch. The LLM training data has stale/wrong citation counts — this is a known, systematic failure mode.
```

### Modifica 2: Sezione VENUE VERIFICATION (righe 228-237)

Cambiare da "ambiguous cases" a "every paper":

```markdown
### Venue Verification — MANDATORY DBLP CROSS-CHECK
1. Fetch the paper from Semantic Scholar API by title or arXiv ID
2. **For EVERY CS paper**, cross-check venue with DBLP: `https://dblp.org/search?q=<PAPER+TITLE>`
   - DO NOT skip this step even if S2 venue looks correct — S2 venue names are often informal
3. Multi-version tracking: if paper exists in multiple forms (arXiv → workshop → conference → journal):
   - Identify the STRONGEST version (journal > conference > workshop > arXiv)
   - Cite the strongest version, note the arXiv ID as reference
4. Flag as **Correzione** if: venue name wrong, year wrong, or citing arXiv when conference version exists
5. Author verification: check first author name matches S2/DBLP (LLMs sometimes confuse co-authors)

#### Known LLM Confusions (accumulated from S29 validation)
| Paper | LLM tends to say | Correct |
|-------|------------------|---------|
| Voyager (Wang et al.) | NeurIPS 2023 | TMLR 2024 |
| Promptbreeder (Fernando et al.) | arXiv-only | ICML 2024 |
| Li AOP | 2025 | ICLR 2024 |
| Brown C4 | 2018 | 2012 |
| Spinellis | IEEE Software 2008, ~150 cit | IEEE Software 2003, ~39 cit (S2) |
| AgentSpec | Zhou et al. | Wang, Poskitt & Sun |
| Predicting Faults | Bird, ICSE 2004 | Kim & Zimmermann, ICSE 2007 |

This table should grow as new confusions are discovered. Add entries in Step 5 (Progressive Enrichment).
```

### Modifica 3: Sezione ALGORITHMIC CORRECTNESS CHECK (righe 246-253)

Sostituire i 4 esempi con una tassonomia strutturata di 8 categorie:

```markdown
### Algorithmic Correctness — Precondition Taxonomy

When a design cites an algorithm, verify EACH of these precondition categories:

| # | Precondition | Question to ask | Example failure (S29) |
|---|---|---|---|
| 1 | **Training access** | Does it require gradient/weight updates? | ETO (#178): requires DPO fine-tuning — incompatible with API-based LLMs (frozen weights). Use ExpeL/Reflexion instead |
| 2 | **Distribution assumption** | Does it assume i.i.d., stationarity, normality? | BOCPD (#181): assumes i.i.d. observations — KPIs have trends/seasonality. Use E-Divisive (non-parametric) |
| 3 | **Space topology** | Discrete/finite vs continuous/open? | Conformal Prediction (#179): assumes discrete label space — requirements elicitation has open-ended space. Use EVPI instead |
| 4 | **Computational complexity** | O(n³)? O(2^n)? Scales to the actual data size? | GP posterior (#178): O(n³) — use sparse GP or CoPS for >1000 datapoints |
| 5 | **Feedback type** | Self-feedback vs external oracle? | Self-Refine (#186): uses self-feedback — CTF loop has compiler/test oracle, which is strictly better. Use Self-Debug pattern |
| 6 | **Pattern sufficiency** | Can regex/exact match capture semantic patterns? | Git safety regex (#185): misses contextual danger (e.g., `rm -rf $VAR` where VAR is user-controlled). Need AST/sequence analysis |
| 7 | **Iteration bounds** | Diminishing returns? Optimal count? | Iterative refinement (#186): 2-3 iterations optimal, beyond is waste or regression. Must cap iterations |
| 8 | **Delivery guarantee** | Fire-and-forget vs at-least-once vs exactly-once? | Redis pub/sub: fire-and-forget — for guaranteed delivery use Redis Streams |
| 9 | **Idempotency** | Can the operation be safely retried? | Webhook delivery (#184): without idempotency keys, retries cause duplicate side effects |
| 10 | **Compensation** | What happens on partial failure? | Lifecycle manager (#180): multi-step plans need Saga pattern with compensating actions, not simple rollback |

**General rule**: for EACH algorithm cited in a design, identify which rows apply and verify the preconditions match. Flag mismatches as **Correzione critica** with the correct alternative.

Legacy examples (still valid):
- **Aho-Corasick**: exact multi-pattern substring matching — NOT subsequence matching
- **Holt-Winters**: requires seasonality — for non-seasonal data use Holt's linear (damped trend)
- **BFS/DFS**: check if the graph structure matches (DAG vs cyclic, weighted vs unweighted)
```

### Modifica 4: Nuova sezione POST-VALIDATION CHECKLIST (dopo Quality Checklist)

Aggiungere checklist specifica per Template F che enforce i 3 hard gates:

```markdown
## TEMPLATE F — HARD GATES

Before delivering a Template F report, verify these BLOCKING requirements:

### Gate 1: Citation Provenance
- [ ] Every paper has a `Citazioni | claimed | verified (S2, date)` row
- [ ] No citation count came from memory — every one was fetched from S2 API
- [ ] Papers with S2 FETCH FAILED do NOT report any count

### Gate 2: Venue Provenance
- [ ] Every CS paper was cross-checked on DBLP (even if S2 looked correct)
- [ ] Multi-version papers cite the strongest version (journal > conference > arXiv)
- [ ] First author name verified against S2/DBLP

### Gate 3: Algorithm Preconditions
- [ ] Each algorithm was checked against the 10-row Precondition Taxonomy
- [ ] At minimum, rows 1-3 (training access, distribution, space) were explicitly evaluated
- [ ] Mismatches flagged as Correzione critica with alternative

If any gate fails, the report is INCOMPLETE — do not deliver it.
```

### Modifica 5: Aggiornamento Step 5 — Progressive Enrichment (righe 357-365)

Aggiungere istruzioni specifiche per accumulare errori:

```markdown
### Step 5 — Progressive Enrichment

After completing each phase of research, codify lessons:
- **New Known LLM Confusions**: add to the "Known LLM Confusions" table in Venue Verification
- **New Precondition rows**: add to the Precondition Taxonomy if a new category was discovered
- **New anti-patterns**: add to the relevant section with the failure case
- Update this agent definition with the new knowledge. **Codify lessons in the system, not in memory.**

Example enrichment from S29:
- Added 7 entries to Known LLM Confusions table
- Expanded Precondition Taxonomy from 4 to 10 rows
- Added "Anti-pattern" callout in Citation Count Verification
```

## Ordine di esecuzione

```
Step 1 (v2 — prompt):      academic-researcher.md → v2 (~950 righe)
Step 2 (v3 — MCP tool):    ResearchValidationTools.java (NEW)
Step 3 (v3 — hook):        validate-research-report.sh (NEW) + settings-hooks.json (MOD)
Step 4 (v2 — agent ref):   academic-researcher.md → aggiornare per referenziare il nuovo tool MCP
Step 5 (test):              Lanciare academic-researcher su un paper noto, verificare enforcement
```

---

## Step 2 — v3: MCP Tool `research_validate_paper`

### Razionale

L'agente ha già `web_fetch(url, extract="semantic_scholar")` ma deve:
1. Costruire l'URL S2 manualmente
2. Ricordarsi di fare anche DBLP
3. Confrontare claimed vs verified a mano

Un tool dedicato elimina tutti e 3 i passaggi — una singola chiamata restituisce la validazione completa.

### Design

```java
// Package: inline in simoge-mcp (come WebSearchTools)
// File: /data/massimiliano/Vari/mcp/src/main/java/com/simoge/mcp/tools/ResearchValidationTools.java

@Service
public class ResearchValidationTools {

    @ReactiveTool(name = "research_validate_paper",
        description = "Valida un paper accademico contro Semantic Scholar + DBLP + OpenAlex. " +
                      "Confronta metadati dichiarati (venue, anno, citazioni) con quelli verificati. " +
                      "Restituisce validazione strutturata con correzioni.")
    public Mono<String> validatePaper(
        @ToolParam(description = "Titolo del paper (ricerca fuzzy)") String title,
        @ToolParam(description = "Venue dichiarata nel design (es. 'NeurIPS 2023')", required = false)
            String claimedVenue,
        @ToolParam(description = "Anno dichiarato", required = false) Integer claimedYear,
        @ToolParam(description = "Citazioni dichiarate (es. ~1000)", required = false)
            Integer claimedCitations,
        @ToolParam(description = "Primo autore dichiarato (es. 'Zhou')", required = false)
            String claimedFirstAuthor
    ) {
        // Pipeline:
        // 1. S2 search by title → get paperId, venue, year, citationCount, authors
        // 2. If S2 has arXiv ID → fetch DBLP by title (venue cross-check)
        // 3. If citations > 500 → OpenAlex cross-reference
        // 4. Build diff: claimed vs verified per field
        // 5. Flag corrections where delta > threshold
        // Return: structured JSON
    }
}
```

### Output JSON

```json
{
  "status": "VALIDATED",
  "paper": {
    "title": "Voyager: An Open-Ended Embodied Agent with Large Language Models",
    "authors": ["Guanzhi Wang", "Yuqi Xie", "..."],
    "first_author": "Guanzhi Wang"
  },
  "validation": {
    "venue": {
      "claimed": "NeurIPS 2023",
      "verified": "TMLR 2024",
      "source": "DBLP",
      "correction": true
    },
    "year": {
      "claimed": 2023,
      "verified": 2024,
      "correction": true
    },
    "citations": {
      "claimed": null,
      "verified": 1360,
      "influential": 117,
      "source": "S2",
      "fetch_date": "2026-03-15"
    },
    "first_author": {
      "claimed": "Wang",
      "verified": "Guanzhi Wang",
      "correction": false
    }
  },
  "multi_version": {
    "arxiv": "arXiv:2305.16291",
    "conference": null,
    "journal": "TMLR 2024",
    "strongest": "journal"
  },
  "corrections_summary": [
    "Venue: NeurIPS 2023 → TMLR 2024",
    "Year: 2023 → 2024"
  ]
}
```

### Dipendenze

- Riusa `WebSearchTools` per HTTP (WebClient già configurato con retry, timeout 30s, 4 livelli resilienza)
- Riusa `ApiExtractors.extractSemanticScholar()` per parsing S2 response
- DBLP: fetch HTML da `https://dblp.org/search?q=<TITLE>`, parse venue dal risultato
- Nessuna nuova dipendenza Maven — tutto stdlib + WebClient esistente

### File

- `ResearchValidationTools.java` (NEW, ~200 righe) — in `/data/massimiliano/Vari/mcp/src/main/java/com/simoge/mcp/tools/`
- `DblpExtractor.java` (NEW, ~80 righe) — parsing DBLP HTML response

---

## Step 3 — v3: Hook `validate-research-report.sh`

### Razionale

Anche con il tool MCP disponibile, l'agente potrebbe non usarlo. Il hook è la rete di sicurezza: blocca il `Write` se il report non contiene evidenza di validazione verificata.

### Design

```bash
#!/bin/bash
# Hook: validate-research-report.sh
# Evento: PreToolUse (matcher: Write)
# Blocca scrittura di research report senza validazione verificata

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Solo file in docs/research/*.md
if ! echo "$FILE_PATH" | grep -qE 'docs/research/.*\.md$'; then
  exit 0
fi

CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')

# Gate 1: Almeno un paper validato con S2 (pattern: "(S2" o "S2," o "Semantic Scholar")
if ! echo "$CONTENT" | grep -qE '\(S2[,)]|Semantic Scholar|S2 FETCH FAILED'; then
  echo "BLOCCATO: research report senza evidenza di validazione Semantic Scholar" >&2
  echo "Ogni paper deve avere citazioni verificate '(S2, YYYY-MM-DD)' o 'S2 FETCH FAILED'" >&2
  exit 2
fi

# Gate 2: Almeno una reference DBLP o dichiarazione esplicita N/A
if ! echo "$CONTENT" | grep -qiE 'dblp\.org|DBLP|dblp'; then
  echo "BLOCCATO: research report senza cross-check DBLP" >&2
  echo "Ogni paper CS deve avere un riscontro DBLP (o 'DBLP: N/A' per paper non-CS)" >&2
  exit 2
fi

# Gate 3: Sezione Algorithmic Correctness o Precondition presente
if ! echo "$CONTENT" | grep -qiE 'Algorithmic Correctness|Precondition|Algorithm.*Appropriate'; then
  echo "BLOCCATO: research report senza sezione Algorithmic Correctness" >&2
  exit 2
fi

exit 0
```

### Configurazione hook

Aggiungere in `settings-hooks.json` sotto `PreToolUse`:

```json
{
  "matcher": "Write",
  "hooks": [
    {
      "type": "command",
      "command": "/data/massimiliano/claude-code-config/hooks/validate-research-report.sh"
    }
  ]
}
```

**Nota**: va aggiunto DOPO gli hook Write esistenti (`protect-sensitive-files.sh`). L'ordine di esecuzione è sequenziale — tutti devono passare (exit 0) per permettere la scrittura.

### File

- `validate-research-report.sh` (NEW, ~40 righe) — in `/data/massimiliano/claude-code-config/hooks/`
- `settings-hooks.json` (MOD) — aggiungere entry PreToolUse Write

---

## Step 4 — v2 aggiornamento: referenziare MCP tool

Dopo aver creato `research_validate_paper`, aggiornare `academic-researcher.md` (v2) per:

1. Aggiungere nella sezione TOOL NAMES:
   ```
   - Paper validation: `mcp__simoge-mcp__research_validate_paper`
   ```

2. Nella sezione PAPER VALIDATION PROTOCOL, aggiungere:
   ```
   ### Preferred Workflow (v3)
   For EACH paper to validate, call `research_validate_paper(title, claimedVenue, claimedYear, claimedCitations, claimedFirstAuthor)`.
   This tool performs S2 + DBLP + OpenAlex validation automatically and returns structured corrections.
   Use the tool output directly in the validation table — DO NOT override with memory-based values.

   If the tool is unavailable, fall back to manual S2 + DBLP fetch (see Manual Workflow below).
   ```

3. Aggiungere header di versione:
   ```
   # Academic Research Agent v2
   # Changelog: v1 → v2 (S29, 2026-03-15): hard gates, precondition taxonomy, known confusions, MCP tool integration
   ```

---

## Verifica

### v2 (prompt)
1. `wc -l academic-researcher.md` — atteso ~950 righe (da 802)
2. Precondition Taxonomy: 10 righe
3. Known LLM Confusions: 7 entry
4. 3 Hard Gates presenti come checklist

### v3 (MCP tool)
1. `mvn compile` in `/data/massimiliano/Vari/mcp/` — compila senza errori
2. Restart `simoge-mcp` container
3. Test: `research_validate_paper("Voyager", "NeurIPS 2023", 2023, null, "Wang")` → deve restituire correzione TMLR 2024
4. Test: `research_validate_paper("Self-Refine", "NeurIPS 2023", 2023, 1000, "Madaan")` → deve restituire ~2961 citazioni

### v3 (hook)
1. Test positivo: scrivere `docs/research/test.md` con pattern `(S2, 2026-03-15)` + `dblp.org` + `Algorithmic Correctness` → deve passare
2. Test negativo: scrivere `docs/research/test.md` senza pattern S2 → deve bloccare con messaggio
3. Test non-interference: scrivere `docs/other-file.md` senza pattern → deve passare (non è `docs/research/`)

### End-to-end
Lanciare `academic-researcher` su item #178 (Cross-Plan Knowledge) e verificare:
- Chiama `research_validate_paper` per ogni paper
- Report contiene `(S2, date)` per ogni citazione
- Report contiene reference DBLP
- Hook permette la scrittura

## File critici

| File | Azione | Livello |
|------|--------|---------|
| `/data/massimiliano/claude-shared/agents/academic-researcher.md` | MOD (v2 prompt) | v2 |
| `/data/massimiliano/Vari/mcp/src/.../ResearchValidationTools.java` | NEW (~200 righe) | v3 |
| `/data/massimiliano/Vari/mcp/src/.../DblpExtractor.java` | NEW (~80 righe) | v3 |
| `/data/massimiliano/claude-code-config/hooks/validate-research-report.sh` | NEW (~40 righe) | v3 |
| `/data/massimiliano/claude-code-config/settings-hooks.json` | MOD (1 entry) | v3 |
