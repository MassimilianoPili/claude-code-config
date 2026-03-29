# Piano: Revisione Formato Tutti i PIANO_*.md

## Context

L'utente ha chiesto di controllare sequenzialmente tutti i piani in `/data/massimiliano/progetti_futuri/` e integrarli dove necessario. Il formato standard (basato su PIANO_DSS_WRAPPER.md come template di riferimento) prevede:

1. `# Piano: [Titolo]`
2. `Ultimo aggiornamento: YYYY-MM-DD`
3. `## Obiettivo`
4. `## Prerequisiti` (checklist con `- [ ]`)
5. `## Fase N — [Titolo] (~Nh)` (fasi con tempo stimato)
6. `## File coinvolti` (tabella: File/Directory | Azione | Descrizione)
7. `## Verifica` (checklist con `- [ ]`)
8. `## Tempo stimato` (tabella o inline con totale)
9. `## Note` (considerazioni finali)

Dopo la revisione di PIANO_AGENT_COBOL.md (creato) e PIANO_APP_MAZE.md (integrato), restano 19 piani da controllare.

---

## Risultato Audit: 12 completi, 9 da integrare

### Piani COMPLETI (nessun intervento necessario)

| Piano | Righe | Stato |
|-------|-------|-------|
| PIANO_CV_REFRESH.md | 240 | Tutti gli elementi standard |
| PIANO_DSS_WRAPPER.md | 352 | Template di riferimento |
| PIANO_FANTACALCIO.md | 366 | Tutti gli elementi standard |
| PIANO_GYM_APP.md | 310 | Tutti gli elementi standard |
| PIANO_HEALTH_DATA.md | 262 | Tutti gli elementi standard |
| PIANO_INPUT_SANITIZER.md | 290 | Tutti gli elementi standard |
| PIANO_RANKING_TODO.md | 295 | Tutti gli elementi standard |
| PIANO_SITO_CSP.md | 254 | Tutti gli elementi standard |
| PIANO_SITO_EDOARDO_VOLPE.md | 179 | Tutti gli elementi standard |
| PIANO_WATCHY.md | 429 | Tutti gli elementi standard |
| PIANO_APP_MAZE.md | ~530 | Gia' integrato in sessione precedente |
| PIANO_AGENT_COBOL.md | ~940 | Gia' creato in sessione precedente |

### Piani INCOMPLETI — dettaglio interventi

---

### 1. PIANO_AZURE_CLOUD.md (131 righe)

**Mancano**: Ultimo aggiornamento, Prerequisiti formali, File coinvolti, Verifica, Note

**Aggiungere**:

- `Ultimo aggiornamento: 2026-03-07`
- `## Prerequisiti` — checklist: account Microsoft, Azure CLI, $200 crediti
- `## File coinvolti` — tabella:
  - `/data/massimiliano/Vari/mcp/.env` | Edit | Variabili Azure DevOps
  - `/data/massimiliano/Vari/mcp-devops-tools/` | Riferimento | Libreria da testare
  - `/data/massimiliano/Vari/mcp-azure-tools/` | Riferimento | Libreria da testare
- `## Verifica` — checklist: PAT funzionante, tool MCP testati (5 tool), SP creato, risorse Azure visibili
- Riformattare "Tempo totale stimato: ~4h" in tabella standard
- `## Note` — considerazioni su scadenza crediti 30gg, free tier permanente DevOps, piano rinnovamento Sandbox

---

### 2. PIANO_JIRA_CLOUD.md (108 righe)

**Mancano**: Ultimo aggiornamento, Prerequisiti, File coinvolti, Verifica, Note

**Aggiungere**:

- `Ultimo aggiornamento: 2026-03-07`
- `## Prerequisiti` — checklist: account Atlassian, email, browser
- `## File coinvolti` — tabella:
  - `/data/massimiliano/Vari/mcp/.env` | Edit | Variabili Jira
  - `/data/massimiliano/Vari/mcp-jira-tools/` | Riferimento | Libreria da testare
- `## Verifica` — checklist: account creato, progetto popolato, API token funzionante, 5 tool MCP testati, confronto con Azure DevOps documentato
- Riformattare "Tempo totale stimato: ~1h" in tabella
- `## Note` — considerazioni su Jira free vs Azure DevOps free, possibilita' di usare entrambi

---

### 3. PIANO_OCP4_SANDBOX.md (151 righe)

**Mancano**: Ultimo aggiornamento, File coinvolti, Verifica, Note

**Aggiungere**:

