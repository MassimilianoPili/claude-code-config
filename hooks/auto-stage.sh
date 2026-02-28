#!/bin/bash
# Hook: auto-stage.sh
# Evento: PostToolUse (matcher: Edit|Write)
# Esegue git add automatico dopo modifica file (solo se in un repo git)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Verifica che il file esista
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Verifica che il file sia in un repository git
FILE_DIR=$(dirname "$FILE_PATH")
if ! git -C "$FILE_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  exit 0
fi

# Stage il file silenziosamente
git -C "$FILE_DIR" add "$FILE_PATH" 2>/dev/null

exit 0
