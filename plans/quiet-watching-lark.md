# Deploy Payload CMS su Server SOL

## Contesto

L'utente vuole esplorare la tecnologia CMS (Content Management System) per la prima volta. Dopo un confronto tra le opzioni disponibili (Directus, Strapi, Payload, Ghost), ha scelto **Payload CMS v3** — un headless CMS basato su Next.js/TypeScript con supporto PostgreSQL nativo.

**Obiettivo**: deployare Payload CMS sul server SOL come nuovo servizio Docker, accessibile a `/cms/` su entrambe le interfacce (Tailscale + pubblica), con il pattern architetturale esistente.

---

## Architettura del deploy

```
Browser → nginx (/cms/) → [OAuth2 Proxy auth] → payload-cms:3000 → postgres:5432 (DB: payload_cms)
```

- **Path**: `/cms/` (Tailscale :80 + Pubblico :8888)
- **Auth**: OAuth2 Proxy → Keycloak (stessa istanza usata da pgAdmin, Portainer, etc.)
- **Database**: PostgreSQL 16 esistente (nuovo DB `payload_cms`, user `payload_cms`)
- **Subpath**: Next.js `basePath: '/cms'` (Pattern B — Payload gestisce il prefisso internamente)
- **Memoria**: limite 512m (runtime ~200-300 MB)

### Perche' OAuth2 Proxy (e non SSO nativo)

Payload ha un proprio sistema di autenticazione (admin panel con login/password). Per il primo deploy, lo proteggiamo con OAuth2 Proxy davanti (come pgAdmin): l'utente si autentica via Keycloak, poi accede all'admin panel di Payload. Piu' avanti si puo' integrare Keycloak SSO nativo via plugin Auth.js.

### Perche' basePath (Pattern B, no prefix stripping)

Payload e' un'app Next.js fullstack che serve sia l'admin panel (HTML/JS/CSS) sia le API REST. Next.js supporta nativamente `basePath` in `next.config.js`, che riscrive tutti gli URL interni (asset, link, API) con il prefisso. Questo e' piu' affidabile di fare prefix stripping in nginx (Pattern A) perche' evita problemi con asset statici e redirect interni.

---

## Step di implementazione

### Step 1: Inizializzare il progetto Payload CMS

```bash
cd /data/massimiliano
npx create-payload-app@latest payload-cms
```

Durante il wizard interattivo, selezionare:
- **Template**: `blank` (progetto vuoto)
- **Database**: `postgres` (adattatore PostgreSQL)

Questo crea la struttura del progetto con `payload.config.ts`, `next.config.mjs`, `package.json`, etc.

### Step 2: Configurare il progetto

**File: `/data/massimiliano/payload-cms/next.config.mjs`**

Aggiungere `basePath: '/cms'` e `output: 'standalone'`:

```javascript
import { withPayload } from '@payloadcms/next/withPayload'

/** @type {import('next').NextConfig} */
const nextConfig = {
  basePath: '/cms',
  output: 'standalone',
}

export default withPayload(nextConfig)
```

**File: `/data/massimiliano/payload-cms/.env`**

```env
DATABASE_URI=postgresql://payload_cms:PASSWORD_QUI@postgres:5432/payload_cms
PAYLOAD_SECRET=GENERARE_STRINGA_RANDOM_64_CARATTERI
NEXT_PUBLIC_SERVER_URL=https://sol.massimilianopili.com/cms
```

### Step 3: Creare il Dockerfile

**File: `/data/massimiliano/payload-cms/Dockerfile`**

Dockerfile multi-stage (deps → build → runtime):

```dockerfile
# Stage 1: Dipendenze
FROM node:20-alpine AS deps
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY package.json package-lock.json ./
RUN npm ci

# Stage 2: Build
FROM node:20-alpine AS builder
WORKDIR /app
RUN apk add --no-cache libc6-compat
COPY --from=deps /app/node_modules ./node_modules
COPY . .
ENV NEXT_TELEMETRY_DISABLED=1
RUN npm run build

# Stage 3: Runtime
FROM node:20-alpine AS runner
WORKDIR /app
RUN apk add --no-cache libc6-compat curl
RUN addgroup -g 1001 -S nodejs && adduser -S payload -u 1001
COPY --from=builder /app/public ./public
COPY --from=builder --chown=payload:nodejs /app/.next/standalone ./
COPY --from=builder --chown=payload:nodejs /app/.next/static ./.next/static
USER payload
EXPOSE 3000
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
CMD ["node", "server.js"]
```

**Nota memoria**: la fase di build (Stage 2) puo' richiedere ~1.5-2 GB di RAM. Se OOM, buildare localmente con `npm run build` e poi copiare l'output nel container.

### Step 4: Creare docker-compose.yml

**File: `/data/massimiliano/payload-cms/docker-compose.yml`**

```yaml
services:
  payload-cms:
    build: .
    container_name: payload-cms
    restart: unless-stopped
    env_file: .env
    environment:
      NODE_ENV: production
    volumes:
      - ./media:/app/media
    deploy:
      resources:
        limits:
          memory: 512m
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/cms/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s
    security_opt:
      - no-new-privileges:true
    networks:
      - shared

networks:
  shared:
    external: true
```