- `Ultimo aggiornamento: 2026-03-07`
- Correggere Dockerfile: Java 17 → Java 21 (coerenza con il resto del server)
- `## File coinvolti` — tabella:
  - `/data/massimiliano/Vari/mcp/pom.xml` | Edit | Aggiunta webflux + actuator
  - `/data/massimiliano/Vari/mcp/Dockerfile` | Nuovo | Multi-stage build
  - `/data/massimiliano/Vari/mcp/k8s/` | Nuovo | Manifesti Kubernetes
  - `/data/massimiliano/Vari/mcp/docker-compose.yml` | Edit | Test locale
- `## Verifica` — checklist: build Docker locale OK, deploy OCP OK, route HTTPS accessibile, health UP, 3 tool OCP autoreferenziali funzionanti
- Riformattare "Tempo totale stimato: ~4.5h" in tabella
- `## Note` — scadenza Sandbox 30gg, rinnovamento, risorse limitate (14GB RAM condiviso)

---

### 4. PIANO_MAIL_STALWART.md (184 righe)

**Mancano**: Titolo specifico, Ultimo aggiornamento, Prerequisiti formale, Tempo stimato, sezioni rinominate

**Aggiungere/Modificare**:

- Rinominare titolo: `# Progetti Futuri — Server SOL` → `# Piano: Mail Server Self-Hosted (Stalwart)`
- Rinominare sottotitolo: `## 1. Mail Server Self-Hosted (Stalwart)` → rimuovere (il titolo lo copre)
- `Ultimo aggiornamento: 2026-03-07`
- `## Prerequisiti` — checklist: account Brevo, App Password Gmail 2FA, Cloudflare Email Routing abilitato
- Rinominare `### Componenti da creare/modificare` → `## File coinvolti` (con colonne standard)
- Rinominare `### Verifica post-implementazione` → `## Verifica` (convertire in checklist `- [ ]`)
- Aggiungere `## Tempo stimato` — tabella (~6-8h stimato: DNS+Brevo 2h, Docker 1h, nginx 30min, Keycloak+Gitea 30min, test 1h, fetchmail 1h)
- Rinominare/ristrutturare `### Rischi` + `### Upgrade futuro` → `## Note` (con contenuto rischi e upgrade)

---

### 5. PIANO_CASTELLO_KAFKA_GODOT.md (396 righe)

**Mancano**: Ultimo aggiornamento, Prerequisiti, File coinvolti, Verifica

**Aggiungere**:

