# Piano: Completamento integrazione WireGuard VPN

## Contesto

Il container WireGuard (`wg-manager`) e la TUI Go (`wg-tui`) sono gia' stati implementati e funzionano. Anche README.md, CLAUDE.md e MEMORY.md sono stati aggiornati. Restano 3 task finali:

1. Aggiungere la card WireGuard alla dashboard home
2. Aggiungere WireGuard al diagramma architettura Mermaid
3. Inizializzare repo Git e pushare a Gitea

---

## Task 1: Card VPN nella dashboard home

**File**: `/data/massimiliano/proxy/home/index.html`

Aggiungere una card statica (senza link, come le altre card infra) nella sezione **Infrastructure** (linea ~569, dopo Tor Client e prima di `<div class="section-label">Monitoring</div>`).

**HTML da aggiungere** (dopo la card `tor-client`, prima della section Monitoring):

```html
<div class="card card-static">
  <div class="card-icon">&#128272;</div>
  <div class="card-body">
    <div class="card-title">WireGuard VPN <span class="badge badge-infra">Infra</span></div>
    <div class="card-desc">VPN tunnel, gestione peer via TUI host</div>
    <span class="card-port">wg-manager:51820</span>
  </div>
</div>
```

- Icona: `&#128272;` (chiave/lucchetto — 🔐)
- `card-static` + `badge-infra` come le altre card infrastruttura
- Nessun `<a>` perche' non ha web UI (solo TUI host)

**Aggiungere a infraMap** (linea ~1298, dentro l'oggetto JS):

```javascript
'wg-manager:51820':'wg-manager',
```

Questo permette al sistema SSE di mostrare il pallino verde/rosso anche su questa card.

---

## Task 2: Diagramma architettura Mermaid

**File**: `/data/massimiliano/proxy/home/architecture.html`

Aggiungere il nodo WireGuard nel subgraph **Infrastructure** (linea ~320-323).

**Modifiche al Mermaid flowchart**:

1. Nel subgraph `infra` (linea ~320), aggiungere il nodo:
   ```
   WgVPN["WireGuard VPN\nwg-manager\nUDP :51820"]
   ```

2. Aggiungere una connessione dall'entry point Internet (il traffico VPN arriva direttamente via UDP, non passa da nginx/Cloudflare):
   ```
   Internet -->|"UDP 51820"| WgVPN
   ```

3. Nella sezione classDef (linea ~405), applicare lo stile infra:
   ```
   class ... WgVPN infraStyle
   ```
   Aggiungere `WgVPN` alla riga esistente che applica `infraStyle`.

---

## Task 3: Git init + push a Gitea

**Directory**: `/data/massimiliano/Vari/wg-manager/`

1. `git init`
2. `git add` dei file (escludendo `data/` e `.env` gia' in `.gitignore`)
3. Commit iniziale
4. Creare repo su Gitea: `ssh git@gitea-local create-repo wg-manager` oppure via Gitea API
5. Aggiungere remote e push

---

## Verifica

1. **Dashboard**: ricaricare la pagina, la card WireGuard deve apparire nella sezione Infrastructure con pallino status
2. **Diagramma**: `/architecture.html` deve mostrare il nodo WireGuard nell'area Infrastructure, con freccia da Internet (UDP 51820)
3. **Gitea**: repo visibile su `https://sol.massimilianopili.com/git/sol_root/wg-manager`
