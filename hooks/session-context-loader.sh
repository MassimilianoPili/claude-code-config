#!/bin/bash
# Hook: session-context-loader.sh
# Evento: SessionStart (matcher: startup)
# Carica contesto del server SOL all'avvio sessione
# L'output su stdout diventa contesto per Claude

# Marker temporale per readme-update-reminder.sh (Stop hook)
touch /tmp/.claude-session-marker

echo "=== Contesto Server SOL ($(date '+%Y-%m-%d %H:%M:%S')) ==="
echo ""

# Container Docker attivi
echo "--- Container Docker attivi ---"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "(docker non raggiungibile)"
echo ""

# Servizi systemd user-level
echo "--- Servizi Host (systemd user) ---"
for svc in ttyd dashboard-api; do
  STATUS=$(systemctl --user is-active "$svc" 2>/dev/null || echo "unknown")
  echo "  $svc: $STATUS"
done
echo ""

# Spazio disco
echo "--- Spazio disco ---"
df -h /data 2>/dev/null | tail -1 || echo "(non disponibile)"
echo ""

# RAM
echo "--- Memoria ---"
free -h 2>/dev/null | grep -E '^Mem:' || echo "(non disponibile)"
echo ""

# SSH Agent (servizio systemd ssh-agent.service)
echo "--- SSH Agent ---"
_SSH_SOCK="/run/user/$(id -u)/ssh-agent.sock"
if [ -S "$_SSH_SOCK" ]; then
    export SSH_AUTH_SOCK="$_SSH_SOCK"
    if ssh-add -l >/dev/null 2>&1; then
        echo "  Agent attivo, chiave caricata"
    else
        echo "  Agent attivo, NESSUNA chiave — eseguire: ssh-ensure"
    fi
else
    echo "  ERRORE: socket non trovato — eseguire: systemctl --user start ssh-agent"
fi
echo ""

exit 0