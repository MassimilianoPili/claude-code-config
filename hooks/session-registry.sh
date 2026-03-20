#!/bin/bash
# Hook: session-registry.sh — registra/deregistra sessione in Redis HASH claude:registry (DB 5)
# Dipende da chat-tracker.sh (deve girare DOPO per avere il chat_id in PostgreSQL)
# Uso: session-registry.sh startup|resume|stop
#
# startup/resume: HSET claude:registry chat-<id> <json>
# stop: HDEL claude:registry chat-<id>

MODE="${1:-startup}"
INPUT=$(cat 2>/dev/null || true)

SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

PSQL="docker exec postgres psql -U postgres -d embeddings -tAq"
REDIS="docker exec redis redis-cli -n 5"

case "$MODE" in
  startup|resume)
    CHAT_ID=$($PSQL -c "SELECT chat_id FROM chat_sessions WHERE session_id = '${SESSION_ID}';" 2>/dev/null)
    [ -z "$CHAT_ID" ] && exit 0

    PROJECT=$(echo "$INPUT" | jq -r '.cwd // "/data/massimiliano"' 2>/dev/null)
    LABEL="chat-${CHAT_ID}"
    NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    REG_JSON=$(jq -nc \
      --argjson cid "$CHAT_ID" \
      --arg sid "$SESSION_ID" \
      --arg proj "$PROJECT" \
      --arg now "$NOW" \
      '{chatId:$cid, sessionId:$sid, project:$proj, role:"main", startedAt:$now}')

    $REDIS HSET claude:registry "$LABEL" "$REG_JSON" >/dev/null 2>&1
    ;;

  stop)
    CHAT_ID=$($PSQL -c "SELECT chat_id FROM chat_sessions WHERE session_id = '${SESSION_ID}';" 2>/dev/null)
    [ -z "$CHAT_ID" ] && exit 0

    $REDIS HDEL claude:registry "chat-${CHAT_ID}" >/dev/null 2>&1
    ;;
esac

exit 0