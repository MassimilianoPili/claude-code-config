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

# Escludi file che legittimamente contengono riferimenti a variabili
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
# Non controllare CLAUDE.md, docs, .md, settings.json (contengono descrizioni, non secrets reali)
if echo "$FILE_PATH" | grep -qE '\.(md|txt|json|sh)$|CLAUDE\.md'; then
  exit 0
fi

# Pattern secrets (solo valori hardcodati, non riferimenti a variabili)
# Cerca "password = valore" o "secret = valore" con valori letterali
SECRETS_FOUND=""

# Chiave privata PEM
if echo "$CONTENT" | grep -q 'BEGIN.*PRIVATE KEY'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- Chiave privata PEM rilevata"
fi

# Password hardcodate con valore letterale (non ${VAR} o $VAR)
# Cattura sia valori quotati: password="secret" che non quotati: password=secret123
if echo "$CONTENT" | grep -qiE '(password|passwd|pwd)\s*[=:]\s*["\x27][^$\{][^"\x27]{4,}'; then
  SECRETS_FOUND="$SECRETS_FOUND\n- Password hardcodata rilevata"
elif echo "$CONTENT" | grep -qiE '(password|passwd|pwd)\s*[=:]\s*[A-Za-z0-9][A-Za-z0-9!@#%^*+/._-]{5,}'; then
  # Escludi riferimenti a variabili ($VAR, ${VAR})
  if ! echo "$CONTENT" | grep -qiE '(password|passwd|pwd)\s*[=:]\s*[\$]'; then
    SECRETS_FOUND="$SECRETS_FOUND\n- Password hardcodata (non quotata) rilevata"
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

if [ -n "$SECRETS_FOUND" ]; then
  echo "ATTENZIONE: possibili secrets nel contenuto da scrivere" >&2
  echo -e "File: $FILE_PATH" >&2
  echo -e "Rilevati:$SECRETS_FOUND" >&2
  echo "Suggerimento: usa variabili d'ambiente o file .env separati." >&2
  exit 2
fi

exit 0
