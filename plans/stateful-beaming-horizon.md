# Piano: Pattern Agent-Framework → Claude Code Globale

## Context

L'agent-framework (`/data/massimiliano/agent-framework/`) implementa un sistema multi-agent con pattern architetturali sofisticati: event sourcing, policy enforcement a 3 livelli, compensation/self-healing, phase state machine, token budget management. Il documento `PIANO_FASE_CC.md` mappa 28 pattern Claude Code (P1-P28) per il framework.

Questo piano va nella **direzione opposta**: portare le intuizioni del framework nel setup Claude Code globale (`~/.claude/`), adattandole al contesto single-user.

**Stato attuale**: 22 hook, 41 plugin, 102 skill. Infrastruttura matura con PostgreSQL (chat_sessions, tool_outcomes), Redis DB 5 (session registry, drift counters), audit logging.

---

## Gap Analysis — Cosa manca nel Claude Code globale

| Pattern Framework | Stato Globale | Gap |
|---|---|---|
| Unified JSONL audit trail (hash chain) | `command-audit-log.sh` solo Bash (testo), `tool-outcome-tracker.sh` solo MCP (PG) | Audit frammentato, nessuna visione unificata |
| Secret scan su file staged (Stop) | `scan-secrets-in-content.sh` solo su Edit/Write content | File modificati via Bash bypassano il check |
| Phase state machine | Nessuno | Nessuna consapevolezza della fase di lavoro |
| Token budget pre-estimation | Nessuno | Compattazione sorprende sempre |
| Failure compensation | Nessuno | Dopo un errore Bash, serve prompt manuale per rimediare |
| Pattern-based drift detection | `context-drift-detector.sh` conta solo tool calls senza TodoWrite | Non rileva drift specifici (builtin vs MCP, percorsi relativi) |
| Compact context persistent | `compact-context-preserver.sh` scrive in `/tmp/` | Perso al reboot, non disponibile al resume |

**Pattern SCARTATI** (utili solo multi-agent):
- enforce-ownership.sh, enforce-tool-allowlist.sh, enforce-mcp-allowlist.sh → dipendono da `AGENT_WORKER_TYPE`
- Council Advisory → `academic-researcher` già copre questo ruolo
- Worker Memory → MEMORY.md + KORE sufficienti
- Per-project session memory → KORE già copre

---

## Piano di Implementazione — 4 Wave

### Wave 1: Quick Wins (questa sessione)

#### 1.1 `unified-audit-log.sh` — Audit trail JSONL unificato
- **File**: `/data/massimiliano/.claude/hooks/unified-audit-log.sh`
- **Evento**: PostToolUse, matcher `.*`, async: true
- **Cosa fa**: Scrive una riga JSONL per OGNI tool call (non solo Bash/MCP)
- **Formato**: `{"ts":"ISO8601","session":"...","tool":"Edit","input_summary":"first 200 chars","exit_code":0,"hash":"sha256","prev_hash":"sha256"}`
- **Hash chain**: SHA-256(prev_hash|tool|ts|input_hash) — l'hash del record precedente è in `~/.claude/audit/.last-hash`
- **Rotazione**: 10MB, 3 file (.1, .2, .3) — stessa logica di `command-audit-log.sh`
- **Output**: `~/.claude/audit/audit.jsonl`
- **Sanitizzazione**: no secrets nell'input_summary (tronca, no .env content)
- **Sostituzione**: `command-audit-log.sh` diventa ridondante → rimuoverlo da settings.json
- **CLI verifica**: `/data/massimiliano/shell-scripts/bin/audit-verify` — ricalcola hash chain e segnala manomissioni

