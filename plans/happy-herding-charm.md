# Task: Aggiungere PIANO_MEDIA_SERVER.md a Progetti Futuri

## Context

L'utente vuole un media server self-hosted per film e serie TV, con UI web di gestione. Scelta: **Jellyfin** (FOSS) su SOL, transcoding software (CPU). GPU 3090 remota esposta come evoluzione futura (NVIDIA GPU Remoting / transcoding proxy).

## Cosa fare

### 1. Creare `/data/massimiliano/progetti_futuri/PIANO_MEDIA_SERVER.md`

Il contenuto completo del file e' riportato sotto.

### 2. Aggiornare `/data/massimiliano/progetti_futuri/INDICE.md`

Aggiungere riga nella tabella (dopo Mail Stalwart, posizione ROI 3 Infra/Docker):

```
| 28 | [Media Server Jellyfin](PIANO_MEDIA_SERVER.md) | Infra / Docker | ~6-8h | Gratis | 3 | Medio — media server personale, skill Docker/reverse proxy, utile quotidianamente | — |
```

Aggiornare statistiche: Progetti totali 30, Infra/DevOps 8, Effort totale ~760-810h.

---

## Contenuto PIANO_MEDIA_SERVER.md

```markdown
# Piano: Media Server Jellyfin su Server SOL

Ultimo aggiornamento: 2026-03-14

## Obiettivo

Deploy di un media server self-hosted per film, serie TV e musica usando **Jellyfin** — alternativa completamente FOSS a Plex/Emby. UI web per gestione libreria, transcoding software (CPU), streaming multi-dispositivo. Opzionalmente, stack *Arr (Sonarr, Radarr, Prowlarr, Bazarr) per automazione acquisizione e sottotitoli.

**Jellyfin**: [jellyfin.org](https://jellyfin.org/) | [GitHub](https://github.com/jellyfin/jellyfin) (~40k stars)

Scelto dopo confronto con Plex (freemium, closed source) e Emby (semi-open, licenza premium) per:
- Completamente FOSS, nessuna licenza o Plex Pass
- Transcoding hardware (VAAPI, NVENC, QSV) incluso senza paywall
- Plugin SSO/OIDC per integrazione Keycloak
- Immagine Docker ufficiale leggera

---

## Prerequisiti

- [ ] Spazio disco sufficiente per media (~100+ GB tipico, scalabile)
- [ ] Docker + rete `shared` (gia' presente)
- [ ] nginx operativo (gia' presente)
- [ ] Keycloak realm `sol` (gia' presente, per SSO OIDC)

---

## Architettura del deploy

### Core: Jellyfin su SOL

```
Browser/App → nginx (/media/) → jellyfin:8096 → /data/massimiliano/jellyfin/media/
                                                   ├── film/
                                                   ├── serie/
                                                   └── musica/
```

| Aspetto | Valore |
|---------|--------|
| **Path** | `/media/` (Tailscale :80 + Pubblico :8888) |
| **Auth** | SSO nativo Jellyfin via plugin OIDC + Keycloak (preferito) oppure OAuth2 Proxy come fallback |
| **Storage** | `/data/massimiliano/jellyfin/media/` (disco HDD di SOL) |
| **Subpath** | Base URL `/media` configurato internamente in Jellyfin |
| **Transcoding** | Software (CPU) — sufficiente per 1080p, 4K limitato. Evoluzione futura: GPU 3090 remota |
| **Memoria** | limite 4g (runtime ~500 MB - 2 GB a seconda dei transcoding attivi) |
| **Container** | `jellyfin` (immagine ufficiale `jellyfin/jellyfin:latest`) |
| **Porta interna** | 8096 (HTTP), 7359/udp (discovery opzionale) |

### Opzionale: Stack *Arr (automazione media)

```
Jellyseerr (richieste utente)
    ↓
Sonarr (serie TV) / Radarr (film)
    ↓
Prowlarr (indexer aggregator)
    ↓
qBittorrent (download client)
    ↓
Post-processing (rename, hardlink → /media/)
    ↓
