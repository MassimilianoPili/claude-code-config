#!/bin/bash
# Hook: compact-context-preserver.sh
# Evento: PreCompact
# Salva snapshot del contesto corrente prima della compattazione

SNAPSHOT_FILE="/tmp/claude-pre-compact-context.txt"

{
  echo "=== Pre-Compact Snapshot ($(date '+%Y-%m-%d %H:%M:%S')) ==="
  echo ""

  echo "--- Container Docker ---"
  docker ps --format "{{.Names}}: {{.Status}}" 2>/dev/null || echo "(non disponibile)"
  echo ""

  echo "--- Working Directory ---"
  echo "CWD: $(pwd)"
  echo ""

  echo "--- Ultimi container con errori ---"
  docker ps -a --filter "status=exited" --format "{{.Names}}: {{.Status}}" 2>/dev/null | head -5
  echo ""

} > "$SNAPSHOT_FILE" 2>/dev/null

exit 0