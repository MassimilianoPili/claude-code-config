#!/bin/bash
# Hook: git-push-guard.sh
# Evento: PreToolUse (matcher: Bash)
# Blocca force-push verso main/master

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Solo comandi git push
if ! echo "$COMMAND" | grep -q 'git push'; then
  exit 0
fi

# Controlla se e' un force push
if echo "$COMMAND" | grep -qE 'git push.*(--force|-f)'; then
  # Controlla se il target e' main o master
  if echo "$COMMAND" | grep -qE '(main|master)'; then
    echo "BLOCCATO: force-push verso main/master non permesso" >&2
    echo "Comando: $COMMAND" >&2
    echo "Il force-push verso branch protetti puo' distruggere la storia del repository." >&2
    exit 2
  fi
  # Force push verso altri branch: permesso ma con warning
  echo "ATTENZIONE: force-push rilevato (non verso main/master)" >&2
fi

exit 0