**Pseudocodice implementativo**:
```bash
#!/bin/bash
# unified-audit-log.sh — PostToolUse, matcher .*, async: true
# Ispirato a: agent-framework/.claude/hooks/audit-log.sh (JSONL + hash chain)

INPUT=$(cat)
SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT")
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
[ -z "$TOOL_NAME" ] && exit 0

AUDIT_DIR="$HOME/.claude/audit"
AUDIT_FILE="$AUDIT_DIR/audit.jsonl"
HASH_FILE="$AUDIT_DIR/.last-hash"
mkdir -p "$AUDIT_DIR"

# Timestamp ISO 8601 UTC
TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Input summary: primi 200 char, sanitizzato
# Per Bash: .tool_input.command, per Edit: .tool_input.file_path, per altri: troncato
case "$TOOL_NAME" in
  Bash)  INPUT_SUMMARY=$(jq -r '.tool_input.command // "" | .[0:200]' <<< "$INPUT") ;;
  Edit)  INPUT_SUMMARY=$(jq -r '(.tool_input.file_path // "") + " → " + (.tool_input.old_string // "" | .[0:100])' <<< "$INPUT") ;;
  Write) INPUT_SUMMARY=$(jq -r '.tool_input.file_path // "" | .[0:200]' <<< "$INPUT") ;;
  Read)  INPUT_SUMMARY=$(jq -r '.tool_input.file_path // "" | .[0:200]' <<< "$INPUT") ;;
  *)     INPUT_SUMMARY=$(jq -r '.tool_input | tostring | .[0:200]' <<< "$INPUT" 2>/dev/null || echo "{}") ;;
esac

# Filtro secrets: se il summary contiene pattern sensibili, censura
if echo "$INPUT_SUMMARY" | grep -qiE '(password|secret|token|AKIA|sk-ant-|ghp_)'; then
  INPUT_SUMMARY="[REDACTED — possible secret]"
fi

# Exit code (disponibile per Bash, 0 per altri)
EXIT_CODE=$(jq -r '.tool_result.exit_code // 0' <<< "$INPUT")

# Hash chain
PREV_HASH=$(cat "$HASH_FILE" 2>/dev/null || echo "genesis")
INPUT_HASH=$(echo -n "$INPUT_SUMMARY" | sha256sum | cut -d' ' -f1)
CURRENT_HASH=$(echo -n "${PREV_HASH}|${TOOL_NAME}|${TS}|${INPUT_HASH}" | sha256sum | cut -d' ' -f1)

# Rotazione log (10MB, 3 rotazioni)
if [ -f "$AUDIT_FILE" ]; then
  FILE_SIZE=$(stat -c%s "$AUDIT_FILE" 2>/dev/null || echo 0)
  if [ "$FILE_SIZE" -gt 10485760 ]; then
    [ -f "$AUDIT_FILE.2" ] && mv "$AUDIT_FILE.2" "$AUDIT_FILE.3"
    [ -f "$AUDIT_FILE.1" ] && mv "$AUDIT_FILE.1" "$AUDIT_FILE.2"
    mv "$AUDIT_FILE" "$AUDIT_FILE.1"
    # Reset hash chain alla rotazione
    PREV_HASH="genesis"
    CURRENT_HASH=$(echo -n "genesis|${TOOL_NAME}|${TS}|${INPUT_HASH}" | sha256sum | cut -d' ' -f1)
  fi
fi

# Scrivi riga JSONL
jq -cn \
  --arg ts "$TS" \
  --arg session "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  --arg input "$INPUT_SUMMARY" \
  --argjson exitCode "${EXIT_CODE:-0}" \
  --arg hash "$CURRENT_HASH" \
  --arg prevHash "$PREV_HASH" \
  '{ts:$ts, session:$session, tool:$tool, input_summary:$input, exit_code:$exitCode, hash:$hash, prev_hash:$prevHash}' \
  >> "$AUDIT_FILE"

# Aggiorna hash per prossimo record
echo -n "$CURRENT_HASH" > "$HASH_FILE"

exit 0
```

#### 1.2 `validate-staged-secrets.sh` — Secret scan su Stop
- **File**: `/data/massimiliano/.claude/hooks/validate-staged-secrets.sh`
- **Evento**: Stop (prima di session-registry.sh stop)
- **Cosa fa**: Scansiona `git diff --cached` e `git diff` per secrets pattern
- **Pattern**: stessi di `scan-secrets-in-content.sh` (PEM, AWS AKIA, gh tokens, connection strings, entropy H>4.5)
- **Aggiunta**: file `.env` staged → blocca sempre (mai committare .env)
- **Exit 2**: blocca stop, mostra file problematici
- **Non blocca**: se non siamo in un git repo, o se non ci sono file staged
- **Relazione**: complementa `scan-secrets-in-content.sh` (quello agisce PreToolUse su contenuto Edit/Write, questo agisce Stop su file staged)

