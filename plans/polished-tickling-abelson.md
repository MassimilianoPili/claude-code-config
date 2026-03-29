# Piano: Mail Server Self-Hosted con Stalwart

## Contesto

Il server SOL non ha attualmente nessun servizio SMTP configurato. Keycloak non puo' inviare email di reset password, Gitea non invia notifiche PR/issue.

**Setup attuale email**: `info@massimilianopili.com` ricevuta tramite servizio Google forwarding → `random@gmail.com`, risposta da Gmail con "Send mail as". Nessun GMX coinvolto (errore iniziale corretto).

**Vincolo critico**: il server non ha IP pubblico diretto — l'accesso e' solo tramite Cloudflare Tunnel (HTTP/HTTPS) e Tailscale. Le porte SMTP (25), IMAP (993) e Submission (587) non sono raggiungibili da Internet.

**Caselle richieste**: solo `info@massimilianopili.com` (piu' alias per servizi: `noreply@`, `gitea@`).

## Architettura

```
INBOUND (ricezione email da Internet):
  mittente@qualsiasi.com → MX Cloudflare → Email Routing catch-all
                                            ↓ forward
                                       random@gmail.com (indirizzo esistente)
                                            ↓ fetchmail (ogni 2 min, IMAP poll)
                                       Stalwart (LMTP locale)

OUTBOUND (invio/risposta da info@massimilianopili.com):
  Webmail Stalwart (componi/rispondi) → relay SMTP Brevo (smtp-relay.brevo.com:587)
                                        → destinatario
  From: info@massimilianopili.com (DKIM firmato, SPF valido)

INTERNO (servizi Docker):
  Keycloak ──smtp://stalwart:25──→ Stalwart
  Gitea    ──smtp://stalwart:25──→ Stalwart

ACCESSO CLIENT:
  Webmail:  https://mail.massimilianopili.com  (Cloudflare Tunnel)
  IMAP:     imap://100.86.46.84:993            (solo Tailscale)
  Admin UI: https://mail.massimilianopili.com/login
```

### Perche' Stalwart

- All-in-one: SMTP + IMAP + JMAP + webmail + admin UI in un singolo container
- Scritto in Rust: ~50-100 MB RAM (critico con 1.7 GB liberi)
- Webmail integrato (no bisogno di Roundcube/SnappyMail separato)
- OIDC support per futura integrazione Keycloak
- Attivamente sviluppato, community attiva

### Perche' subdomain (mail.massimilianopili.com) e non subpath (/mail/)

Stalwart non supporta il funzionamento sotto un subpath. La webmail, JMAP, e admin UI generano URL assoluti che non includerebbero il prefisso. Il pattern subdomain e' quello raccomandato dalla documentazione ufficiale.

## Step di Implementazione

### Step 1 — Creare la stack Docker Stalwart

**File**: `/data/massimiliano/stalwart/docker-compose.yml`

```yaml
services:
  stalwart:
    image: stalwartlabs/stalwart:latest
    container_name: stalwart
    restart: unless-stopped
    volumes:
      - ./data:/opt/stalwart
    networks:
      - shared
    # Nessuna porta esposta sull'host:
    # - HTTP (8080) accessibile via Cloudflare Tunnel / nginx
    # - SMTP (25) accessibile solo sulla rete Docker (per Keycloak/Gitea)
    # - IMAP (993) esposto solo per Tailscale (aggiunto dopo primo setup)

networks:
  shared:
    external: true
```

**Primo avvio**:
```bash
mkdir -p /data/massimiliano/stalwart/data
cd /data/massimiliano/stalwart && docker compose up -d
docker logs stalwart  # → copiare password admin generata
```

### Step 2 — Configurazione iniziale Stalwart (via Admin UI)

Accedere temporaneamente alla admin UI:
```bash
# Accesso diretto via Tailscale (temporaneo, per setup)
docker compose exec stalwart curl http://localhost:8080/login
# Oppure: esporre temporaneamente la porta per il setup
```

Configurare via Admin UI (`http://stalwart:8080/login`):
1. **Hostname**: `mail.massimilianopili.com`
2. **Domain**: `massimilianopili.com`
3. **DKIM**: generare chiave DKIM per `massimilianopili.com`
4. **Relay SMTP outbound**: configurare Brevo come relay (vedi Step 5)
5. **Account utente**: creare `info@massimilianopili.com` (casella principale)
6. **Alias email**: `noreply@massimilianopili.com` → `info@` (per Keycloak), `gitea@massimilianopili.com` → `info@` (per Gitea)
6. **Disabilitare TLS sui listener interni**: il TLS e' terminato da Cloudflare/nginx

### Step 3 — Routing Cloudflare Tunnel per il subdomain

**File**: `/data/massimiliano/cloudflared/config.yml`

Aggiungere ingress rule per `mail.massimilianopili.com`:
```yaml
tunnel: 6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec
credentials-file: /home/nonroot/.cloudflared/6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.json

ingress:
  - hostname: mail.massimilianopili.com
    service: http://stalwart:8080
  - hostname: sol.massimilianopili.com
    service: http://nginx:8888
  - service: http_status:404
```

**DNS Cloudflare** (da configurare nella dashboard Cloudflare):
- Aggiungere CNAME: `mail` → `6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.cfargotunnel.com` (proxied)

**Ricreare cloudflared** (file bind-mounted, stessa logica di nginx):
```bash
cd /data/massimiliano/cloudflared && docker compose up -d --force-recreate
```

### Step 4 — Accesso IMAP via Tailscale (nginx stream)

Aggiungere al `docker-compose.yml` di Stalwart l'esposizione della porta IMAP per Tailscale:
```yaml
    ports:
      - "993:993"    # IMAP — solo Tailscale (non raggiungibile da Internet)
```

Questo permette ai client email (Thunderbird, etc.) di connettersi via `100.86.46.84:993` su Tailscale.

### Step 5 — Configurare relay SMTP outbound (Brevo)

1. Registrarsi su [Brevo](https://www.brevo.com/) (free tier: 300 email/giorno)
2. Aggiungere e verificare il dominio `massimilianopili.com`
3. Ottenere credenziali SMTP: `smtp-relay.brevo.com:587`
4. Configurare in Stalwart Admin UI:
   - **Relay host**: `smtp-relay.brevo.com`
   - **Porta**: 587
   - **Auth**: credenziali Brevo
   - **STARTTLS**: abilitato

**Alternativa**: usare GMX SMTP (`smtp.gmx.net:587`) se si preferisce non registrare un nuovo servizio. Brevo e' consigliato per la migliore deliverability e il DKIM dedicato.

### Step 6 — Configurare ricezione email (Cloudflare Email Routing + fetchmail)

#### 6a. Cloudflare Email Routing

Nella dashboard Cloudflare per `massimilianopili.com`:
1. **Email** → **Email Routing** → abilitare
2. Aggiungere **Catch-all rule**: forward tutto a `random@gmail.com` (indirizzo Gmail esistente)
3. Verificare l'indirizzo di destinazione (Cloudflare invia email di conferma a Gmail)
4. Disattivare il vecchio forwarding Google (sostituito da Cloudflare Email Routing)

Cloudflare gestira' automaticamente i record MX per `massimilianopili.com`.

#### 6b. Gmail App Password (prerequisito)

Gmail richiede OAuth2 o App Password per accesso IMAP. Con 2FA attivo:
1. Google Account → **Sicurezza** → **Password per le app**
2. Creare una password per "Mail" / "Altro (fetchmail)"
3. Copiare la password a 16 caratteri generata

Senza 2FA: abilitare prima il 2FA, poi creare l'App Password.

#### 6c. Container fetchmail (sidecar)

**File**: aggiungere al `docker-compose.yml` di Stalwart:

```yaml
  fetchmail:
    image: alpine:latest
    container_name: fetchmail
    restart: unless-stopped
    volumes:
      - ./fetchmailrc:/etc/fetchmailrc:ro
    networks:
      - shared
    entrypoint: >
      sh -c 'apk add --no-cache fetchmail &&
             while true; do
               fetchmail -f /etc/fetchmailrc --nodetach --nosyslog -v || true
               sleep 120
             done'
```

**File**: `/data/massimiliano/stalwart/fetchmailrc`
```
set daemon 0
set no bouncemail

poll imap.gmail.com
  protocol IMAP
  port 993
  user "random@gmail.com"
  password "<APP_PASSWORD_GMAIL>"
  ssl
  keep
  fetchall
  smtphost stalwart
  smtpname info@massimilianopili.com
```

**Nota**: `keep` lascia le email su Gmail (backup, come ora). Rimuovere per eliminare dopo il fetch.
I segreti (App Password) andranno nel file `.env`.

**Label Gmail**: per evitare che fetchmail scarichi TUTTA la posta Gmail, creare un filtro Gmail che etichetta le email `to:info@massimilianopili.com` (o forwarded da Cloudflare) e configurare fetchmail per leggere solo quella cartella/label. Oppure creare un account Gmail dedicato solo per il forwarding.

### Step 7 — Configurare Keycloak SMTP

Nella Keycloak Admin Console → Realm `sol` → **Realm Settings** → **Email**:
- **From**: `noreply@massimilianopili.com`
- **From Display Name**: `SOL Server`
- **Host**: `stalwart`
- **Port**: `25`
- **Enable SSL**: No
- **Enable StartTLS**: No (connessione interna Docker, no TLS necessario)
- **Enable Authentication**: Si (credenziali dell'account Stalwart)

**Test**: bottone "Test connection" nella pagina, invia email di test.

### Step 8 — Configurare Gitea mailer

**File**: `/data/massimiliano/gitea/docker-compose.yml`

Aggiungere environment variables:
```yaml
    environment:
      # ... variabili esistenti ...
      - GITEA__mailer__ENABLED=true
      - GITEA__mailer__PROTOCOL=smtp
      - GITEA__mailer__SMTP_ADDR=stalwart
      - GITEA__mailer__SMTP_PORT=25
      - GITEA__mailer__FROM=gitea@massimilianopili.com
      - GITEA__mailer__USER=gitea@massimilianopili.com
      - GITEA__mailer__PASSWD=${GITEA_SMTP_PASSWD}
      - GITEA__service__ENABLE_NOTIFY_MAIL=true
```

`gitea@massimilianopili.com` e' un alias di `info@` creato nello Step 2.
Per l'autenticazione SMTP usare l'account `info@massimilianopili.com`.
Aggiungere `GITEA_SMTP_PASSWD` al file `.env` di Gitea.

Ricreare Gitea:
```bash
cd /data/massimiliano/gitea && docker compose up -d --force-recreate
```

### Step 9 — DNS Records

Nella dashboard **Cloudflare** per `massimilianopili.com`:

| Tipo | Nome | Valore | Note |
|------|------|--------|------|
| CNAME | `mail` | `6e7eafe0...cfargotunnel.com` | Proxied, per webmail |
| MX | (gestito da Email Routing) | (automatico) | Cloudflare Email Routing |
| TXT | `@` | `v=spf1 include:_spf.brevo.com include:_spf.mx.cloudflare.net ~all` | SPF (Brevo + Cloudflare) |
| TXT | `brevo._domainkey` | (fornito da Brevo) | DKIM per relay outbound |
| TXT | `_dmarc` | `v=DMARC1; p=quarantine; rua=mailto:postmaster@massimilianopili.com` | DMARC |

**Nota**: i record MX attuali di GMX andranno sostituiti con quelli di Cloudflare Email Routing. Cloudflare li configura automaticamente quando si abilita Email Routing.

## File coinvolti

| File | Azione |
|------|--------|
| `/data/massimiliano/stalwart/docker-compose.yml` | **NUOVO** — stack Stalwart + fetchmail |
| `/data/massimiliano/stalwart/.env` | **NUOVO** — App Password Gmail, credenziali Brevo |
| `/data/massimiliano/stalwart/fetchmailrc` | **NUOVO** — config fetchmail |
| `/data/massimiliano/cloudflared/config.yml` | **MODIFICA** — aggiungere ingress `mail.massimilianopili.com` |
| `/data/massimiliano/gitea/docker-compose.yml` | **MODIFICA** — aggiungere env vars mailer |
| `/data/massimiliano/gitea/.env` | **MODIFICA** — aggiungere `GITEA_SMTP_PASSWD` |
| Dashboard Cloudflare | **MANUALE** — DNS CNAME, Email Routing, SPF/DKIM/DMARC |
| Keycloak Admin Console | **MANUALE** — Realm Settings → Email |
| Brevo account | **MANUALE** — registrazione, verifica dominio |

## Verifica

1. **Webmail accessibile**: `https://mail.massimilianopili.com` → login Stalwart
2. **Invio email**: dalla webmail, inviare a un indirizzo esterno → verificare ricezione
3. **Ricezione email**: inviare da un indirizzo esterno a `massimiliano@massimilianopili.com` → verificare che arrivi (attesa ~2 min per fetchmail)
4. **Keycloak**: Realm Settings → Email → "Test connection" → email ricevuta
5. **Gitea**: Settings → verificare "Email Notifications" abilitato, testare con notifica issue
6. **IMAP Tailscale**: configurare Thunderbird con `100.86.46.84:993` → email visibili
7. **SPF/DKIM/DMARC**: inviare email a `check-auth@verifier.port25.com` → verificare pass

## Rischi e mitigazioni

| Rischio | Mitigazione |
|---------|-------------|
| fetchmail delay 2-5 min | Accettabile per uso personale. Upgrade futuro: Cloudflare Email Worker per delivery istantanea via JMAP |
| RAM insufficiente | Stalwart usa ~50-100 MB, fetchmail ~5 MB. Monitorare con `free -h` |
| Gmail blocca polling frequente | `keep` + `sleep 120` (2 min) e' conservativo. Gmail tollera bene IMAP poll con App Password |
| fetchmail scarica tutta la posta Gmail | Creare account Gmail dedicato per forwarding, oppure usare filtri/label Gmail per isolare le email @massimilianopili.com |
| Brevo free tier (300/day) | Piu' che sufficiente per uso personale + notifiche servizi |
| Email in spam | SPF + DKIM + DMARC correttamente configurati riducono il rischio. Brevo ha ottima reputazione IP |
