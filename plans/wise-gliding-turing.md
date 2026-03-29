# Piano: Annotazioni Didattiche per Research Domains dell'Agent Framework

## Contesto

I 6 file Research Domains in `/data/massimiliano/docs/agent-framework/` documentano 67 item di ricerca (#50-#116) distribuiti su 6 fasi (8-13) dell'agent-framework roadmap. Ogni sezione presenta fondamento accademico, formule, mapping al codebase, e piano implementativo.

**Problema**: le formule sono spesso presentate come "scatole nere" — mancano passaggi intermedi, spiegazione dei simboli, dimostrazioni dei teoremi, e pseudocodice per molte sezioni. Un laureando in matematica che incontra per la prima volta concetti da financial engineering, mechanism design, control theory o neuroscience non ha gli strumenti per seguire il ragionamento.

**Obiettivo**: aggiungere annotazioni didattiche (puramente additive, nessuna modifica al testo esistente) che rendano ogni sezione autocontenuta per un matematico puro.

## File Target

| File | Items | Pseudocodice esistenti | Righe attuali |
|------|-------|----------------------|---------------|
| `research-domains.md` | 12 (#50-#61) | 0 | ~4100 |
| `research-domains-new.md` | 25 (#62-#86) | 5 | ~2600 |
| `research-domains-ext.md` | 30 (#87-#116) | 5 | ~4500 |
| `research-domains-consolidation.md` | (cross-ref) | — | ~560 |
| `research-implementation-ideas.md` | (patterns) | — | ~820 |
| `research-references.md` | (bibliografia) | — | ~420 |

**Solo i primi 3 file vanno annotati** (67 sezioni). Gli altri 3 sono di supporto.

## Tipi di Annotazione

### Tipo A: Glossario Simboli (`> **Glossario simboli**`)

**Dove**: dopo ogni blocco formula in code fence.
**Formato**: blockquote con tabella Markdown.
**Tutte le 67 sezioni** ricevono questo.

```markdown
> **Glossario simboli**
>
> | Simbolo | Significato | Dominio |
> |---------|-------------|---------|
> | `w_i` | Peso del profilo i nel portafoglio | [0, 0.6] ⊂ R |
> | `E[R_i]` | Rendimento atteso del profilo i (media reward storici) | R |
> | `Cov(R_i, R_j)` | Covarianza tra i reward dei profili i e j | R |
> | `Sigma` | Matrice di covarianza |R^{n×n}, simmetrica semidefinita positiva |
> | `R_f` | Rendimento risk-free (soglia minima accettabile) | R, default 0.3 |
```

### Tipo B: Nota Derivazione (`> **Nota didattica: derivazione**`)

**Dove**: dopo blocchi formula con passaggi non ovvi.
**Formato**: blockquote con derivazione passo-passo in code fence interno.
**Solo sezioni Tier 1 e Tier 2** (~33 sezioni) ricevono questo.

```markdown
> **Nota didattica: derivazione**
>
> La varianza del portafoglio si ricava dalla bilinearita' della covarianza:
>
> ```
> Var(R_p) = Var(Σ w_i R_i)
>          = E[(Σ w_i R_i - E[Σ w_i R_i])²]    per definizione
>          = E[(Σ w_i (R_i - μ_i))²]            linearita' E[·]
>          = Σ_i Σ_j w_i w_j E[(R_i-μ_i)(R_j-μ_j)]  bilinearita'
>          = Σ_i Σ_j w_i w_j Cov(R_i, R_j)      definizione covarianza
>          = w^T Σ w                              forma matriciale
> ```
>
> **Perche' Sharpe e non Var?** Lo Sharpe Ratio σ_p (non σ²_p) al denominatore
> perche' geometricamente e' la pendenza della Capital Allocation Line nello
> spazio (σ, E[R]) — la retta dal risk-free rate al portafoglio. Pendenza = ΔE[R]/Δσ.
```

### Tipo C: Dimostrazione Teoremi/Lemmi (`> **Dimostrazione**`)

**Dove**: dopo ogni enunciato di teorema, lemma, o risultato fondamentale.
**Formato**: blockquote con dimostrazione strutturata (ipotesi → passaggi → □).
**Sezioni con teoremi/lemmi importanti** (~20 sezioni).

```markdown
> **Dimostrazione (Diversity Prediction Theorem, Page 2007)**
>
> *Enunciato*: (c - θ)² = avg[(x_i - θ)²] - avg[(x_i - c)²]
>
> *Dim.* Espandiamo il termine sinistro dell'identita':
>
> ```
> avg[(x_i - θ)²] = avg[(x_i - c + c - θ)²]
>                  = avg[(x_i - c)² + 2(x_i - c)(c - θ) + (c - θ)²]
>                  = avg[(x_i - c)²] + 2(c - θ)·avg[(x_i - c)] + (c - θ)²
> ```
>
> Ora, `avg[(x_i - c)] = avg[x_i] - c = c - c = 0` per definizione di media.
> Il termine incrociato si annulla:
>
> ```
> avg[(x_i - θ)²] = avg[(x_i - c)²] + (c - θ)²
> ```
>
> Riordinando: `(c - θ)² = avg[(x_i - θ)²] - avg[(x_i - c)²]`.  □
>
> **Nota**: questa e' un'identita' algebrica, non un teorema probabilistico.
> Vale per QUALSIASI insieme di numeri reali {x_i}, qualsiasi θ ∈ R.
> Non richiede indipendenza, normalita', o altre assunzioni.
```

### Tipo D: Pseudocodice Algoritmico (`### Pseudocodice`)

**Dove**: dopo `Classi e metodi coinvolti`, prima di `Sforzo stimato`.
**Formato**: identico ai 10 pseudocodice gia' esistenti.
**57 sezioni** senza pseudocodice lo ricevono.

```markdown
### Pseudocodice

```
ALGORITHM: Greeks_FiniteDifferences
Input:  GP model, worker profile P, embedding x ∈ R^1024, step fraction ε = 0.05
Output: (Delta, Gamma, Vega, Theta) ∈ R^4

1. h = ε · ||x||_2                          // step proporzionale alla norma
2. mu_0 = GP.predict(x, P)                  // predizione base
3. x_+ = x · (1 + h/||x||)                 // perturbazione +h radiale
4. x_- = x · (1 - h/||x||)                 // perturbazione -h radiale
5. mu_+ = GP.predict(x_+, P)
6. mu_- = GP.predict(x_-, P)

7. Delta = (mu_+ - mu_-) / (2h)            // derivata prima centrale O(h²)
   // Taylor: f(x+h)-f(x-h) = 2hf'(x) + O(h³) → f' ≈ diff/2h

8. Gamma = (mu_+ - 2·mu_0 + mu_-) / h²     // derivata seconda O(h²)
   // Taylor: f(x+h)+f(x-h) = 2f(x) + h²f''(x) + O(h⁴) → f'' ≈ sum/h²

9. Vega = Cov(mu, sigma²) / Var(sigma²)     // regressione su 20 predizioni
10. Theta = (avg_reward_7gg - avg_reward_14gg) / 7  // trend temporale

11. Return (Delta, Gamma, Vega, Theta)
```
```

## Copertura per Sezione

**TUTTE le 67 sezioni** ricevono tutti e 4 i tipi di annotazione (A+B+C+D):
- Glossario simboli
- Nota derivazione (passaggi intermedi per ogni formula)
- Dimostrazione (per ogni teorema/lemma/risultato enunciato)
- Pseudocodice (dove mancante — 57 sezioni su 67)

Nessun tier differenziato — il lettore decidera' cosa skippare.

## Teoremi e Lemmi da Dimostrare

Elenco dei risultati che richiedono una dimostrazione esplicita (o sketch rigoroso):

| Teorema | Sezione | Tipo dimostrazione |
|---------|---------|-------------------|
| Frontiera efficiente (Markowitz) | #50 | KKT su min w^T Σ w s.t. w^T μ = r_target, Σw_i = 1 |
| VCG truthfulness | #62 | Dominanza strategica: mostrare che v_i vero massimizza payoff |
| Regola 1/e (Secretary Problem) | #71 | DP + calcolo del limite asintotico |
| Shapley: esistenza e unicita' | #67 | Dimostrazione per induzione su |N|, verifica 4 assiomi |
| Arrow impossibility | #90 | Via ultrafiltri (sketch), o via dictator propagation |
| Condorcet Jury Theorem | #90 | Calcolo binomiale diretto |
| Diversity Prediction Theorem | #91 | Identita' algebrica (espansione quadrati) |
| PAC-Bayes bound (McAllester) | #89 | Donsker-Varadhan + Markov inequality |
| KL tra Gaussiane (forma chiusa) | #89 | Calcolo diretto dell'integrale |
| Cramer-Rao lower bound | #68 | Via disuguaglianza di Cauchy-Schwarz |
| Kelly: ottimalita' per crescita | #69 | Massimizzazione E[ln(1+f·r)] |
| Hedge regret bound | #65 | Potential argument classico |
| Petri net soundness ↔ liveness+boundedness | #87 | Sketch via short-circuit construction |
| RIP → exact recovery (Candes-Tao) | #94 | Sketch via restricted isometry + L1 minimization |
| Peters: non-ergodicita' delle dinamiche moltiplicative | #95 | Jensen's inequality su ln (concavo) |
| Free Energy ≥ Surprisal | #77 | KL ≥ 0 (Gibbs' inequality) |

Per le dimostrazioni piu' lunghe (Arrow, VCG, PAC-Bayes), si fornisce uno sketch rigoroso con i passaggi chiave, rimandando al paper originale per i dettagli tecnici completi. Per le dimostrazioni brevi (Diversity Prediction, Cramer-Rao, Kelly, Jensen), si da la dimostrazione completa.

**Strumento**: l'agent `academic-researcher` sara' usato per verificare la correttezza delle dimostrazioni e trovare le formulazioni originali nei paper.

## Strategia di Esecuzione

### Ordine di processamento

1. **`research-domains.md`** (12 sezioni, Tier 1: 2, Tier 2: 4, Tier 3: 6)
   - Tutte le 12 sezioni mancano di pseudocodice → massimo impatto iniziale
   - Start: §1 Portfolio Theory → §12 Persistent Homology

2. **`research-domains-new.md`** (25 sezioni, Tier 1: 5, Tier 2: 8, Tier 3: 12)
   - Concentrazione massima di Tier 1 (mechanism design, control theory, behavioral)
   - 20 sezioni mancano di pseudocodice, 5 gia' presenti

3. **`research-domains-ext.md`** (30 sezioni, Tier 1: 3, Tier 2: 5, Tier 3: 22)
   - File piu' grande ma molte sezioni Tier 3 → annotazioni piu' leggere
   - 25 sezioni mancano di pseudocodice, 5 gia' presenti

4. **`research-domains-consolidation.md`** — aggiornamento statistiche finali

### Metodo per sezione

Per ogni sezione:
1. Leggere il blocco formule esistente
2. Aggiungere `> **Glossario simboli**` subito dopo il blocco formule
3. Se Tier 1/2: aggiungere `> **Nota didattica: derivazione**` dopo il glossario
4. Se presente un teorema: aggiungere `> **Dimostrazione**`
5. Se manca pseudocodice: aggiungere `### Pseudocodice` dopo `Classi e metodi`
6. Usare `academic-researcher` per verificare dimostrazioni non banali

### Convenzioni

- **Lingua**: italiano (come i documenti esistenti)
- **Formato**: blockquote (`>`) per TUTTE le annotazioni (visivamente distinte, facilmente rimovibili)
- **Nessuna modifica** al testo esistente — solo aggiunte
- **Cross-reference preservati**: le annotazioni vanno inserite *tra* sezioni, non dentro
- **Notazione**: stessa notazione ASCII gia' usata nei documenti (no LaTeX)

## Stima di Lavoro

| Tipo | Sezioni | Righe/sezione | Totale righe |
|------|---------|---------------|-------------|
| Glossario simboli (A) | 67 | ~20 | ~1340 |
| Derivazioni (B) | 67 | ~15 | ~1005 |
| Dimostrazioni (C) | 67 | ~20 | ~1340 |
| Pseudocodice (D) | 57 | ~25 | ~1425 |
| **Totale** | | | **~5110 righe** |

Incremento ~45% sulle ~11.200 righe attuali. Copertura completa su tutte le sezioni.

## Verifica

1. **Correttezza matematica**: ogni dimostrazione verificata contro il paper originale (via `academic-researcher`)
2. **Completezza**: ogni sezione ha almeno glossario + pseudocodice
3. **Rendering**: test in WikiJS che i blockquote innestati con code fence rendano correttamente
4. **Cross-reference**: nessun link `Vedi anche` rotto dalle inserzioni
5. **YAML frontmatter**: aggiornare `date` nei 3 file modificati
