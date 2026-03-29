# Piano: Aggiornare README e MEMORY con sezione SSH Agent

## Contesto

La configurazione SSH Agent (gpg-agent con SSH emulation) e' stata implementata nella conversazione precedente.
Ora i file di documentazione devono essere aggiornati per riflettere la nuova infrastruttura.

File gia' creati/modificati nella sessione precedente:
- `~/.gnupg/gpg-agent.conf` (cache 8h, pinentry-curses)
- `~/.bashrc` (SSH_AUTH_SOCK prima del guard non-interattivo)
- `~/.profile` (SSH_AUTH_SOCK per login shell)
- `~/.ssh/config` (AddKeysToAgent yes, host aliases)
- `shell-scripts/bin/ssh-ensure` (diagnostica/caricamento chiave)

## Modifiche

### 1. MEMORY.md — aggiungere `ssh-ensure` alla lista tool
**File**: `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md`
- Riga 7: aggiungere `ssh-ensure` alla lista "Principali" degli shell scripts

### 2. README.md — aggiungere sezione SSH Agent
**File**: `/data/massimiliano/README.md`
- Aggiungere nuova sezione "SSH Agent" dopo "Dashboard API" (riga ~378) e prima di "PostgreSQL"
- Contenuto: architettura gpg-agent, file coinvolti, comandi operativi (`ssh-ensure`, verifica)
- Aggiungere `ssh-ensure` nella sezione "Operazioni comuni" (~riga 590)

### 3. CLAUDE.md — aggiornare nota SSH
**File**: `/data/massimiliano/CLAUDE.md`
- Nella sezione "Directory Layout": aggiungere `shell-scripts/` al tree
- Aggiungere sezione "SSH Agent" prima o dopo "Dashboard API"
- Nella sezione "Operazioni comuni": aggiungere comandi `ssh-ensure`

## Verifica

Rileggere i file modificati per verificare coerenza con la configurazione reale.