**Pseudocodice implementativo**:
```bash
#!/bin/bash
# validate-staged-secrets.sh — Stop hook
# Ispirato a: agent-framework/.claude/hooks/validate-no-secrets.sh
# Complementa scan-secrets-in-content.sh (PreToolUse) con check finale su file staged

INPUT=$(cat)

# Anti-loop guard (come stop-reminder.sh)
STOP_HOOK_ACTIVE=$(jq -r '.stop_hook_active // false' <<< "$INPUT")
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

CWD=$(jq -r '.cwd // "."' <<< "$INPUT")

# Skip se non in git repo
git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null || exit 0

FINDINGS=""

# 1. Check file .env staged (mai committare .env)
ENV_FILES=$(git -C "$CWD" diff --cached --name-only 2>/dev/null | grep -E '\.env$|\.env\.' || true)
if [ -n "$ENV_FILES" ]; then
  FINDINGS="$FINDINGS\n- FILE .env STAGED: $ENV_FILES"
fi

# 2. Check estensioni sensibili staged
SENSITIVE_EXT=$(git -C "$CWD" diff --cached --name-only 2>/dev/null | grep -E '\.(key|pem|p12|credentials|secret)$' || true)
if [ -n "$SENSITIVE_EXT" ]; then
  FINDINGS="$FINDINGS\n- File sensibili staged: $SENSITIVE_EXT"
fi

# 3. Scan contenuto staged per pattern secrets
STAGED_CONTENT=$(git -C "$CWD" diff --cached 2>/dev/null || true)
if [ -n "$STAGED_CONTENT" ]; then
  # Solo righe aggiunte (iniziano con +, non +++)
  ADDED_LINES=$(echo "$STAGED_CONTENT" | grep '^+[^+]' | sed 's/^+//')

  # Pattern da scan-secrets-in-content.sh
  echo "$ADDED_LINES" | grep -q 'BEGIN.*PRIVATE KEY' && FINDINGS="$FINDINGS\n- Chiave privata PEM in staged content"
  echo "$ADDED_LINES" | grep -qE 'AKIA[0-9A-Z]{16}' && FINDINGS="$FINDINGS\n- AWS Access Key ID in staged content"
  echo "$ADDED_LINES" | grep -qE 'gh[pso]_[A-Za-z0-9]{20,}' && FINDINGS="$FINDINGS\n- GitHub token in staged content"
  echo "$ADDED_LINES" | grep -qE 'glpat-[A-Za-z0-9_-]{20,}' && FINDINGS="$FINDINGS\n- GitLab token in staged content"
  echo "$ADDED_LINES" | grep -qE 'sk-ant-[A-Za-z0-9_-]{20,}' && FINDINGS="$FINDINGS\n- Anthropic API key in staged content"
  echo "$ADDED_LINES" | grep -qE '(mongodb|postgresql|mysql|redis|amqp)://[^:]+:[^@]+@' && FINDINGS="$FINDINGS\n- Connection string con credenziali in staged content"

  # Password hardcodate
  echo "$ADDED_LINES" | grep -qiE '(password|passwd|secret)\s*[=:]\s*["\x27][^$\{][^"\x27]{4,}' && \
    FINDINGS="$FINDINGS\n- Password hardcodata in staged content"
fi

# 4. Anche file unstaged modificati (git diff senza --cached) — warning più leggero
UNSTAGED_CONTENT=$(git -C "$CWD" diff 2>/dev/null || true)
if [ -n "$UNSTAGED_CONTENT" ]; then
  UNSTAGED_ADDED=$(echo "$UNSTAGED_CONTENT" | grep '^+[^+]' | sed 's/^+//')
  echo "$UNSTAGED_ADDED" | grep -qE 'AKIA[0-9A-Z]{16}' && FINDINGS="$FINDINGS\n- [unstaged] AWS key in modifiche non staged"
  echo "$UNSTAGED_ADDED" | grep -q 'BEGIN.*PRIVATE KEY' && FINDINGS="$FINDINGS\n- [unstaged] Chiave PEM in modifiche non staged"
fi

if [ -n "$FINDINGS" ]; then
  jq -cn --arg reason "$(echo -e "SECRETS RILEVATI nei file:\n$FINDINGS\n\nRimuovere i secrets prima di terminare. Usare variabili d'ambiente o file .env (gitignored).")" \
    '{decision:"block", reason:$reason}'
  exit 0
fi

exit 0
```

#### 1.3 Merge pattern `eval` in `reversibility-guard.sh`
- **File**: `/data/massimiliano/.claude/hooks/reversibility-guard.sh`
- **Modifica**: aggiungere 2 pattern alla lista CAUTION_PATTERNS dopo la riga `'pkill'`:
```bash
  # Code injection via eval
  'eval\s+.*\$\('
  'eval\s+.*`'
