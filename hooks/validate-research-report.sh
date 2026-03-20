#!/bin/bash
# Hook: validate-research-report.sh
# Evento: PreToolUse (matcher: Edit|Write)
# Blocca scrittura di research report senza evidenza di validazione S2 + DBLP + Algorithmic Correctness
#
# Parte del pipeline academic-researcher v3:
# - MCP tool `research_validate_paper` rende facile la validazione
# - Questo hook rende impossibile saltarla
#
# Gate 1: ogni paper deve avere citazioni verificate con S2 (pattern: "(S2" o "S2 FETCH FAILED")
# Gate 2: cross-check DBLP deve essere presente (pattern: "dblp" o "DBLP")
# Gate 3: sezione Algorithmic Correctness / Precondition deve esistere

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Solo file in docs/research/*.md
if ! echo "$FILE_PATH" | grep -qE 'docs/research/.*\.md$'; then
  exit 0
fi

# Per Edit, il contenuto e' in new_string; per Write, in content
CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')

# Se content e' vuoto (es. Edit con old_string piccolo), non bloccare
if [ ${#CONTENT} -lt 100 ]; then
  exit 0
fi

ERRORS=""

# Gate 1: Almeno un paper validato con S2
if ! echo "$CONTENT" | grep -qE '\(S2[,) ]|Semantic Scholar|S2 FETCH FAILED|S2,|~[0-9]+ \(S2'; then
  ERRORS="${ERRORS}\n  Gate 1 FAIL: nessuna evidenza di validazione Semantic Scholar"
  ERRORS="${ERRORS}\n    Ogni paper deve avere citazioni '~N (S2, YYYY-MM-DD)' o 'S2 FETCH FAILED'"
fi

# Gate 2: Almeno una reference DBLP o dichiarazione esplicita N/A
if ! echo "$CONTENT" | grep -qiE 'dblp\.org|DBLP|dblp'; then
  ERRORS="${ERRORS}\n  Gate 2 FAIL: nessun cross-check DBLP"
  ERRORS="${ERRORS}\n    Ogni paper CS deve avere riscontro DBLP (o 'DBLP: N/A' per paper non-CS)"
fi

# Gate 3: Sezione Algorithmic Correctness o Precondition presente
if ! echo "$CONTENT" | grep -qiE 'Algorithmic Correctness|Precondition|Algorithm.*Appropriate'; then
  ERRORS="${ERRORS}\n  Gate 3 FAIL: nessuna sezione Algorithmic Correctness"
  ERRORS="${ERRORS}\n    Il report deve includere analisi delle precondizioni algoritmiche"
fi

if [ -n "$ERRORS" ]; then
  echo "BLOCCATO: research report incompleto ($FILE_PATH)" >&2
  echo -e "$ERRORS" >&2
  echo "" >&2
  echo "Usa 'research_validate_paper' per ogni paper, poi riscrivi il report." >&2
  exit 2
fi

exit 0
