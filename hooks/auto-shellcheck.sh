#!/bin/bash
# Hook: auto-shellcheck.sh
# Evento: PostToolUse (matcher: Edit|Write)
# Esegue shellcheck su file .sh/.bash modificati (se shellcheck e' installato)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Solo file shell
if ! echo "$FILE_PATH" | grep -qE '\.(sh|bash)$'; then
  exit 0
fi

# Verifica che il file esista
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Graceful fallback: se shellcheck non e' installato, esci silenziosamente
if ! command -v shellcheck &>/dev/null; then
  exit 0
fi

# Esegui shellcheck e cattura output
SC_OUTPUT=$(shellcheck -f gcc "$FILE_PATH" 2>&1)
SC_EXIT=$?

if [ $SC_EXIT -ne 0 ] && [ -n "$SC_OUTPUT" ]; then
  # Ritorna come additionalContext per Claude
  jq -n --arg ctx "shellcheck ha trovato problemi in $FILE_PATH:\n$SC_OUTPUT" '{
    hookSpecificOutput: {
      hookEventName: "PostToolUse",
      additionalContext: $ctx
    }
  }'
fi

exit 0