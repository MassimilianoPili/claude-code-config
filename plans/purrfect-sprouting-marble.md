# Migliorie Hook Claude Code Esistenti

## Contesto

I 13 hook in `/data/massimiliano/.claude/hooks/` forniscono sicurezza, automazione e auditing per le sessioni Claude Code sul server SOL. Questa analisi identifica vulnerabilità e migliorie per gli hook esistenti.

---

## Analisi Hook Esistenti

### 1. `block-dangerous-commands.sh` (PreToolUse → Bash)

**Funzione**: Blocca comandi distruttivi (rm -rf, fork bomb, mkfs, docker prune, curl|sh, ecc.)

**Problemi trovati**:
- **Bypass con spazi/opzioni intermedie**: `rm  -r  -f /` o `rm --recursive --force /` non vengono catturati perché il pattern è letterale `rm -rf /`
- **Bypass con variabili**: `DIR=/; rm -rf $DIR` passa il controllo
- **Bypass con alias/subshell**: `bash -c "rm -rf /"` non viene catturato
- **Pattern `dd if=` troppo ampio**: blocca anche `dd if=/dev/zero of=./test.img` (uso legittimo per creare file di test)
- **Manca `docker compose down -v`**: rimuove volumi (dati permanenti), non catturato
- **Manca `docker volume prune`**: elimina tutti i volumi non in uso
- **Pattern escaped inutilmente**: `rm -rf \.` e `rm -rf \*` — il backslash non serve dentro stringa bash, `grep -qE` li interpreta come regex

**Migliorie proposte**:
```
- Normalizzare spazi multipli prima del match: COMMAND=$(echo "$COMMAND" | tr -s ' ')
- Aggiungere pattern per opzioni lunghe: 'rm\s+(-r\s+-f|-f\s+-r|--recursive\s+--force|--force\s+--recursive|-rf|-fr)\s+/'
- Aggiungere: 'docker compose down.*-v', 'docker volume prune', 'docker volume rm'
- Aggiungere: 'bash -c.*rm -rf', 'sh -c.*rm -rf' (subshell wrapper)
- Rimuovere backslash inutili dai pattern (\.  \*  \$)
- Pattern dd più preciso: 'dd if=.*/dev/sd' (solo scritture disco, non file normali)
```

---

### 2. `protect-sensitive-files.sh` (PreToolUse → Edit|Write)

**Funzione**: Blocca scrittura su .env, .pem, .key, /etc/, .ssh/, .gnupg/, credenziali

**Problemi trovati**:
- **Pattern `credentials` troppo generico**: blocca qualsiasi file con "credentials" nel path, incluso `docs/credentials-setup.md` (documentazione)
- **Pattern `/etc/` troppo ampio**: blocca anche `/etc/hosts` lookup che potrebbe essere utile (ma Write/Edit, non Read → OK)
- **Manca `id_rsa` / `id_ed25519`**: chiavi SSH fuori da `.ssh/` non catturate
- **Non cattura `.secrets`**: file convenzione comune per secrets
- **Non cattura `kubeconfig`**: file Kubernetes con credenziali
- **Manca `token` come nome file**: es. `runner-token.txt`

**Migliorie proposte**:
```
- Pattern credentials più specifico: 'credentials\.(json|yml|yaml|xml|properties)$'
- Aggiungere: 'id_(rsa|ed25519|ecdsa)' (chiavi SSH ovunque)
- Aggiungere: '\.secrets$', 'kubeconfig', '\.kube/config'
- Aggiungere: '/\.claude/settings\.json' (protegge la config di Claude Code stessa)
```

---

### 3. `scan-secrets-in-content.sh` (PreToolUse → Write|Edit)

**Funzione**: Scansiona contenuto per PEM keys, password hardcodate, API keys, AWS keys

**Problemi trovati**:
- **Esclusione `.sh` troppo ampia**: file shell con password hardcodate non vengono catturati (es. script che fa `export PASSWORD=supersecret`)
- **Esclusione `.json`**: un `config.json` con API key non viene controllato
- **Manca detection token JWT hardcodato**: pattern `eyJ...` (base64 JWT header)
- **Manca detection connection string**: `mongodb://user:pass@host`, `postgresql://user:pass@host`
- **Manca GitHub/GitLab token**: pattern `ghp_`, `glpat-`, `ghs_`
- **Manca Anthropic/OpenAI key**: pattern `sk-ant-`, `sk-`
- **Regex password non cattura YAML**: `password: myvalue` (spazio dopo `:`)

