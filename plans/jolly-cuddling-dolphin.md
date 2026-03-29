# Piano: Integrazione NVIDIA NIM come quarto provider nel proxy-ai

## Contesto

Il proxy-ai (`/data/massimiliano/Vari/anthropic-api-proxy/`) è un reverse proxy Go multi-provider che gestisce Anthropic, Codex e Copilot. L'utente vuole aggiungere **NVIDIA NIM** come quarto provider per accedere a modelli open-source (Llama, Mistral, DeepSeek, Qwen, Nemotron) tramite la stessa infrastruttura auth (JWT Keycloak + tier enforcement).

L'API NVIDIA NIM (`integrate.api.nvidia.com/v1`) è **completamente compatibile con OpenAI Chat Completions**, quindi il pattern è identico a Copilot ma più semplice: API key statica (no OAuth, no token refresh, no per-request token).

## File da modificare

| File | Tipo modifica |
|------|---------------|
| `Vari/anthropic-api-proxy/main.go` | Aggiungere provider NVIDIA (catalogo, init, handler, route, generic dispatch) |
| `Vari/anthropic-api-proxy/docker-compose.yml` | Aggiungere env vars NVIDIA |
| `Vari/anthropic-api-proxy/.env` | Aggiungere `NVIDIA_API_KEY`, `CC_CLIENT_SECRET_NVIDIA` |
| `proxy/nginx.conf` | Aggiungere route `/proxy/ai/nvidia/` su server block :80, :8090, :8888 |

## Implementazione — main.go

### 1. Catalogo modelli default

Aggiungere `defaultNvidiaModels` dopo `defaultCopilotModels` (~riga 125):

```go
var defaultNvidiaModels = []Model{
    // Tier 3 — modelli più grandi e capaci
    {ID: "meta/llama-3.1-405b-instruct", DisplayName: "Llama 3.1 405B", Tier: 3, Description: "Meta's largest open model"},
    {ID: "deepseek/deepseek-v3", DisplayName: "DeepSeek V3", Tier: 3, Description: "DeepSeek flagship model"},
    // Tier 2 — modelli medi, buon rapporto qualità/costo
    {ID: "meta/llama-3.3-70b-instruct", DisplayName: "Llama 3.3 70B", Tier: 2, Description: "Meta's balanced model"},
    {ID: "nvidia/llama-3.1-nemotron-70b-instruct", DisplayName: "Nemotron 70B", Tier: 2, Description: "NVIDIA fine-tuned Llama"},
    {ID: "mistralai/mixtral-8x7b-instruct-v0.1", DisplayName: "Mixtral 8x7B", Tier: 2, Description: "Mistral MoE model"},
    {ID: "qwen/qwen2.5-72b-instruct", DisplayName: "Qwen 2.5 72B", Tier: 2, Description: "Alibaba's large model"},
    // Tier 1 — modelli piccoli e veloci
    {ID: "meta/llama-3.1-8b-instruct", DisplayName: "Llama 3.1 8B", Tier: 1, Description: "Meta's smallest model"},
    {ID: "mistralai/mistral-7b-instruct-v0.3", DisplayName: "Mistral 7B", Tier: 1, Description: "Mistral's base model"},
    {ID: "google/gemma-2-9b-it", DisplayName: "Gemma 2 9B", Tier: 1, Description: "Google's efficient model"},
}
```

### 2. Inizializzazione in main()

Dopo l'init di Copilot, aggiungere il blocco NVIDIA (~riga 350):

```go
// --- NVIDIA provider (optional) ---
nvidiaClientID := envOr("ROLE_CLIENT_ID_NVIDIA", "nvidia_client")
nvidiaCCSecret := os.Getenv("CC_CLIENT_SECRET_NVIDIA")
nvidiaAPIKey := os.Getenv("NVIDIA_API_KEY")
nvidiaBaseURL := envOr("NVIDIA_BASE_URL", "https://integrate.api.nvidia.com")
nvidiaEnabled := nvidiaAPIKey != ""

nvidiaModels := defaultNvidiaModels
if modelsFile := os.Getenv("NVIDIA_MODELS_FILE"); modelsFile != "" {
    if custom, err := loadModelsFile(modelsFile); err != nil {
        log.Fatalf("NVIDIA models file error: %v", err)
    } else if custom != nil {
        nvidiaModels = custom
        log.Printf("Loaded %d NVIDIA models from %s", len(nvidiaModels), modelsFile)
    }
}
nvidiaCatalog := buildCatalog(nvidiaModels)

var nvidiaProxy *httputil.ReverseProxy
if nvidiaEnabled {
    nvidiaProxy = newProviderProxy(nvidiaBaseURL)
    log.Printf("NVIDIA catalog: %d models, tiers: %v", len(nvidiaCatalog.all), nvidiaCatalog.tierBest)
} else {
    log.Printf("NVIDIA provider disabled (no NVIDIA_API_KEY)")
}
```

### 3. Header builder

Aggiungere `buildNvidiaUpstreamHeaders()`:

