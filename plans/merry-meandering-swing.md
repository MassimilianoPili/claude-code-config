# Piano: Aggiornamento README + Fix SSH per Claude Code

## Contesto

Nella sessione precedente abbiamo scoperto che **gpg-agent SSH emulation e' incompatibile con OpenSSH 8.9+** (estensione `hostbound-v00`). La firma SSH fallisce con "agent refused operation" nonostante la chiave sia caricata. Il workaround e' stato un `ssh-agent` temporaneo, ma svanisce al termine della sessione.

**Obiettivo**: rendere SSH funzionante automaticamente per tutte le sessioni future (Claude Code, terminale web, SSH diretta) e aggiornare il README con il riferimento ai docs.

---

## 1. Creare servizio systemd `ssh-agent.service`

**File**: `~/.config/systemd/user/ssh-agent.service`

Un `ssh-agent` standard persistente come servizio user-level. Socket a path fisso `$XDG_RUNTIME_DIR/ssh-agent.sock` (= `/run/user/1000/ssh-agent.sock`).

```ini
[Unit]
Description=SSH Agent (persistent)

[Service]
Type=simple
ExecStart=/usr/bin/ssh-agent -D -a %t/ssh-agent.sock
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
```

**Attivazione** (utente, richiede comando manuale):
```bash
systemctl --user enable --now ssh-agent.service
```

---

## 2. Aggiornare `.bashrc` — puntare al nuovo ssh-agent

**File**: `~/.bashrc` (righe 5-11)

Da:
```bash
# --- SSH Agent (gpg-agent SSH emulation) ---
_GPG_SSH_SOCK="/run/user/$(id -u)/gnupg/S.gpg-agent.ssh"
if [ -S "$_GPG_SSH_SOCK" ]; then
    export SSH_AUTH_SOCK="$_GPG_SSH_SOCK"
fi
unset _GPG_SSH_SOCK
```

A:
```bash
# --- SSH Agent (servizio systemd user-level) ---
# Socket fisso: non dipende da gpg-agent (incompatibile con OpenSSH 8.9+ hostbound-v00)
_SSH_SOCK="/run/user/$(id -u)/ssh-agent.sock"
if [ -S "$_SSH_SOCK" ]; then
    export SSH_AUTH_SOCK="$_SSH_SOCK"
fi
unset _SSH_SOCK
```

---

## 3. Aggiornare `.profile` — stesso cambio

**File**: `~/.profile` (righe 30-34)

Stessa modifica di `.bashrc`: puntare a `/run/user/$(id -u)/ssh-agent.sock`.

---

## 4. Aggiornare `ssh-ensure`

**File**: `/data/massimiliano/shell-scripts/bin/ssh-ensure`

Modifiche:
- Cambiare `SOCK` da gpg-agent a ssh-agent: `/run/user/$(id -u)/ssh-agent.sock`
- Rimuovere i riferimenti a gpg-agent
- Aggiungere check: se il servizio systemd non e' attivo, suggerire `systemctl --user start ssh-agent`
- Mantenere la stessa interfaccia (`--quiet`)

---

## 5. Aggiornare `session-context-loader.sh`

**File**: `/data/massimiliano/.claude/hooks/session-context-loader.sh`

Aggiungere sezione SSH dopo i container Docker:
```bash
# SSH Agent status
echo "--- SSH Agent ---"
_SSH_SOCK="/run/user/$(id -u)/ssh-agent.sock"
if [ -S "$_SSH_SOCK" ]; then
    export SSH_AUTH_SOCK="$_SSH_SOCK"
    KEYS=$(ssh-add -l 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "  Agent attivo, chiave caricata"
    else
        echo "  Agent attivo, NESSUNA chiave — eseguire: ssh-ensure"
    fi
else
    echo "  ERRORE: socket non trovato — eseguire: systemctl --user start ssh-agent"
fi
echo ""
```

---

## 6. Aggiornare `.ssh/config`

**File**: `~/.ssh/config`

Rimuovere `IdentityAgent none` da `Host gitea-local` — non piu' necessario perche' non usiamo piu' gpg-agent per SSH.

---

## 7. Rimuovere `enable-ssh-support` da gpg-agent.conf

**File**: `~/.gnupg/gpg-agent.conf`

Rimuovere le righe relative a SSH (righe 1-2 e 4-8):
```
# SSH agent emulation (socket: ...)
enable-ssh-support
default-cache-ttl-ssh 28800
max-cache-ttl-ssh 28800
```

**NOTA**: Questo file e' in `.gnupg/` — protetto dal hook `protect-sensitive-files.sh`. L'utente dovra' farlo manualmente oppure daremo istruzioni di approvare l'edit.

Dopo la modifica: `gpg-connect-agent reloadagent /bye`

---

## 8. Aggiornare README.md

**File**: `/data/massimiliano/README.md`

### 8a. Aggiungere sezione "Documentazione operativa"

