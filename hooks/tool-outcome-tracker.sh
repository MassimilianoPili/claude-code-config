#!/bin/bash
# Hook: tool-outcome-tracker.sh
# Evento: PostToolUse (matcher: mcp__simoge-mcp__.*)
# Registra outcome di ogni tool call MCP → PostgreSQL tool_outcomes (source of truth)
# Async: non rallenta l'esecuzione

INPUT=$(cat)

# Estrai info dal JSON di input
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Salta se tool_name vuoto o se è il tracker stesso (evita loop)
[ -z "$TOOL_NAME" ] && exit 0
case "$TOOL_NAME" in
  mcp__simoge-mcp__recovery_report_outcome|mcp__simoge-mcp__recovery_health_dashboard)
    exit 0
    ;;
esac

# Rimuovi prefisso MCP per il nome tool pulito
CLEAN_NAME="${TOOL_NAME#mcp__simoge-mcp__}"

# Determina successo: tool_response è array di content blocks [{type, text}]
# Il JSON effettivo del tool è in .tool_response[0].text (stringa JSON)
RESPONSE_TEXT=$(echo "$INPUT" | jq -r '.tool_response[0].text // empty')
HAS_ERROR=""

# Parsa il testo come JSON e cerca campi error/isError
if [ -n "$RESPONSE_TEXT" ]; then
  HAS_ERROR=$(echo "$RESPONSE_TEXT" | jq -r 'if type == "object" then (.error // .isError // empty) else empty end' 2>/dev/null)
fi

if [ -n "$HAS_ERROR" ] && [ "$HAS_ERROR" != "null" ] && [ "$HAS_ERROR" != "false" ]; then
  SUCCESS="false"
  ERROR_MSG=$(echo "$HAS_ERROR" | head -c 500)
else
  SUCCESS="true"
  ERROR_MSG=""
fi

# Stima latenza (non disponibile direttamente, usiamo 0 come placeholder)
LATENCY_MS=0

# Escape single quotes per SQL
CLEAN_NAME_ESC="${CLEAN_NAME//\'/\'\'}"
SESSION_ID_ESC="${SESSION_ID//\'/\'\'}"
ERROR_MSG_ESC="${ERROR_MSG//\'/\'\'}"

# Scrivi direttamente su PostgreSQL via docker exec (bypassa MCP SSE, fire-and-forget)
SQL="INSERT INTO tool_outcomes (session_id, tool_name, success, latency_ms, error_message) VALUES ('${SESSION_ID_ESC}', '${CLEAN_NAME_ESC}', ${SUCCESS}, ${LATENCY_MS}, $([ -n "$ERROR_MSG" ] && echo "'${ERROR_MSG_ESC}'" || echo "NULL"));"

docker exec -i postgres psql -U postgres -d embeddings -c "$SQL" >/dev/null 2>&1 &

exit 0
