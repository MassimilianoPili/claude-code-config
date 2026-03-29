# Piano: Aggiungere card Monitoring + Preference Sort alla Dashboard

## Contesto

La dashboard (`/data/massimiliano/proxy/home/index.html`) mostra 18 card per i servizi del server, ma mancano:
- **Preference Sort** (`/rank/`) — API attiva con route nginx, nessuna card cliccabile
- **Stack monitoring backend** (Prometheus, Loki, Vector, node-exporter, cAdvisor) — container attivi ma invisibili nella dashboard

L'obiettivo è dare visibilità completa a tutti i servizi: Preference Sort come card cliccabile (ha una UI), i backend monitoring come card statiche in una nuova sezione "Monitoring".

## File da modificare

**Unico file**: `/data/massimiliano/proxy/home/index.html`

## Modifiche (5 edit nello stesso file)

### 1. Card Preference Sort — sezione "APIs" (dopo riga 436)

Inserire dopo la card Claude Proxy (`</a>` riga 436), prima della section-label "Infrastructure" (riga 438):

```html
      <a class="card" id="link-rank">
        <div class="card-icon">&#127942;</div>
        <div class="card-body">
          <div class="card-title">Preference Sort <span class="badge badge-oidc">JWT</span></div>
          <div class="card-desc">Ranking tramite confronti a coppie, Bradley-Terry</div>
          <span class="card-port" id="port-rank"></span>
        </div>
      </a>
```

- Emoji: 🏆 (`&#127942;` trofeo — tema ranking)
- Badge: `badge-oidc` con testo "JWT" (stesso pattern di Docker Manager, riga 365)
- ID: `link-rank` / `port-rank`

### 2. Sezione "Monitoring" con 5 card statiche (dopo riga 483)

Inserire dopo l'ultima card Infrastructure (Gitea Runner, riga 483), prima del `</div>` chiusura (riga 485):

```html
      <div class="section-label">Monitoring</div>

      <div class="card card-static">
        <div class="card-icon">&#128293;</div>
        <div class="card-body">
          <div class="card-title">Prometheus <span class="badge badge-infra">Backend</span></div>
          <div class="card-desc">Metriche time-series, scrape 30s, retention 2d</div>
          <span class="card-port">prometheus:9090</span>
        </div>
      </div>

      <div class="card card-static">
        <div class="card-icon">&#128209;</div>
        <div class="card-body">
          <div class="card-title">Loki <span class="badge badge-infra">Backend</span></div>
          <div class="card-desc">Log aggregation, TSDB + filesystem, retention 72h</div>
          <span class="card-port">loki:3100</span>
        </div>
      </div>

      <div class="card card-static">
        <div class="card-icon">&#10148;</div>
        <div class="card-body">
          <div class="card-title">Vector <span class="badge badge-infra">Backend</span></div>
          <div class="card-desc">Log shipper, Docker logs e nginx verso Loki</div>
          <span class="card-port">vector</span>
        </div>
      </div>

      <div class="card card-static">
        <div class="card-icon">&#128268;</div>
        <div class="card-body">
          <div class="card-title">node-exporter <span class="badge badge-infra">Backend</span></div>
          <div class="card-desc">Metriche host: CPU, RAM, disco, rete</div>
          <span class="card-port">node-exporter:9100</span>
        </div>
      </div>

      <div class="card card-static">
        <div class="card-icon">&#128225;</div>
        <div class="card-body">
          <div class="card-title">cAdvisor <span class="badge badge-infra">Backend</span></div>
          <div class="card-desc">Metriche per-container Docker, risorse e limiti</div>
          <span class="card-port">cadvisor:8080</span>
        </div>
      </div>
```

Emoji scelti (tutti unici nel file):
- 🔥 Prometheus (fuoco — tema mitologico)
- 📋 Loki (clipboard — raccolta log)
- ➤ Vector (freccia — flusso dati)
- 🔌 node-exporter (plug — collegamento all'host)
- 📡 cAdvisor (satellite — monitoraggio remoto container)

### 3. Entry `rank` nell'oggetto `links` (riga 558)

Aggiungere virgola dopo `grafana` e nuova entry:

```javascript
  grafana:     { pub: '/grafana/',                   ts: ts + '/grafana/',                port: '/grafana/' },
  rank:        { pub: '/rank/',                      ts: ts + '/rank/',                   port: '/rank/' }
```

### 4. Entry `link-rank` in `svcMap` (riga 1153)

Aggiungere Preference Sort alla mappa status dot dei servizi interattivi:

```javascript
    'link-stats':'goaccess', 'link-grafana':'grafana', 'link-rank':'preference-sort'
```

### 5. Entry monitoring in `infraMap` (righe 1155-1158)

Aggiungere i 5 container monitoring alla mappa status dot delle card statiche:

```javascript
  var infraMap = {
    'mongodb:27017':'mongodb', 'postgres:5432':'postgres', 'redis:6379':'redis',
    'sol.cfargotunnel.com':'cloudflared', 'act_runner':'act-runner',
    'prometheus:9090':'prometheus', 'loki:3100':'loki', 'vector':'vector',
    'node-exporter:9100':'node-exporter', 'cadvisor:8080':'cadvisor'
  };
```

Le chiavi di `infraMap` devono corrispondere esattamente al testo nel `<span class="card-port">` delle card statiche.

## Verifica

1. `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate`
2. Aprire `http://100.86.46.84/` — verificare:
   - Sezione "APIs": 2 card (Claude Proxy + Preference Sort con status dot)
   - Sezione "Infrastructure": 5 card statiche (invariate)
   - Nuova sezione "Monitoring": 5 card statiche con status dot
3. Cliccare su Preference Sort — deve aprire `/rank/`
4. Status dot verdi su tutti i container attivi (SSE da `/server/status/stream`)
