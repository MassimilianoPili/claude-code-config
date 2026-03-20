#!/bin/bash
# Hook: compact-context-preserver.sh
# Evento: PreCompact
# Salva snapshot del contesto corrente prima della compattazione
# Wave 3 enhancement: persiste anche in Redis DB 5 (TTL 24h) per il resume
# Ispirato a: agent-framework ConversationCheckpoint (serializzato per session resume)

INPUT=$(cat)
SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT" 2>/dev/null)

SNAPSHOT_FILE="/tmp/claude-pre-compact-context.txt"
MARKER="/tmp/.claude-session-marker"
REDIS="docker exec redis redis-cli -n 5"

# Costruisci snapshot come testo
SNAPSHOT=""

SNAPSHOT="${SNAPSHOT}=== Pre-Compact Snapshot ($(date '+%Y-%m-%d %H:%M:%S')) ===\n"

# Working directory
SNAPSHOT="${SNAPSHOT}\nCWD: $(pwd)\n"

# Fase corrente (da phase-tracker)
PHASE_JSON=$($REDIS GET "claude:phase:${SESSION_ID}" 2>/dev/null)
if [ -n "$PHASE_JSON" ] && [ "$PHASE_JSON" != "(nil)" ]; then
  PHASE=$(echo "$PHASE_JSON" | jq -r '.phase // "?"' 2>/dev/null)
  SNAPSHOT="${SNAPSHOT}Fase: ${PHASE}\n"
fi

# Token stimati (da context-pressure-estimator)
TOKEN_COUNT=$($REDIS GET "claude:tokens:${SESSION_ID}" 2>/dev/null)
if [ -n "$TOKEN_COUNT" ] && [ "$TOKEN_COUNT" != "(nil)" ]; then
  SNAPSHOT="${SNAPSHOT}Token stimati: ~${TOKEN_COUNT}\n"
fi

# Stato git se in un repo
if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
  GIT_STAT=$(git diff --stat 2>/dev/null | head -10)
  if [ -n "$GIT_STAT" ]; then
    SNAPSHOT="${SNAPSHOT}\n--- Git Status ---\n${GIT_STAT}\n"
  fi
fi

# File modificati nella sessione (se il marker esiste)
if [ -f "$MARKER" ]; then
  MODIFIED=$(find /data/massimiliano -maxdepth 4 -newer "$MARKER" \( \
    -name "*.sh" -o -name "*.go" -o -name "*.js" -o -name "*.java" -o -name "*.yml" \
    -o -name "*.html" -o -name "*.conf" -o -name "*.md" -o -name "*.json" \
  \) -not -path "*/.git/*" -not -path "*/node_modules/*" -not -path "*/.claude/*" 2>/dev/null \
    | sed 's|/data/massimiliano/||' | head -15)
  if [ -n "$MODIFIED" ]; then
    SNAPSHOT="${SNAPSHOT}\n--- File modificati ---\n${MODIFIED}\n"
  fi
fi

# Ultime 10 righe dall'audit JSONL (tool recenti)
AUDIT_FILE="$HOME/.claude/audit/audit.jsonl"
if [ -f "$AUDIT_FILE" ]; then
  RECENT_TOOLS=$(tail -10 "$AUDIT_FILE" | jq -r '[.tool, .input_summary[:60]] | join(": ")' 2>/dev/null | head -10)
  if [ -n "$RECENT_TOOLS" ]; then
    SNAPSHOT="${SNAPSHOT}\n--- Ultime 10 tool call ---\n${RECENT_TOOLS}\n"
  fi
fi

# Container con errori
EXITED=$(docker ps -a --filter "status=exited" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -5)
if [ -n "$EXITED" ]; then
  SNAPSHOT="${SNAPSHOT}\n--- Container con errori ---\n${EXITED}\n"
fi

# --- Salva su file (compatibilita' backward) ---
echo -e "\n${SNAPSHOT}" >> "$SNAPSHOT_FILE" 2>/dev/null

# --- Salva su Redis (persistente, TTL 24h) ---
if [ "$SESSION_ID" != "unknown" ]; then
  REDIS_KEY="claude:compact:${SESSION_ID}"
  # Escape per Redis SET
  ESCAPED_SNAPSHOT=$(echo -e "$SNAPSHOT" | head -50)
  $REDIS SET "$REDIS_KEY" "$ESCAPED_SNAPSHOT" EX 86400 >/dev/null 2>&1
fi

exit 0