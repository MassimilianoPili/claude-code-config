#!/bin/bash
# Hook: auto-memory-corrections.sh
# Evento: UserPromptSubmit
# Detecta pattern di correzione utente e suggerisce di salvare come feedback memory
# Non salva automaticamente — solo suggerimento a Claude
# Ref: framework #140 (Human Correction Learning)

INPUT=$(cat 2>/dev/null || true)
PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // empty' 2>/dev/null)

[ -z "$PROMPT" ] && exit 0

# Pattern di correzione in italiano e inglese
if echo "$PROMPT" | grep -qiE '(no[, ] non cos[iì]|non fare|smetti di|instead do|don.t do that|stop doing|mai pi[uù]|non usare|evita di|preferisco|non voglio|sbagliato|wrong approach|that.s not what|non [eè] quello)'; then
  echo "Correzione utente rilevata. Considerare di salvare come feedback memory per sessioni future." >&2
fi

exit 0
