#!/bin/bash
# Hook: stop-reminder.sh
# Evento: Stop
# Ricorda di eseguire test/verifiche se sono stati modificati file nella sessione
# IMPORTANTE: guard anti-loop — se stop_hook_active e' true, esci subito

INPUT=$(cat)

# Anti-loop guard: se questo hook ha gia' causato una continuazione, permetti lo stop
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Controlla se ci sono file modificati non committati nella working directory
CWD=$(echo "$INPUT" | jq -r '.cwd // "."')

# Verifica se siamo in un repo git
if ! git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  exit 0
fi

# Controlla se ci sono modifiche staged o unstaged
CHANGES=$(git -C "$CWD" status --porcelain 2>/dev/null)
if [ -z "$CHANGES" ]; then
  exit 0
fi

# Ci sono modifiche non committate — mostra lista file (max 10) e suggerisci verifiche
NUM_CHANGES=$(echo "$CHANGES" | wc -l | tr -d ' ')
FILE_LIST=$(echo "$CHANGES" | head -10 | awk '{print $NF}' | tr '\n' ', ' | sed 's/,$//')
if [ "$NUM_CHANGES" -gt 10 ]; then
  FILE_LIST="$FILE_LIST, ... (+$((NUM_CHANGES - 10)) altri)"
fi

jq -n --arg reason "Ci sono $NUM_CHANGES file modificati nella working directory ($FILE_LIST). Prima di terminare, considera: (1) eseguire test se applicabile, (2) verificare che le modifiche siano corrette, (3) committare se richiesto dall'utente." '{
  decision: "block",
  reason: $reason
}'

exit 0