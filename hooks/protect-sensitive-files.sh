#!/bin/bash
# Hook: protect-sensitive-files.sh
# Evento: PreToolUse (matcher: Edit|Write)
# Blocca modifiche a file sensibili (secrets, chiavi, configurazioni critiche)

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Pattern file protetti
PROTECTED_PATTERNS=(
  '\.env$'                          # File .env (esatti)
  '\.env\.'                         # .env.local, .env.production, etc.
  '\.pem$'                          # Certificati
  '\.key$'                          # Chiavi private
  '\.p12$'                          # Keystore PKCS12
  '\.jks$'                          # Java keystore
  '/\.ssh/'                         # Directory SSH
  '/\.gnupg/'                       # Directory GPG
  '/cloudflared/.*\.json$'          # Credenziali tunnel
  '/cloudflared/cert\.pem'          # Certificato tunnel
  'credentials'                     # File con "credentials" nel nome
  '/etc/'                           # File di sistema
  '/keycloak/\.env'                 # Specifico: password Keycloak
  '/postgres/\.env'                 # Specifico: password PostgreSQL
  '/mongodb/\.env'                  # Specifico: password MongoDB
  '/artemis/\.env'                  # Specifico: password Artemis
  '/pgadmin/\.env'                  # Specifico: password pgAdmin
  '/proxy/\.env'                    # Specifico: cookie secrets OAuth2
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
  if echo "$FILE_PATH" | grep -qE "$pattern"; then
    echo "BLOCCATO: modifica a file sensibile non permessa" >&2
    echo "File: $FILE_PATH" >&2
    echo "Pattern: $pattern" >&2
    echo "Per modificare file .env o secrets, fallo manualmente o chiedi conferma all'utente." >&2
    exit 2
  fi
done

exit 0