```
- **Origine**: `block-destructive.sh` dell'agent-framework cattura `eval $(` che è un vettore di injection

#### 1.4 Aggiornamento `settings.json`
- **File**: `/data/massimiliano/claude-code-config/settings.json`

**Modifica 1** — PostToolUse Bash: rimuovere blocco `command-audit-log.sh`:
```json
// RIMUOVERE questo blocco (linee 271-280):
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "/data/massimiliano/.claude/hooks/command-audit-log.sh",
      "async": true
    }
  ]
}
```

**Modifica 2** — PostToolUse `.*`: aggiungere `unified-audit-log.sh` accanto a `context-drift-detector.sh`:
```json
{
  "matcher": ".*",
  "hooks": [
    {
      "type": "command",
      "command": "/data/massimiliano/.claude/hooks/context-drift-detector.sh",
      "async": true
    },
    {
      "type": "command",
      "command": "/data/massimiliano/.claude/hooks/unified-audit-log.sh",
      "async": true
    }
  ]
}
```

**Modifica 3** — Stop: aggiungere `validate-staged-secrets.sh` PRIMA di `session-registry.sh stop`:
```json
"Stop": [
  {
    "hooks": [
      { "type": "command", "command": "/data/massimiliano/.claude/hooks/stop-reminder.sh" },
      { "type": "command", "command": "/data/massimiliano/.claude/hooks/readme-update-reminder.sh" },
      { "type": "command", "command": "/data/massimiliano/.claude/hooks/validate-staged-secrets.sh" },
      { "type": "command", "command": "/data/massimiliano/.claude/hooks/session-registry.sh stop" },
      { "type": "command", "command": "/data/massimiliano/.claude/hooks/chat-tracker.sh stop", "async": true }
    ]
  }
]
```

**Dopo Wave 1**: eliminare il file `/data/massimiliano/.claude/hooks/command-audit-log.sh` (non più referenziato)

---

### Wave 2: Medium Effort, High Value

#### 2.1 `phase-tracker.sh` — Phase State Machine
- **File**: `/data/massimiliano/.claude/hooks/phase-tracker.sh`
- **Evento**: PostToolUse, matcher `.*`, async: true
- **Storage**: Redis DB 5
  - `claude:tools:<session_id>` — LIST delle ultime 20 tool call (RPUSH + LTRIM)
  - `claude:phase:<session_id>` — STRING con JSON `{phase, since, toolCount}`
  - TTL 4h su entrambe

**Pseudocodice**:
```bash
#!/bin/bash
# phase-tracker.sh — PostToolUse, matcher .*, async: true
# Ispirato a: agent-framework Phase State Machine (EXPLORING→IMPLEMENTING→VERIFYING→FINALIZING)

INPUT=$(cat)
TOOL_NAME=$(jq -r '.tool_name // empty' <<< "$INPUT")
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")
[ -z "$SESSION_ID" ] || [ -z "$TOOL_NAME" ] && exit 0

REDIS="docker exec redis redis-cli -n 5"
TOOLS_KEY="claude:tools:${SESSION_ID}"
PHASE_KEY="claude:phase:${SESSION_ID}"

# Append tool name, keep last 20
$REDIS RPUSH "$TOOLS_KEY" "$TOOL_NAME" >/dev/null 2>&1
$REDIS LTRIM "$TOOLS_KEY" -20 -1 >/dev/null 2>&1
$REDIS EXPIRE "$TOOLS_KEY" 14400 >/dev/null 2>&1

# Get last 20 tool calls
TOOLS=$($REDIS LRANGE "$TOOLS_KEY" 0 -1 2>/dev/null)
TOTAL=$(echo "$TOOLS" | wc -l)
[ "$TOTAL" -lt 5 ] && exit 0  # Non classificare con pochi dati

# Count tool categories
EXPLORE_COUNT=$(echo "$TOOLS" | grep -cE '^(Glob|Grep|Read|Agent)$' || echo 0)
IMPLEMENT_COUNT=$(echo "$TOOLS" | grep -cE '^(Edit|Write)$' || echo 0)
# Per Bash: classificare in base al contenuto del comando (heuristica semplice)
BASH_COUNT=$(echo "$TOOLS" | grep -c '^Bash$' || echo 0)
GIT_COUNT=$(echo "$TOOLS" | grep -c '^Bash$' || echo 0)  # Raffinato sotto

# Classificazione
EXPLORE_PCT=$((EXPLORE_COUNT * 100 / TOTAL))
IMPLEMENT_PCT=$((IMPLEMENT_COUNT * 100 / TOTAL))

if [ "$EXPLORE_PCT" -ge 60 ]; then
  NEW_PHASE="EXPLORING"
elif [ "$IMPLEMENT_PCT" -ge 40 ]; then
  NEW_PHASE="IMPLEMENTING"
elif [ "$BASH_COUNT" -ge $((TOTAL / 3)) ]; then
  NEW_PHASE="VERIFYING"
