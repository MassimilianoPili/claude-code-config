# Cleanup automatico sessioni Claude — systemd timer

## Contesto

Sul server SOL girano spesso piu' sessioni Claude Code in parallelo (VS Code extension, terminale, code-server). Le sessioni vecchie restano attive consumando ~350-400 MB di RAM ciascuna. Serve un meccanismo esterno che faccia pulizia periodica delle sessioni **vecchie E non piu' utilizzate**.

**Storico centralizzato** (confermato): `~/.claude/projects` → `/data/massimiliano/claude-shared/`. SIGTERM e' graceful — la chat resta nello storico e si riprende con `claude --resume`.

## Logica di cleanup

Una sessione viene terminata se soddisfa ENTRAMBE le condizioni:
1. **Eta' > 4 ore** (wall clock time)
2. **Non utilizzata**: `PPID = 1` (processo orfano, parent morto) OPPURE `CPU% < 1.0` (idle)

Questo protegge sessioni vecchie ma ancora attive (CPU > 1% = sta elaborando).

## File da creare

### 1. Script: `/data/massimiliano/shell-scripts/bin/claude-cleanup`

```bash
#!/bin/bash
# claude-cleanup — Termina sessioni Claude Code vecchie e non utilizzate
# Uso: claude-cleanup [--dry-run] [--max-age HOURS]
#
# Condizioni per terminare:
#   1. Eta' > MAX_AGE_HOURS (default 4)
#   2. Processo orfano (PPID=1) oppure idle (CPU% < 1.0)

MAX_AGE_HOURS=4
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)   DRY_RUN=true; shift ;;
    --max-age)   MAX_AGE_HOURS="$2"; shift 2 ;;
    *)           shift ;;
  esac
done

MAX_AGE_SECS=$((MAX_AGE_HOURS * 3600))
KILLED=0

while IFS= read -r line; do
  PID=$(echo "$line" | awk '{print $1}')
  PPID_VAL=$(echo "$line" | awk '{print $2}')
  ELAPSED=$(echo "$line" | awk '{print $3}')
  CPU=$(echo "$line" | awk '{print $4}')
  [ -z "$PID" ] && continue

  # Converti etime (DD-hh:mm:ss / hh:mm:ss / mm:ss) in secondi
  SECS=0
  if [[ "$ELAPSED" =~ ([0-9]+)-([0-9]+):([0-9]+):([0-9]+) ]]; then
    SECS=$(( ${BASH_REMATCH[1]}*86400 + ${BASH_REMATCH[2]}*3600 + ${BASH_REMATCH[3]}*60 + ${BASH_REMATCH[4]} ))
  elif [[ "$ELAPSED" =~ ([0-9]+):([0-9]+):([0-9]+) ]]; then
    SECS=$(( ${BASH_REMATCH[1]}*3600 + ${BASH_REMATCH[2]}*60 + ${BASH_REMATCH[3]} ))
  elif [[ "$ELAPSED" =~ ([0-9]+):([0-9]+) ]]; then
    SECS=$(( ${BASH_REMATCH[1]}*60 + ${BASH_REMATCH[2]} ))
  fi

  # Condizione 1: troppo vecchio
  [ "$SECS" -lt "$MAX_AGE_SECS" ] && continue

  # Condizione 2: non utilizzato (orfano o idle)
  ORPHAN=false; IDLE=false
  [ "$PPID_VAL" = "1" ] && ORPHAN=true
  awk "BEGIN{exit ($CPU < 1.0) ? 0 : 1}" && IDLE=true

  if [ "$ORPHAN" = "true" ] || [ "$IDLE" = "true" ]; then
    REASON=""
    [ "$ORPHAN" = "true" ] && REASON="orphan"
    [ "$IDLE" = "true" ] && REASON="${REASON:+$REASON+}idle(${CPU}%)"
    if [ "$DRY_RUN" = "true" ]; then
      echo "[dry-run] would kill PID $PID (age: ${SECS}s, $REASON)"
    else
      kill "$PID" 2>/dev/null && KILLED=$((KILLED + 1)) && \
        echo "killed PID $PID (age: ${SECS}s, $REASON)"
    fi
  fi
done < <(ps -eo pid,ppid,etime,pcpu,args --no-headers | grep '[c]laude.*--stream-json')

[ "$KILLED" -gt 0 ] && echo "claude-cleanup: terminated $KILLED session(s)"
exit 0
```

### 2. Service: `~/.config/systemd/user/claude-cleanup.service`

```ini
[Unit]
Description=Cleanup stale Claude Code sessions

[Service]
Type=oneshot
ExecStart=/data/massimiliano/shell-scripts/bin/claude-cleanup
```

### 3. Timer: `~/.config/systemd/user/claude-cleanup.timer`

```ini
[Unit]
Description=Run Claude cleanup every 30 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=30min

[Install]
WantedBy=timers.target
```

## Attivazione

```bash
chmod +x /data/massimiliano/shell-scripts/bin/claude-cleanup
systemctl --user daemon-reload
systemctl --user enable --now claude-cleanup.timer
```

## Verifica

1. `claude-cleanup --dry-run` — mostra cosa verrebbe killato senza agire
2. `systemctl --user status claude-cleanup.timer` — timer attivo
3. `systemctl --user list-timers` — prossima esecuzione
4. `journalctl --user -u claude-cleanup` — log esecuzioni passate
