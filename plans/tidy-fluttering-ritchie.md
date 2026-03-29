# Fix Cloudflare 403 blocking on chatgpt.com — TLS fingerprint

## Contesto

Il proxy Codex (`proxy-ai`) usa `httputil.ReverseProxy` verso `chatgpt.com`. Cloudflare restituisce HTTP 403 con pagina HTML "Unable to load site" al proxy Go, ma curl dallo stesso server (IP 5.90.152.174) passa senza problemi.

**Root cause**: Go 1.22 `net/http` ha un TLS fingerprint (JA3/JA4) distintivo che Cloudflare identifica come traffico bot. curl usa OpenSSL con un fingerprint diverso che non viene bloccato. Il cambio di User-Agent non aiuta: Cloudflare verifica il TLS ClientHello *prima* di vedere le HTTP headers.

**Evidenza dai log**:
```
08:52:23 Upstream chatgpt.com returned HTML (status=403, len=3357)  # 3 retry
09:45:36 Upstream chatgpt.com returned HTML (status=403, len=3354)  # 3 retry
```
Il proxy Anthropic (`api.anthropic.com`) NON ha questo problema.

## File da modificare

- **`/data/massimiliano/Vari/anthropic-api-proxy/main.go`** — unico file

## Approccio: Custom `http.Transport` con TLS config Chrome-like

### Step 1: Aggiungere import `crypto/tls` e `net`

```go
import (
    "crypto/tls"
    "net"
    // ... existing imports ...
)
```

### Step 2: Creare un Transport custom per il codex proxy

Nella funzione `newProviderProxy()`, creare un `*http.Transport` separato per `chatgpt.com` con un `tls.Config` che modifica il fingerprint TLS rispetto al default di Go:

```go
func newProviderProxy(targetRawURL string) *httputil.ReverseProxy {
    target, _ := url.Parse(targetRawURL)

    // Custom transport for chatgpt.com to avoid Cloudflare TLS fingerprint blocking.
    // Go's default TLS ClientHello has a distinctive JA3 hash that Cloudflare detects.
    // We customize cipher suites and curves to produce a different fingerprint.
    var transport http.RoundTripper
    if target.Host == "chatgpt.com" {
        transport = &http.Transport{
            TLSClientConfig: &tls.Config{
                MinVersion: tls.VersionTLS12,
                MaxVersion: tls.VersionTLS13,
                CipherSuites: []uint16{
                    // Chrome-like ordering: ECDHE+AESGCM first, then ChaCha20
                    tls.TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256,
                    tls.TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256,
                    tls.TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384,
                    tls.TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384,
                    tls.TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256,
                    tls.TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256,
                },
                CurvePreferences: []tls.CurveID{
                    tls.X25519,    // Chrome puts X25519 first
                    tls.CurveP256,
                    tls.CurveP384,
                },
            },
            ForceAttemptHTTP2: true,
            DialContext: (&net.Dialer{
                Timeout:   30 * time.Second,
                KeepAlive: 30 * time.Second,
            }).DialContext,
            MaxIdleConns:        100,
            IdleConnTimeout:     90 * time.Second,
            TLSHandshakeTimeout: 10 * time.Second,
        }
    }

    return &httputil.ReverseProxy{
        Transport:     transport, // nil = default for Anthropic, custom for chatgpt.com
        Director:      /* ... unchanged ... */,
        FlushInterval: 10 * time.Millisecond,
        /* ... rest unchanged ... */
    }
}
```