else
  NEW_PHASE="MIXED"
fi

# Leggi fase precedente
OLD_PHASE=$($REDIS GET "$PHASE_KEY" 2>/dev/null | jq -r '.phase // "UNKNOWN"' 2>/dev/null)

# Aggiorna solo se cambiata
if [ "$NEW_PHASE" != "$OLD_PHASE" ]; then
  TS=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  PHASE_JSON=$(jq -cn --arg phase "$NEW_PHASE" --arg since "$TS" --argjson count "$TOTAL" \
    '{phase:$phase, since:$since, toolCount:$count}')
  $REDIS SET "$PHASE_KEY" "$PHASE_JSON" EX 14400 >/dev/null 2>&1
fi

exit 0
```

#### 2.2 `context-pressure-estimator.sh` — Token Budget Warning
- **File**: `/data/massimiliano/.claude/hooks/context-pressure-estimator.sh`
- **Evento**: PostToolUse, matcher `.*`, async: true
- **Storage**: Redis DB 5, `claude:tokens:<session_id>` — counter INCRBY
- **Soglie**: 600K → warning, 750K → critico
- **Reset**: in session-context-loader.sh su startup

**Pseudocodice**:
```bash
#!/bin/bash
# context-pressure-estimator.sh — PostToolUse, matcher .*, async: true
# Ispirato a: agent-framework CompactingToolCallingManager (pre-call token budget check)

INPUT=$(cat)
SESSION_ID=$(jq -r '.session_id // empty' <<< "$INPUT")
[ -z "$SESSION_ID" ] && exit 0

REDIS="docker exec redis redis-cli -n 5"
KEY="claude:tokens:${SESSION_ID}"

# Stima token dal tool_response (chars / 4, approssimazione)
RESPONSE_LEN=$(jq -r '[.tool_response[]? | .text // "" | length] | add // 0' <<< "$INPUT")
TOKEN_EST=$((RESPONSE_LEN / 4))

# Anche tool_input contribuisce al contesto
INPUT_LEN=$(jq -r '.tool_input | tostring | length' <<< "$INPUT" 2>/dev/null || echo 0)
TOKEN_EST=$((TOKEN_EST + INPUT_LEN / 4))

# Incrementa counter
TOTAL=$($REDIS INCRBY "$KEY" "$TOKEN_EST" 2>/dev/null || echo 0)
$REDIS EXPIRE "$KEY" 14400 >/dev/null 2>&1  # 4h TTL

# Soglie di warning
WARN_THRESHOLD=600000
CRIT_THRESHOLD=750000

if [ "${TOTAL:-0}" -ge "$CRIT_THRESHOLD" ] 2>/dev/null; then
  echo "CONTESTO CRITICO: ~${TOTAL} token stimati (~$((TOTAL * 100 / 1000000))% del budget). Compattazione imminente. Salvare stato e considerare compattazione manuale." >&2
elif [ "${TOTAL:-0}" -ge "$WARN_THRESHOLD" ] 2>/dev/null; then
  echo "Contesto al ~$((TOTAL * 100 / 1000000))% (~${TOTAL} token stimati). Considerare compattazione o completare il lavoro corrente." >&2
fi

exit 0
```

**Modifica a `session-context-loader.sh`** — aggiungere reset token counter a fine script:
```bash
# Reset token pressure counter per nuova sessione
SESSION_ID="${CLAUDE_SESSION_ID:-unknown}"
docker exec redis redis-cli -n 5 DEL "claude:tokens:${SESSION_ID}" >/dev/null 2>&1
```
**Nota**: `CLAUDE_SESSION_ID` potrebbe non essere disponibile in SessionStart. Alternativa: il counter si auto-resetta con TTL 4h. Se non disponibile, skip il reset esplicito.

#### 2.3 `failure-advisor.sh` — Compensation/Auto-remediation
- **File**: `/data/massimiliano/.claude/hooks/failure-advisor.sh`
- **Evento**: PostToolUse, matcher Bash, async: false (suggerimento visibile nel contesto)
- **Integrazione DB**: `tool_outcomes.error_class` + `tool_outcomes.recovery_tool` (colonne esistenti, mai popolate)

**Pseudocodice**:
```bash
#!/bin/bash
# failure-advisor.sh — PostToolUse, matcher Bash, async: false
# Ispirato a: agent-framework COMPENSATOR_MANAGER (saga compensation pattern)
# Suggerisce rimedi per errori comuni. Non blocca mai.