- `Ultimo aggiornamento: 2026-03-07`
- `## Prerequisiti` — checklist: Godot 4.3+, Dialogic 2 plugin, Aseprite o Krita (sprite), GIMP/Photoshop (fondali), lettura del romanzo
- `## File coinvolti` — tabella (basata sulla struttura progetto gia' nel piano):
  - `il-castello/project.godot` | Nuovo | Progetto Godot
  - `il-castello/scripts/autoload/` | Nuovo | 5 autoload script
  - `il-castello/scenes/rooms/` | Nuovo | Scene location (25-30 fondali)
  - `il-castello/dialogic/` | Nuovo | Timeline Dialogic
  - etc. (~10 entries dalla struttura gia' descritta)
- `## Verifica` — checklist: prototipo 2 stanze, click-to-move + hotspot, inventario funzionante, 1 dialogo ramificato, salvataggio/caricamento, vertical slice 15-20 min
- Rinominare `## Note e Rischi` → `## Note`
- Riformattare "Tempo stimato: ~6-12 mesi" in tabella con fasi:
  - Fase 0 Prototipo: ~2 settimane
  - Fase 1 Vertical Slice: ~1 mese
  - Fase 2 Atto I: ~2 mesi
  - Fase 3 Atti II-IV: ~4-6 mesi
  - Fase 4 Polish: ~1 mese

---

### 6. PIANO_PAYLOAD_CMS.md (261 righe)

**Mancano**: Ultimo aggiornamento, Prerequisiti, Tempo stimato

**Aggiungere/Modificare**:

- `Ultimo aggiornamento: 2026-03-07`
- `## Prerequisiti` — checklist: Node.js 20+, PostgreSQL operativo, npm, spazio disco per build (~2GB), OAuth2 Proxy configurato
- Convertire `## Verifica` da lista numerata a checklist `- [ ]`
- `## Tempo stimato` — tabella (~4-5h: init progetto 30min, config 30min, Dockerfile 30min, compose 15min, DB 15min, nginx 30min, build+test 1h, primo accesso 30min)
- Rinominare `## Note e rischi` → `## Note`

---

### 7. PIANO_RSS_TO_KINDLE.md (300 righe)

**Mancano**: Ultimo aggiornamento, File coinvolti, Verifica, Note

**Aggiungere**:

- `Ultimo aggiornamento: 2026-03-07`
- `## File coinvolti` — tabella:
  - `/data/massimiliano/kindle/rss/feeds.recipe` | Nuovo | Definizione feed RSS
  - `/data/massimiliano/kindle/rss/send-daily.sh` | Nuovo | Script wrapper bash
  - `/data/massimiliano/kindle/rss/.env` | Nuovo | Credenziali SMTP + KINDLE_EMAIL
  - Crontab utente | Edit | Aggiunta job 6:00
- `## Verifica` — checklist: calibre installato, recipe valido (ebook-convert test), EPUB generato, email inviata, EPUB ricevuto su Kindle, cron job attivo, cleanup 7 giorni funzionante
- `## Note` — considerazioni: dipendenza da Stalwart (vedi PIANO_MAIL_STALWART) vs Gmail App Password per SMTP, formato EPUB vs MOBI (deprecato), limiti Amazon (50MB per email), ciclo completo RSS→Kindle→Neo4j

---

### 8. PIANO_KINDLE_GRAPH_ENRICHMENT.md (292 righe)

**Mancano**: Ultimo aggiornamento, File coinvolti, Note

**Aggiungere**:

- `Ultimo aggiornamento: 2026-03-07`
- `## File coinvolti` — tabella:
  - `/data/massimiliano/kindle/enrich_kindle.py` | Nuovo | Script extraction + linking
  - `/data/massimiliano/kindle/requirements.txt` | Nuovo | anthropic SDK (se opzione A/C)
  - Neo4j constraint | Edit | `CREATE CONSTRAINT concept_name`
- `## Note` — considerazioni: costo API (~$0.25 Haiku per 50 libri), idempotenza (MERGE), qualita' extraction dipende dal prompt, hybrid approach raccomandato

---

### 9. PIANO_CARTE_SPESA.md (1244 righe)

**Mancano**: File coinvolti, Verifica, Tempo stimato

**Aggiungere** (il piano e' gia' molto dettagliato, serve solo standardizzazione):

- `## File coinvolti` — tabella (basata sulla struttura gia' descritta nel piano, ~15 entry):
  - Repo Gitea `carte-spesa` | Nuovo | Progetto CMP
  - `composeApp/src/commonMain/` | Nuovo | Codice condiviso
  - `composeApp/src/androidMain/` | Nuovo | Platform-specific Android
  - `composeApp/src/iosMain/` | Nuovo | Platform-specific iOS
  - etc.
- `## Verifica` — checklist: scan barcode EAN-13, render barcode full-screen alla cassa, import CSV Catima, luminosita' max automatica, wakelock attivo, Room DB persistenza, APK < 25MB, iOS build funzionante
- `## Tempo stimato` — tabella basata sulle milestone gia' definite nel piano (M1-M10):
  - M1 Setup: ~2h
  - M2 Scan: ~4h
  - M3 DB+List: ~4h
  - M4 Render: ~4h
  - M5 UX cassa: ~3h
  - M6 Search: ~2h
  - M7 CRUD: ~3h
  - M8 Import/Export: ~4h
  - M9 iOS: ~6h
  - M10 Polish: ~4h
  - Totale: ~36h

---

## Ordine di esecuzione

I 9 piani incompleti, ordinati per effort crescente (per completarli tutti in sequenza):

1. **PIANO_JIRA_CLOUD.md** (~5 min) — aggiungere 5 sezioni brevi
2. **PIANO_AZURE_CLOUD.md** (~5 min) — aggiungere 5 sezioni brevi
3. **PIANO_OCP4_SANDBOX.md** (~10 min) — aggiungere 4 sezioni + fix Java 17→21
4. **PIANO_PAYLOAD_CMS.md** (~10 min) — aggiungere 3 sezioni + rinominare 1
5. **PIANO_RSS_TO_KINDLE.md** (~10 min) — aggiungere 4 sezioni
6. **PIANO_KINDLE_GRAPH_ENRICHMENT.md** (~5 min) — aggiungere 3 sezioni
7. **PIANO_MAIL_STALWART.md** (~15 min) — ristrutturazione titolo + 5 sezioni
8. **PIANO_CASTELLO_KAFKA_GODOT.md** (~15 min) — aggiungere 4 sezioni sostanziose
9. **PIANO_CARTE_SPESA.md** (~15 min) — aggiungere 3 sezioni a piano molto lungo

## Verifica finale

- [ ] Tutti i 21 piani hanno: Ultimo aggiornamento, Prerequisiti, File coinvolti, Verifica, Tempo stimato, Note
- [ ] Nessun titolo generico (tutti iniziano con `# Piano: [Nome Specifico]`)
- [ ] Tempo stimato in formato tabella o inline con totale chiaro
- [ ] Verifica in formato checklist `- [ ]`
- [ ] Aggiornare MEMORY.md con il conteggio finale dei piani