Jellyfin (rileva nuovi media) → Bazarr (sottotitoli automatici)
```

| Container | Immagine | Porta | Path nginx | Funzione |
|-----------|----------|-------|------------|----------|
| `jellyfin` | `jellyfin/jellyfin` | 8096 | `/media/` | Streaming + UI gestione |
| `sonarr` | `linuxserver/sonarr` | 8989 | `/sonarr/` | Gestione serie TV |
| `radarr` | `linuxserver/radarr` | 7878 | `/radarr/` | Gestione film |
| `prowlarr` | `linuxserver/prowlarr` | 9696 | `/prowlarr/` | Aggregatore indexer |
| `bazarr` | `linuxserver/bazarr` | 6767 | `/bazarr/` | Sottotitoli automatici |
| `qbittorrent` | `linuxserver/qbittorrent` | 8080 | `/qbt/` | Download client |
| `jellyseerr` | `fallenbagel/jellyseerr` | 5055 | `/requests/` | Richieste utente (opzionale) |

### Decisioni architetturali

**Jellyfin su SOL**: Jellyfin gira direttamente su SOL come tutti gli altri servizi Docker. Il transcoding e' software-only (CPU). Per contenuti 1080p il transcoding SW e' adeguato. Per 4K, preferire Direct Play (client che supportano il codec nativo) evitando transcoding. Evoluzione futura: esporre la GPU 3090 remota via NVIDIA GPU Remoting o transcoding proxy dedicato.

**SSO nativo (non OAuth2 Proxy)**: Jellyfin ha un plugin SSO/OIDC maturo (`jellyfin-plugin-sso` di 9p4) che supporta Keycloak. Preferito rispetto a OAuth2 Proxy perche':
- Le app mobile Jellyfin (Android, Swiftfin iOS) non funzionano dietro OAuth2 Proxy
- Il plugin gestisce il mapping ruoli Keycloak → ruoli Jellyfin (admin/user)
- OAuth2 Proxy resta come fallback se il plugin SSO ha problemi

**Base URL `/media` (Pattern ibrido)**: Jellyfin supporta nativamente Base URL nella configurazione di rete. nginx fa proxy_pass senza stripping, Jellyfin gestisce internamente il prefisso. Nota: Base URL puo' rompere DLNA e HDHomeRun (non rilevanti per questo setup).

**Subpath vs subdomain**: si usa subpath `/media/` per coerenza con l'architettura SOL (tutti i servizi su subpath). Un subdomain `media.sol.massimilianopili.com` e' l'alternativa se il Base URL causa problemi con i client.

**Stack *Arr come fase separata**: il deploy base (solo Jellyfin) e' funzionale da solo. Lo stack *Arr e' un'aggiunta opzionale per automazione — implementabile in un secondo momento.

**Storage su /data**: il disco HDD da 295 GB ha 266 GB liberi. Per una libreria media iniziale (50-100 film, qualche serie) e' sufficiente. Per crescita futura, considerare un disco dedicato montato come volume aggiuntivo.

---

## Struttura directory media

```
/data/massimiliano/jellyfin/
├── config/          # Configurazione Jellyfin, database SQLite, plugin
├── cache/           # Cache transcoding, thumbnail
├── downloads/       # Download temporanei (qBittorrent → hardlink a media/)
└── media/
    ├── film/
    │   ├── Inception (2010)/
    │   │   ├── Inception (2010).mkv
    │   │   └── Inception (2010).srt
    │   ├── The Matrix (1999)/
    │   │   └── The Matrix (1999).mkv
    │   └── ...
    ├── serie/
    │   ├── Breaking Bad/
    │   │   ├── Season 01/
    │   │   │   ├── Breaking Bad - S01E01 - Pilot.mkv
    │   │   │   └── Breaking Bad - S01E02 - Cat's in the Bag.mkv
    │   │   └── Season 02/
    │   │       └── ...
    │   └── ...
    └── musica/
        ├── Artist Name/
        │   └── Album Title (2020)/
        │       ├── 01 - Track Name.flac
        │       └── folder.jpg
        └── ...
```

**Regole naming** (necessarie per metadata scraping TMDb/MusicBrainz):
- Film: `Titolo (Anno)/Titolo (Anno).ext` — una cartella per film
- Serie: `Nome Serie/Season XX/Nome Serie - SXXEXX - Titolo Episodio.ext`
- Musica: `Artista/Album (Anno)/NN - Titolo.ext`

---

## Step di implementazione

### Fase 1: Deploy base Jellyfin (~3-4h)

#### Step 1: Creare directory

```bash
mkdir -p /data/massimiliano/jellyfin/{config,cache,media/{film,serie,musica},downloads,arr-config/{prowlarr,sonarr,radarr,bazarr,qbittorrent}}
```

#### Step 2: Creare docker-compose.yml

**`/data/massimiliano/jellyfin/docker-compose.yml`**:

```yaml
services:
  jellyfin:
    image: jellyfin/jellyfin:latest
    container_name: jellyfin
    restart: unless-stopped
    user: "1000:1000"
    environment:
      TZ: Europe/Rome
      JELLYFIN_PublishedServerUrl: https://sol.massimilianopili.com/media
    volumes:
      - ./config:/config
      - ./cache:/cache
      - ./media:/media:ro
    deploy:
      resources:
        limits:
          memory: 4g
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8096/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    security_opt:
      - no-new-privileges:true
    networks:
      - shared

