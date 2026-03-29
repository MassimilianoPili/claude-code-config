# Piano: Riduzione Confronti in Preference Sort

## Context

Il servizio Preference Sort (`/data/massimiliano/Vari/preference-sort/`) usa Bradley-Terry + Information Gain per selezionare le coppie da confrontare. È già near-optimal per active learning, ma spreca confronti in due modi:
1. **Cold start random** — le prime N-1 coppie sono casuali, spesso poco informative
2. **Nessun pre-ranking dei candidati** — l'IG viene calcolato su tutti i candidati indiscriminatamente

Obiettivo: **ridurre i confronti totali del 30-50%** mantenendo la stessa qualità di ranking.

## Fondamenti dalla ricerca accademica (3 ricerche deep, ~60 paper)

### Risultati fondamentali

| Paper | Finding chiave | Impatto |
|-------|---------------|---------|
| **Kahle, Rottger & Schwabe, Alg. Stat. 2021** | D-optimal design per BT con N-1 confronti **= PATH graph** | Swiss pairing IS the optimal initialization — non un'euristica, un teorema |
| **Maystre & Grossglauser, ICML 2017** "Just Sort It!" | Quicksort + BT-MLE ≈ active learning ottimale, 100x meno costoso | Il sorting concentra confronti sulle coppie difficili. Swiss è la versione online |
| **Hendrickx & Olshevsky, ICML 2019/2020** | Errore minimax scala con **effective resistance** `R_ij` del grafo | La centrality giusta per pair selection è R_ij, non degree o betweenness |
| **Caron & Doucet, JCGS 2012** | Fisher Information Matrix del BT = **weighted graph Laplacian** | R_ij si calcola con UNA Cholesky del Laplaciano — riusa la stessa infra |
| **Shah & Wainwright, JMLR 2018** | Borda count (contare le vittorie) è già **minimax optimal** per top-k | Top-k mode: successive elimination con BT CIs, enorme risparmio |
| **Fageot et al., arXiv 2023** | MAP con prior Gaussiano **sempre esiste** (no connectivity requirement) | Cold-start stabile: MAP invece di MLE durante warm-up |

### La formula unificata (scoperta chiave)

L'Expected Information Gain ha un'approssimazione closed-form via matrix determinant lemma:

```
EIG(i,j) ≈ 0.5 · log(1 + p_ij · (1-p_ij) · R_ij)
```

Che per il pre-ranking si semplifica in:

```
priority(i,j) = p_ij · (1 - p_ij) · R_ij
```

dove:
- `p_ij = π_i / (π_i + π_j)` — probabilità BT (già calcolata)
- `R_ij = (e_i - e_j)^T · L^+ · (e_i - e_j)` — effective resistance nel grafo dei confronti
- `L` = Laplaciano pesato con pesi `w_ij = n_ij · p_ij · (1 - p_ij)`

**Questa formula combina già uncertainty E graph centrality in un unico numero.** Non servono 3 pesi separati — è la derivazione del primo ordine dell'IG ottimale. `p_ij·(1-p_ij)` cattura l'incertezza sull'esito (massima quando p=0.5), `R_ij` cattura quanto quel confronto riduce l'errore globale.

### Transitività: non serve calcolarla lungo i path

Under BT, **i log-odds sono additivi** (non le probabilità moltiplicative):
```
log(π_A/π_C) = log(π_A/π_B) + log(π_B/π_C)
```

P(A>C) si calcola **direttamente** dai parametri BT: `P(A>C) = π_A/(π_A+π_C)`. Il modello BT soddisfa Strong Stochastic Transitivity: la transitività è intrinseca, non va calcolata via BFS. La formula `priority = p·(1-p)·R` la sfrutta automaticamente — coppie con alta transitivity hanno p lontano da 0.5 → basso priority → postposte.

### Intransitività: Hodge decomposition (diagnostica)

Jiang, Lim, Yao & Ye (Math. Programming 2011, ~398 cit): il **curl** della Hodge decomposition misura dove la transitività fallisce. Per-triangle: `curl(i,j,k) = Y_ij + Y_jk + Y_ki`. Alto curl → confronto diretto necessario. Usa la **stessa Cholesky** del Laplaciano. Aggiungibile come segnale opzionale al priority score.

## Strategia in 4 fasi incrementali

### Fase 1: Swiss-System Cold Start

**File**: `scheduler.go` — riscrittura blocco cold start (righe 31-70)

**Algoritmo "Warm Swiss"** (Kahle 2021 + Fageot 2023):
1. Prime 3 coppie: **random** (minimo per stime BT non-degeneri, con prior MAP Gaussiano σ=1)
2. Dalla 4ª coppia: ordina per BT score MAP, accoppia item **adiacenti** in ranking
3. Fallback: se tutti gli adiacenti visti, allarga gap (i vs i+2, i+3...)
4. Mantiene connessione grafo: la catena di adiacenti è uno **spanning path** (= D-optimal per Kahle)

