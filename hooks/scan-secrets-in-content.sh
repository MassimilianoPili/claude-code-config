#!/bin/bash
# Hook: scan-secrets-in-content.sh
# Evento: PreToolUse (matcher: Write|Edit)
# Scansiona il contenuto scritto per pattern di secrets hardcodati

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Estrai il contenuto da controllare in base al tool
if [ "$TOOL_NAME" = "Write" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.content // empty')
elif [ "$TOOL_NAME" = "Edit" ]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // empty')
else
  exit 0
fi

if [ -z "$CONTENT" ]; then
  exit 0
fi

# Escludi file che legittimamente contengono riferimenti a pattern
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
# Esclusi: docs (.md, .txt), file temporanei (/tmp/), hook stessi (.claude/hooks/)
if echo "$FILE_PATH" | grep -qE '\.(md|txt)$|CLAUDE\.md|^/tmp/|/\.claude/hooks/'; then
  exit 0
fi

# Pattern secrets (solo valori hardcodati, non riferimenti a variabili)
SECRETS_FOUND=""

# Chiave privata PEM
if echo "$CONTENT" | grep -q 'BEGIN.*PRIVATE KEY'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- Chiave privata PEM rilevata"
fi

# Password hardcodate con valore letterale (non ${VAR} o $VAR)
# Cattura valori quotati: password="secret", password: "secret"
if echo "$CONTENT" | grep -qiE '(password|passwd|pwd|secret)\s*[=:]\s*["\x27][^$\{][^"\x27]{4,}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- Password/secret hardcodata rilevata"
elif echo "$CONTENT" | grep -qiE '(password|passwd|pwd|secret)\s*[=:]\s*[A-Za-z0-9][A-Za-z0-9!@#%^*+/._-]{5,}'; then
  # Escludi riferimenti a variabili ($VAR, ${VAR})
  if ! echo "$CONTENT" | grep -qiE '(password|passwd|pwd|secret)\s*[=:]\s*[\$]'; then
    SECRETS_FOUND="$SECRETS_FOUND\n- Password/secret hardcodata (non quotata) rilevata"
  fi
fi

# API key con valore letterale
if echo "$CONTENT" | grep -qiE '(api_key|apikey|api-key)\s*[=:]\s*["\x27][^$\{][^"\x27]{8,}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- API key hardcodata rilevata"
fi

# AWS credentials
if echo "$CONTENT" | grep -qE 'AKIA[0-9A-Z]{16}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- AWS Access Key ID rilevato"
fi

# GitHub/GitLab tokens (ghp_ classic, ghs_ server-to-server, gho_ OAuth)
if echo "$CONTENT" | grep -qE 'gh[pso]_[A-Za-z0-9]{20,}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- GitHub token rilevato"
fi
if echo "$CONTENT" | grep -qE 'glpat-[A-Za-z0-9_-]{20,}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- GitLab token rilevato"
fi

# AI API keys (Anthropic, OpenAI)
if echo "$CONTENT" | grep -qE 'sk-ant-[A-Za-z0-9_-]{20,}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- Anthropic API key rilevata"
fi
if echo "$CONTENT" | grep -qE 'sk-[A-Za-z0-9]{20,}' | grep -qvE 'sk-ant-'; then
  # Solo se non e' gia' catturata come Anthropic key
  if ! echo "$CONTENT" | grep -qE 'sk-ant-'; then
    if echo "$CONTENT" | grep -qE 'sk-[A-Za-z0-9]{20,}'; then
      SECRETS_FOUND="$SECRETS_FOUND\n- OpenAI API key rilevata"
    fi
  fi
fi

# Connection string con credenziali embedded
if echo "$CONTENT" | grep -qE '(mongodb|postgresql|mysql|redis|amqp)://[^:]+:[^@]+@'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- Connection string con credenziali rilevata"
fi

# Layer 2: Entropy check per stringhe ad alta entropia (token/key casuali non catturati dai pattern)
# Shannon entropy > 4.5 su stringhe alfanumeriche > 20 char = probabile secret
calc_entropy() {
  local s="$1"
  local len=${#s}
  [ "$len" -lt 20 ] && echo "0" && return
  python3 -c "
import math, collections, sys
s = sys.argv[1]
freq = collections.Counter(s)
n = len(s)
h = -sum((c/n) * math.log2(c/n) for c in freq.values())
print(f'{h:.2f}')
" "$s" 2>/dev/null || echo "0"
}

# Estrai stringhe alfanumeriche lunghe (potenziali token/key) non gia' catturate dai pattern
HIGH_ENTROPY_FOUND=""
while IFS= read -r candidate; do
  [ -z "$candidate" ] && continue
  # Salta se gia' catturato dai pattern regex sopra
  echo "$candidate" | grep -qE '^(AKIA|gh[pso]_|glpat-|sk-ant-|sk-)' && continue
  # Salta riferimenti a variabili
  echo "$candidate" | grep -qE '^\$' && continue
  ENT=$(calc_entropy "$candidate")
  if [ "$(echo "$ENT > 4.5" | bc -l 2>/dev/null)" = "1" ]; then
    HIGH_ENTROPY_FOUND="$HIGH_ENTROPY_FOUND\n- Stringa ad alta entropia (H=${ENT}): ${candidate:0:12}..."
  fi
done < <(echo "$CONTENT" | grep -oE '[A-Za-z0-9+/=_-]{20,}' | head -10)

if [ -n "$HIGH_ENTROPY_FOUND" ]; then
  SECRETS_FOUND="$SECRETS_FOUND$HIGH_ENTROPY_FOUND"
fi

if [ -n "$SECRETS_FOUND" ]; then
  echo "ATTENZIONE: possibili secrets nel contenuto da scrivere" >&2
  echo -e "File: $FILE_PATH" >&2
  echo -e "Rilevati:$SECRETS_FOUND" >&2
  echo "Suggerimento: usa variabili d'ambiente o file .env separati." >&2
  exit 2
fi

exit 0