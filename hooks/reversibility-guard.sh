#!/bin/bash
# Hook: reversibility-guard.sh
# Evento: PreToolUse (matcher: Bash)
# Classifica comandi per livello di reversibilita' e blocca quelli irreversibili
# non gia' coperti da block-dangerous-commands.sh
# Riferimento: Framework item #168 (Reversibility Guard)

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

COMMAND_NORM=$(echo "$COMMAND" | tr -s ' ')

# Pattern CAUTION: operazioni difficili da annullare ma non catastrofiche
# block-dangerous-commands.sh gestisce gia' rm -rf, shutdown, mkfs, dd, docker prune
CAUTION_PATTERNS=(
  # Database DROP/TRUNCATE
  'DROP\s+(TABLE|DATABASE|INDEX|SCHEMA|EXTENSION)'
  'TRUNCATE\s+'
  'DELETE\s+FROM\s+\w+\s*;'
  # Git operazioni distruttive (no rebase -i, gia' bloccato)
  'git\s+reset\s+--hard'
  'git\s+push\s+.*--force'
  'git\s+push\s+.*-f\b'
  'git\s+clean\s+-f'
  'git\s+checkout\s+--\s+\.'
  'git\s+restore\s+--source'
  'git\s+branch\s+-D'
  # File system
  'rm\s+-r\s+'
  '>\s*/dev/null\s+2>&1\s*<'
  # Docker senza -a ma potenzialmente distruttivi
  'docker\s+rm\s+'
  'docker\s+rmi\s+'
  'docker\s+network\s+rm'
  'docker\s+volume\s+rm'
  # Permessi
  'chmod\s+-R\s+'
  'chown\s+-R\s+'
  # Systemd
  'systemctl\s+(stop|disable|mask)\s+'
  'systemctl\s+--user\s+(stop|disable)\s+'
  # Kill
  'kill\s+-9'
  'killall'
  'pkill'
  # Code injection via eval (da agent-framework block-destructive.sh)
  'eval\s+.*\$\('
  'eval\s+.*`'
)

for pattern in "${CAUTION_PATTERNS[@]}"; do
  if echo "$COMMAND_NORM" | grep -qiE "$pattern"; then
    echo "BLOCCATO: operazione a bassa reversibilita' (pattern: $pattern)" >&2
    echo "Comando: $COMMAND" >&2
    echo "Questa operazione e' difficile da annullare. Verifica che sia intenzionale." >&2
    exit 2
  fi
done

exit 0