### Step 5: Creare database PostgreSQL

**File: `/data/massimiliano/postgres/init/04-payload-cms.sh`**

```bash
#!/bin/bash
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    CREATE USER payload_cms WITH PASSWORD '${PAYLOAD_CMS_DB_PASSWD}';
    CREATE DATABASE payload_cms OWNER payload_cms;
EOSQL
```

**NOTA**: lo script init gira solo al primo avvio del container PostgreSQL. Siccome PostgreSQL e' gia' attivo, dovremo creare il database manualmente:

```bash
docker exec postgres psql -U postgres -c "CREATE USER payload_cms WITH PASSWORD 'PASSWORD_QUI';"
docker exec postgres psql -U postgres -c "CREATE DATABASE payload_cms OWNER payload_cms;"
```

Lo script in `init/` serve per i futuri rebuild da zero.

### Step 6: Aggiungere la rotta in nginx.conf

Aggiungere in **entrambi** i server block (:80 Tailscale e :8888 Pubblico):

```nginx
# Payload CMS (OAuth2 Proxy auth, Pattern B — basePath gestito internamente)
location /cms/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;
    auth_request_set $user $upstream_http_x_auth_request_user;
    auth_request_set $email $upstream_http_x_auth_request_email;
    proxy_set_header X-Forwarded-User $user;
    proxy_set_header X-Forwarded-Email $email;

    set $payload_upstream http://payload-cms:3000;
    proxy_pass $payload_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    client_max_body_size 64m;
}
```

**Nota**: `proxy_http_version 1.1` + `Upgrade`/`Connection` per supporto WebSocket (Next.js HMR in dev, live preview in admin).

Nel block pubblico (:8888), usare `oauth2-proxy-public` (porta 4181) invece di `oauth2-proxy` (porta 4180):
- L'`/oauth2/` internal location nel block :8888 punta gia' a oauth2-proxy-public
- Nessuna modifica aggiuntiva necessaria

### Step 7: Build e avvio

```bash
# 1. Build Docker image
cd /data/massimiliano/payload-cms
docker compose build

# 2. Creare database (se PostgreSQL gia' attivo)
docker exec postgres psql -U postgres -c "CREATE USER payload_cms WITH PASSWORD 'PASSWORD';"
docker exec postgres psql -U postgres -c "CREATE DATABASE payload_cms OWNER payload_cms;"

# 3. Avviare Payload
docker compose up -d

# 4. Riavviare nginx con la nuova config
cd /data/massimiliano/proxy
docker compose up -d nginx --force-recreate
```

### Step 8: Primo accesso

1. Navigare a `http://100.86.46.84/cms/admin` (Tailscale) oppure `https://sol.massimilianopili.com/cms/admin`
2. OAuth2 Proxy redirige a Keycloak per login
3. Dopo il login Keycloak, Payload mostra la pagina di creazione del primo utente admin
4. Creare l'utente admin di Payload (email + password)
5. Accedere all'admin panel

---

## File coinvolti

| File | Azione | Descrizione |
|------|--------|-------------|
| `/data/massimiliano/payload-cms/` | **Nuovo** | Directory progetto Payload CMS |
| `/data/massimiliano/payload-cms/next.config.mjs` | **Modifica** | Aggiungere basePath + standalone |
| `/data/massimiliano/payload-cms/.env` | **Nuovo** | Secrets (DATABASE_URI, PAYLOAD_SECRET) |
| `/data/massimiliano/payload-cms/Dockerfile` | **Nuovo** | Multi-stage build Next.js |
| `/data/massimiliano/payload-cms/docker-compose.yml` | **Nuovo** | Stack Docker |
| `/data/massimiliano/postgres/init/04-payload-cms.sh` | **Nuovo** | Init script database |
| `/data/massimiliano/proxy/nginx.conf` | **Modifica** | Aggiungere location /cms/ (x2 server block) |

---

## Verifica

1. **Container attivo**: `docker ps | grep payload-cms` → status "Up" + healthy
2. **Database connesso**: `docker logs payload-cms --tail 20` → nessun errore connessione
3. **Nginx routing**: `curl -I http://100.86.46.84/cms/` → 302 (redirect OAuth2) o 200 (se autenticato)
4. **Admin panel**: navigare a `/cms/admin` → form creazione utente (primo accesso) o login
5. **API REST**: `curl http://100.86.46.84/cms/api/` (con JWT o dopo OAuth2) → JSON di risposta
6. **Accesso pubblico**: `https://sol.massimilianopili.com/cms/admin` → stessa esperienza via Cloudflare

---

## Note e rischi

- **RAM build**: il build Next.js puo' richiedere ~1.5-2 GB. Se fallisce con OOM, opzione alternativa: buildare localmente con `npm run build` e poi containerizzare solo l'output standalone
- **basePath**: se Payload ha problemi con `basePath: '/cms'` (asset 404, redirect loop), fallback a Pattern A (nginx prefix stripping) + configurazione `routes` nel payload.config.ts
- **Media uploads**: il volume `./media` persiste i file caricati. Includere nel backup restic
- **Aggiornamenti futuri**: rebuild con `docker compose build --no-cache && docker compose up -d`
