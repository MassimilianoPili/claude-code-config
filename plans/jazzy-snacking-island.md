# Piano: Esporre il Terminale Web sulla URL Pubblica — COMPLETATO

## Contesto

Il terminale web (xterm.js → WebSocket → dashboard-api → ttyd) è attualmente limitato alla Tailnet (porta 80 nginx). La sicurezza è già garantita da JWT Keycloak su ogni connessione WebSocket — il vincolo Tailscale era un layer aggiuntivo di difesa in profondità. L'utente vuole poter usare il terminale anche da `https://sol.massimilianopili.com/`.

Il backend (`dashboard-api/server.js`) **non richiede modifiche** — accetta già connessioni da qualsiasi origine purché il JWT sia valido, e supporta l'issuer pubblico (`https://sol.massimilianopili.com/auth/realms/sol`).

## Modifiche

### 1. nginx.conf — Aggiungere `/api/` al server block porta 8888

**File**: `/data/massimiliano/proxy/nginx.conf`

Nel server block porta 8888 (pubblico), attualmente c'è solo:
```nginx
# Dashboard API — solo endpoint note (JWT Keycloak, no terminal WebSocket)
location = /api/notes {
    proxy_pass http://host.docker.internal:7681/notes;
    ...
}
```

**Sostituire** con un blocco `/api/` completo (identico a quello su porta 80, riga 97-108), che copre sia le note che il WebSocket:

```nginx
# Dashboard API (terminal WebSocket + notes — JWT Keycloak)
location /api/ {
    proxy_pass http://host.docker.internal:7681/;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```

Il `location = /api/notes` (exact match) va **rimosso** perché il nuovo `location /api/` lo copre già.

### 2. index.html — Rimuovere la restrizione frontend

**File**: `/data/massimiliano/proxy/home/index.html`

Tre punti da modificare:

**a)** Righe ~508-511 — Rimuovere il blocco che nasconde la sezione terminale:
```javascript
// RIMUOVERE:
if (isPublic) {
  document.getElementById('terminal-section').style.display = 'none';
  document.getElementById('terminal-hint').style.display = '';
}
```

**b)** Righe ~486-492 — Rimuovere l'hint "solo Tailscale":
```html
<!-- RIMUOVERE: -->
<div id="terminal-hint" class="tailscale-hint" style="display:none">
  Terminal disponibile solo via <a href="http://100.86.46.84/">Tailscale</a>
</div>
```

**c)** Righe ~880-882 — Rimuovere il gate `if (!isPublic)` attorno all'inizializzazione del terminale:
```javascript
// DA:
if (!isPublic) {
  try { if (!window.termInitialized) initTerminal(); } catch(e) { ... }
}

// A:
try { if (!window.termInitialized) initTerminal(); } catch(e) { ... }
```

### 3. CLAUDE.md — Aggiornare documentazione

Aggiornare le sezioni che menzionano "solo Tailscale" per il terminale:
- Tabella routing (riga `/api/`): rimuovere nota "no terminal WebSocket" dalla porta 8888
- Sezione "Dashboard API > Sicurezza": aggiornare per riflettere che il terminale è ora anche pubblico
- Sezione "Frontend": rimuovere menzione di terminale nascosto su URL pubblica

## File coinvolti

| File | Tipo modifica |
|------|--------------|
| `/data/massimiliano/proxy/nginx.conf` | Sostituire `= /api/notes` con `/api/` + WebSocket (porta 8888) |
| `/data/massimiliano/proxy/home/index.html` | Rimuovere 3 blocchi di restrizione `isPublic` |
| `/data/massimiliano/CLAUDE.md` | Aggiornare documentazione (terminale ora pubblico) |

## Verifica

1. `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate`
2. Da browser pubblico (`https://sol.massimilianopili.com/`):
   - Login Keycloak
   - Verificare che la sezione Terminal sia visibile
   - Verificare che il WebSocket si connetta e il terminale funzioni
3. Da Tailscale (`http://100.86.46.84/`): verificare che tutto funzioni come prima
4. Controllare i log: `docker logs nginx --tail 20` e `journalctl --user -u dashboard-api --tail 20`