**Migliorie proposte**:
```
- Raffinare esclusioni: solo .md e .txt (non .json e .sh)
- Aggiungere pattern connection string: '(mongodb|postgresql|mysql|redis)://[^:]+:[^@]+@'
- Aggiungere GitHub/GitLab tokens: 'gh[ps]_[A-Za-z0-9]{36}', 'glpat-[A-Za-z0-9-]{20}'
- Aggiungere AI API keys: 'sk-ant-[A-Za-z0-9-]{20,}', 'sk-[A-Za-z0-9]{20,}'
- Aggiungere hardcoded JWT: 'eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.'
```

---

### 4. `git-push-guard.sh` (PreToolUse → Bash)

**Funzione**: Blocca force-push verso main/master

**Problemi trovati**:
- **Bypass con `--force-with-lease`**: non viene catturato da `--force|-f` (è tecnicamente meno pericoloso ma comunque rischioso su main)
- **Pattern `main|master` non ancorato**: cattura anche branch che CONTENGONO "main" (es. `feature/maintain-cache`) — falso positivo
- **Non cattura `git push --delete`**: eliminazione branch remoto non controllata
- **Non cattura `git push origin :branch`**: sintassi alternativa per delete

**Migliorie proposte**:
```
- Aggiungere --force-with-lease al pattern force: '(--force|--force-with-lease|-f\b)'
- Ancorare main/master come parola intera: '\b(main|master)\b'
- Aggiungere warning per push --delete: 'git push.*(--delete|:[a-z])'
```

---

### 5. `auto-shellcheck.sh` (PostToolUse → Edit|Write)

**Funzione**: Esegue shellcheck su file .sh modificati, riporta warning come context

**Stato**: Ben implementato, graceful fallback. Nessun bug.

**Migliorie minori**:
```
- Aggiungere file senza estensione con shebang: controllare prima riga per #!/bin/bash
- Aggiungere severity filter: shellcheck -S warning (ignora info/style per ridurre rumore)
```

---

### 6. `auto-gofmt.sh` (PostToolUse → Edit|Write)

**Funzione**: Formatta file .go con gofmt in-place

**Stato**: Funzionale e minimale. Nessun bug. Nessuna modifica necessaria.

---

### 7. `auto-stage.sh` (PostToolUse → Edit|Write)

**Funzione**: `git add` automatico dopo Edit/Write su file in repo git

**Problemi trovati**:
- **Conflitto con CLAUDE.md istruzioni**: CLAUDE.md dice "prefer adding specific files by name rather than git add -A", ma questo hook fa `git add` su ogni file editato — coerente con l'intent ma potrebbe aggiungere file che l'utente non vuole committare
- **Nessun filtro per file grandi**: potrebbe stagare un binary accidentale
- **Nessun output per Claude**: Claude non sa che il file è stato staged

**Migliorie proposte**:
```
- Aggiungere check dimensione file: skip se > 1MB (evita staging binari)
- Aggiungere check .gitignore: skip se il file è ignorato
- Feedback minimo a Claude via additionalContext (opzionale)
```

---

### 8. `command-audit-log.sh` (PostToolUse → Bash, async)

**Funzione**: Logga ogni comando Bash in `~/.claude/audit/commands.log`

**Problemi trovati**:
- **Manca exit code del comando**: non logga se il comando è riuscito o fallito
- **Manca output/stderr**: utile per audit post-mortem
- **Log cresce infinitamente**: nessuna rotazione
- **Formato poco parsabile**: timestamp e session_id nel log ma non strutturato (JSON sarebbe meglio per parsing)

**Migliorie proposte**:
```
- Aggiungere exit code: jq -r '.tool_result.exit_code // "?"'
- Aggiungere rotazione: se file > 10MB, rinomina .log.1 e ricrea
- Formato: [$TIMESTAMP] [$SESSION_ID] [exit=$EXIT_CODE] $COMMAND
```

---

### 9. `session-context-loader.sh` (SessionStart)

**Funzione**: Carica contesto Docker/systemd/disco/RAM all'avvio + crea marker sessione

**Stato**: Ben implementato, output conciso.

