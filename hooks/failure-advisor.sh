#!/bin/bash
# Hook: failure-advisor.sh
# Evento: PostToolUse (matcher: Bash, async: false — suggerimento visibile nel contesto)
# Suggerisce rimedi per errori comuni nei comandi Bash falliti
# Ispirato a: agent-framework COMPENSATOR_MANAGER (saga compensation pattern)
# Integrazione: scrive error_class + recovery_tool in tool_outcomes (colonne gia' esistenti)

INPUT=$(cat)
EXIT_CODE=$(jq -r '.tool_result.exit_code // 0' <<< "$INPUT")

# Solo per comandi falliti
[ "$EXIT_CODE" = "0" ] && exit 0

# Estrai output e comando
OUTPUT=$(jq -r '.tool_response // "" | if type == "array" then .[0].text // "" else tostring end' <<< "$INPUT")
COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT")

# Limita output per pattern matching (primi 2000 char)
OUTPUT="${OUTPUT:0:2000}"

ADVICE=""
ERROR_CLASS=""
RECOVERY_TOOL=""

# --- Pattern matching per rimedi (ordine: piu' specifico prima) ---

if echo "$OUTPUT" | grep -qi "connection refused"; then
  ERROR_CLASS="connection_refused"
  SERVICE=$(echo "$COMMAND" | grep -oE '(localhost|127\.0\.0\.1|[a-z][-a-z0-9]*):([0-9]+)' | head -1)
  ADVICE="Connessione rifiutata${SERVICE:+ a $SERVICE}. Verificare: docker ps --filter name=... oppure systemctl --user status <service>"
  RECOVERY_TOOL="docker_ps"

elif echo "$OUTPUT" | grep -qi "no space left on device"; then
  ERROR_CLASS="disk_full"
  ADVICE="Spazio disco esaurito. Verificare: df -h. Cleanup: docker system prune (con cautela)"
  RECOVERY_TOOL="df_cleanup"

elif echo "$OUTPUT" | grep -qi "address already in use"; then
  ERROR_CLASS="port_conflict"
  PORT=$(echo "$OUTPUT" | grep -oE ':[0-9]+' | head -1 | tr -d ':')
  ADVICE="Porta${PORT:+ $PORT} gia' in uso. Identificare: lsof -i :${PORT:-<porta>}"
  RECOVERY_TOOL="lsof_port"

elif echo "$OUTPUT" | grep -qi "OCI runtime"; then
  ERROR_CLASS="docker_runtime"
  ADVICE="Errore runtime Docker/OCI. Verificare: systemctl status docker, docker info"
  RECOVERY_TOOL="docker_check"

elif echo "$OUTPUT" | grep -qiE "BUILD FAILURE|COMPILATION ERROR|compiler error"; then
  ERROR_CLASS="build_failure"
  ADVICE="Errore di compilazione. Analizzare il messaggio d'errore sopra e correggere il codice sorgente."
  RECOVERY_TOOL="fix_source"

elif echo "$OUTPUT" | grep -qi "permission denied"; then
  ERROR_CLASS="permission_denied"
  ADVICE="Permessi insufficienti. Verificare ownership: ls -la <path>. Se serve root, chiedere il comando sudo esatto."
  RECOVERY_TOOL="check_permissions"

elif echo "$OUTPUT" | grep -qiE "not found|command not found|No such file"; then
  ERROR_CLASS="not_found"
  CMD=$(echo "$OUTPUT" | grep -oiE '[a-z][-a-z0-9]*: (command )?not found' | head -1 | cut -d: -f1)
  ADVICE="Risorsa${CMD:+ \"$CMD\"} non trovata. Verificare PATH, nome file, o installare il pacchetto."
  RECOVERY_TOOL="check_path"

elif echo "$OUTPUT" | grep -qiE "timeout|timed out"; then
  ERROR_CLASS="timeout"
  ADVICE="Timeout. Il servizio potrebbe essere sovraccarico o irraggiungibile. Riprovare dopo verifica stato."
  RECOVERY_TOOL="retry"

elif echo "$OUTPUT" | grep -qiE "authentication|unauthorized|401|403"; then
  ERROR_CLASS="auth_failure"
  ADVICE="Errore di autenticazione/autorizzazione. Verificare token/credenziali e permessi."
  RECOVERY_TOOL="check_auth"

elif echo "$OUTPUT" | grep -qiE "out of memory|cannot allocate|OOM"; then
  ERROR_CLASS="oom"
  ADVICE="Memoria insufficiente. Verificare: free -h, docker stats. Considerare ridurre il carico."
  RECOVERY_TOOL="check_memory"

elif echo "$OUTPUT" | grep -qiE "network.*unreachable|name.*resolution|DNS"; then
  ERROR_CLASS="network"
  ADVICE="Problema di rete/DNS. Verificare: ping, docker network ls, resolver."
  RECOVERY_TOOL="check_network"
fi

# --- Emetti suggerimento (se trovato) ---
if [ -n "$ADVICE" ]; then
  echo "Suggerimento: $ADVICE" >&2

  # Scrivi error_class e recovery_tool in tool_outcomes (fire-and-forget)
  if [ -n "$ERROR_CLASS" ]; then
    ERROR_CLASS_ESC="${ERROR_CLASS//\'/\'\'}"
    RECOVERY_TOOL_ESC="${RECOVERY_TOOL//\'/\'\'}"
    COMMAND_SHORT="${COMMAND:0:200}"
    COMMAND_ESC="${COMMAND_SHORT//\'/\'\'}"
    SESSION_ESC="${SESSION_ID//\'/\'\'}"

    SQL="INSERT INTO tool_outcomes (session_id, tool_name, success, latency_ms, error_message, error_class, recovery_tool) VALUES ('${SESSION_ESC}', 'bash:${COMMAND_ESC}', false, 0, '${ERROR_CLASS_ESC}', '${ERROR_CLASS_ESC}', '${RECOVERY_TOOL_ESC}');"
    docker exec -i postgres psql -U postgres -d embeddings -c "$SQL" >/dev/null 2>&1 &
  fi
fi

exit 0