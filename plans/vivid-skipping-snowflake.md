# Piano: Aggiornamento documentazione per Tor

## Contesto

I container `tor-relay` e `tor-client` sono stati appena installati e funzionano. La documentazione (CLAUDE.md, MEMORY.md, architecture.md) deve riflettere i nuovi servizi.

## File da modificare

### 1. `/data/massimiliano/CLAUDE.md` — 3 punti di inserimento

**a) Directory Layout** (dopo riga ~146, dopo `docs/`):
Aggiungere entry `tor/` con Dockerfile, entrypoint, torrc, compose, data dirs.

**b) Servizi e Porte** (dopo riga ~202, dopo act_runner):
Aggiungere 2 righe nella tabella:
- `tor-relay` — alpine custom, `:9001`, `:9030`, porta 9001/9030, nessuna auth
- `tor-client` — alpine custom, `127.0.0.1:9050`, porta 9050, nessuna auth (SOCKS)

**c) Nuova sezione** (dopo "## Preference Sort API", riga ~611):
Sezione `## Tor (Middle Relay + Hidden Service + SOCKS Proxy)` con:
- Architettura a 2 container separati (motivazione sicurezza)
- Relay: ORPort 9001, DirPort 9030, policy non-exit, bandwidth limits
- Client: Hidden Service (`HiddenServicePort 80 nginx:80`), SOCKS 9050
- Indirizzo .onion
- MetricsPort 9035 (Prometheus)
- Prerequisito: port forwarding 9001 sul router
- Comandi utili

### 2. `/home/massimiliano/.claude/projects/-data-massimiliano/memory/architecture.md` — 2 punti

**a) Diagramma ASCII**: aggiungere sezione Tor nel blocco Infra
**b) Inventario container**: aggiungere 2 righe (tor-relay, tor-client)

### 3. `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` — 1 punto

**Sezione Architettura** (riga ~25): aggiornare conteggio container (~28 → ~30) e aggiungere menzione Tor nei confini rete.
Aggiungere sotto "Sicurezza e Autenticazione" un breve paragrafo Tor.

## Verifica

Rileggere le 3 sezioni modificate per verificare coerenza con lo stato reale dei container.
