#!/bin/bash
# Hook: command-audit-log.sh
# Evento: PostToolUse (matcher: Bash)
# Logga ogni comando Bash eseguito (async per non rallentare)

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
EXIT_CODE=$(echo "$INPUT" | jq -r '.tool_result.exit_code // "?"')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

AUDIT_DIR="$HOME/.claude/audit"
AUDIT_FILE="$AUDIT_DIR/commands.log"

# Crea directory se non esiste
mkdir -p "$AUDIT_DIR" 2>/dev/null

# Rotazione log: se > 10MB, rinomina e ricrea
if [ -f "$AUDIT_FILE" ]; then
  FILE_SIZE=$(stat -c%s "$AUDIT_FILE" 2>/dev/null || echo 0)
  if [ "$FILE_SIZE" -gt 10485760 ]; then
    # Mantieni max 3 rotazioni
    [ -f "$AUDIT_FILE.2" ] && mv "$AUDIT_FILE.2" "$AUDIT_FILE.3"
    [ -f "$AUDIT_FILE.1" ] && mv "$AUDIT_FILE.1" "$AUDIT_FILE.2"
    mv "$AUDIT_FILE" "$AUDIT_FILE.1"
  fi
fi

# Appendi al log con exit code
echo "[$TIMESTAMP] [$SESSION_ID] [exit=$EXIT_CODE] $COMMAND" >> "$AUDIT_FILE"

exit 0
