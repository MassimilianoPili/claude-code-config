#!/bin/bash
# Hook: unified-audit-log.sh
# Evento: PostToolUse (matcher: .*, async: true)
# Audit trail JSONL unificato per OGNI tool call, con hash chain SHA-256
# Ispirato a: agent-framework PlanEventStore (event sourcing immutabile)
# Sostituisce: command-audit-log.sh (solo Bash, testo)

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
[ -z "$TOOL_NAME" ] && exit 0

SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT")

AUDIT_DIR="$HOME/.claude/audit"
AUDIT_FILE="$AUDIT_DIR/audit.jsonl"
HASH_FILE="$AUDIT_DIR/.last-hash"
mkdir -p "$AUDIT_DIR" 2>/dev/null

# Timestamp ISO 8601 UTC
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Input summary: primi 200 char, specifico per tool type
case "$TOOL_NAME" in
  Bash)
    INPUT_SUMMARY=$(jq -r '.tool_input.command // "" | .[0:200]' <<< "$INPUT")
    ;;
  Edit)
    INPUT_SUMMARY=$(jq -r '(.tool_input.file_path // "") + " → " + (.tool_input.old_string // "" | .[0:100])' <<< "$INPUT")
    ;;
  Write)
    INPUT_SUMMARY=$(jq -r '.tool_input.file_path // "" | .[0:200]' <<< "$INPUT")
    ;;
  Read)
    INPUT_SUMMARY=$(jq -r '.tool_input.file_path // "" | .[0:200]' <<< "$INPUT")
    ;;
  Glob)
    INPUT_SUMMARY=$(jq -r '.tool_input.pattern // "" | .[0:200]' <<< "$INPUT")
    ;;
  Grep)
    INPUT_SUMMARY=$(jq -r '(.tool_input.pattern // "") + " in " + (.tool_input.path // ".") | .[0:200]' <<< "$INPUT")
    ;;
  Agent)
    INPUT_SUMMARY=$(jq -r '.tool_input.description // "" | .[0:200]' <<< "$INPUT")
    ;;
  TodoWrite)
    INPUT_SUMMARY="todo-update"
    ;;
  *)
    INPUT_SUMMARY=$(jq -r '.tool_input | tostring | .[0:200]' <<< "$INPUT" 2>/dev/null || echo "{}")
    ;;
esac

# Sanitizzazione: censura possibili secrets nell'input summary
if echo "$INPUT_SUMMARY" | grep -qiE '(password|passwd|secret|token|AKIA|sk-ant-|ghp_|glpat-)'; then
  INPUT_SUMMARY="[REDACTED]"
fi

# Exit code (disponibile per Bash, 0 per altri)
EXIT_CODE=$(jq -r '.tool_result.exit_code // 0' <<< "$INPUT")
# Assicurati che sia un numero
[[ "$EXIT_CODE" =~ ^[0-9]+$ ]] || EXIT_CODE=0

# --- Hash chain (ispirato a PlanEventStore.java SHA-256 immutabile) ---
PREV_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "genesis")
INPUT_HASH=$(echo -n "$INPUT_SUMMARY" | sha256sum | cut -d' ' -f1)
CURRENT_HASH=$(echo -n "${PREV_HASH}|${TOOL_NAME}|${TS}|${INPUT_HASH}" | sha256sum | cut -d' ' -f1)

# Rotazione log: 10MB, mantieni 3 rotazioni
if [ -f "$AUDIT_FILE" ]; then
  FILE_SIZE=$(stat -c%s "$AUDIT_FILE" 2>/dev/null || echo 0)
  if [ "$FILE_SIZE" -gt 10485760 ]; then
    [ -f "$AUDIT_FILE.2" ] && mv "$AUDIT_FILE.2" "$AUDIT_FILE.3"
    [ -f "$AUDIT_FILE.1" ] && mv "$AUDIT_FILE.1" "$AUDIT_FILE.2"
    mv "$AUDIT_FILE" "$AUDIT_FILE.1"
    # Reset hash chain alla rotazione
    PREV_HASH="genesis"
    CURRENT_HASH=$(echo -n "genesis|${TOOL_NAME}|${TS}|${INPUT_HASH}" | sha256sum | cut -d' ' -f1)
  fi
fi

# Scrivi riga JSONL
jq -cn \
  --arg ts "$TS" \
  --arg session "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  --arg input "$INPUT_SUMMARY" \
  --argjson exitCode "$EXIT_CODE" \
  --arg hash "$CURRENT_HASH" \
  --arg prevHash "$PREV_HASH" \
  '{ts:$ts,session:$session,tool:$tool,input_summary:$input,exit_code:$exitCode,hash:$hash,prev_hash:$prevHash}' \
  >> "$AUDIT_FILE"

# Aggiorna hash per prossimo record
echo -n "$CURRENT_HASH" > "$HASH_FILE"

exit 0