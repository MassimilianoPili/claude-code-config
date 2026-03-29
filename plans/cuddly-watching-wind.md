# Piano: Miglioramenti Watchdog Connettività

## Context

Il 19 marzo 2026 si sono verificati **2 episodi consecutivi** di perdita connettività Internet (~16:11 e ~17:10). In entrambi i casi:
- L'interfaccia WiFi (`wlp3s0`) restava UP, DNS locale funzionante
- UDP bloccato a livello ISP/router, latenza DERP da 300ms a 4000ms+
- Tailscale in flapping tra relay europei
- L'utente ha dovuto riavviare manualmente perché la connessione non tornava

Il watchdog attuale (`/usr/local/bin/tailscale-watchdog.sh`) ha una sola risposta: **reboot del server** dopo ~30 min. Ma il reboot è inutile quando il problema è ISP/router — il server funziona perfettamente.

## Miglioramenti proposti

### 1. Restart NetworkManager/WiFi prima del reboot
**Perché**: anche se l'interfaccia risulta UP, un ciclo down/up può forzare il router a riassegnare il lease DHCP e ristabilire il NAT. Molto meno distruttivo di un reboot.

**Implementazione**: aggiungere uno step intermedio nel watchdog:
- Fallimenti 1-2 (~0-10 min): solo log, attesa
- **Fallimenti 3-4 (~15-20 min): restart interfaccia WiFi** (`nmcli device disconnect wlp3s0 && sleep 3 && nmcli device connect wlp3s0`)
- Fallimenti 5: restart tailscaled (dopo il recovery rete)
- Fallimenti 6-11: reboot condizionale (invariato)
- Fallimenti 12+: reboot forzato (invariato)

### 2. Ridurre intervallo timer durante outage
**Perché**: 5 min tra check è troppo lento durante un'interruzione attiva. Servono 30 min per raggiungere la soglia reboot.

**Implementazione**: il watchdog scrive un file flag `/tmp/tailscale-watchdog-fast-mode` quando rileva il primo fallimento. Un **secondo timer** (`tailscale-watchdog-fast.timer`, `OnUnitActiveSec=1min`) controlla il flag e lancia il watchdog più frequentemente. Il timer normale (5 min) resta per lo steady-state.

**Alternativa più semplice**: ridurre il timer a 2 min e abbassare le soglie proporzionalmente. Pro: nessun timer aggiuntivo. Contro: più carico in steady-state (trascurabile).

### 3. Logging strutturato degli outage
**Perché**: serve uno storico per capire se è un pattern ricorrente (orario, durata, frequenza) e correlare con problemi ISP.

**Implementazione**: appendere a `/var/log/connectivity-outages.log` un record JSON per ogni outage:
```json
{"start":"2026-03-19T16:11:49","end":"2026-03-19T16:25:39","duration_min":14,"type":"isp","udp_blocked":true,"dns_ok":true,"recovery":"manual_reboot"}
```

### 4. Notifica push su outage
**Perché**: se non sei davanti al server, non sai che è giù finché non provi a connetterti.

**Implementazione**: al primo fallimento, tentare una notifica via canale alternativo (es. `curl` verso un webhook esterno prima che la connettività cada completamente, o via Tailscale se il peer è ancora raggiungibile).

### 5. Ping gateway locale come diagnostica
**Perché**: distinguere "router irraggiungibile" (WiFi/cavo) da "router raggiungibile ma Internet giù" (ISP).

**Implementazione**: aggiungere `ping -c 1 -W 2 192.168.1.1` come primo check. Se il gateway non risponde → problema locale (restart interfaccia). Se risponde ma Internet no → problema ISP (nessun reboot, solo log + notifica).

## File da modificare

- `/usr/local/bin/tailscale-watchdog.sh` — logica principale
- `/etc/systemd/system/tailscale-watchdog.timer` — eventuale riduzione intervallo
- (nuovo) `/etc/systemd/system/tailscale-watchdog-fast.timer` — solo se opzione timer doppio

## Approccio raccomandato

Implementare **#1 + #3 + #5** come primo step — massimo beneficio, minima complessità:
- Ping gateway per diagnostica (#5)
- Restart WiFi come step intermedio prima del reboot (#1)
- Log strutturato per tracking (#3)

Il #2 (timer veloce) e #4 (notifiche) sono utili ma secondari.

## Verifica

1. `tailscale-watchdog.sh --dry-run` — verifica logica senza azioni
2. Simulare outage: `sudo iptables -A OUTPUT -p udp -j DROP` → verificare che il watchdog faccia restart WiFi invece di reboot → `sudo iptables -D OUTPUT -p udp -j DROP`
3. Controllare `/var/log/connectivity-outages.log` dopo il test
