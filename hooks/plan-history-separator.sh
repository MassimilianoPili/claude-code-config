#!/bin/bash
# Hook: plan-history-separator.sh
# Evento: PostToolUse (matcher: Edit|Write)
# Avvisa quando un file PIANO*.md accumula troppo contenuto storico,
# suggerendo la separazione in un file *_HISTORY.md dedicato.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Solo file PIANO*.md (case-insensitive)
BASENAME=$(basename "$FILE_PATH")
if ! echo "$BASENAME" | grep -iqE '^PIANO.*\.md$'; then
  exit 0
fi

# Salta file gia' dedicati allo storico
if echo "$BASENAME" | grep -iq 'HISTORY'; then
  exit 0
fi

# Verifica che il file esista
if [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Conta marker di contenuto storico
COMPLETED=$(grep -cE '✅|~~[^~]+~~|\[(completato|fatto|done|DONE|archiviato)\]' "$FILE_PATH" 2>/dev/null || echo 0)

# Conta righe totali
LINES=$(wc -l < "$FILE_PATH" 2>/dev/null || echo 0)

# Soglie: (file grande + qualche completato) oppure (molti completati)
WARN=false
if [ "$LINES" -gt 200 ] && [ "$COMPLETED" -gt 5 ]; then
  WARN=true
elif [ "$COMPLETED" -gt 15 ]; then
  WARN=true
fi

if [ "$WARN" = "true" ]; then
  # Suggerisci il nome del file history basato sul nome attuale
  HISTORY_NAME="${BASENAME%.md}_HISTORY.md"
  HISTORY_DIR=$(dirname "$FILE_PATH")

  jq -n \
    --arg basename "$BASENAME" \
    --arg completed "$COMPLETED" \
    --arg lines "$LINES" \
    --arg history "$HISTORY_NAME" \
    --arg dir "$HISTORY_DIR" \
    '{
      hookSpecificOutput: {
        hookEventName: "PostToolUse",
        additionalContext: ($basename + " contiene " + $completed + " item completati su " + $lines + " righe.\nConsidera spostare il contenuto storico in " + $dir + "/" + $history + "\nper mantenere il piano attivo snello e focalizzato sul futuro.")
      }
    }'
fi

exit 0