```go
func buildNvidiaUpstreamHeaders(r *http.Request, apiKey string) http.Header {
    h := make(http.Header, 5)
    h.Set("Authorization", "Bearer "+apiKey)
    h.Set("User-Agent", "nvidia-proxy/1.0")
    h.Set("Accept", "text/event-stream")
    h.Set("Accept-Encoding", "identity")
    h.Set("Content-Type", normalizedContentType(r))
    return h
}
```

### 4. Forward handler

Definire `nvidiaForward` closure in main(). Pattern identico a `copilotForward` ma:
- **No** `extractCopilotUpstreamToken()` — usa `nvidiaAPIKey` statico dall'env
- Check `nvidiaEnabled` all'inizio → 503 se provider non configurato

```go
nvidiaForward := func(w http.ResponseWriter, r *http.Request) {
    if !nvidiaEnabled {
        jsonError(w, `{"error":{"message":"NVIDIA provider not configured","type":"server_error"}}`,
                  http.StatusServiceUnavailable)
        return
    }
    token := extractToken(r)
    if token == "" {
        jsonError(w, `{"error":{"message":"missing api key","type":"authentication_error"}}`,
                  http.StatusUnauthorized)
        return
    }
    user, roles, err := resolveAuth(token, gatewayURL, nvidiaCCSecret,
                                    "CC_CLIENT_SECRET_NVIDIA", "nvidia:"+nvidiaClientID)
    if err != nil {
        jsonError(w, `{"error":{"message":"invalid api key","type":"authentication_error"}}`,
                  http.StatusUnauthorized)
        return
    }
    maxTier := maxTierFromRoles(roles, nvidiaClientID, nvidiaCatalog)
    if err := clampRequestModel(r, "nvidia", user, maxTier, nvidiaCatalog); err != nil {
        jsonError(w, `{"error":{"message":"failed to process request body","type":"invalid_request_error"}}`,
                  http.StatusBadRequest)
        return
    }
    path := strings.TrimPrefix(r.URL.Path, "/nvidia")
    r.URL.Path = path
    if r.URL.RawPath != "" {
        r.URL.RawPath = strings.TrimPrefix(r.URL.RawPath, "/nvidia")
    }
    r.Header = buildNvidiaUpstreamHeaders(r, nvidiaAPIKey)
    nvidiaProxy.ServeHTTP(w, r)
}
```

### 5. Models handler

```go
nvidiaModelsHandler := func(w http.ResponseWriter, r *http.Request) {
    // auth + tier check (stesso pattern di copilotModelsHandler)
    // writeModels() con OwnedBy: "nvidia"
}
```

**Riuso**: se `writeCopilotModels` usa un parametro `ownedBy`, riutilizzare. Altrimenti creare `writeProviderModels(w, catalog, maxTier, ownedBy string)` generico e refactorare Copilot + NVIDIA per usarlo.

### 6. Route registration

Aggiungere dopo le route Copilot:

```go
mux.HandleFunc("GET /nvidia/v1/models", nvidiaModelsHandler)
mux.HandleFunc("POST /nvidia/v1/chat/completions", nvidiaForward)
```

### 7. providerFromClientID()

Aggiungere parametro `nvidiaClientID` e case `"nvidia"`:

```go
func providerFromClientID(token, anthropicClientID, codexClientID, copilotClientID, nvidiaClientID string) string {
    switch token {
    case anthropicClientID:  return "anthropic"
    case codexClientID:      return "codex"
    case copilotClientID:    return "copilot"
    case nvidiaClientID:     return "nvidia"
    default:                 return ""
    }
}
```

Aggiornare tutti i call site di `providerFromClientID()`.

### 8. Generic dispatch

Nei 3 switch del generic handler (`/generic/v1/messages`, `/generic/v1/responses`, `/generic/v1/chat/completions`):

**`/generic/v1/messages`** (client invia formato Anthropic → NVIDIA):
```go
} else if provider == "nvidia" {
    // Traduzione Anthropic → Chat Completions (riuso translateAnthropicToCopilotChat)
    if err := translateAnthropicToCopilotChat(r); err != nil { ... }
    tw := newSSETranslator(w, newCopilotChatToAnthropicTranslate(""))
    r.URL.Path = "/nvidia/v1/chat/completions"
    nvidiaForward(tw, r)
}
```

**`/generic/v1/chat/completions`** (client invia formato Chat Completions → NVIDIA nativo):
```go
} else if provider == "nvidia" {
    r.URL.Path = "/nvidia/v1/chat/completions"
    nvidiaForward(w, r)  // nessuna traduzione, formato nativo
}
```

**`/generic/v1/responses`** (client invia formato Codex Responses → NVIDIA):
```go
} else if provider == "nvidia" {
    // Traduzione Responses → Chat Completions (riuso translateResponsesToCopilotChat)
    if err := translateResponsesToCopilotChat(r); err != nil { ... }
    tw := newSSETranslator(w, newCopilotChatToCodexTranslate(""))
    r.URL.Path = "/nvidia/v1/chat/completions"
    nvidiaForward(tw, r)
}
```

