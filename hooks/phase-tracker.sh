#!/bin/bash
# Hook: phase-tracker.sh
# Evento: PostToolUse (matcher: .*, async: true)
# Classifica la fase di lavoro basandosi sulle ultime 20 tool call
# Ispirato a: agent-framework Phase State Machine (EXPLORING→IMPLEMENTING→VERIFYING→FINALIZING)
# Storage: Redis DB 5, claude:tools:<session> (LIST), claude:phase:<session> (JSON)

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")
[ -z "$SESSION_ID" ] || [ -z "$TOOL_NAME" ] && exit 0

REDIS="docker exec redis redis-cli -n 5"
TOOLS_KEY="claude:tools:${SESSION_ID}"
PHASE_KEY="claude:phase:${SESSION_ID}"

# Append tool name alla sliding window, mantieni ultime 20
$REDIS RPUSH "$TOOLS_KEY" "$TOOL_NAME" >/dev/null 2>&1
$REDIS LTRIM "$TOOLS_KEY" -20 -1 >/dev/null 2>&1
$REDIS EXPIRE "$TOOLS_KEY" 14400 >/dev/null 2>&1

# Leggi ultime 20 tool call
TOOLS=$($REDIS LRANGE "$TOOLS_KEY" 0 -1 2>/dev/null)
[ -z "$TOOLS" ] && exit 0

TOTAL=$(echo "$TOOLS" | wc -l | tr -d ' ')
[ "$TOTAL" -lt 5 ] && exit 0  # Troppo pochi dati per classificare

# Conta categorie tool (grep -c ritorna 0 se nessun match, ma con || gestisce exit code 1)
EXPLORE_COUNT=$(echo "$TOOLS" | grep -cE '^(Glob|Grep|Read|Agent|ToolSearch)$' || true)
IMPLEMENT_COUNT=$(echo "$TOOLS" | grep -cE '^(Edit|Write)$' || true)
BASH_COUNT=$(echo "$TOOLS" | grep -c '^Bash$' || true)

# Sanitizza: assicurati che siano numeri
EXPLORE_COUNT=${EXPLORE_COUNT:-0}
IMPLEMENT_COUNT=${IMPLEMENT_COUNT:-0}
BASH_COUNT=${BASH_COUNT:-0}

# Calcola percentuali
EXPLORE_PCT=$((EXPLORE_COUNT * 100 / TOTAL))
IMPLEMENT_PCT=$((IMPLEMENT_COUNT * 100 / TOTAL))
BASH_PCT=$((BASH_COUNT * 100 / TOTAL))

# Classificazione fase (priorità: EXPLORING > IMPLEMENTING > VERIFYING > MIXED)
if [ "$EXPLORE_PCT" -ge 60 ]; then
  NEW_PHASE="EXPLORING"
elif [ "$IMPLEMENT_PCT" -ge 40 ]; then
  NEW_PHASE="IMPLEMENTING"
elif [ "$BASH_PCT" -ge 33 ]; then
  NEW_PHASE="VERIFYING"
else
  NEW_PHASE="MIXED"
fi

# Leggi fase precedente
OLD_JSON=$($REDIS GET "$PHASE_KEY" 2>/dev/null)
OLD_PHASE=$(echo "$OLD_JSON" | jq -r '.phase // "UNKNOWN"' 2>/dev/null)

# Aggiorna solo se cambiata
if [ "$NEW_PHASE" != "$OLD_PHASE" ]; then
  TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  PHASE_JSON=$(jq -cn \
    --arg phase "$NEW_PHASE" \
    --arg since "$TS" \
    --argjson count "$TOTAL" \
    --argjson explore "$EXPLORE_PCT" \
    --argjson implement "$IMPLEMENT_PCT" \
    --argjson bash "$BASH_PCT" \
    '{phase:$phase, since:$since, toolCount:$count, pct:{explore:$explore, implement:$implement, bash:$bash}}')
  $REDIS SET "$PHASE_KEY" "$PHASE_JSON" EX 14400 >/dev/null 2>&1
fi

exit 0