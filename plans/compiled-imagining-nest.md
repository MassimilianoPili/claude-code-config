# Fix terminale dashboard — COMPLETATO, commit pendente

## Contesto

Il terminale web della dashboard mostra un cursore lampeggiante ma nessun prompt e non accetta input. Due cause identificate:

1. **CDN xterm.js 404** (già fixato): il pacchetto npm `xterm` → `@xterm/xterm` (scoped rename dalla v5.4.0+)
2. **Protocollo ttyd incompatibile**: il codice usa type bytes binari (0, 1, 2) ma ttyd 1.7.7 usa ASCII ('0'=48, '1'=49, '2'=50). Inoltre manca l'init handshake e il subprotocollo `["tty"]`.

### Protocollo ttyd 1.7.7 (verificato da source client nativo)

**Init (client → server, una volta sola su open):**
- Messaggio JSON plain (NO type byte): `{AuthToken: "", columns: N, rows: N}`
- Subprotocollo WebSocket: `["tty"]`

**Dopo l'init — Server → Client:**
- byte `48` ('0') + dati = output PTY
- byte `49` ('1') + stringa = titolo finestra
- byte `50` ('2') + JSON = preferenze

**Dopo l'init — Client → Server:**
- byte `48` ('0') + dati = input stdin
- byte `49` ('1') + JSON = resize `{columns, rows}`

## File da modificare

### 1. `/data/massimiliano/dashboard-api/server.js` (riga 162)

Aggiungere subprotocollo `["tty"]` e init handshake su ttyd open:

```javascript
// PRIMA:
const ttydWs = new WebSocket(TTYD_WS);
ttydWs.on('open', () => {
    // Drain any buffered messages would go here if needed
});

// DOPO:
const ttydWs = new WebSocket(TTYD_WS, ['tty']);
ttydWs.on('open', () => {
    // ttyd 1.7.7: init handshake — JSON senza type byte prefix
    const init = JSON.stringify({ AuthToken: '', columns: 80, rows: 24 });
    ttydWs.send(Buffer.from(init, 'utf8'));
});
```

### 2. `/data/massimiliano/proxy/home/index.html`

**a) Output handler (riga ~1261)** — type check da binario ad ASCII:
```javascript
// PRIMA:
if (type === 0) { term.write(payload); }

// DOPO:
if (type === 48) { term.write(payload); }  // ASCII '0'
```

**b) Resize su onopen (riga ~1253)** — type byte da binario ad ASCII:
```javascript
// PRIMA:
buf[0] = 1;

// DOPO:
buf[0] = 49;  // ASCII '1'
```

**c) Input handler (riga ~1283)** — type byte da binario ad ASCII:
```javascript
// PRIMA:
buf[0] = 0;

// DOPO:
buf[0] = 48;  // ASCII '0'
```

**d) Onclose handler (riga ~1273)** — type byte nel messaggio visitor:
Nessuna modifica (il close message è scritto con term.write, non inviato al server).

## Verifica

1. `systemctl --user restart dashboard-api` (server.js modificato)
2. `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate` (index.html modificato)
3. Aprire `https://sol.massimilianopili.com/` → Login → verificare prompt bash visibile
4. Digitare `whoami` → deve mostrare `massimiliano`
5. Ridimensionare la finestra → il terminale deve adattarsi (resize)
6. Network tab: WebSocket deve mostrare dati che fluiscono
