# Piano: Aggiornare Preferenza in INDICE.md da /rank

## Contesto

La lista "Progetti Futuri" nella Preference Sort API e' convergata (280 confronti, 25 item, coverage 37.7%).
La colonna **Preferenza** nell'INDICE.md e' ancora tutta "TBD". Va aggiornata con i rank calcolati.
Inoltre, la sezione "Preferenza" dice "Lista da creare" — va aggiornata perche' la lista esiste gia'.

## Ranking calcolato da /rank

| Rank | Progetto | W | L |
|------|----------|---|---|
| 1 | App Maze | 93 | 0 |
| 2 | Carte Spesa | 69 | 6 |
| 3 | CV Refresh | 4 | 6 |
| 4 | RSS to Kindle | 10 | 12 |
| 5 | Kindle Graph Enrichment | 9 | 12 |
| 6 | Sito Edoardo Volpe | 3 | 10 |
| 7 | Health Data | 47 | 10 |
| 8 | Sito CSP | 17 | 12 |
| 9 | DSS Wrapper | 16 | 13 |
| 10 | Ranking Todo | 1 | 16 |
| 11 | Input Sanitizer | 3 | 14 |
| 12 | Payload CMS | 0 | 10 |
| 13 | Fossify Gallery iOS | 0 | 13 |
| 14 | HeliBoard iOS | 0 | 13 |
| 15 | OCP4 Sandbox | 0 | 16 |
| 16 | Watchy | 1 | 11 |
| 17 | Gym App | 6 | 12 |
| 18 | Aegis iOS | 0 | 17 |
| 19 | Fantacalcio | 1 | 11 |
| 20 | Jira Cloud | 0 | 11 |
| 21 | Fossify Files iOS | 0 | 11 |
| 22 | Mail Stalwart | 0 | 11 |
| 23 | Castello Kafka Godot | 0 | 11 |
| 24 | Azure Cloud | 0 | 11 |
| 25 | Agent COBOL | 0 | 11 |

## Modifiche

### 1. Aggiornare INDICE.md (`/data/massimiliano/progetti_futuri/INDICE.md`)

- **Colonna Preferenza**: sostituire tutti i "TBD" con il rank (formato `#N/25`)
- **Sezione Preferenza** (riga ~69): aggiornare da "Lista da creare" a stato attuale (convergata, 280 confronti)
- **Data aggiornamento** (riga 3): confermare 2026-03-07

Mapping per ogni riga della tabella (ordine tabella attuale per ROI -> nuovo valore Preferenza):

| Piano (ordine ROI) | Rank /rank |
|---------------------|-----------|
| Input Sanitizer | #11/25 |
| OCP4 Sandbox | #15/25 |
| Azure Cloud | #24/25 |
| Jira Cloud | #20/25 |
| DSS Wrapper | #9/25 |
| Aegis iOS | #18/25 |
| CV Refresh | #3/25 |
| Kindle Graph Enrichment | #5/25 |
| Ranking Todo | #10/25 |
| Fossify Gallery iOS | #13/25 |
| Fossify Files iOS | #21/25 |
| RSS to Kindle | #4/25 |
| Health Data | #7/25 |
| Gym App | #17/25 |
| Mail Stalwart | #22/25 |
| Payload CMS | #12/25 |
| Sito CSP | #8/25 |
| Sito Edoardo Volpe | #6/25 |
| Watchy | #16/25 |
| Fantacalcio | #19/25 |
| Agent COBOL | #25/25 |
| HeliBoard iOS | #14/25 |
| App Maze | #1/25 |
| Carte Spesa | #2/25 |
| Castello Kafka Godot | #23/25 |

### 2. ~~Sync alla wiki~~ COMPLETATO

`docs-sync` gia' eseguito (timer automatico 12:30). Commit `f4b3ef3` nel bare repo Gitea.

### 3. Fix sync WikiJS (BLOCCATO)

WikiJS ha il git sync in **errore**: rebase bloccato su `agent-framework/piano-history.md` (both added).
Questo impedisce:
- Aggiornamento `progetti/indice` (fermo al 1 marzo, contenuto diverso)
- Importazione 5 pagine mancanti: `aegis-ios`, `agent-cobol`, `fossify-files-ios`, `fossify-gallery-ios`, `heliboard-ios`

**Stato repo interno WikiJS** (`/wiki/data/repo`):
```
interactive rebase in progress; onto 1c10e91
Unmerged paths: both added: agent-framework/piano-history.md
```

**Fix proposta**: risolvere il conflitto nel repo interno di WikiJS.

```bash
# Opzione A: accettare la versione dal remote (Gitea e' source of truth)
docker exec wikijs sh -c 'cd /wiki/data/repo && git checkout --theirs agent-framework/piano-history.md && git add agent-framework/piano-history.md && git rebase --continue'

# Opzione B: se il rebase ha piu' conflitti, abort e force reset
docker exec wikijs sh -c 'cd /wiki/data/repo && git rebase --abort && git fetch origin && git reset --hard origin/main'
```

Dopo la fix, resettare lo stato sync in WikiJS:
```bash
docker exec postgres psql -U wikijs -d wikijs -c "UPDATE storage SET state = '{\"status\":\"ok\",\"message\":\"\",\"lastAttempt\":\"\"}'::jsonb WHERE key = 'git';"
docker restart wikijs
```

### 4. Verifica post-fix

Dopo restart WikiJS, verificare:
1. Sync status OK: `SELECT state FROM storage WHERE key = 'git';`
2. Pagina indice aggiornata: `SELECT substring(content, 1, 200) FROM pages WHERE path = 'progetti/indice';`
3. 5 pagine mancanti importate: `SELECT count(*) FROM pages WHERE path LIKE 'progetti/%';` (deve essere 26)

## File coinvolti

- `/data/massimiliano/progetti_futuri/INDICE.md` — file sorgente (GIA' AGGIORNATO)
- `/data/massimiliano/docs/progetti/indice.md` — copia wiki (GIA' SINCRONIZZATA via docs-sync)
- WikiJS internal repo `/wiki/data/repo` — da fixare (rebase conflict)
