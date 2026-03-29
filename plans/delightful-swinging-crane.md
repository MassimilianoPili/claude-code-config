# Piano: Chat ID Tracker — Sequence PostgreSQL per conversazioni Claude Code

## Context

Le conversazioni Claude Code sono identificate da UUID opachi (`sessionId`). Recuperare una chat specifica è scomodo. Un ID numerico sequenziale (`chat #847`) rende il recupero immediato e intuitivo.

## Dove salviamo — Database e Sequence

**Database**: `embeddings` (PostgreSQL 18, container `postgres`, rete `shared`)
— già usato per indicizzare le conversazioni via pgvector. Sede naturale.

**Sequence**: `chat_id_seq` nel schema `public` — genera ID monotoni via `nextval('chat_id_seq')`.
Ogni chiamata a `nextval()` è atomica e unica, anche con accessi concorrenti.

**Tabella**: `chat_sessions` nel schema `public`

```sql
CREATE SEQUENCE IF NOT EXISTS chat_id_seq START 1;

CREATE TABLE IF NOT EXISTS chat_sessions (
    chat_id     BIGINT PRIMARY KEY DEFAULT nextval('chat_id_seq'),
    session_id  UUID NOT NULL UNIQUE,
    project     TEXT NOT NULL DEFAULT '/data/massimiliano',
    title       TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ
);

CREATE INDEX idx_chat_sessions_created ON chat_sessions(created_at DESC);
CREATE INDEX idx_chat_sessions_title ON chat_sessions USING gin(to_tsvector('italian', coalesce(title, '')));
```

| Colonna | Tipo | Note |
|---------|------|------|
| `chat_id` | BIGINT | ID sequenziale da `chat_id_seq` — il numero umano |
| `session_id` | UUID UNIQUE | UUID sessione Claude Code (per `--resume`) |
| `project` | TEXT | Working directory (`CLAUDE_PROJECT_DIR`) |
| `title` | TEXT nullable | Primo messaggio utente, popolato allo Stop |
| `created_at` | TIMESTAMPTZ | Timestamp avvio |
| `updated_at` | TIMESTAMPTZ | Timestamp aggiornamento titolo |

## Flusso

```
Nuova chat → SessionStart:startup → chat-tracker.sh startup
           → INSERT ON CONFLICT DO NOTHING + SELECT chat_id
           → stdout: "=== Chat #N ==="

Resume    → SessionStart:resume  → chat-tracker.sh resume
           → SELECT chat_id, title
           → stdout: "=== Chat #N (resumed) — titolo ==="

Fine chat → Stop → chat-tracker.sh stop (async)
           → grep sessionId in history.jsonl
           → UPDATE title WHERE session_id = ...
```

## File da creare/modificare

### 1. ✅ DDL — COMPLETATO
Schema creato: sequence `chat_id_seq` + tabella `chat_sessions` + indici su `embeddings`.

### 2. CREARE: `/data/massimiliano/.claude/hooks/chat-tracker.sh`

Script bash unico, argomento `startup|resume|stop`:
- **startup**: INSERT idempotente (`ON CONFLICT DO NOTHING`) + SELECT → stdout `=== Chat #N ===`
- **resume**: SELECT chat_id, title → stdout `=== Chat #N (resumed) — titolo ===`
- **stop** (async): grep `history.jsonl` per sessionId, UPDATE title
- Postgres down → exit 0 silenzioso

### 3. MODIFICARE: `/home/massimiliano/.claude/settings.json`

Tre registrazioni hook:
- `SessionStart` matcher `startup`: aggiungere `chat-tracker.sh startup` dopo `session-context-loader.sh`
- `SessionStart` matcher `resume`: nuovo blocco con `chat-tracker.sh resume`
- `Stop`: aggiungere `chat-tracker.sh stop` con `async: true`

### 4. CREARE: `/data/massimiliano/shell-scripts/bin/chat`

CLI per recupero conversazioni:
- `chat list [N]` — ultime N chat, tabella ID/data/titolo
- `chat find <query>` — ricerca full-text (tsvector italiano) + ILIKE
- `chat show <id>` — dettagli completi
- `chat last` — ID ultima chat
- `chat resume <id>` — stampa `claude --resume <session_uuid>`

## Modifica: readme-update-reminder.sh → include KORE

### Context
L'hook Stop `readme-update-reminder.sh` blocca se ci sono file infra modificati ma la documentazione non è aggiornata. Attualmente controlla solo README.md, CLAUDE.md, MEMORY.md. L'utente vuole che il messaggio dica "aggiorna KORE" al posto di "aggiorna documentazione", dato che KORE (AGE knowledge graph) è la fonte primaria.

### File: `/data/massimiliano/.claude/hooks/readme-update-reminder.sh`

Due modifiche:
1. **Aggiungere check KORE**: verificare se `graph_write` è stato chiamato nella sessione (proxy: controllare se `chat-tracker.sh` o audit log contiene `graph_write` — ma più semplice: non c'è modo affidabile di sapere se KORE è stato aggiornato da un hook bash). Approccio pragmatico: **cambiare solo il messaggio** per includere KORE nel reminder.
2. **Messaggio aggiornato**: da "documentazione (README.md, CLAUDE.md, MEMORY.md)" a "documentazione e KORE (MEMORY.md, CLAUDE.md, knowledge graph AGE)"

Riga 83-85 attuale:
```bash
jq -n --arg reason "Hai modificato $NUM_INFRA file infrastrutturali ($FILE_LIST) ma la documentazione (README.md, CLAUDE.md, MEMORY.md) non e' stata aggiornata. Considera di aggiornare la documentazione di riferimento prima di terminare." '{
```

Diventa:
```bash
jq -n --arg reason "Hai modificato $NUM_INFRA file infrastrutturali ($FILE_LIST) ma documentazione e KORE non sono stati aggiornati. Considera di aggiornare MEMORY.md, CLAUDE.md e/o il knowledge graph AGE (graph_write) prima di terminare." '{
```

## Verifica

1. Avviare nuova sessione → deve stampare `=== Chat #1 ===`
2. Uscire → `chat list` mostra ID 1 con titolo
3. `chat resume 1` stampa il comando corretto
4. Con postgres down → sessione parte normalmente
5. Stop con file infra modificati senza doc → messaggio menziona KORE
