# Sanitizzare la Home per Visitor — Senza Sandbox

## Context

Il visitor token della home dashboard gira contro l'infrastruttura reale. L'idea iniziale era un container sandbox isolato, ma l'analisi ha rivelato che il sistema ha **già 3 livelli di protezione** server-side. Mancano solo 2 cose: il force-model haiku per visitor e un rate limit ancora più aggressivo sulla chat AI.

### Stato attuale (già sicuro)

| Protezione | Client-side (HTML) | Server-side |
|---|---|---|
| Terminal bloccato | `accessLevel < 3` → messaggio | `isReadOnly()` → WS close 4403 |
| Notes read-only | `accessLevel < 3` → editor.readOnly | `isReadOnly()` → 403 su PUT |
| Token panel nascosto | `level < 4` → hidden | Nessun endpoint esposto |
| Chat rate limit | — | nginx `ai_vis_limit` 1r/s burst=2 |
| JWT required | — | dashboard-api verifica JWT, nginx auth_request |

### Gap da colmare

1. **Visitor può scegliere qualsiasi modello AI** (opus costa 75$/M output tokens vs haiku 4$/M)
2. **Rate limit 1r/s = ≈3600 req/giorno** — con opus, potrebbe costare $5-10/giorno se abusato
3. **Nessun badge visuale** che indica "modalità demo/visitor"

## Piano di implementazione

### 1. Force haiku per visitor (HTML)
**File**: `/data/massimiliano/proxy/home/index.html`

Nella funzione `sendMessage()` (riga ~1247), dopo aver letto il modello dal select, aggiungere:
```javascript
// Force haiku for visitor users
if (auth.getAccessLevel() <= 1) {
  model = 'claude-haiku-4-5-20251001';
}
```

Nascondere il model selector per visitor nella funzione `updateUI()`:
```javascript
document.getElementById('model-select').style.display = (auth.getAccessLevel() <= 1) ? 'none' : '';
```

### 2. Rate limit più aggressivo per visitor (nginx)
**File**: `/data/massimiliano/proxy/nginx.conf`

Ridurre il rate limit visitor da `1r/s` a qualcosa di più restrittivo. Opzioni:
- **Cambiare la zona esistente** `ai_vis_limit` da `rate=1r/s` a `rate=10r/m` (riga 82)
- Questo limita a ~600 req/giorno max, con haiku il costo massimo è trascurabile (~$0.10/giorno)

Modificare riga 82:
```nginx
limit_req_zone $ai_vis_key zone=ai_vis_limit:10m rate=10r/m;
```

### 3. Badge "Visitor" visuale (HTML, opzionale)
**File**: `/data/massimiliano/proxy/home/index.html`

Nella funzione `updateUI()`, quando l'utente è visitor, aggiungere un badge accanto al titolo:
```javascript
// Show visitor badge
var badge = document.getElementById('visitor-badge');
if (badge) badge.style.display = (auth.getAccessLevel() <= 1) ? 'inline' : 'none';
```

E nel markup HTML, accanto a `<h1>`:
```html
<span id="visitor-badge" style="display:none;font-size:12px;background:#ffa500;color:#000;padding:2px 8px;border-radius:4px;vertical-align:middle;margin-left:8px">VISITOR</span>
```

## File da modificare

1. `/data/massimiliano/proxy/home/index.html` — force haiku + hide model select + badge visitor
2. `/data/massimiliano/proxy/nginx.conf` — rate limit visitor più aggressivo (riga 82)

## Verifica

1. Login come visitor sulla home pubblica
2. Verificare che il model selector sia nascosto
3. Inviare un messaggio chat → deve usare haiku (verificare nel response header o nel testo)
4. Verificare che il badge "VISITOR" appaia
5. Inviare >10 messaggi in 1 minuto → deve ricevere 429
6. Verificare che terminal e notes write siano ancora bloccati (già funzionante)
7. `docker compose up -d nginx --force-recreate` per applicare le modifiche nginx
