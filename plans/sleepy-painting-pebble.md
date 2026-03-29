# Anthropic API Proxy — Scelta del Modello

## Stato: COMPLETATO

Implementate 3 feature sul proxy (`Vari/anthropic-api-proxy/main.go`):

1. **Catalogo modelli configurabile** — `defaultModels` + `MODELS_FILE` env var opzionale
2. **`/v1/models` filtrato per tier** — catalogo locale, non proxy Anthropic
3. **Header downgrade** — `X-Model-Requested`, `X-Model-Used`, `X-Model-Downgraded`

Deploy eseguito e verificato. Nessuna modifica Keycloak necessaria (ruoli esistenti).
