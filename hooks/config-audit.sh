#!/bin/bash
# Hook: config-audit.sh
# Evento: ConfigChange
# Logga modifiche ai file di configurazione Claude Code

INPUT=$(cat)
SOURCE=$(echo "$INPUT" | jq -r '.source // "unknown"')
FILE_PATH=$(echo "$INPUT" | jq -r '.file_path // "none"')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

AUDIT_DIR="$HOME/.claude/audit"
AUDIT_FILE="$AUDIT_DIR/config-changes.log"

# Crea directory se non esiste
mkdir -p "$AUDIT_DIR" 2>/dev/null

# Appendi al log
echo "[$TIMESTAMP] source=$SOURCE file=$FILE_PATH" >> "$AUDIT_FILE"

exit 0