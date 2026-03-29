# Ottimizzazione caricamento icone architecture.html

## Contesto

Il diagramma architettura carica 3 pack Iconify JSON da unpkg CDN al primo render:
- `simple-icons` ~700KB (usiamo 16 icone su ~2700)
- `logos` ~2MB (usiamo 4 icone su ~1500)
- `fa6-solid` ~150KB (usiamo 16 icone su ~1400)

Totale: **~3MB** di JSON per **36 icone**. Il primo caricamento e' lento.

## Soluzione

Creare 3 mini-pack JSON con solo le icone usate, hostati localmente su nginx. Risultato stimato: **~30-50KB** totali (riduzione ~98%).

## Passo 1 — Scaricare i pack completi e estrarre le icone

```bash
mkdir -p /data/massimiliano/proxy/home/static/icons

# Scaricare pack, estrarre solo icone usate con jq
```

### Icone da estrarre

**fa6-solid** (16): `globe`, `folder-open`, `house`, `lock`, `database`, `envelope`, `chart-bar`, `book`, `book-open`, `server`, `terminal`, `sort`, `shield-halved`, `microchip`, `arrows-left-right`, `play`

**simple-icons** (16): `tailscale`, `torproject`, `cloudflare`, `nginx`, `gitea`, `visualstudiocode`, `portainer`, `mongodb`, `grafana`, `minio`, `jenkins`, `anthropic`, `keycloak`, `prometheus`, `docker`, `wireguard`

**logos** (4): `postgresql`, `redis`, `mongodb-icon`, `neo4j`

### Formato JSON Iconify

```json
{
  "prefix": "nome-pack",
  "icons": {
    "nome-icona": { "body": "<path d=\"...\"/>", "width": 24, "height": 24 }
  },
  "width": 24,
  "height": 24
}
```

Estrarre con `jq` mantenendo `prefix`, `width`, `height` globali e solo le `icons` necessarie.

## Passo 2 — Aggiornare registerIconPacks

Da:
```javascript
fetch('https://unpkg.com/@iconify-json/simple-icons@1/icons.json')
```

A:
```javascript
fetch('/static/icons/simple-icons.json')
```

Stesso pattern per tutti e 3 i pack. I file locali vengono serviti da nginx istantaneamente (stesso server, zero latenza CDN).

## Passo 3 — Deploy

```bash
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

## File da modificare

| File | Modifica |
|------|----------|
| `proxy/home/static/icons/fa6-solid.json` | **NUOVO** — mini-pack 16 icone |
| `proxy/home/static/icons/simple-icons.json` | **NUOVO** — mini-pack 16 icone |
| `proxy/home/static/icons/logos.json` | **NUOVO** — mini-pack 4 icone |
| `proxy/home/architecture.html` | Aggiornare 3 URL fetch da unpkg a `/static/icons/` |

## Verifica

1. `ls -lh /data/massimiliano/proxy/home/static/icons/` — file < 100KB ciascuno
2. Browser: `http://100.86.46.84/architecture.html` — icone visibili, render veloce
3. DevTools Network: 3 fetch a `/static/icons/*.json` invece di `unpkg.com`, tempo < 100ms