networks:
  shared:
    external: true
```

Note:
- Transcoding software (CPU) — nessun device GPU
- `./media:ro` — Jellyfin legge i media in sola lettura (le scritture le fanno Sonarr/Radarr)
- `user: "1000:1000"` — stesso UID/GID dell'utente massimiliano
- Nessuna porta esposta — raggiungibile via rete `shared` Docker dal container nginx

#### Step 3: Configurare nginx

Aggiungere in **entrambi** i server block (:80 Tailscale e :8888 Pubblico) di `/data/massimiliano/proxy/nginx.conf`:

```nginx
# Jellyfin Media Server (SSO OIDC nativo)
location /media/ {
    set $jellyfin_upstream http://jellyfin:8096;
    proxy_pass $jellyfin_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;

    # WebSocket (necessario per SyncPlay e comunicazione real-time)
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # Streaming: disabilita buffering, timeout lunghi
    proxy_buffering off;
    proxy_request_buffering off;
    proxy_connect_timeout 600s;
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
    send_timeout 600s;

    # Nessun limite upload (media management)
    client_max_body_size 0;
}
```

Note: nessun `auth_request` — Jellyfin ha la propria autenticazione + SSO OIDC. Lazy DNS con `set $var` come da pattern SOL.

#### Step 4: Avvio e configurazione iniziale

```bash
# Avvio Jellyfin
cd /data/massimiliano/jellyfin && docker compose up -d

# Reload nginx
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

Primo accesso:
1. Navigare a `http://100.86.46.84/media/`
2. Wizard iniziale: lingua, utente admin, librerie media
3. Dashboard → Networking → Base URL: `/media`
4. Dashboard → Playback → Transcoding: **Software** (nessun HW acceleration)
5. Aggiungere librerie: Film (`/media/film`), Serie TV (`/media/serie`), Musica (`/media/musica`)
6. Metadata: abilitare TMDb (film/serie), MusicBrainz (musica), OpenSubtitles (sottotitoli)

#### Step 5: Configurare SSO OIDC con Keycloak

**Keycloak — creare client:**
- Client ID: `jellyfin`
- Client Protocol: `openid-connect`
- Access Type: `confidential`
- Valid Redirect URIs:
  - `https://sol.massimilianopili.com/media/sso/OID/redirect/Keycloak`
  - `http://100.86.46.84/media/sso/OID/redirect/Keycloak`
- Mapper: Audience → `jellyfin`

**Jellyfin — installare plugin SSO:**
1. Dashboard → Plugins → Repositories → aggiungere:
   `https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json`
2. Installare "SSO Authentication" → riavviare Jellyfin
3. Configurare provider:
   - Nome: `Keycloak`
   - OIDC Endpoint: `http://keycloak:8080/realms/sol` (rete interna Docker)
   - Client ID: `jellyfin`
   - Client Secret: (dal client Keycloak)
   - Scope: `openid profile email`
   - Default role: User
   - Admin claim: `realm_access.roles` contiene `admin`

### Fase 2: Stack *Arr — automazione (opzionale, ~3-4h aggiuntive)

#### Step 6: docker-compose *Arr stack

**`/data/massimiliano/jellyfin/docker-compose.arr.yml`** (stack separata, stessa rete):

```yaml
services:
  prowlarr:
    image: linuxserver/prowlarr:latest
    container_name: prowlarr
    restart: unless-stopped
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Rome
    volumes:
      - ./arr-config/prowlarr:/config
    deploy:
      resources:
        limits:
          memory: 256m
    networks:
      - shared

  sonarr:
    image: linuxserver/sonarr:latest
    container_name: sonarr
    restart: unless-stopped
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Rome
    volumes:
      - ./arr-config/sonarr:/config
      - ./media/serie:/tv
      - ./downloads:/downloads
    deploy:
      resources:
        limits:
          memory: 512m
    networks:
      - shared

  radarr:
    image: linuxserver/radarr:latest
    container_name: radarr
    restart: unless-stopped
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Rome
    volumes:
      - ./arr-config/radarr:/config
      - ./media/film:/movies
      - ./downloads:/downloads
    deploy:
      resources:
        limits:
          memory: 512m
    networks:
      - shared

  bazarr:
    image: linuxserver/bazarr:latest
    container_name: bazarr
    restart: unless-stopped
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Rome
    volumes:
      - ./arr-config/bazarr:/config
      - ./media/serie:/tv
      - ./media/film:/movies
    deploy:
      resources:
        limits:
          memory: 256m
    networks:
      - shared

  qbittorrent:
    image: linuxserver/qbittorrent:latest
    container_name: qbittorrent
    restart: unless-stopped
    environment:
      PUID: "1000"
      PGID: "1000"
      TZ: Europe/Rome
      WEBUI_PORT: "8080"
    volumes:
      - ./arr-config/qbittorrent:/config
      - ./downloads:/downloads
    deploy:
      resources:
        limits:
          memory: 512m
    networks:
      - shared

networks:
  shared:
    external: true
```

