#!/bin/bash
# Hook: block-dangerous-commands.sh
# Evento: PreToolUse (matcher: Bash)
# Blocca comandi distruttivi prima che vengano eseguiti

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Normalizza spazi multipli per evitare bypass con "rm  -rf  /"
COMMAND_NORM=$(echo "$COMMAND" | tr -s ' ')

# Pattern comandi pericolosi
DANGEROUS_PATTERNS=(
  # rm ricorsivo forzato su path critici (cattura -rf, -fr, -r -f, --recursive --force)
  'rm\s+(-rf|-fr|-r\s+-f|-f\s+-r|--recursive\s+--force|--force\s+--recursive)\s+/'
  'rm\s+(-rf|-fr|-r\s+-f|-f\s+-r|--recursive\s+--force|--force\s+--recursive)\s+~'
  'rm\s+(-rf|-fr|-r\s+-f|-f\s+-r|--recursive\s+--force|--force\s+--recursive)\s+\.'
  'rm\s+(-rf|-fr|-r\s+-f|-f\s+-r|--recursive\s+--force|--force\s+--recursive)\s+\*'
  'rm\s+(-rf|-fr)\s+/data'
  'rm\s+(-rf|-fr)\s+/home'
  # rm via subshell
  '(bash|sh)\s+-c\s+.*rm\s+-(rf|fr)'
  # fork bomb
  ':\(\)\s*\{.*\}.*;\s*:'
  # formattazione disco
  'mkfs\.'
  # scrittura disco raw (solo device, non file normali)
  'dd\s+.*of=/dev/sd'
  'dd\s+.*of=/dev/nvme'
  '>\s*/dev/sd'
  # shutdown/reboot
  '\bshutdown\b'
  '\breboot\b'
  'systemctl poweroff'
  'systemctl reboot'
  '\binit [06]\b'
  # docker distruttivi
  'docker system prune -a'
  'docker compose down.*-v'
  'docker volume prune'
  'docker rm -f \$\(docker ps'
  'docker stop \$\(docker ps'
  'docker kill \$\(docker ps'
  # pipe da internet a shell
  'curl.*[|].*\b(ba)?sh\b'
  'wget.*[|].*\b(ba)?sh\b'
  # permessi pericolosi
  'chmod -R 777 /'
  'chown -R .* /'
  # firewall
  'iptables -F'
)

for pattern in "${DANGEROUS_PATTERNS[@]}"; do
  if echo "$COMMAND_NORM" | grep -qE "$pattern"; then
    echo "BLOCCATO: comando pericoloso rilevato (pattern: $pattern)" >&2
    echo "Comando: $COMMAND" >&2
    echo "Usa un'alternativa piu' sicura o chiedi conferma all'utente." >&2
    exit 2
  fi
done

exit 0