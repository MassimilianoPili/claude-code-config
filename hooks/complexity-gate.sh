#!/bin/bash
# Hook: complexity-gate.sh
# Evento: PostToolUse (matcher: Edit|Write)
# Calcola complessita' approssimativa dei file modificati e avvisa se sopra soglia
# Non blocca mai (exit 0). Solo messaggio informativo.
# Ref: framework #175 (Structural Complexity Gate)

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Estrai file path
FILE_PATH=""
if [ "$TOOL_NAME" = "Write" ] || [ "$TOOL_NAME" = "Edit" ]; then
  FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
fi

[ -z "$FILE_PATH" ] && exit 0
[ ! -f "$FILE_PATH" ] && exit 0

# Solo file sorgente supportati
EXT="${FILE_PATH##*.}"
case "$EXT" in
  java|go|py|ts|js|tsx|jsx|kt|rs|c|cpp|cs) ;;
  *) exit 0 ;;
esac

# Soglia: complessita' approssimativa > 15 = warning
THRESHOLD=15

# Calcola complessita' approssimativa:
# - Conta keyword di branching (if, for, while, switch, case, catch, elif, else if)
# - Pesa il nesting depth (ogni livello di indentazione aggiunge 1 per keyword)
# Approccio semplificato senza AST, zero dipendenze
COMPLEXITY=$(python3 -c "
import sys, re

try:
    with open(sys.argv[1], 'r', errors='replace') as f:
        lines = f.readlines()
except Exception:
    print(0)
    sys.exit(0)

branch_kw = re.compile(r'\b(if|else\s+if|elif|for|while|switch|case|catch|except|&&|\|\|)\b')
complexity = 0

for line in lines:
    stripped = line.lstrip()
    if not stripped or stripped.startswith(('//', '#', '*', '/*')):
        continue
    # Nesting depth: count leading spaces/tabs
    indent = len(line) - len(stripped)
    depth = indent // 4  # assume 4-space indent (or 1 tab = 4 spaces)
    tab_depth = line.count('\t')
    if tab_depth > 0:
        depth = tab_depth
    # Count branch keywords on this line
    matches = branch_kw.findall(stripped)
    for _ in matches:
        # Cognitive complexity: +1 per keyword, +depth for nesting
        complexity += 1 + max(0, depth - 1)

print(complexity)
" "$FILE_PATH" 2>/dev/null)

COMPLEXITY=${COMPLEXITY:-0}

if [ "$COMPLEXITY" -gt "$THRESHOLD" ] 2>/dev/null; then
  BASENAME=$(basename "$FILE_PATH")
  echo "Complessita' $BASENAME: ~${COMPLEXITY} (soglia: ${THRESHOLD}). Considerare refactoring." >&2
fi

exit 0