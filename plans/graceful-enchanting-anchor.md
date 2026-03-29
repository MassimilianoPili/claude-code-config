# Hook: plan-history-separator

## Context

I file PIANO*.md tendono a crescere nel tempo accumulando contenuto storico (fasi completate, decisioni passate) insieme al piano attivo. Esempio: `agent-framework/PIANO.md` ha 1877 righe.
La best practice è separare storico da piano attivo: PIANO.md snello e focalizzato, PIANO_HISTORY.md come audit trail.

## Hook Design

**File**: `/data/massimiliano/.claude/hooks/plan-history-separator.sh`
**Evento**: PostToolUse (matcher: `Edit|Write`)
**Tipo**: non-bloccante (warning via `additionalContext`)

### Logica

1. Estrae `file_path` dal JSON input
2. Verifica che il file matchi `PIANO*.md` (case-insensitive)
3. Salta file che contengono già `HISTORY` nel nome
4. Conta i marker di contenuto storico:
   - `✅` (item completati)
   - `~~...~~` (strikethrough)
   - Pattern: `completato`, `fatto`, `done`, `DONE`, `archiviato`
5. Conta le righe totali del file
6. **Soglie warning**:
   - File > 200 righe **E** marker completati > 5
   - Oppure marker completati > 15 (indipendentemente dalla dimensione)
7. Se supera soglia → output `additionalContext` che suggerisce la separazione in `*_HISTORY.md`

### Output di warning (esempio)

```
PIANO.md contiene N item completati su M righe.
Considera spostare il contenuto storico in PIANO_HISTORY.md
per mantenere il piano attivo snello e leggibile.
```

## Modifiche

### 1. Creare `/data/massimiliano/.claude/hooks/plan-history-separator.sh`

Script bash seguendo le convenzioni esistenti:
- Shebang + header comment (italiano)
- `INPUT=$(cat)` + `jq` per parsing
- Exit 0 sempre (non-bloccante)
- `additionalContext` per il warning

### 2. Registrare in `~/.claude/settings.json`

Aggiungere alla sezione `PostToolUse` → matcher `Edit|Write` → array `hooks`:

```json
{
  "type": "command",
  "command": "/data/massimiliano/.claude/hooks/plan-history-separator.sh"
}
```

### 3. Aggiornare MEMORY.md

Aggiungere alla sezione "Claude Code Hooks" il riferimento al nuovo hook.

## Verifica

1. Editare un PIANO*.md con contenuto completato → deve apparire il warning
2. Editare un file non-PIANO → nessun output
3. Editare un PIANO_HISTORY.md → nessun output
