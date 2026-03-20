#!/bin/bash
# Hook: context-drift-detector.sh
# Evento: PostToolUse (qualsiasi matcher), async
# Conta tool calls senza progress update (TodoWrite). Se > soglia, emette reminder.
# Rileva anche pattern specifici: WebSearch/WebFetch builtin vs MCP.
# Soglia adattiva per fase (legge da phase-tracker.sh via Redis).
# Counter persistente in Redis DB 5 (claude:drift:<session_id>). TTL 2h.
# Ref: framework #170 (Context Reminder Enricher) + Wave 2 pattern-based enhancement

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")

[ -z "$SESSION_ID" ] && exit 0

REDIS="docker exec redis redis-cli -n 5"
KEY="claude:drift:${SESSION_ID}"

# TodoWrite resetta il counter (l'utente sta facendo progress tracking)
if [ "$TOOL_NAME" = "TodoWrite" ]; then
  $REDIS DEL "$KEY" >/dev/null 2>&1
  exit 0
fi

# --- Pattern: WebSearch/WebFetch builtin → usare MCP ---
if [ "$TOOL_NAME" = "WebSearch" ] || [ "$TOOL_NAME" = "WebFetch" ]; then
  WEB_COUNT=$($REDIS INCR "${KEY}:web_builtin" 2>/dev/null)
  $REDIS EXPIRE "${KEY}:web_builtin" 7200 >/dev/null 2>&1
  if [ "${WEB_COUNT:-0}" -ge 3 ] 2>/dev/null; then
    echo "Drift: ${WEB_COUNT} chiamate ${TOOL_NAME} builtin. Usare web_search/web_fetch MCP per failure isolation." >&2
    $REDIS DEL "${KEY}:web_builtin" >/dev/null 2>&1
  fi
fi

# --- Soglia adattiva per fase (legge da phase-tracker) ---
PHASE_JSON=$($REDIS GET "claude:phase:${SESSION_ID}" 2>/dev/null)
PHASE=$(echo "$PHASE_JSON" | jq -r '.phase // "UNKNOWN"' 2>/dev/null)
case "$PHASE" in
  EXPLORING)  THRESHOLD=50 ;;   # Esplorazione e' naturalmente lunga
  VERIFYING)  THRESHOLD=20 ;;   # Verifica deve essere focalizzata
  *)          THRESHOLD=30 ;;   # Default (IMPLEMENTING, MIXED, UNKNOWN)
esac

# Incrementa counter + TTL 2h
COUNT=$($REDIS INCR "$KEY" 2>/dev/null)
$REDIS EXPIRE "$KEY" 7200 >/dev/null 2>&1

# Se sopra soglia, emetti reminder e resetta
if [ "${COUNT:-0}" -gt "$THRESHOLD" ] 2>/dev/null; then
  echo "Drift: ${COUNT} tool call senza progress update (soglia ${THRESHOLD}, fase ${PHASE:-?}). Considerare TodoWrite per tracciare lo stato." >&2
  $REDIS DEL "$KEY" >/dev/null 2>&1
fi

exit 0