**Migliorie minori**:
```
- Aggiungere stato git dei repo principali (se utile)
- Aggiungere check health endpoint servizi critici (nginx, keycloak)
- Queste aggiunte rischiano di appesantire il contesto — valutare con cautela
```

---

### 10. `compact-context-preserver.sh` (PreCompact)

**Funzione**: Salva snapshot Docker/CWD/errori prima della compattazione

**Problemi trovati**:
- **Info limitate**: non salva stato git, file modificati, todo correnti
- **File sovrascrito ad ogni compact**: perde lo storico dei compact precedenti

**Migliorie proposte**:
```
- Aggiungere git status/diff stat della CWD
- Aggiungere lista file modificati nella sessione (find -newer marker)
- Usare append con separatore invece di sovrascrittura (o file con timestamp)
```

---

### 11. `config-audit.sh` (ConfigChange)

**Funzione**: Logga source e path delle modifiche config

**Problemi trovati**:
- **Non logga il contenuto della modifica**: sa che settings.json è cambiato, ma non cosa è cambiato
- **Nessuna rotazione log**

**Migliorie proposte**:
```
- Aggiungere diff se possibile (catturare before/after)
- Stessa rotazione del command-audit-log
```

---

### 12. `stop-reminder.sh` (Stop)

**Funzione**: Blocca stop se ci sono modifiche non committate

**Stato**: Ben progettato con anti-loop guard. Design solido.

**Migliorie minori**:
```
- Mostrare lista file modificati (non solo count) per contesto
- Limitare a 5-10 file per evitare messaggi enormi
```

---

### 13. `readme-update-reminder.sh` (Stop)

**Funzione**: Blocca stop se file infra modificati ma docs non aggiornate

**Stato**: Logica sofisticata, ben implementato con marker sessione.

**Problemi trovati**:
- **`find` costoso**: scansiona tutto /data/massimiliano ad ogni Stop
- **Pattern file infra hardcodati**: nuovi file tipo (es. `.toml`, `Caddyfile`) non catturati senza aggiornamento manuale

**Migliorie proposte**:
```
- Usare find con -maxdepth 3 per limitare la scansione
- Aggiungere .toml, .yaml al pattern infra
```

---

## Riepilogo Priorità

| Priorità | Hook | Impatto |
|----------|------|---------|
| **Alta** | block-dangerous-commands | Fix bypass con spazi, opzioni lunghe e subshell |
| **Alta** | scan-secrets-in-content | Pattern token moderni + ridurre esclusioni |
| **Alta** | git-push-guard | Fix falso positivo su branch con "main" nel nome |
| **Media** | protect-sensitive-files | Pattern credentials più specifico + chiavi SSH |
| **Media** | command-audit-log | Exit code + rotazione log |
| **Bassa** | auto-stage | Check dimensione + gitignore |
| **Bassa** | compact-context-preserver | Più contesto nel snapshot |
| **Bassa** | stop-reminder | Lista file nel messaggio |
| **Bassa** | readme-update-reminder | Limitare profondità find |

Hook senza modifiche: `auto-shellcheck.sh`, `auto-gofmt.sh`, `session-context-loader.sh`, `config-audit.sh`

## File da Modificare

- `/data/massimiliano/.claude/hooks/block-dangerous-commands.sh`
- `/data/massimiliano/.claude/hooks/scan-secrets-in-content.sh`
- `/data/massimiliano/.claude/hooks/git-push-guard.sh`
- `/data/massimiliano/.claude/hooks/protect-sensitive-files.sh`
- `/data/massimiliano/.claude/hooks/command-audit-log.sh`
- `/data/massimiliano/.claude/hooks/auto-stage.sh`
- `/data/massimiliano/.claude/hooks/compact-context-preserver.sh`
- `/data/massimiliano/.claude/hooks/stop-reminder.sh`
- `/data/massimiliano/.claude/hooks/readme-update-reminder.sh`

Documentazione da aggiornare dopo le modifiche:
- `CLAUDE.md` (sezione Claude Code Hooks — bug noti corretti)
- `MEMORY.md` (sezione Claude Code Hooks)

## Verifica

1. Testare ogni hook modificato con input simulato via `echo '{"tool_input":...}' | ./hook.sh`
2. Verificare che i pattern migliorati non producano falsi positivi sugli usi comuni
3. Verificare che nessun hook ritorni exit 2 su operazioni legittime