INPUT=$(cat)
EXIT_CODE=$(jq -r '.tool_result.exit_code // 0' <<< "$INPUT")

# Solo per comandi falliti
[ "$EXIT_CODE" = "0" ] && exit 0

# Estrai output del comando (stderr + stdout combinati in tool_response)
OUTPUT=$(jq -r '.tool_response // "" | if type == "array" then .[0].text // "" else tostring end' <<< "$INPUT")
COMMAND=$(jq -r '.tool_input.command // ""' <<< "$INPUT")
SESSION_ID=$(jq -r '.session_id // "unknown"' <<< "$INPUT")

ADVICE=""
ERROR_CLASS=""
RECOVERY_TOOL=""

# --- Pattern matching per rimedi ---

if echo "$OUTPUT" | grep -qi "connection refused"; then
  ERROR_CLASS="connection_refused"
  # Estrai hostname/porta dal comando o output
  SERVICE=$(echo "$COMMAND" | grep -oE '(localhost|127\.0\.0\.1|[a-z][-a-z0-9]*):([0-9]+)' | head -1)
  ADVICE="Connessione rifiutata${SERVICE:+ a $SERVICE}. Verificare: docker ps --filter name=... oppure systemctl --user status <service>"
  RECOVERY_TOOL="docker_ps"

elif echo "$OUTPUT" | grep -qi "no space left on device"; then
  ERROR_CLASS="disk_full"
  ADVICE="Spazio disco esaurito. Verificare: df -h. Cleanup: docker system prune (con cautela)"
  RECOVERY_TOOL="df_cleanup"

elif echo "$OUTPUT" | grep -qi "permission denied"; then
  ERROR_CLASS="permission_denied"
  ADVICE="Permessi insufficienti. Verificare ownership: ls -la <path>. Se serve root, chiedere il comando sudo esatto."
  RECOVERY_TOOL="check_permissions"

elif echo "$OUTPUT" | grep -qiE "BUILD FAILURE|COMPILATION ERROR|compiler error"; then
  ERROR_CLASS="build_failure"
  ADVICE="Errore di compilazione. Analizzare il messaggio d'errore sopra e correggere il codice sorgente."
  RECOVERY_TOOL="fix_source"

elif echo "$OUTPUT" | grep -qi "address already in use"; then
  ERROR_CLASS="port_conflict"
  PORT=$(echo "$OUTPUT" | grep -oE ':[0-9]+' | head -1 | tr -d ':')
  ADVICE="Porta${PORT:+ $PORT} già in uso. Identificare: lsof -i :${PORT:-<porta>}"
  RECOVERY_TOOL="lsof_port"

elif echo "$OUTPUT" | grep -qi "OCI runtime"; then
  ERROR_CLASS="docker_runtime"
  ADVICE="Errore runtime Docker/OCI. Verificare: systemctl status docker, docker info"
  RECOVERY_TOOL="docker_check"

elif echo "$OUTPUT" | grep -qi "not found\|command not found"; then
  ERROR_CLASS="command_not_found"
  CMD=$(echo "$OUTPUT" | grep -oE '[a-z][-a-z0-9]*: (command )?not found' | head -1 | cut -d: -f1)
  ADVICE="Comando${CMD:+ '$CMD'} non trovato. Verificare PATH o installare il pacchetto."
  RECOVERY_TOOL="install_package"

elif echo "$OUTPUT" | grep -qi "timeout\|timed out"; then
  ERROR_CLASS="timeout"
  ADVICE="Timeout. Il servizio potrebbe essere sovraccarico o irraggiungibile. Riprovare dopo verifica stato."
  RECOVERY_TOOL="retry"

elif echo "$OUTPUT" | grep -qi "authentication\|unauthorized\|401\|403"; then
  ERROR_CLASS="auth_failure"
  ADVICE="Errore di autenticazione/autorizzazione. Verificare token/credenziali e permessi."
  RECOVERY_TOOL="check_auth"
fi

