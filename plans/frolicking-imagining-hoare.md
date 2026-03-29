# Piano: Aggiungere PIANO_OPENALEX a INDICE.md

## Context
Il PIANO_OPENALEX.md esiste dal 2026-03-11 ma non è nell'indice dei progetti futuri (30 progetti). Va aggiunto come #31.

## Valori proposti

| Campo | Valore | Motivazione |
|-------|--------|-------------|
| Categoria | AI / Graph DB | Come Kindle Graph Enrichment, estende lo stesso sistema |
| Effort | ~20h | ~18-23h codice (Step 1-5), escluso tempo unattended |
| Costo | Gratis | API key gratuita, HDD 4TB prerequisito ma non costo progetto |
| ROI | 4 | Buon rapporto: estende infra esistente, riusa paper_archive + AGE + pgvector |
| Impatto | Alto | Motore ricerca accademico personale, 100K paper, skill GraphRAG + semantic search |

## Modifiche

1. **File**: `/data/massimiliano/progetti_futuri/INDICE.md`
   - Aggiungere riga #29 nella tabella (dopo Kindle Graph Enrichment #8, posizione ROI 4)
   - Aggiornare conteggio "Progetti totali" da 30 a 31
   - Aggiornare "Effort totale" (~760-810h → ~780-830h)
   - Aggiornare "Progetti AI/Graph" da 3 a 4
   - Preferenza: `—` (non ancora classificato in Preference Sort)

## Verifica
- Controllare che la tabella markdown sia ben formattata
- Verificare che i conteggi nelle statistiche siano coerenti
