#!/bin/bash
# Hook: block-dangerous-commands.sh
# Evento: PreToolUse (matcher: Bash)
# Blocca comandi distruttivi prima che vengano eseguiti

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Pattern comandi pericolosi (case-insensitive dove serve)
DANGEROUS_PATTERNS=(
  'rm -rf /'
  'rm -rf ~'
  'rm -rf \.'
  'rm -rf \*'
  ':(){ :|:& };:'        # fork bomb
  'mkfs\.'                # formattazione disco
  'dd if='                # scrittura disco raw
  '> /dev/sd'             # sovrascrittura disco
  'shutdown'
  'reboot'
  'systemctl poweroff'
  'systemctl reboot'
  'init 0'
  'init 6'
  'docker system prune -a'
  'docker rm -f \$(docker ps'
  'docker stop \$(docker ps'
  'docker kill \$(docker ps'
  'curl.*[|].*sh'         # pipe da internet a shell
  'curl.*[|].*bash'
  'wget.*[|].*sh'
  'wget.*[|].*bash'
  'chmod -R 777 /'
  'chown -R.*/'
  'iptables -F'           # flush firewall
  'rm -rf /data'
  'rm -rf /home'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "BLOCCATO: comando pericoloso rilevato (pattern: $pattern)" >&2
    echo "Comando: $COMMAND" >&2
    echo "Usa un'alternativa piu' sicura o chiedi conferma all'utente." >&2
    exit 2
  fi
done

exit 0