```go
func swissPair(items []Item, seen map[[2]int64]bool) *[2]int64 {
    sorted := sortByBTScore(items)
    for gap := 1; gap < len(sorted); gap++ {
        for i := 0; i < len(sorted)-gap; i++ {
            key := orderedKey(sorted[i].ID, sorted[i+gap].ID)
            if !seen[key] { return &[2]int64{sorted[i].ID, sorted[i+gap].ID} }
        }
    }
    return nil
}
```

**Perché 3 e non N-1**: il cold start attuale fa N-1 random (24 per N=25). Swiss riduce a 3 random + adaptive. Ogni confronto Swiss-paired dà ~1 bit (p≈0.5) vs <<1 bit per random tra item distanti.

**Stima impatto**: -5/-8 confronti per N=25, -15/-20 per N=100

### Fase 2: Fisher Priority Pre-ranking (cuore)

**File**: `graph.go` (nuovo) + `scheduler.go`

**La formula**: `priority(i,j) = p_ij · (1-p_ij) · R_ij`

**Flusso**:
```
1. Dopo ogni confronto, aggiorna BT scores (esistente)
2. Costruisci Laplaciano pesato L (pesi = n_ij · p_ij · (1-p_ij))
3. Cholesky di L_reg = L + εI → tutte le R_ij in O(N²) dopo la fattorizzazione
4. Calcola priority per ogni candidato → ordina decrescente
5. Top-K candidati per priority (es. K=10) → calcola IG solo su questi
6. Seleziona coppia con IG massimo tra i top-K
7. Convergenza: se maxIG < threshold → stop
```

**Perché non sostituisce l'IG**: il priority è un'approssimazione del primo ordine dell'EIG. L'IG completo (che simula il BT refit) resta il criterio finale — ma calcolato su **10 candidati** invece di N²/2. Il priority è O(1) per coppia (dopo la Cholesky), l'IG è O(N·BT_iter) per coppia.

**Effective resistance — implementazione Go**:
```go
// Una Cholesky dà tutte le R_ij
func computeEffectiveResistances(items []Item, comps []Comparison) map[[2]int64]float64 {
    L := buildWeightedLaplacian(items, comps)     // N×N, O(|E|)
    Lreg := addRegularization(L, 1e-6)            // L + εI
    Linv := choleskyInverse(Lreg)                  // O(N³), una volta
    R := make(map[[2]int64]float64)
    for i := range items {
        for j := i+1; j < len(items); j++ {
            R[key(i,j)] = Linv[i][i] + Linv[j][j] - 2*Linv[i][j]
        }
    }
    return R
}
```

Per N < 200, la Cholesky costa <1ms. Per N > 200, cache R e ricalcola ogni K confronti.

**Segnali opzionali** (attivabili dopo Fase 2 base):
- `+ w2 · σ_diff²` — posterior uncertainty TrueSkill-style (cattura item con pochi confronti totali)
- `+ w3 · curl_score(i,j)` — Hodge intransitività (confronto diretto necessario per cicli)
- `+ w4 · (1 - n_ij/n_max)` — exploration bonus (coppie mai confrontate)

**Default**: `w1=1, w2=w3=w4=0` (puro Fisher IG — fondamento teorico più forte, da Hendrickx).

**Stima impatto**: convergenza in **40-60% meno confronti** (IG calcolato su candidati migliori + meno candidati da valutare).

### Fase 3: Candidate Pre-filter (per N > 30)

**File**: `scheduler.go` — ottimizzazione di `generateCandidates`

Per N > 30, O(N²) candidati è costoso anche per il priority scoring. Pre-filtro Swiss-style:
- Ordina per BT score, genera solo coppie entro finestra di `log₂(N)` posizioni
- Aggiungi coppie con alta SE (top-10) indipendentemente dalla distanza
- Da O(N²) a **O(N · log N)** candidati

Le coppie lontane hanno R_ij basso E p_ij lontano da 0.5 → priority ≈ 0 comunque.

### Fase 4 (opzionale): Top-k Mode

**File**: `scheduler.go` + `models.go` + `handlers.go` + `store.go`

**Algoritmo**: successive elimination con BT confidence intervals (Heckel et al. 2018 AR algorithm):

```go
func (t *TopKMode) eliminateOrConfirm(items []Item, k int, delta float64) {
    ranked := sortByBTScore(items)
    kthLower := ranked[k-1].BTScore - ranked[k-1].BTSE * zBonferroni(len(items), delta)
    kplus1Upper := ranked[k].BTScore + ranked[k].BTSE * zBonferroni(len(items), delta)

    for _, item := range activeSet {
        upper := item.BTScore + item.BTSE * zBonferroni(len(items), delta)
        lower := item.BTScore - item.BTSE * zBonferroni(len(items), delta)
        if upper < kthLower { eliminate(item) }     // definitivamente non top-k
        if lower > kplus1Upper { confirm(item) }    // definitivamente top-k
    }
}
```

