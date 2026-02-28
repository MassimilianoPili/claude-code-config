#!/bin/bash
# Hook: command-audit-log.sh
# Evento: PostToolUse (matcher: Bash)
# Logga ogni comando Bash eseguito (async per non rallentare)

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

AUDIT_DIR="$HOME/.claude/audit"
AUDIT_FILE="$AUDIT_DIR/commands.log"

# Crea directory se non esiste
mkdir -p "$AUDIT_DIR" 2>/dev/null

# Appendi al log
echo "[$TIMESTAMP] [$SESSION_ID] $COMMAND" >> "$AUDIT_FILE"

exit 0
