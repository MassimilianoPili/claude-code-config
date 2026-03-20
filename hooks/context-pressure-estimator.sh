#!/bin/bash
# Hook: context-pressure-estimator.sh
# Evento: PostToolUse (matcher: .*, async: true)
# Stima token cumulativi per la sessione e avvisa quando il contesto e' sotto pressione
# Ispirato a: agent-framework CompactingToolCallingManager (pre-call token budget check al 75%)
# Storage: Redis DB 5, claude:tokens:<session_id> (counter INCRBY)

INPUT=$(cat)
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")
[ -z "$SESSION_ID" ] && exit 0

REDIS="docker exec redis redis-cli -n 5"
KEY="claude:tokens:${SESSION_ID}"

# Stima token dal tool_response (chars / 4, approssimazione)
RESPONSE_LEN=$(jq -r '[.tool_response[]? | .text // "" | length] | add // 0' <<< "$INPUT" 2>/dev/null)
[[ "$RESPONSE_LEN" =~ ^[0-9]+$ ]] || RESPONSE_LEN=0
TOKEN_EST=$((RESPONSE_LEN / 4))

# Anche tool_input contribuisce al contesto
INPUT_LEN=$(jq -r '.tool_input | tostring | length' <<< "$INPUT" 2>/dev/null)
[[ "$INPUT_LEN" =~ ^[0-9]+$ ]] || INPUT_LEN=0
TOKEN_EST=$((TOKEN_EST + INPUT_LEN / 4))

# Skip se stima trascurabile
[ "$TOKEN_EST" -lt 10 ] && exit 0

# Incrementa counter
TOTAL=$($REDIS INCRBY "$KEY" "$TOKEN_EST" 2>/dev/null)
[[ "$TOTAL" =~ ^[0-9]+$ ]] || exit 0
$REDIS EXPIRE "$KEY" 14400 >/dev/null 2>&1  # 4h TTL

# Soglie di warning (stima conservativa — il contesto reale include system prompt, CLAUDE.md, etc.)
WARN_THRESHOLD=600000
CRIT_THRESHOLD=750000

# Emetti warning solo ogni 50K token per evitare spam
WARN_KEY="claude:tokens:warned:${SESSION_ID}"

if [ "$TOTAL" -ge "$CRIT_THRESHOLD" ]; then
  LAST_WARN=$($REDIS GET "$WARN_KEY" 2>/dev/null)
  [[ "$LAST_WARN" =~ ^[0-9]+$ ]] || LAST_WARN=0
  if [ $((TOTAL - LAST_WARN)) -ge 50000 ]; then
    PCT=$((TOTAL * 100 / 1000000))
    echo "CONTESTO CRITICO: ~${TOTAL} token stimati (~${PCT}%). Compattazione imminente. Salvare stato." >&2
    $REDIS SET "$WARN_KEY" "$TOTAL" EX 14400 >/dev/null 2>&1
  fi
elif [ "$TOTAL" -ge "$WARN_THRESHOLD" ]; then
  LAST_WARN=$($REDIS GET "$WARN_KEY" 2>/dev/null)
  [[ "$LAST_WARN" =~ ^[0-9]+$ ]] || LAST_WARN=0
  if [ $((TOTAL - LAST_WARN)) -ge 50000 ]; then
    PCT=$((TOTAL * 100 / 1000000))
    echo "Contesto al ~${PCT}% (~${TOTAL} token stimati). Considerare compattazione o completare il lavoro corrente." >&2
    $REDIS SET "$WARN_KEY" "$TOTAL" EX 14400 >/dev/null 2>&1
  fi
fi

exit 0