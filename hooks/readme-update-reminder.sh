#!/bin/bash
# Hook: readme-update-reminder.sh
# Evento: Stop
# Ricorda di aggiornare README.md/CLAUDE.md se sono stati modificati file infrastrutturali
# Usa un marker temporale creato da session-context-loader.sh al SessionStart

INPUT=$(cat)

# Anti-loop guard: se stop_hook_active, lascia passare
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

# Marker creato da session-context-loader.sh al SessionStart
MARKER="/tmp/.claude-session-marker"
if [ ! -f "$MARKER" ]; then
  exit 0
fi

# Cerca file infrastrutturali modificati dopo il marker di sessione (maxdepth 3)
INFRA_CHANGED=$(find /data/massimiliano -maxdepth 3 -newer "$MARKER" \( \
  -name "docker-compose.yml" -o -name "docker-compose.*.yml" \
  -o -name "nginx.conf" -o -name "Dockerfile" \
  -o -name "*.service" -o -name "config.yml" \
  -o -name "*.toml" -o -name "*.yaml" \
  -o -name "server.js" -o -name "main.go" -o -name "app.ini" \
  -o -path "*/.claude/hooks/*.sh" \
  -o -path "*/shell-scripts/bin/*" \
  -o -path "*/home/index.html" \
\) -not -path "*/node_modules/*" -not -path "*/.git/*" 2>/dev/null)

if [ -z "$INFRA_CHANGED" ]; then
  exit 0
fi

# Filtra: esclude file che hanno solo modifiche staged in git (working tree pulito).
# Questo previene falsi positivi da git stat-refresh su file staged di sessioni precedenti.
INFRA_REAL=""
while IFS= read -r f; do
  [ -z "$f" ] && continue
  repo_root=$(git -C "$(dirname "$f")" rev-parse --show-toplevel 2>/dev/null)
  if [ -n "$repo_root" ]; then
    rel="${f#"$repo_root"/}"
    # Includi solo se il working tree differisce dall'index (modifiche non-staged reali)
    if ! git -C "$repo_root" diff --quiet -- "$rel" 2>/dev/null; then
      INFRA_REAL="${INFRA_REAL}${f}"$'\n'
    fi
    # Includi anche se il file non e' ancora tracciato da git (nuovo, untracked)
    if git -C "$repo_root" ls-files --others --exclude-standard -- "$rel" | grep -q .; then
      INFRA_REAL="${INFRA_REAL}${f}"$'\n'
    fi
  else
    # Non in un repo git: includi sempre
    INFRA_REAL="${INFRA_REAL}${f}"$'\n'
  fi
done <<< "$INFRA_CHANGED"
INFRA_CHANGED="$INFRA_REAL"

if [ -z "$INFRA_CHANGED" ]; then
  exit 0
fi

# Controlla se almeno un file di documentazione e' stato aggiornato
DOC_CHANGED=""
if [ -n "$(find /data/massimiliano -maxdepth 1 -name 'README.md' -newer "$MARKER" 2>/dev/null)" ]; then
  DOC_CHANGED="yes"
elif [ -n "$(find /data/massimiliano -maxdepth 1 -name 'CLAUDE.md' -newer "$MARKER" 2>/dev/null)" ]; then
  DOC_CHANGED="yes"
elif [ -n "$(find /home/massimiliano/.claude/projects/-data-massimiliano/memory -name 'MEMORY.md' -newer "$MARKER" 2>/dev/null)" ]; then
  DOC_CHANGED="yes"
fi

if [ -n "$DOC_CHANGED" ]; then
  exit 0
fi

# Documentazione non aggiornata — costruisci lista file per il messaggio
NUM_INFRA=$(echo "$INFRA_CHANGED" | wc -l | tr -d ' ')
# Mostra solo i nomi relativi (strip /data/massimiliano/)
FILE_LIST=$(echo "$INFRA_CHANGED" | sed 's|/data/massimiliano/||g' | head -10 | tr '\n' ', ' | sed 's/,$//')

jq -n --arg reason "Hai modificato $NUM_INFRA file infrastrutturali ($FILE_LIST) ma documentazione e KORE non sono stati aggiornati. Considera di aggiornare MEMORY.md, CLAUDE.md e/o il knowledge graph AGE (graph_write) prima di terminare." '{
  decision: "block",
  reason: $reason
}'

exit 0