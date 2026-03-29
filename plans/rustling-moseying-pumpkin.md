# Piano: Dashboard + READMEs + Centralizzazione Knowledge

## Contesto

La documentazione del Server SOL e' distribuita in 50+ file markdown sparsi in 15+ directory.
WikiJS ha un import manuale (import-docs.js, 47 file), la dashboard ha un servizio mancante (Ollama),
e non c'e' sincronizzazione automatica tra docs, Gitea e WikiJS.

L'utente vuole:
1. Dashboard aggiornata con tutti i servizi
2. READMEs aggiornati allo stato corrente
3. Knowledge centralizzata verso la wiki, con Gitea come hub di sincronizzazione automatica

## Architettura proposta

```
Service README.md (sorgente)
    | copia (sync script, timer ogni 30min)
    v
sol-docs repo (Gitea) ──── hub centrale ────
    |                                       |
    | WikiJS Git sync (bidirezionale)       | git clone/pull
    v                                       v
WikiJS (UI web, editing)            /data/massimiliano/docs/ (locale)
```

- **sol-docs** (Gitea repo) = single source of truth
- **WikiJS** Git sync bidirezionale: pull dal repo + push delle modifiche fatte via UI wiki
- **Sync script** (`docs-sync`): copia i README dei servizi dentro sol-docs e committa
- I service README restano nei loro directory (nessun symlink rotto nei repo Gitea)

---

## Fase 1: Dashboard — Aggiungere servizi mancanti

### 1.1 Aggiungere card Ollama nella sezione Infrastructure

File: `/data/massimiliano/proxy/home/index.html`

Aggiungere card statica dopo WireGuard VPN, prima della sezione Monitoring:

```html
<div class="card card-static">
  <div class="card-icon">&#129302;</div>
  <div class="card-body">
    <div class="card-title">Ollama <span class="badge badge-infra">Backend</span></div>
    <div class="card-desc">LLM inference server, modelli locali</div>
    <span class="card-port">ollama:11434</span>
  </div>
</div>
```

### 1.2 Aggiungere Ollama alla `infraMap`

Nella sezione JavaScript (~riga 1321), aggiungere:
```javascript
'ollama:11434':'ollama'
```

### 1.3 Ricreare nginx

