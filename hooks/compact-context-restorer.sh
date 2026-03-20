#!/bin/bash
# Hook: compact-context-restorer.sh
# Evento: SessionStart (matcher: resume)
# Legge lo snapshot pre-compact da Redis e lo stampa per ripristinare il contesto
# Ispirato a: agent-framework ConversationCheckpoint restore on session resume

INPUT=$(cat)
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT" 2>/dev/null)
[ -z "$SESSION_ID" ] && exit 0

REDIS="docker exec redis redis-cli -n 5"
REDIS_KEY="claude:compact:${SESSION_ID}"

# Leggi snapshot da Redis
SNAPSHOT=$($REDIS GET "$REDIS_KEY" 2>/dev/null)

# Se non c'e' snapshot per questa sessione, prova la chiave generica
if [ -z "$SNAPSHOT" ] || [ "$SNAPSHOT" = "(nil)" ]; then
  exit 0
fi

# Stampa il contesto pre-compact (visibile nel contesto della sessione)
echo "=== Contesto ripristinato (pre-compattazione) ==="
echo "$SNAPSHOT"
echo "================================================="

exit 0