Dopo la sezione "Storage" (riga ~369), aggiungere:

```markdown
## Documentazione Operativa

Guida operativa dettagliata in `/data/massimiliano/docs/` (repo Gitea: `sol_root/sol-docs`).

| File | Argomento |
|------|-----------|
| [indice.md](docs/indice.md) | Indice completo con cross-reference |
| [rete-e-routing.md](docs/rete-e-routing.md) | Rete Docker, routing nginx, Cloudflare Tunnel, Tailscale |
| [servizi-docker.md](docs/servizi-docker.md) | Inventario container, boot order, healthcheck, hardening |
| [security.md](docs/security.md) | Keycloak SSO, 3 pattern auth, confini di rete, visitor |
| [backup.md](docs/backup.md) | Restic AES-256, cron, retention, restore |
| [shell-scripts.md](docs/shell-scripts.md) | Toolkit CLI (sol, deploy-mcp, gitall, x-tools) |
| [ssh-e-git.md](docs/ssh-e-git.md) | SSH agent, struttura repo, remote convention |
| [dashboard.md](docs/dashboard.md) | Dashboard, terminal web, note API |
| [monitoraggio.md](docs/monitoraggio.md) | Healthcheck, Vector→PostgreSQL, GoAccess, audit |
| [mcp-libraries.md](docs/mcp-libraries.md) | 8 artifact Maven Central, CI/CD pipeline |
| [sysctl-tuning.md](docs/sysctl-tuning.md) | Buffer UDP per QUIC |
```

### 8b. Aggiornare sezione "SSH Agent"

Sostituire la sezione SSH Agent (~righe 343-364) con la nuova architettura basata su ssh-agent systemd.

---

## 9. Aggiornare `/data/massimiliano/docs/ssh-e-git.md`

Riscrivere le sezioni SSH (righe 1-77) per riflettere la migrazione:

- **Panoramica** (riga 7): da "gpg-agent con emulazione SSH" a "ssh-agent systemd user-level"
- **Flusso Passphrase** (righe 15-18): rimuovere riferimenti a gpg-agent/pinentry-curses, sostituire con ssh-agent + ssh-add
- **File di configurazione** (tabella riga 26-31): rimuovere `gpg-agent.conf`, aggiungere `ssh-agent.service`
- **Perche' SSH_AUTH_SOCK** (righe 33-37): aggiornare per riflettere il nuovo socket path
- **Socket** (tabella righe 42-45): da `gpg-agent-ssh.socket` / `S.gpg-agent.ssh` a `ssh-agent.service` / `ssh-agent.sock`
- **Comandi Utili** (righe 60-76): rimuovere `gpg-connect-agent reloadagent /bye`, aggiungere `systemctl --user status ssh-agent`
- Aggiungere sezione "Migrazione da gpg-agent" con nota storica sulla incompatibilita' hostbound-v00

---

## 10. Aggiornare `/data/massimiliano/docs/shell-scripts.md`

Aggiornare la sezione `ssh-ensure` (righe 77-91):

- Riga 88: da "imposta il socket gpg-agent" a "verifica il servizio systemd ssh-agent"
- Aggiungere step: "Verifica che il servizio `ssh-agent.service` sia attivo"

---

## Ordine di esecuzione

1. Creare `ssh-agent.service` (nuovo file)
2. Aggiornare `.bashrc` e `.profile` (SSH_AUTH_SOCK)
3. Aggiornare `ssh-ensure` (nuovo socket)
4. Aggiornare `session-context-loader.sh` (check SSH)
5. Aggiornare `.ssh/config` (rimuovere IdentityAgent none)
6. Stampare istruzione manuale per `gpg-agent.conf` (hook blocca .gnupg/)
7. Attivare il servizio: `systemctl --user enable --now ssh-agent`
8. Caricare la chiave: `ssh-ensure` (utente inserisce passphrase)
9. Aggiornare README.md (sezione docs + sezione SSH Agent)
10. Aggiornare `docs/ssh-e-git.md` (migrazione gpg-agent → ssh-agent)
11. Aggiornare `docs/shell-scripts.md` (descrizione ssh-ensure aggiornata)
12. Committare e pushare le modifiche (shell-scripts, claude-code-config, proxy/README, docs)

---

## Verifica

```bash
# 1. Servizio attivo
systemctl --user status ssh-agent

# 2. Socket presente
ls -la /run/user/1000/ssh-agent.sock

# 3. SSH_AUTH_SOCK corretto (nuova shell)
bash -c 'echo $SSH_AUTH_SOCK'
# Atteso: /run/user/1000/ssh-agent.sock

# 4. Chiave caricata
ssh-add -l

# 5. Test connessione Gitea
ssh -T git@100.86.46.84 -p 222

# 6. Test connessione GitHub
ssh -T git@github.com

# 7. Test push
cd /data/massimiliano/docs && git push origin main
```