**Perché funziona**: Cloudflare confronta il JA3 hash (derivato dall'ordine cipher suites + curve + extensions nel TLS ClientHello) con i pattern noti dei bot. Cambiare l'ordine delle cipher suites e le curve preferences produce un hash diverso che non corrisponde al fingerprint di `Go-http-client`.

**Nota TLS 1.3**: I `CipherSuites` nel config di Go 1.22 influenzano solo TLS 1.2. Le cipher suites TLS 1.3 non sono configurabili e vengono sempre incluse. Tuttavia, le `CurvePreferences` influenzano anche TLS 1.3, e mettere `X25519` prima è il pattern Chrome/Firefox.

### Step 3: Nessuna modifica ad anthropicProxy

`api.anthropic.com` non ha Cloudflare bot detection aggressivo → lasciare `Transport: nil` (default Go) per il proxy Anthropic.

## Scope della modifica

- **~20 righe** di codice nuovo in `newProviderProxy()`
- **2 import** nuovi: `crypto/tls`, `net`
- **Zero dipendenze esterne** (tutto stdlib)
- **Nessuna modifica** alle route, handler, o traduzione SSE
- Il cambio User-Agent (`codex-proxy/1.0`) e HTML detection (ModifyResponse) restano come difesa secondaria

## Verifica

### Test locali (localhost → proxy-ai diretto)

```bash
cd /data/massimiliano/Vari/anthropic-api-proxy
docker compose up -d --build --remove-orphans
docker logs proxy-ai --tail 5

# Test 1: Direct codex route (il test critico - deve passare senza 403)
curl -s -N -X POST http://127.0.0.1:8097/codex/v1/responses \
  -H "x-api-key: codex_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.1-codex-mini","instructions":"test","input":[{"role":"user","content":"Say hi"}],"store":false,"stream":true}' | head -c 500

# Test 2: Cross-provider (codex_client su /messages → traduzione)
curl -s -N -X POST http://127.0.0.1:8097/generic/v1/messages \
  -H "x-api-key: codex_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.1-codex-mini","system":"test","messages":[{"role":"user","content":"Hi"}],"max_tokens":100,"stream":true}' | head -c 500

# Test 3: Anthropic (regressione — deve continuare a funzionare)
curl -s -N -X POST http://127.0.0.1:8097/v1/messages \
  -H "x-api-key: claude_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","messages":[{"role":"user","content":"Hi"}],"max_tokens":50,"stream":true}' | head -c 500
```

### Test pubblici (sol.massimilianopili.com → Cloudflare Tunnel → nginx → proxy-ai)

```bash
# Test 4: Codex via URL pubblica (path completo: Cloudflare → nginx → proxy-ai → chatgpt.com)
curl -s -N -X POST https://sol.massimilianopili.com/proxy/ai/codex/v1/responses \
  -H "x-api-key: codex_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.1-codex-mini","instructions":"test","input":[{"role":"user","content":"Say hi"}],"store":false,"stream":true}' | head -c 500

# Test 5: Cross-provider via URL pubblica
curl -s -N -X POST https://sol.massimilianopili.com/proxy/ai/generic/v1/messages \
  -H "x-api-key: codex_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.1-codex-mini","system":"test","messages":[{"role":"user","content":"Hi"}],"max_tokens":100,"stream":true}' | head -c 500

# Test 6: Anthropic via URL pubblica
curl -s -N -X POST https://sol.massimilianopili.com/proxy/ai/claude/v1/messages \
  -H "x-api-key: claude_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-haiku-4-5-20251001","messages":[{"role":"user","content":"Hi"}],"max_tokens":50,"stream":true}' | head -c 500

# Test 7: Via Tailscale (stessa path ma HTTP diretto)
curl -s -N -X POST http://100.86.46.84/proxy/ai/codex/v1/responses \
  -H "x-api-key: codex_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"gpt-5.1-codex-mini","instructions":"test","input":[{"role":"user","content":"Say hi"}],"store":false,"stream":true}' | head -c 500
```

### Verifica log

```bash
# Deve NON mostrare nuovi "returned HTML" dopo il deploy
docker logs proxy-ai 2>&1 | grep "returned HTML"

# Health
curl -s http://127.0.0.1:8097/health
```

Se i test Codex (1, 2, 4, 5, 7) restituiscono eventi SSE invece di 403 HTML, il fix è corretto.

## Rischio residuo

Se Cloudflare usa anche fingerprinting basato sulle TLS extensions (non solo cipher suites), potrebbe essere necessario usare `utls` (libreria esterna Go per TLS fingerprint spoofing). Questo romperebbe il vincolo zero-dependency. In quel caso, valutare:
1. Aggiungere `github.com/refraction-networking/utls` come unica dipendenza
2. Oppure usare `api.openai.com` come upstream alternativo (richiede un API key OpenAI, non il ChatGPT token)
