---
name: systemd-services
description: Systemd user-level service patterns for running host processes (Node.js, Go binaries, ttyd) alongside Docker containers, with proper PATH configuration, NVM integration, service dependencies, and journalctl logging.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [systemd, services, linux, process-management, journalctl]
version: 1.0.0
---

# Systemd User-Level Services — SOL Server

## Overview

Tre servizi sul server SOL girano come unit systemd user-level (NON Docker): `dashboard-api`
(Node.js), `ttyd` (binary statico), `claude-proxy` (binary Go). Necessitano accesso diretto
all'host (filesystem, Docker socket, chiavi SSH) che i container Docker non possono fornire facilmente.

Tutti i file delle unit sono in `~/.config/systemd/user/` e vengono gestiti con il flag `--user`.

## When to Use

- Creare un nuovo servizio systemd user-level
- Debuggare problemi di startup o PATH
- Capire la divisione host vs Docker
- Gestire dipendenze tra servizi
- Consultare i log con journalctl

## Current Services

### ttyd.service — PTY backend per il terminale web

Binary statico che espone una shell bash come WebSocket. Ascolta solo su localhost
(127.0.0.1:7682), protetto dal JWT gateway di dashboard-api.

File: `~/.config/systemd/user/ttyd.service`

```ini
[Unit]
Description=ttyd terminal (PTY backend for dashboard)
After=network.target

[Service]
ExecStart=/data/massimiliano/dashboard-api/ttyd -p 7682 -i 127.0.0.1 -W bash -l
WorkingDirectory=/data/massimiliano
Environment=HOME=/home/massimiliano
Environment=TERM=xterm-256color
Environment=PATH=/data/massimiliano/shell-scripts/bin:/home/massimiliano/.nvm/versions/node/v24.13.1/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Note:
- `-W` abilita WebSocket writable (bidirezionale)
- `-i 127.0.0.1` limita a localhost (sicurezza: nessuna auth propria)
- `bash -l` avvia una login shell con accesso completo all'host
- PATH include shell-scripts e NVM per averli disponibili nel terminale web

### dashboard-api.service — JWT gateway Node.js

Server Node.js che autentica le connessioni WebSocket (JWT Keycloak) e le inoltra a ttyd.
Gestisce anche le note condivise (GET/PUT /notes).

File: `~/.config/systemd/user/dashboard-api.service`

```ini
[Unit]
Description=Dashboard API (JWT gateway + notes)
After=network.target ttyd.service

[Service]
ExecStart=/home/massimiliano/.nvm/versions/node/v24.13.1/bin/node server.js
WorkingDirectory=/data/massimiliano/dashboard-api
Environment=HOME=/home/massimiliano
Environment=PATH=/home/massimiliano/.nvm/versions/node/v24.13.1/bin:/data/massimiliano/shell-scripts/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Note:
- `After=ttyd.service` assicura che ttyd sia avviato prima (dashboard-api fa proxy verso di esso)
- `ExecStart` usa il path completo del binary Node.js di NVM (nessun alias shell)
- NVM path e' il primo elemento di PATH per garantire che `node` sia trovato

### claude-proxy.service — Go binary

Proxy API per Claude CLI. Usa `EnvironmentFile` per caricare le variabili dal file `.env`
(contiene API keys e configurazione JWT).

File: `~/.config/systemd/user/claude-proxy.service`

```ini
[Unit]
Description=Claude Proxy (claude CLI backend)
After=network.target

[Service]
ExecStart=/data/massimiliano/Vari/claude-proxy/claude-proxy-bin
WorkingDirectory=/data/massimiliano/Vari/claude-proxy
EnvironmentFile=/data/massimiliano/Vari/claude-proxy/.env
Environment=PATH=/home/massimiliano/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
Environment=HOME=/home/massimiliano
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
```

Note:
- `EnvironmentFile` carica coppie KEY=VALUE dal file `.env` (API keys, JWKS URL, etc.)
- Nessuna dipendenza da NVM (binary Go compilato staticamente)
- PATH include `.local/bin` per eventuali tool Go installati localmente

## Key Concepts

### User-level vs System-level

| Aspetto | User-level | System-level |
|---------|-----------|--------------|
| Directory | `~/.config/systemd/user/` | `/etc/systemd/system/` |
| Gestione | `systemctl --user` | `systemctl` (root) |
| Utente | Corrente (massimiliano) | root o `User=` specificato |
| Avvio | Al login (o con lingering) | Al boot |
| Uso su SOL | Tutti i servizi host | Solo daemons di sistema |

### Problema NVM e PATH

systemd non esegue `.bashrc` ne' `.nvm/nvm.sh`. Il binary `node` installato via NVM non e'
nel PATH di default di systemd. Soluzione: specificare il path completo in `ExecStart` e
aggiungere la directory NVM a `Environment=PATH`:

```ini
ExecStart=/home/massimiliano/.nvm/versions/node/v24.13.1/bin/node server.js
Environment=PATH=/home/massimiliano/.nvm/versions/node/v24.13.1/bin:/usr/local/bin:/usr/bin:/bin
```

**ATTENZIONE**: Quando NVM aggiorna la versione di Node.js, i path nei file .service
devono essere aggiornati manualmente.

### EnvironmentFile vs Environment

- `Environment=KEY=VALUE` — variabile singola, visibile nel file .service
- `EnvironmentFile=/path/to/.env` — carica tutte le coppie KEY=VALUE dal file

