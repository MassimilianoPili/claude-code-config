#!/bin/bash
# Hook: auto-gofmt.sh
# Evento: PostToolUse (matcher: Edit|Write)
# Formatta automaticamente file .go con gofmt (se installato)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Solo file Go
if ! echo "$FILE_PATH" | grep -qE '\.go$'; then
  exit 0
fi

# Verifica che il file esista
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Graceful fallback: se gofmt non e' installato, esci silenziosamente
if ! command -v gofmt &>/dev/null; then
  exit 0
fi

# Formatta in-place silenziosamente
gofmt -w "$FILE_PATH" 2>/dev/null

exit 0