# --- Emetti suggerimento (se trovato) ---
if [ -n "$ADVICE" ]; then
  echo "Suggerimento: $ADVICE" >&2

  # Scrivi error_class e recovery_tool in tool_outcomes (fire-and-forget)
  if [ -n "$ERROR_CLASS" ]; then
    # Trova l'ultima riga tool_outcomes per questa sessione e aggiorna
    # Alternativa: INSERT diretto con i campi (il tool-outcome-tracker gestisce solo MCP)
    ERROR_CLASS_ESC="${ERROR_CLASS//\'/\'\'}"
    RECOVERY_TOOL_ESC="${RECOVERY_TOOL//\'/\'\'}"
    COMMAND_ESC="${COMMAND:0:200}"
    COMMAND_ESC="${COMMAND_ESC//\'/\'\'}"
    SESSION_ESC="${SESSION_ID//\'/\'\'}"

    SQL="INSERT INTO tool_outcomes (session_id, tool_name, success, latency_ms, error_message, error_class, recovery_tool) VALUES ('${SESSION_ESC}', 'bash:${COMMAND_ESC}', false, 0, '${ERROR_CLASS_ESC}', '${ERROR_CLASS_ESC}', '${RECOVERY_TOOL_ESC}');"
    docker exec -i postgres psql -U postgres -d embeddings -c "$SQL" >/dev/null 2>&1 &
  fi
fi

exit 0
```

#### 2.4 Enhance `context-drift-detector.sh` — Pattern-based reminders
- **File**: `/data/massimiliano/.claude/hooks/context-drift-detector.sh` (modifica in-place)
- **Logica attuale**: counter `claude:drift:<session_id>`, reset su TodoWrite, warning a 30
- **Nuovi counter Redis** (con TTL 2h ciascuno):
  - `claude:drift:<session_id>:web_builtin` — conta WebSearch/WebFetch builtin
  - `claude:drift:<session_id>:phase` — legge fase da phase-tracker per adattare soglia

**Modifiche al codice esistente**:
```bash
# DOPO il check TodoWrite (riga 22), PRIMA dell'INCR generale, aggiungere:

# --- Pattern: WebSearch/WebFetch builtin → usare MCP ---
if [ "$TOOL_NAME" = "WebSearch" ] || [ "$TOOL_NAME" = "WebFetch" ]; then
  WEB_COUNT=$($REDIS INCR "${KEY}:web_builtin" 2>/dev/null)
  $REDIS EXPIRE "${KEY}:web_builtin" 7200 >/dev/null 2>&1
  if [ "${WEB_COUNT:-0}" -ge 3 ] 2>/dev/null; then
    echo "Drift: ${WEB_COUNT} chiamate WebSearch/WebFetch builtin. Usare web_search/web_fetch MCP per failure isolation." >&2
    $REDIS DEL "${KEY}:web_builtin" >/dev/null 2>&1
  fi
fi

# --- Soglia adattiva per fase ---
# Legge fase da phase-tracker (se disponibile)
PHASE_JSON=$($REDIS GET "claude:phase:${SESSION_ID}" 2>/dev/null)
PHASE=$(echo "$PHASE_JSON" | jq -r '.phase // "UNKNOWN"' 2>/dev/null)
case "$PHASE" in
  EXPLORING)  THRESHOLD=50 ;;   # Esplorazione è naturalmente lunga
  VERIFYING)  THRESHOLD=20 ;;   # Verifica deve essere focalizzata
  *)          THRESHOLD=30 ;;   # Default (IMPLEMENTING, MIXED, UNKNOWN)