Note:
- `/downloads` e `/media/*` sullo stesso filesystem → hardlink atomici (no copia)
- Ogni container *Arr: 256-512 MB RAM, totale stack ~2 GB
- Tutti su rete `shared`, raggiungibili per nome DNS Docker

#### Step 7: Route nginx per *Arr

Aggiungere in nginx.conf (entrambi i server block), protette da OAuth2 Proxy (admin only):

```nginx
# Stack *Arr — gestione media (OAuth2 Proxy auth)
location /sonarr/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $sonarr_upstream http://sonarr:8989;
    proxy_pass $sonarr_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /radarr/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $radarr_upstream http://radarr:7878;
    proxy_pass $radarr_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /prowlarr/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $prowlarr_upstream http://prowlarr:9696;
    proxy_pass $prowlarr_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /bazarr/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $bazarr_upstream http://bazarr:6767;
    proxy_pass $bazarr_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

location /qbt/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    set $qbt_upstream http://qbittorrent:8080;
    proxy_pass $qbt_upstream;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

#### Step 8: Configurazione inter-servizio

1. **Prowlarr**: aggiungere indexer (1337x, RARBG, Nyaa, etc.)
2. **Prowlarr → Sonarr/Radarr**: sync automatico indexer
3. **Sonarr**: Root Folder `/tv`, Download Client → qBittorrent (`qbittorrent:8080`)
4. **Radarr**: Root Folder `/movies`, Download Client → qBittorrent
5. **Bazarr**: Sonarr/Radarr integration (API key), lingue sottotitoli (it, en)
6. **Sonarr/Radarr → Jellyfin**: notifica via webhook per scan immediato libreria

### Fase 3: GPU remota (evoluzione futura)

Quando il server GPU sara' operativo, esporre la 3090 per il transcoding Jellyfin. Opzioni:

1. **NVIDIA GPU Remoting**: virtualizzazione GPU remota — il container Jellyfin su SOL "vede" la GPU remota. Richiede NVIDIA GRID/vGPU o soluzioni simili.
2. **FFmpeg transcoding proxy**: servizio dedicato sul server GPU che riceve richieste di transcoding da Jellyfin via API. Jellyfin delega il transcoding al proxy remoto.
3. **Migrazione Jellyfin**: spostare il container Jellyfin sul server GPU e fare reverse proxy da SOL (l'approccio piu' semplice ma cambia l'architettura).

Da valutare quando il server GPU sara' disponibile. Per ora il transcoding SW e' sufficiente per 1080p.

---

## Risorse di sistema

### RAM (su SOL)

| Componente | RAM stimata |
|------------|-------------|
| Jellyfin (idle, libreria media) | ~300-500 MB |
| Jellyfin (1 transcoding SW 1080p) | +500 MB - 1 GB |
| Jellyfin (1 transcoding SW 4K) | +1-2 GB (sconsigliato) |
| Stack *Arr (5 container) | ~1.5-2 GB |
| qBittorrent (download attivo) | ~200-500 MB |
| **Totale massimo** | **~3-5 GB** |

### Disco

- Libreria media: variabile (50 film 1080p ≈ ~200-400 GB, 4K ≈ ~1-2 TB)
- Config + cache: ~1-5 GB
- Downloads temporanei: variabile (spazio per 2-3 download simultanei)
- **Attenzione**: con 266 GB liberi su `/data`, pianificare in base alla dimensione della libreria. Per crescita, aggiungere disco dedicato.

---

## File coinvolti

| File | Azione | Descrizione |
|------|--------|-------------|
| `/data/massimiliano/jellyfin/` | **Nuovo** | Directory progetto |
| `/data/massimiliano/jellyfin/docker-compose.yml` | **Nuovo** | Stack Jellyfin |
| `/data/massimiliano/jellyfin/docker-compose.arr.yml` | **Nuovo** | Stack *Arr (opzionale) |
| `/data/massimiliano/proxy/nginx.conf` | **Modifica** | location /media/ + *Arr (x2 server block) |
| Keycloak realm `sol` | **Modifica** | Nuovo client `jellyfin` (OIDC) |

---

## Verifica

- [ ] `docker ps | grep jellyfin` → status "Up" + healthy
- [ ] `curl -I http://100.86.46.84/media/` → 200 o redirect a wizard
- [ ] `https://sol.massimilianopili.com/media/` → UI Jellyfin via Cloudflare
- [ ] Libreria film/serie visibile con poster e metadata
- [ ] Streaming video funzionante (play diretto + transcoding SW)
- [ ] Login SSO via Keycloak (pulsante "Sign in with Keycloak")
- [ ] (Opzionale) Sonarr/Radarr raggiungibili e connessi a Prowlarr
- [ ] (Opzionale) Download test → file appare in Jellyfin

