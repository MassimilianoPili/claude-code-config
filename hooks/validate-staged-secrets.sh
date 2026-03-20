#!/bin/bash
# Hook: validate-staged-secrets.sh
# Evento: Stop (prima di session-registry.sh stop)
# Safety net finale: scansiona file staged/modificati in git per secrets
# Complementa scan-secrets-in-content.sh (PreToolUse su Edit/Write)
# Ispirato a: agent-framework/.claude/hooks/validate-no-secrets.sh

INPUT=$(cat)

# Anti-loop guard (come stop-reminder.sh)
STOP_HOOK_ACTIVE=$(jq -r '.stop_hook_active // false' <<< "$INPUT")
[ "$STOP_HOOK_ACTIVE" = "true" ] && exit 0

CWD=$(jq -r '.cwd // "."' <<< "$INPUT")

# Skip se non in git repo
git -C "$CWD" rev-parse --is-inside-work-tree &>/dev/null 2>&1 || exit 0

FINDINGS=""

# --- 1. File .env staged: blocca sempre ---
ENV_FILES=$(git -C "$CWD" diff --cached --name-only 2>/dev/null | grep -E '\.env$|\.env\.' || true)
if [ -n "$ENV_FILES" ]; then
  FINDINGS="${FINDINGS}\n- FILE .env STAGED (mai committare .env): ${ENV_FILES}"
fi

# --- 2. Estensioni sensibili staged ---
SENSITIVE_EXT=$(git -C "$CWD" diff --cached --name-only 2>/dev/null | grep -E '\.(key|pem|p12|pfx|credentials|secret|keystore|jks)$' || true)
if [ -n "$SENSITIVE_EXT" ]; then
  FINDINGS="${FINDINGS}\n- File sensibili staged: ${SENSITIVE_EXT}"
fi

# --- 3. Scan contenuto staged per pattern secrets ---
STAGED_CONTENT=$(git -C "$CWD" diff --cached 2>/dev/null || true)
if [ -n "$STAGED_CONTENT" ]; then
  # Solo righe aggiunte (+, escludi +++ headers)
  ADDED_LINES=$(echo "$STAGED_CONTENT" | grep '^+[^+]' | sed 's/^+//')

  # Pattern replicati da scan-secrets-in-content.sh
  echo "$ADDED_LINES" | grep -q 'BEGIN.*PRIVATE KEY' && \
    FINDINGS="${FINDINGS}\n- Chiave privata PEM in staged content"

  echo "$ADDED_LINES" | grep -qE 'AKIA[0-9A-Z]{16}' && \
    FINDINGS="${FINDINGS}\n- AWS Access Key ID in staged content"

  echo "$ADDED_LINES" | grep -qE 'gh[pso]_[A-Za-z0-9]{20,}' && \
    FINDINGS="${FINDINGS}\n- GitHub token in staged content"

  echo "$ADDED_LINES" | grep -qE 'glpat-[A-Za-z0-9_-]{20,}' && \
    FINDINGS="${FINDINGS}\n- GitLab token in staged content"

  echo "$ADDED_LINES" | grep -qE 'sk-ant-[A-Za-z0-9_-]{20,}' && \
    FINDINGS="${FINDINGS}\n- Anthropic API key in staged content"

  echo "$ADDED_LINES" | grep -qE 'sk-[A-Za-z0-9]{20,}' && \
    ! echo "$ADDED_LINES" | grep -qE 'sk-ant-' && \
    FINDINGS="${FINDINGS}\n- OpenAI API key in staged content"

  echo "$ADDED_LINES" | grep -qE '(mongodb|postgresql|mysql|redis|amqp)://[^:]+:[^@]+@' && \
    FINDINGS="${FINDINGS}\n- Connection string con credenziali in staged content"

  # Password/secret hardcodate (non variabili $VAR/${VAR})
  echo "$ADDED_LINES" | grep -qiE '(password|passwd|pwd|secret)\s*[=:]\s*["\x27][^$\{][^"\x27]{4,}' && \
    FINDINGS="${FINDINGS}\n- Password/secret hardcodata in staged content"
fi

# --- 4. Scan file unstaged modificati (warning leggero) ---
UNSTAGED_CONTENT=$(git -C "$CWD" diff 2>/dev/null || true)
if [ -n "$UNSTAGED_CONTENT" ]; then
  UNSTAGED_ADDED=$(echo "$UNSTAGED_CONTENT" | grep '^+[^+]' | sed 's/^+//')

  echo "$UNSTAGED_ADDED" | grep -qE 'AKIA[0-9A-Z]{16}' && \
    FINDINGS="${FINDINGS}\n- [unstaged] AWS key in modifiche non staged"

  echo "$UNSTAGED_ADDED" | grep -q 'BEGIN.*PRIVATE KEY' && \
    FINDINGS="${FINDINGS}\n- [unstaged] Chiave PEM in modifiche non staged"

  echo "$UNSTAGED_ADDED" | grep -qE '(mongodb|postgresql|mysql|redis|amqp)://[^:]+:[^@]+@' && \
    FINDINGS="${FINDINGS}\n- [unstaged] Connection string con credenziali"
fi

# --- Risultato ---
if [ -n "$FINDINGS" ]; then
  REASON=$(printf "SECRETS RILEVATI nei file git:\n%b\n\nRimuovere i secrets prima di terminare. Usare variabili d'ambiente o file .env (gitignored)." "$FINDINGS")
  jq -cn --arg reason "$REASON" '{decision:"block", reason:$reason}'
  exit 0
fi

exit 0