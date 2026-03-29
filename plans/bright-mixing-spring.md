# Fix Embedding Space — timeout su cache refresh [COMPLETATO]

## Contesto

L'Embedding Space (`embedding-viz`) rimane in caricamento quando il cache è scaduto (TTL 5 min).
Il cache refresh scarica 15082 vettori da pgvector, li parsa e calcola PCA (1024-dim → 2D). Questo impiega **~65 secondi**, ma:

1. **Go server `WriteTimeout: 60s`** (`main.go:100`) — la connessione si chiude prima che il refresh finisca
2. **Nginx `proxy_read_timeout` default 60s** — nessun timeout custom per `/embeddings/` (righe 327-336, 1286-1295 di `nginx.conf`)

Il risultato: ogni 5 minuti la prima richiesta muore per timeout e la pagina resta in loading.

## Fix

### 1. Aumentare WriteTimeout del Go server
**File**: `/data/massimiliano/embedding-viz/main.go:100`
- Cambiare `WriteTimeout: 60 * time.Second` → `WriteTimeout: 120 * time.Second`

### 2. Aggiungere proxy_read_timeout nginx
**File**: `/data/massimiliano/proxy/nginx.conf`
- Riga ~332 (blocco Tailscale): aggiungere `proxy_read_timeout 120s;`
- Riga ~1291 (blocco pubblico): aggiungere `proxy_read_timeout 120s;`

## File da modificare

1. `/data/massimiliano/embedding-viz/main.go` — WriteTimeout
2. `/data/massimiliano/proxy/nginx.conf` — proxy_read_timeout per embeddings

## Deploy

```bash
# 1. Rebuild embedding-viz
cd /data/massimiliano/embedding-viz && docker compose up -d --build

# 2. Reload nginx
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

## Verifica

1. `curl -s http://localhost:80/embeddings/health` → 200
2. Aprire `/embeddings/` nel browser → la pagina si carica senza restare in loading