**Numeri concreti** (da Ren, Liu & Shroff, ICML 2020 — tight bounds):

| Scenario | Full ranking | Top-k (active) | Risparmio |
|----------|-------------|----------------|-----------|
| N=100, k=10 | ~12,000-15,000 | ~3,000-5,000 | **60-70%** |
| N=50, k=5 | ~3,000-5,000 | ~800-1,500 | **60-70%** |
| N=25, k=5 | ~40-50 | ~15-25 | **40-50%** |

**Transizione smooth**: tutti i confronti del top-k portano over al full ranking. BT scores sono globali — nessun lavoro perso.

**Adaptive k** (bonus): rilevare gap naturali nella distribuzione score e suggerire k all'utente.

## Modifiche per file

| File | Tipo | Descrizione |
|------|------|-------------|
| `scheduler.go` | **Principale** | Swiss cold start (F1), priority pre-ranking flow (F2), candidate pre-filter (F3), top-k active set (F4) |
| `graph.go` | **Nuovo** | `buildWeightedLaplacian()`, `computeEffectiveResistances()`, `fisherPriority()` |
| `models.go` | Minima | `PriorityScore float64` in `NextPairResponse`, `TopK *int` in `List` |
| `handlers.go` | Minima | Espone priority info in stats |
| `store.go` | Minima (F4) | Persist `top_k` field |
| `migrations/002_top_k.sql` | Solo F4 | `ALTER TABLE lists ADD COLUMN top_k INTEGER` |

**Dipendenza esterna**: `gonum/mat` per Cholesky (già usata? verificare `go.mod`). Alternativa: Cholesky manuale ~50 righe.

## Backward Compatibility

- API invariata per fasi 1-3: `GET /next`, `POST /comparisons` restano identici
- Fase 4: `top_k` opzionale (NULL = ranking completo, comportamento attuale)
- Priority pre-ranking non cambia l'output — stesse coppie proposte, ordine migliore
- L'IG resta il criterio finale e di convergenza
- `ig_threshold` invariato

## Stime riduzione confronti

| N items | Attuale (IG puro) | Fasi 1-3 (Fisher priority) | + Top-k (k=10) | Riduzione |
|---------|-------------------|---------------------------|----------------|-----------|
| 25 | ~40-50 | ~15-25 | ~10-15 | 50-70% |
| 50 | ~100-120 | ~40-60 | ~20-30 | 60-75% |
| 100 | ~200+ | ~80-120 | ~30-50 | 70-85% |

## Verifica

1. **Benchmark**: `cmd/benchmark/main.go` — genera N items con score "vero" noto, simula confronti (Fisher priority vs IG puro vs random), misura: confronti a convergenza, Kendall tau, tempo per selezione
2. **Regressione**: Kendall tau vs ranking di riferimento ≥ 0.95
3. **Stats**: `GET /stats` mostra `avg_priority`, `avg_effective_resistance`, confronti totali
4. **Top-k** (F4): items fuori dal top-k eliminati dal set attivo, transizione smooth a full ranking
5. **Deploy**: `deploy-mcp preference-sort` (scale trick, zero downtime)

## Riferimenti (verificati, con arXiv ID)

### Core (citati nel codice)
- Caron & Doucet (2012) JCGS — Bayesian BT prior, Fisher = Laplacian [già usato in bt.go]

### Cold Start (Fase 1)
- Kahle, Rottger & Schwabe (2021) Algebraic Statistics — D-optimal BT = path. arXiv:1901.02375
- Maystre & Grossglauser (2017) ICML — "Just Sort It!". arXiv:1502.05556
- Fageot et al. (2023) arXiv — MAP BT always exists. arXiv:2308.08644
- Braverman & Mossel (2008) SODA — noisy sorting O(N log N)
- Gu & Xu (2023) STOC — tight bounds noisy sorting

### Graph Priority (Fase 2)
- Hendrickx, Olshevsky & Saligrama (2019/2020) ICML — effective resistance = minimax error
- Herbrich, Minka & Graepel (2006) NeurIPS — TrueSkill, posterior variance matchmaking
- Jiang, Lim, Yao & Ye (2011) Math. Programming — HodgeRank. DOI:10.1007/s10107-010-0419-x

### Top-k (Fase 4)
- Shah & Wainwright (2018) JMLR — Borda count optimal, model-free
- Chen & Suh (2015) ICML — Spectral MLE top-k optimal. arXiv:1504.01994
- Heckel et al. (2018) AISTATS — AR algorithm, CI-based elimination. arXiv:1801.01253
- Ren, Liu & Shroff (2020) ICML — tight best-k bounds. arXiv:2007.03133
- Kalyanakrishnan et al. (2012) ICML — LUCB algorithm

### Generale
- Shah & Wainwright (2018) JMLR — Θ(N log N / δ²) bound
- Heckel et al. (2019) Annals of Statistics — parametric futility
- Negahban, Oh & Shah (2012) NeurIPS/OR — Rank Centrality