Preferire `EnvironmentFile` quando ci sono molte variabili o contengono segreti (API keys).
Le variabili in `Environment=` sono visibili con `systemctl --user show <service>`.

### Dipendenze tra servizi

`After=ttyd.service` nel dashboard-api assicura l'ordine di avvio. Non implica che ttyd
debba essere attivo (per quello serve `Requires=`). Su SOL, `After=` e' sufficiente
perche' entrambi i servizi sono sempre abilitati.

### Lingering — avvio al boot senza login

I servizi user-level girano solo quando l'utente ha una sessione attiva, a meno che
il lingering non sia abilitato:

```bash
# Verificare
loginctl show-user massimiliano | grep Linger

# Abilitare (richiede root)
sudo loginctl enable-linger massimiliano
```

Senza lingering, i servizi si fermano al logout e non partono al boot.

## Creating a New Service

### 1. Scrivere il file unit

```bash
cat > ~/.config/systemd/user/myservice.service << 'EOF'
[Unit]
Description=My New Service
After=network.target

[Service]
ExecStart=/path/to/binary --flags
WorkingDirectory=/data/massimiliano/myservice
Environment=HOME=/home/massimiliano
Environment=PATH=/data/massimiliano/shell-scripts/bin:/usr/local/bin:/usr/bin:/bin
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF
```

### 2. Ricaricare, abilitare, avviare

```bash
systemctl --user daemon-reload
systemctl --user enable myservice
systemctl --user start myservice
```

### 3. Verificare

```bash
systemctl --user status myservice
journalctl --user -u myservice --tail 20
```

## Common Operations

```bash
# Stato di tutti i servizi host
systemctl --user status dashboard-api ttyd claude-proxy

# Restart singolo
systemctl --user restart dashboard-api

# Restart tutti
systemctl --user restart dashboard-api ttyd claude-proxy

# Stop
systemctl --user stop dashboard-api

# Abilitare (auto-start)
systemctl --user enable dashboard-api

# Disabilitare
systemctl --user disable dashboard-api

# Ricaricare dopo modifica al file .service
systemctl --user daemon-reload

# Lista tutti i servizi user-level
systemctl --user list-units --type=service
```

### Journalctl — consultare i log

```bash
# Ultimi 50 log
journalctl --user -u dashboard-api --tail 50

# Follow (tempo reale)
journalctl --user -u dashboard-api -f

# Ultima ora
journalctl --user -u ttyd --since "1 hour ago"

# Da un timestamp specifico
journalctl --user -u claude-proxy --since "2026-02-28 10:00:00"

# Solo errori
journalctl --user -u dashboard-api -p err

# Log di tutti i servizi user-level
journalctl --user --since "30 min ago"
```

## Best practices

1. Usare sempre path assoluti per i binary (nessun alias shell, nessun `nvm use`)
2. Impostare `Environment=HOME=/home/massimiliano` — systemd potrebbe non settarlo
3. Includere `shell-scripts/bin` nel PATH per servizi che necessitano del toolkit sol
4. Usare `Restart=always` + `RestartSec=5` per servizi di produzione
5. Usare `After=` per ordinare l'avvio tra servizi dipendenti
6. Preferire `EnvironmentFile=` a molte righe `Environment=` per segreti
7. Abilitare lingering per l'avvio al boot senza sessione login
8. Eseguire sempre `daemon-reload` dopo aver modificato un file .service
9. Usare `127.0.0.1` come bind address per servizi che non devono essere esposti
10. Documentare nel `Description=` lo scopo del servizio

## Troubleshooting

### Errore 203/EXEC — binary non trovato o non eseguibile
```bash
# Verificare che il path esista e sia eseguibile
ls -la /path/to/binary
chmod +x /path/to/binary
```

### Node.js non trovato
Il path NVM non e' in `ExecStart` o `PATH`. Verificare la versione corrente:
```bash
ls /home/massimiliano/.nvm/versions/node/
```
Aggiornare il file .service con il path corretto.

### Il servizio parte ma esce subito
```bash
journalctl --user -u myservice --tail 30
# Cercare errori di binding porta, file mancanti, variabili non impostate
```

### Il servizio non parte al boot
Verificare che lingering sia abilitato:
```bash
loginctl show-user massimiliano | grep Linger
# Se Linger=no:
sudo loginctl enable-linger massimiliano
```

### Variabili d'ambiente non caricate
- `EnvironmentFile` non supporta espansione shell (`$VAR`, backtick, etc.)
- Formato richiesto: `KEY=VALUE` (una per riga, senza `export`)
- Verificare: `systemctl --user show myservice | grep Environment`

### PATH tools non disponibili nel servizio
Aggiungere `/data/massimiliano/shell-scripts/bin` al PATH nel file .service:
```ini
Environment=PATH=/data/massimiliano/shell-scripts/bin:/usr/local/bin:/usr/bin:/bin
```

### Porta gia' in uso
```bash
# Trovare chi occupa la porta
ss -tlnp | grep :7681
# Fermare il processo conflittuale o cambiare porta nel servizio
```

### Quando usare systemd vs Docker

**Systemd**: accesso diretto a filesystem/Docker socket/chiavi SSH, binary statici leggeri,
layer di gestione dell'infrastruttura Docker stessa.

**Docker**: dipendenze isolabili, comunicazione inter-servizio via rete Docker, rollback
via immagini tagged, replicabilita' su altri host.
