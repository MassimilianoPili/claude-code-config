# Plan: Add Ollama Provider to Proxy AI + Set as Default

## Context

Il proxy AI (`anthropic-api-proxy`, Go, ~2540 righe) supporta 4 provider (Anthropic, Codex, Copilot, NVIDIA). L'utente vuole:
1. Verificare che il proxy funzioni
2. Aggiungere Ollama su Gaia (`100.109.3.40:11434`, Tailscale) come 5° provider
3. Far sì che il default (catch-all `/`) punti a Ollama anziché Anthropic

Ollama espone API OpenAI-compatible (`/v1/chat/completions`), stessa interfaccia di NVIDIA. Modelli disponibili: `qwen3.5:27b` (27B), `qwen3:4b` (4B).

## Critical Files

- `/data/massimiliano/Vari/anthropic-api-proxy/main.go` — codice proxy (~2540 righe)
- `/data/massimiliano/Vari/anthropic-api-proxy/.env` — config secrets
- `/data/massimiliano/Vari/anthropic-api-proxy/docker-compose.yml` — container config

## Funzioni/pattern esistenti da riusare

- `newProviderProxy(baseURL)` (line 887) — crea httputil.ReverseProxy
- `buildNvidiaUpstreamHeaders()` (line 715) — template per Ollama (senza `Authorization`)
- `writeNvidiaModels()` (line 855) — template per writeOllamaModels (cambio `owned_by`)
- `resolveAuth()` — auth caller via jwt-gateway (già usata da tutti i provider)
- `clampRequestModel()` (line 727) — tier enforcement
- `providerFromClientID()` (line 642) — dispatch per generic route
- `translateAnthropicToCopilotChat()` — riusabile per Ollama (stessa interfaccia OpenAI)
- `translateResponsesToCopilotChat()` — riusabile per Ollama

## Steps

### Step 1: Verify proxy health
```bash
curl -s http://localhost:8097/health
```

### Step 2: Add Ollama provider to main.go

**2a. Model catalog** (dopo line ~383):
```go
var defaultOllamaModels = []Model{
    {ID: "qwen3.5:27b", DisplayName: "Qwen 3.5 27B", Tier: 3, Description: "Largest local model (RTX 3090)"},
    {ID: "qwen3:4b", DisplayName: "Qwen 3 4B", Tier: 1, Description: "Fast local model"},
}
```

**2b. Header builder** (dopo line ~723):
```go
func buildOllamaUpstreamHeaders(r *http.Request) http.Header {
    h := make(http.Header, 4)
    h.Set("User-Agent", "ollama-proxy/1.0")
    h.Set("Accept", "text/event-stream")
    h.Set("Accept-Encoding", "identity")
    h.Set("Content-Type", normalizedContentType(r))
    return h
}
```

**2c. writeOllamaModels** (dopo writeNvidiaModels, line ~885) — copia di writeNvidiaModels con `OwnedBy: "ollama"`

**2d. Provider setup block** (dopo NVIDIA setup, ~line 2006):
- Env vars: `ROLE_CLIENT_ID_OLLAMA` (default `ollama_client`), `CC_CLIENT_SECRET_OLLAMA`, `OLLAMA_BASE_URL` (default `http://100.109.3.40:11434`), `OLLAMA_MODELS_FILE`
- `ollamaEnabled = true` (sempre attivo — no API key needed)
- `ollamaProxy = newProviderProxy(ollamaBaseURL)`

**2e. Handlers**:
- `ollamaModelsHandler` — auth + writeOllamaModels
- `ollamaForward` — auth + clampRequestModel + strip prefix + buildOllamaUpstreamHeaders + proxy

**2f. Route registration**:
```go
mux.HandleFunc("GET /ollama/v1/models", ollamaModelsHandler)
mux.HandleFunc("POST /ollama/v1/chat/completions", ollamaForward)
mux.HandleFunc("/ollama/", /* 404 */)
```

**2g. Update `providerFromClientID`** (line 642): aggiungere parametro `ollamaClientID` e case `"ollama"`

**2h. Update generic route** (line 2348): aggiungere `provider == "ollama"` branches:
- `chat/completions` → native pass-through
- `messages` → translateAnthropicToCopilotChat (riuso) + newCopilotChatToAnthropicTranslate
- `responses` → translateResponsesToCopilotChat (riuso) + newCopilotChatToCodexTranslate
- `models` → ollamaModelsHandler

**2i. Catch-all default → Ollama**:
```go
mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
    ollamaForward(w, r)  // era: anthropicForward(w, r)
})
```

**2j. Startup log**: aggiungere ollama labels

### Step 3: docker-compose.yml — aggiungere env vars
```yaml
- ROLE_CLIENT_ID_OLLAMA=${ROLE_CLIENT_ID_OLLAMA:-ollama_client}
- CC_CLIENT_SECRET_OLLAMA=${CC_CLIENT_SECRET_OLLAMA}
- OLLAMA_BASE_URL=${OLLAMA_BASE_URL:-http://100.109.3.40:11434}
```

### Step 4: .env — aggiungere CC_CLIENT_SECRET_OLLAMA
Generare secret random per il client_credentials flow.

### Step 5: Keycloak client `ollama_client`
Creare in realm `sol` con:
- Client authentication: ON
- Service account roles: ON (client_credentials)
- Secret → copiare in .env come CC_CLIENT_SECRET_OLLAMA

### Step 6: Build & deploy
```bash
cd /data/massimiliano/Vari/anthropic-api-proxy
docker compose build proxy-ai
sol deploy anthropic-api-proxy
```

### Step 7: Verify

```bash
# Health check
curl -s http://localhost:8097/health

# Ollama route diretto
curl -s http://localhost:8097/ollama/v1/chat/completions \
  -H "x-api-key: ollama_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:4b","messages":[{"role":"user","content":"hello"}]}'

# Default catch-all (ora Ollama)
curl -s http://localhost:8097/v1/chat/completions \
  -H "x-api-key: ollama_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3:4b","messages":[{"role":"user","content":"hello"}]}'

# Anthropic route (verificare che funziona ancora)
curl -s http://localhost:8097/v1/messages \
  -H "x-api-key: <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"model":"claude-sonnet-4-6","max_tokens":100,"messages":[{"role":"user","content":"hello"}]}'

# Generic route con ollama_client
curl -s http://localhost:8097/generic/v1/chat/completions \
  -H "x-api-key: ollama_client" \
  -H "Content-Type: application/json" \
  -d '{"model":"qwen3.5:27b","messages":[{"role":"user","content":"hello"}]}'

# Via nginx/Tailscale
curl -s http://100.86.46.84:8090/health
```