```bash
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

### 1.4 Verifica

Aprire la dashboard e verificare che la card Ollama appaia con status dot funzionante.

**Nota**: nginx, jwt-gateway, oauth2-proxy, oauth2-proxy-public sono intenzionalmente esclusi
(infrastruttura interna, non servizi utente).

---

## Fase 2: Aggiornamento READMEs

### 2.1 Verificare e aggiornare `/data/massimiliano/README.md`

- Controllare tabella servizi vs `docker ps -a`
- Aggiungere Ollama se mancante
- Verificare porte, auth, memory limits

### 2.2 Verificare `/data/massimiliano/docs/*.md` (13 file)

File prioritari:
- `servizi-docker.md` — cross-reference con container attuali
- `rete-e-routing.md` — verificare routing table vs nginx.conf
- `security.md` — verificare client Keycloak e pattern auth
- `monitoraggio.md` — verificare Prometheus targets e Grafana
- `dashboard.md` — aggiornare conteggio card/sezioni
- `mcp-libraries.md` — verificare conteggio librerie
- `shell-scripts.md` — verificare script in bin/
- `indice.md` — aggiornare con nuova struttura centralizzata

### 2.3 Verificare service README

Ogni README va confrontato con il suo docker-compose.yml e la configurazione nginx attuale.

### 2.4 Aggiungere file mancanti dall'import

3 piani futuri non presenti in import-docs.js:
- `PIANO_CASTELLO_KAFKA_GODOT.md`
- `PIANO_KINDLE_GRAPH_ENRICHMENT.md`
- `PIANO_RSS_TO_KINDLE.md`

---

## Fase 3: Centralizzazione Knowledge

### 3.1 Ristrutturare il repo sol-docs

Creare subdirectory nel repo `/data/massimiliano/docs/`:

```
docs/
├── *.md                    (13 file operativi esistenti, invariati)
├── servizi/                (NUOVO: copie dei service README)
│   ├── proxy.md
│   ├── code-server.md
│   ├── monitoring.md
│   ├── wg-manager.md
│   ├── kp-manager.md
│   ├── claude-proxy.md
│   └── claude-remote.md
├── mcp/                    (NUOVO: copie dei README MCP)
│   ├── server.md
│   ├── spring-ai-reactive-tools.md
│   ├── azure-tools.md ... (12 file)
├── progetti/               (NUOVO: copie dei piani futuri)
│   ├── azure-cloud.md
│   ├── jira-cloud.md ... (8 file)
├── agent-framework/        (NUOVO: copie docs agent framework)
│   ├── overview.md
│   ├── piano.md
│   └── setup.md
└── misc/                   (NUOVO: altri doc)
    ├── graph-vector-piano.md
    ├── claude-code-config.md
    └── claude-shared-storage.md
```

I file nelle subdirectory sono **copie reali** (non symlink) perche' Git sync di WikiJS clona il repo
e i symlink apparirebbero come file di testo con il path target.

### 3.2 Creare lo script `docs-sync`

Nuovo script: `/data/massimiliano/shell-scripts/bin/docs-sync`

Funzionalita':
1. Legge una mappa sorgente → destinazione (stessa struttura di FILE_MAP in import-docs.js)
2. Per ogni file sorgente, confronta `mtime` con la copia in docs/
3. Se il sorgente e' piu' recente, copia e fa `git add`
4. Se ci sono modifiche, committa e push a Gitea
5. Flag `--dry-run` per simulazione

```bash
#!/bin/bash
# docs-sync — Sincronizza README dei servizi verso sol-docs repo
# Uso: docs-sync [--dry-run]

DOCS_DIR="/data/massimiliano/docs"
DRY_RUN=false
[[ "$1" == "--dry-run" ]] && DRY_RUN=true

# Mappa: sorgente -> destinazione relativa in docs/
declare -A SYNC_MAP=(
  # Servizi
  ["/data/massimiliano/proxy/README.md"]="servizi/proxy.md"
  ["/data/massimiliano/code-server/README.md"]="servizi/code-server.md"
  ["/data/massimiliano/monitoring/README.md"]="servizi/monitoring.md"
  ["/data/massimiliano/Vari/wg-manager/README.md"]="servizi/wg-manager.md"
  ["/data/massimiliano/Vari/kp-manager/README.md"]="servizi/kp-manager.md"
  ["/data/massimiliano/Vari/claude-proxy/README.md"]="servizi/claude-proxy.md"
  ["/data/massimiliano/Vari/claude-remote/README.md"]="servizi/claude-remote.md"
  # MCP Libraries (12 file)
  ["/data/massimiliano/Vari/mcp/README.md"]="mcp/server.md"
  ["/data/massimiliano/Vari/spring-ai-reactive-tools/README.md"]="mcp/spring-ai-reactive-tools.md"
  # ... (tutti i 12)
  # Progetti futuri (8 file)
  ["/data/massimiliano/progetti_futuri/PIANO_AZURE_CLOUD.md"]="progetti/azure-cloud.md"
  # ... (tutti gli 8)
  # Agent framework (3 file)
  ["/data/massimiliano/agent-framework/README.md"]="agent-framework/overview.md"
  # ... (tutti i 3)
  # Misc
  ["/data/massimiliano/graph_vector_piano.md"]="misc/graph-vector-piano.md"
  # ... (tutti i 3)
)

changed=0
for src in "${!SYNC_MAP[@]}"; do
  dst="$DOCS_DIR/${SYNC_MAP[$src]}"
  if [[ ! -f "$src" ]]; then continue; fi
  if [[ ! -f "$dst" ]] || [[ "$src" -nt "$dst" ]]; then
    ((changed++))
    if $DRY_RUN; then
      echo "[DRY] $src -> $dst"
    else
      mkdir -p "$(dirname "$dst")"
      cp "$src" "$dst"
      git -C "$DOCS_DIR" add "${SYNC_MAP[$src]}"
    fi
  fi
done

if [[ $changed -gt 0 ]] && ! $DRY_RUN; then
  git -C "$DOCS_DIR" commit -m "sync: aggiornamento da service README ($changed file)"
  git -C "$DOCS_DIR" push origin main
fi
echo "Sincronizzati: $changed file"
```

### 3.3 Creare timer systemd per docs-sync

`~/.config/systemd/user/docs-sync.service`:
```ini
[Unit]
Description=Sync service READMEs to sol-docs repo

[Service]
Type=oneshot
ExecStart=/data/massimiliano/shell-scripts/bin/docs-sync
```

`~/.config/systemd/user/docs-sync.timer`:
```ini
[Unit]
Description=Periodic docs sync (every 30 min)

[Timer]
OnCalendar=*:00/30
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now docs-sync.timer
```

### 3.4 Riconfigurare WikiJS Git sync (bidirezionale con sol-docs)

Cambiare la configurazione Git storage in WikiJS:

```bash
docker exec postgres psql -U wikijs -d wikijs -c "
UPDATE storage SET config = jsonb_set(
  jsonb_set(config, '{repoUrl}', '\"ssh://git@gitea:22/sol_root/sol-docs.git\"'),
  '{syncDirection}', '\"sync\"'
) WHERE key = 'git';"
```

**Nota**: Verificare che la deploy key SSH di WikiJS sia aggiunta come deploy key
nel repo `sol_root/sol-docs` su Gitea (con permessi write).

Dopo la modifica, riavviare WikiJS:
```bash
cd /data/massimiliano/wikijs && docker compose up -d --force-recreate
```

### 3.5 Refactoring import-docs.js (opzionale, per la migrazione iniziale)

Sostituire il FILE_MAP hardcoded con uno scanner di directory:

```javascript
function scanDocsDirectory(baseDir) {
  const entries = [];
  function walk(dir, prefix) {
    for (const item of fs.readdirSync(dir, { withFileTypes: true })) {
      if (item.name.startsWith('.')) continue;
      const fullPath = path.join(dir, item.name);
      if (item.isDirectory()) {
        walk(fullPath, prefix ? `${prefix}/${item.name}` : item.name);
      } else if (item.name.endsWith('.md')) {
        const pageName = item.name.replace(/\.md$/, '');
        const pagePath = prefix ? `${prefix}/${pageName}` : `docs/${pageName}`;
        entries.push({ src: fullPath, path: pagePath, tags: [prefix || 'docs'] });
      }
    }
  }
  walk(baseDir, '');
  return entries;
}
```

Questo rende l'aggiunta di nuovi doc automatica: basta copiare il file nella directory giusta.

### 3.6 Aggiornare indice.md

Riscrivere l'indice per riflettere la nuova struttura centralizzata con link alle subdirectory.

### 3.7 Commit e push

```bash
cd /data/massimiliano/docs
git add -A
git commit -m "feat: centralizzazione documentazione — struttura subdirectory per WikiJS sync"
git push origin main
```

---

## Ordine di esecuzione

1. **Fase 2** (README updates) — prima, perche' i contenuti devono essere corretti prima di centralizzarli
2. **Fase 1** (Dashboard) — indipendente, puo' andare in parallelo con Fase 2
3. **Fase 3** (Centralizzazione) — per ultima, costruisce sui README aggiornati:
   - 3.1: Creare struttura directory + copie iniziali
   - 3.2: Creare script docs-sync
   - 3.3: Timer systemd
   - 3.4: Riconfigurare WikiJS Git sync
   - 3.5: Refactoring import-docs.js (opzionale)
   - 3.6: Aggiornare indice.md
   - 3.7: Commit e push

## Verifica end-to-end

1. Dashboard: card Ollama visibile con status dot
2. docs-sync: `docs-sync --dry-run` mostra 0 file (tutto allineato)
3. WikiJS: pagine visibili su `wiki.massimilianopili.com`, navigate per categoria
4. Bidirezionale: editare una pagina in WikiJS → verificare che il commit appaia su sol-docs in Gitea
5. Reverse: editare un README di servizio → attendere timer (30 min) → verificare che la pagina wiki si aggiorni

## File critici

- `/data/massimiliano/proxy/home/index.html` — card Ollama + infraMap
- `/data/massimiliano/docs/` — repo sol-docs: nuove subdirectory + copie
- `/data/massimiliano/shell-scripts/bin/docs-sync` — script di sincronizzazione (NUOVO)
- `~/.config/systemd/user/docs-sync.{service,timer}` — timer systemd (NUOVO)
- `/data/massimiliano/wikijs/import-docs.js` — refactoring scanner directory (opzionale)
- `/data/massimiliano/docs/indice.md` — aggiornamento indice
- Configurazione WikiJS Git storage in PostgreSQL (tabella `storage`, key `git`)