**Riuso traduttori SSE**: NVIDIA usa lo stesso formato SSE di Copilot (Chat Completions), quindi `newCopilotChatToAnthropicTranslate()` e `newCopilotChatToCodexTranslate()` funzionano senza modifiche.

### 9. writeModels refactor (opzionale ma consigliato)

Estrarre una funzione generica da `writeCopilotModels`:

```go
func writeProviderModels(w http.ResponseWriter, catalog modelCatalog, maxTier int, ownedBy string) {
    // ... corpo identico a writeCopilotModels ma con ownedBy parametrico
}
```

Aggiornare `writeCopilotModels` per chiamare `writeProviderModels(..., "github")` e usare `writeProviderModels(..., "nvidia")` per NVIDIA.

## Implementazione — docker-compose.yml

Aggiungere env vars al servizio `proxy-ai`:

```yaml
environment:
  # ... env vars esistenti ...
  - ROLE_CLIENT_ID_NVIDIA=${ROLE_CLIENT_ID_NVIDIA:-nvidia_client}
  - CC_CLIENT_SECRET_NVIDIA=${CC_CLIENT_SECRET_NVIDIA}
  - NVIDIA_API_KEY=${NVIDIA_API_KEY}
  - NVIDIA_BASE_URL=${NVIDIA_BASE_URL:-https://integrate.api.nvidia.com}
```

## Implementazione — .env

Aggiungere:

```
NVIDIA_API_KEY=nvapi-xxxxxxxxxxxxxxxx
CC_CLIENT_SECRET_NVIDIA=<da creare in Keycloak>
```

## Implementazione — nginx.conf

Aggiungere route `/proxy/ai/nvidia/` nei 3 server block (`:80`, `:8090`, `:8888`).
Pattern: prefix stripping (come `/proxy/ai/copilot/`):

```nginx
location /proxy/ai/nvidia/ {
    set $proxyai_upstream http://proxy-ai:8097;
    rewrite ^/proxy/ai/nvidia/(.*) /nvidia/$1 break;
    proxy_pass $proxyai_upstream;
    proxy_http_version 1.1;
    proxy_set_header Connection '';
    proxy_buffering off;
    proxy_read_timeout 300s;
}
```

## Setup Keycloak (manuale, post-deploy)

1. **Clients** → Create `nvidia_client` (confidential, service account enabled)
2. **Client Scopes** → `nvidia_client-dedicated` → mapper per `resource_access`
3. **Roles** nel client: `opus` (tier 3), `sonnet` (tier 2), `haiku` (tier 1) — stessi nomi per coerenza
4. **User `sol_root`** → Role mapping → assegnare tutti e 3 i ruoli
5. **User `visitor`** → Role mapping → assegnare solo `haiku` (tier 1, read-only)
6. Copiare il Client Secret → `.env` come `CC_CLIENT_SECRET_NVIDIA`

## Documentazione

Aggiornare `CLAUDE.md`:
- Tabella routing: aggiungere riga `/proxy/ai/nvidia/`
- Tabella servizi: aggiungere nota NVIDIA nel Proxy AI
- Tabella configurazioni subpath: aggiungere riga NVIDIA

Aggiornare `proxy/home/docs/` (OpenAPI spec) se presente una spec per proxy-ai.

## Ordine di implementazione

1. **main.go** — catalogo modelli + init + header builder + forward handler + models handler + route registration + providerFromClientID + generic dispatch
2. **docker-compose.yml** — env vars
3. **.env** — API key + client secret (placeholder)
4. **nginx.conf** — route `/proxy/ai/nvidia/` nei 3 server block
5. **Build + deploy** — `docker compose build && docker compose up -d --force-recreate`
6. **Keycloak** — setup client (manuale)
7. **Test** — verifica e2e

## Verifica

1. **Health check**: `curl http://100.86.46.84/proxy/ai/nvidia/health` → 200 (o 503 se no API key)
2. **Models**: `curl -H "x-api-key: nvidia_client" http://100.86.46.84/proxy/ai/nvidia/v1/models` → lista modelli filtrata per tier
3. **Chat Completions** (formato nativo):
   ```bash
   curl -X POST http://100.86.46.84/proxy/ai/nvidia/v1/chat/completions \
     -H "x-api-key: nvidia_client" \
     -H "Content-Type: application/json" \
     -d '{"model":"meta/llama-3.1-8b-instruct","messages":[{"role":"user","content":"Say hello"}],"max_tokens":50,"stream":true}'
   ```
4. **Generic dispatch** (formato Anthropic → NVIDIA):
   ```bash
   curl -X POST http://100.86.46.84/proxy/ai/generic/v1/messages \
     -H "x-api-key: nvidia_client" \
     -H "Content-Type: application/json" \
     -d '{"model":"meta/llama-3.1-8b-instruct","messages":[{"role":"user","content":"Say hello"}],"max_tokens":50,"stream":true}'
   ```
5. **Tier enforcement**: richiedere un modello tier 3 con ruolo tier 1 → header `X-Model-Downgraded: true`
6. **Nginx**: verificare che `/proxy/ai/nvidia/` funzioni su `:80`, `:8090`, `:8888`