esac
```

#### 2.5 Aggiornamento `settings.json` per Wave 2
- **File**: `/data/massimiliano/claude-code-config/settings.json`

**PostToolUse matcher `.*`** — aggiungere 2 hook async:
```json
{
  "type": "command",
  "command": "/data/massimiliano/.claude/hooks/phase-tracker.sh",
  "async": true
},
{
  "type": "command",
  "command": "/data/massimiliano/.claude/hooks/context-pressure-estimator.sh",
  "async": true
}
```

**PostToolUse matcher `Bash`** — aggiungere failure-advisor (NON async, suggerimento visibile):
```json
{
  "matcher": "Bash",
  "hooks": [
    {
      "type": "command",
      "command": "/data/massimiliano/.claude/hooks/failure-advisor.sh"
    }
  ]
}
```
**Nota**: questo è un NUOVO blocco matcher Bash in PostToolUse (il vecchio command-audit-log è stato rimosso in Wave 1).

### Verifica Wave 2
1. `phase-tracker`: dopo 10 Read/Grep → `docker exec redis redis-cli -n 5 GET claude:phase:<session>` deve contenere `EXPLORING`
2. `context-pressure-estimator`: dopo molte tool call → verificare counter in Redis e warning su stderr
3. `failure-advisor`: eseguire `docker compose up -d` in directory senza docker-compose.yml → deve suggerire rimedio
4. `drift-detector`: usare WebSearch builtin 3 volte → deve suggerire MCP alternative

---

### Wave 3: Ambitious (sessioni successive)

#### 3.1 Enhanced Compact Context — Persistent + Restorer
- **Modifica**: `/data/massimiliano/.claude/hooks/compact-context-preserver.sh`
  - Oltre a `/tmp/`, scrive snapshot in Redis DB 5 `claude:compact:<session_id>` (TTL 24h)
  - Include: fase corrente (da 2.1), ultime 10 righe da audit.jsonl, file in lavorazione
- **Nuovo**: `/data/massimiliano/.claude/hooks/compact-context-restorer.sh`
  - Evento: SessionStart resume
  - Legge da Redis il last compact snapshot e lo stampa

#### 3.2 `audit-verify` CLI — Verifica integrità hash chain
- **File**: `/data/massimiliano/shell-scripts/bin/audit-verify`
- **Cosa fa**: Legge `audit.jsonl`, ricalcola SHA-256 chain, segnala record manomessi
- **Uso**: `audit-verify [--last N]` — verifica ultimi N record (default: tutti)

#### 3.3 Event-Sourced Session Replay (PostgreSQL)
- **Tabella**: `session_events` nel DB `embeddings`
  ```sql
  CREATE TABLE session_events (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    session_id TEXT NOT NULL,
    seq BIGSERIAL,
    event_type VARCHAR(64) NOT NULL,
    payload JSONB,
    occurred_at TIMESTAMPTZ DEFAULT now(),
    event_hash CHAR(64) NOT NULL,
    previous_hash CHAR(64) NOT NULL
  );
  CREATE INDEX idx_session_events_session ON session_events(session_id, seq);
  ```
- **Writer**: batch insert da audit.jsonl ogni 60s o al Stop (cron/hook)
- **CLI**: `/data/massimiliano/shell-scripts/bin/session-replay` — ricostruisce timeline sessione

---

## File da creare/modificare

### Nuovi file
| File | Wave | Descrizione |
|---|---|---|
| `.claude/hooks/unified-audit-log.sh` | 1 | Audit JSONL unificato con hash chain |
| `.claude/hooks/validate-staged-secrets.sh` | 1 | Secret scan su file staged (Stop) |
| `shell-scripts/bin/audit-verify` | 3 | CLI verifica integrità audit |
| `.claude/hooks/phase-tracker.sh` | 2 | Phase state machine |
| `.claude/hooks/context-pressure-estimator.sh` | 2 | Token budget warning |
| `.claude/hooks/failure-advisor.sh` | 2 | Compensation suggerimenti |
| `.claude/hooks/compact-context-restorer.sh` | 3 | Restore context post-compact |

### File da modificare
| File | Wave | Modifica |
|---|---|---|
| `claude-code-config/settings.json` | 1+2 | W1: +unified-audit, +validate-staged-secrets, -command-audit-log. W2: +phase-tracker, +pressure-estimator, +failure-advisor |
| `.claude/hooks/reversibility-guard.sh` | 1 | +pattern eval ✅ |
| `.claude/hooks/context-drift-detector.sh` | 2 | +web_builtin counter, +fase-aware threshold (legge da phase-tracker) |
| `.claude/hooks/compact-context-preserver.sh` | 3 | +Redis persistent snapshot |

### File da rimuovere (ridondanti dopo Wave 1)
| File | Motivo |
|---|---|
| `.claude/hooks/command-audit-log.sh` | Sostituito da `unified-audit-log.sh` |

---

## Verifica

### Wave 1
1. Creare i file, aggiornare settings.json
2. Avviare nuova sessione Claude Code → verificare che unified-audit-log.sh scriva in `~/.claude/audit/audit.jsonl`
3. Fare un Edit, un Bash, un MCP tool → verificare che tutti producano riga JSONL
4. Verificare hash chain: `jq -s '.[0].prev_hash == "genesis" and .[1].prev_hash == .[0].hash' audit.jsonl`
5. Testare validate-staged-secrets: `echo "AKIA1234567890123456" > /tmp/test-secret.txt && git add /tmp/test-secret.txt` → lo Stop hook deve bloccare
6. Testare eval pattern: `eval $(curl ...)` → reversibility-guard deve bloccare

### Wave 2
1. Dopo 20+ tool call, verificare che `redis-cli -n 5 GET claude:phase:<session>` ritorna JSON con fase corretta
2. Simulare sessione lunga → verificare warning token budget
3. Eseguire `docker compose up -d` su stack non attiva → failure-advisor deve suggerire `docker ps`
4. Usare `WebSearch` builtin 3+ volte → drift detector deve suggerire MCP

### Wave 3
1. Compattare sessione → verificare snapshot in Redis
2. Riprendere sessione → restorer deve stampare context
3. `audit-verify` su audit.jsonl → nessun errore hash
