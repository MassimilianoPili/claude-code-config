#!/bin/bash
# Hook: chat-tracker.sh
# Assegna ID sequenziale da PostgreSQL ad ogni nuova chat Claude Code
# Uso: chat-tracker.sh startup|resume|stop
# - startup: INSERT + nextval(chat_id_seq) → stdout "=== Chat #N ==="
# - resume:  SELECT chat_id, title → stdout "=== Chat #N (resumed) ==="
# - stop:    UPDATE title da history.jsonl (async, fire-and-forget)

MODE="${1:-startup}"
INPUT=$(cat 2>/dev/null || true)

# Estrai session_id dal JSON stdin
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
if [ -z "$SESSION_ID" ]; then
    exit 0
fi

PSQL="docker exec postgres psql -U postgres -d embeddings -tAq"
PROJECT=$(echo "$INPUT" | jq -r '.cwd // "/data/massimiliano"' 2>/dev/null)

case "$MODE" in
  startup)
    # INSERT idempotente + SELECT — ON CONFLICT per sessioni già registrate
    CHAT_ID=$($PSQL -c "
      INSERT INTO chat_sessions (session_id, project)
      VALUES ('${SESSION_ID}', '${PROJECT}')
      ON CONFLICT (session_id) DO NOTHING;
      SELECT chat_id FROM chat_sessions WHERE session_id = '${SESSION_ID}';
    " 2>/dev/null)

    if [ -n "$CHAT_ID" ]; then
      echo ""
      echo "=== Chat #${CHAT_ID} ==="
      echo ""
    fi
    ;;

  resume)
    # Recupera ID e titolo esistenti
    ROW=$($PSQL -c "
      SELECT chat_id || '|' || coalesce(title, '')
      FROM chat_sessions WHERE session_id = '${SESSION_ID}';
    " 2>/dev/null)

    if [ -n "$ROW" ]; then
      CHAT_ID="${ROW%%|*}"
      TITLE="${ROW#*|}"
      if [ -n "$TITLE" ]; then
        # Tronca titolo a 80 char per display
        DISPLAY_TITLE="${TITLE:0:80}"
        echo ""
        echo "=== Chat #${CHAT_ID} (resumed) — ${DISPLAY_TITLE} ==="
        echo ""
      else
        echo ""
        echo "=== Chat #${CHAT_ID} (resumed) ==="
        echo ""
      fi
    fi
    ;;

  stop)
    # Aggiorna titolo + plan_file alla chiusura sessione

    # 1. Titolo dal primo messaggio utente in history.jsonl
    TITLE=""
    HISTORY="/data/massimiliano/claude-shared/history.jsonl"
    if [ -f "$HISTORY" ]; then
      TITLE=$(grep "\"${SESSION_ID}\"" "$HISTORY" | head -1 | jq -r '.display // empty' 2>/dev/null)
      TITLE="${TITLE:0:200}"
      TITLE="${TITLE//\'/\'\'}"
    fi

    # 2. Plan file dal JSONL della sessione
    PLAN_FILE=""
    JSONL="/data/massimiliano/claude-shared/projects/-data-massimiliano/${SESSION_ID}.jsonl"
    if [ -f "$JSONL" ]; then
      PLAN_FILE=$(grep -oh 'plans/[a-z][a-z0-9\-]*\.md' "$JSONL" | head -1)
    fi

    # 3. UPDATE condizionale (solo campi non ancora valorizzati)
    SET_CLAUSES="updated_at = now()"
    [ -n "$TITLE" ] && SET_CLAUSES="$SET_CLAUSES, title = COALESCE(title, '${TITLE}')"
    [ -n "$PLAN_FILE" ] && SET_CLAUSES="$SET_CLAUSES, plan_file = COALESCE(plan_file, '${PLAN_FILE}')"

    $PSQL -c "
      UPDATE chat_sessions SET $SET_CLAUSES
      WHERE session_id = '${SESSION_ID}';
    " >/dev/null 2>&1
    ;;
esac

exit 0
