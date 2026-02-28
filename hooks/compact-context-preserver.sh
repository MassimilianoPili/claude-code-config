#!/bin/bash
# Hook: compact-context-preserver.sh
# Evento: PreCompact
# Salva snapshot del contesto corrente prima della compattazione

SNAPSHOT_FILE="/tmp/claude-pre-compact-context.txt"
MARKER="/tmp/.claude-session-marker"

{
  echo ""
  echo "=== Pre-Compact Snapshot ($(date '+%Y-%m-%d %H:%M:%S')) ==="
  echo ""

  echo "--- Container Docker ---"
  docker ps --format "{{.Names}}: {{.Status}}" 2>/dev/null || echo "(non disponibile)"
  echo ""

  echo "--- Working Directory ---"
  echo "CWD: $(pwd)"
  echo ""

  # Stato git se in un repo
  if git rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    echo "--- Git Status ---"
    git diff --stat 2>/dev/null | head -10
    echo ""
  fi

  # File modificati nella sessione (se il marker esiste)
  if [ -f "$MARKER" ]; then
    echo "--- File modificati nella sessione ---"
    find /data/massimiliano -maxdepth 4 -newer "$MARKER" \( \
      -name "*.sh" -o -name "*.go" -o -name "*.js" -o -name "*.yml" \
      -o -name "*.html" -o -name "*.conf" -o -name "*.md" \
    \) -not -path "*/.git/*" -not -path "*/node_modules/*" 2>/dev/null \
      | sed 's|/data/massimiliano/||' | head -15
    echo ""
  fi

  echo "--- Ultimi container con errori ---"
  docker ps -a --filter "status=exited" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -5
  echo ""

} >> "$SNAPSHOT_FILE" 2>/dev/null

exit 0