---

## Tempo stimato

| Fase | Tempo |
|------|-------|
| Fase 1: Jellyfin base (compose + nginx + wizard + SSO) | ~3-4h |
| Fase 2: Stack *Arr (compose + nginx + config inter-servizio) | ~3-4h |
| Fase 3: GPU remota (quando disponibile, da valutare) | ~2-4h |
| **Totale Fase 1** | **~3-4h** |
| **Totale Fase 1+2** | **~6-8h** |

---

## Note

- **Base URL fallback**: se `/media` causa problemi con client mobile, passare a subdomain `media.sol.massimilianopili.com` (aggiungere CNAME Cloudflare + ingress rule in `cloudflared/config.yml`)
- **DLNA**: non funziona dietro reverse proxy — irrilevante per accesso via browser/app
- **Backup**: includere `./config` nel backup restic. I file media non necessitano backup (recuperabili)
- **Visitor**: Jellyfin ha il proprio sistema utenti — non esporre al visitor senza configurare un utente read-only dedicato
- **Transcoding SW**: sufficiente per 1080p. Per 4K preferire Direct Play. GPU remota come evoluzione futura
- **VPN per *Arr**: considerare routing qBittorrent attraverso WireGuard per privacy download (container-level VPN o `wg-manager`)
- **RAM SOL**: con 16 GB totali e ~11 GB usati, lo stack completo (Jellyfin + *Arr ~4-5 GB) potrebbe richiedere attenzione. Fase 1 (solo Jellyfin ~500 MB idle) e' sicura.

## Risorse

- [Jellyfin Docs](https://jellyfin.org/docs/)
- [Jellyfin Docker Installation](https://jellyfin.org/docs/general/installation/container/)
- [Jellyfin nginx Reverse Proxy](https://jellyfin.org/docs/general/post-install/networking/reverse-proxy/nginx/)
- [jellyfin-plugin-sso (OIDC/Keycloak)](https://github.com/9p4/jellyfin-plugin-sso)
- [Servarr Wiki (Sonarr/Radarr/Prowlarr)](https://wiki.servarr.com/)
- [TRaSH Guides (best practice *Arr)](https://trash-guides.info/)
- [LinuxServer.io Docker Images](https://docs.linuxserver.io/)

## Confronto Media Server (per riferimento)

| | Jellyfin | Plex | Emby |
|---|---|---|---|
| **Licenza** | GPLv2 (FOSS) | Proprietary (freemium) | Proprietary (freemium) |
| **HW Transcoding** | Incluso | Plex Pass (~120 EUR) | Premiere (~5 EUR/mese) |
| **Plugin SSO/OIDC** | Si (jellyfin-plugin-sso) | No | No |
| **Client mobile** | App gratuite + Swiftfin (iOS) | App gratuite (limitate senza Pass) | App a pagamento |
| **Metadata** | TMDb, OMDb, MusicBrainz | Plex agents (proprietari) | TMDb, OMDb |
| **SyncPlay** | Si (watch together nativo) | Watch Together (Plex Pass) | Sync Play (Premiere) |
| **RAM runtime** | ~300-500 MB | ~300-600 MB | ~300-500 MB |
| **GitHub Stars** | ~40k | — (closed) | — (closed) |
```

---

## File coinvolti nell'implementazione

- **Creare**: `/data/massimiliano/progetti_futuri/PIANO_MEDIA_SERVER.md` (contenuto sopra)
- **Modificare**: `/data/massimiliano/progetti_futuri/INDICE.md` (nuova riga + statistiche)
