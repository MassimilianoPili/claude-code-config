#!/bin/bash
# Hook: session-events-writer.sh
# Evento: Stop (async: true)
# Batch-insert degli eventi della sessione corrente da audit.jsonl a PostgreSQL session_events
# Ispirato a: agent-framework PlanEventStore (append-only, hash-chained, queryable)
# Complementa unified-audit-log.sh: JSONL per velocita', PostgreSQL per persistenza e query

INPUT=$(cat)

# Anti-loop guard
STOP_HOOK_ACTIVE=$(jq -r '.stop_hook_active // false' <<< "$INPUT")
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")
[ -z "$SESSION_ID" ] && exit 0

AUDIT_FILE="$HOME/.claude/audit/audit.jsonl"
[ ! -f "$AUDIT_FILE" ] && exit 0

# Filtra solo i record di questa sessione (non gia' importati)
# Usa un marker Redis per evitare duplicati
REDIS="docker exec redis redis-cli -n 5"
MARKER_KEY="claude:events:lastseq:${SESSION_ID}"
LAST_SEQ=$($REDIS GET "$MARKER_KEY" 2>/dev/null)
[[ "$LAST_SEQ" =~ ^[0-9]+$ ]] || LAST_SEQ=0

# Estrai record della sessione corrente
SESSION_RECORDS=$(grep "\"session\":\"${SESSION_ID}\"" "$AUDIT_FILE" 2>/dev/null)
[ -z "$SESSION_RECORDS" ] && exit 0

TOTAL=$(echo "$SESSION_RECORDS" | wc -l)
# Skip se gia' tutto importato
[ "$TOTAL" -le "$LAST_SEQ" ] && exit 0

# Prepara batch SQL (skip prime LAST_SEQ righe gia' importate)
SQL_BATCH=""
SEQ=0
IMPORTED=0

while IFS= read -r line; do
  SEQ=$((SEQ + 1))
  [ "$SEQ" -le "$LAST_SEQ" ] && continue
  [ -z "$line" ] && continue

  # Estrai campi
  TS=$(echo "$line" | jq -r '.ts // ""' 2>/dev/null)
  TOOL=$(echo "$line" | jq -r '.tool // ""' 2>/dev/null)
  INPUT_SUM=$(echo "$line" | jq -r '.input_summary // ""' 2>/dev/null)
  EXIT_CODE=$(echo "$line" | jq -r '.exit_code // 0' 2>/dev/null)
  HASH=$(echo "$line" | jq -r '.hash // ""' 2>/dev/null)
  PREV_HASH=$(echo "$line" | jq -r '.prev_hash // ""' 2>/dev/null)

  [ -z "$TOOL" ] && continue

  # Escape per SQL
  SESSION_ESC="${SESSION_ID//\'/\'\'}"
  TOOL_ESC="${TOOL//\'/\'\'}"
  INPUT_ESC="${INPUT_SUM:0:500}"
  INPUT_ESC="${INPUT_ESC//\'/\'\'}"
  [[ "$EXIT_CODE" =~ ^[0-9]+$ ]] || EXIT_CODE=0

  SQL_BATCH="${SQL_BATCH}INSERT INTO session_events (session_id, event_type, tool_name, input_summary, exit_code, occurred_at, event_hash, previous_hash) VALUES ('${SESSION_ESC}', 'TOOL_CALL', '${TOOL_ESC}', '${INPUT_ESC}', ${EXIT_CODE}, '${TS}'::timestamptz, '${HASH}', '${PREV_HASH}');\n"
  IMPORTED=$((IMPORTED + 1))

  # Batch ogni 50 record per evitare comandi troppo lunghi
  if [ "$IMPORTED" -ge 50 ]; then
    echo -e "$SQL_BATCH" | docker exec -i postgres psql -U postgres -d embeddings >/dev/null 2>&1
    SQL_BATCH=""
    IMPORTED=0
  fi
done <<< "$SESSION_RECORDS"

# Scrivi ultimo batch
if [ -n "$SQL_BATCH" ]; then
  echo -e "$SQL_BATCH" | docker exec -i postgres psql -U postgres -d embeddings >/dev/null 2>&1
fi

# Aggiorna marker
$REDIS SET "$MARKER_KEY" "$SEQ" EX 86400 >/dev/null 2>&1

exit 0