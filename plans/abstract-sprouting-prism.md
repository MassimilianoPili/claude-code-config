# OpenCloud — Keycloak Identity Backend: PR Upstream

## Context

OpenCloud (fork oCIS) richiede LDAP anche quando Keycloak è l'IdP. Stiamo contribuendo un **Keycloak Admin API identity backend** che elimina LDAP per chi usa già Keycloak. Il container è deployed e funzionante su SOL (`cloud.massimilianopili.com`). Ci sono 15 file staged (999 inserzioni) non committati. L'obiettivo è completare il lavoro e preparare una PR upstream eccellente che dimostri gestione centralizzata su Keycloak.

## Convenzioni progetto (da CONTRIBUTING.md)

- **Commit**: conventional commits, present tense, imperative → `feat(graph): add Keycloak identity backend`
- **Branch**: lowercase, hyphens, <30 char → `feat-keycloak-identity-backend`
- **Logger**: `kb.logger.SubloggerWithRequestID(ctx)` (zerolog), MAI `fmt.Printf`
- **Error codes**: `errorcode.New()` dal pacchetto interno
- **Linter**: golangci-lint (errcheck, staticcheck, govet abilitati)
- **Test**: testify/mock + testify/assert, mocked clients
- **PR template**: Description, Related Issue, Motivation, Test cases, Screenshots, Checklist
- **Dipendenza**: gocloak v13.9.0 già in go.mod

## Decisioni architetturali da tracciare

| # | Decisione | Motivazione | Alternativa scartata |
|---|-----------|-------------|---------------------|
| D1 | **Tutto su Keycloak**: graph + REVA users + REVA groups | Keycloak è l'unica fonte di verità per utenti e gruppi. Zero LDAP, zero duplicazione, un solo punto di gestione | Approccio ibrido (graph su Keycloak + REVA su LDAP) — fragile, due fonti di verità, richiede sync |
| D2 | gocloak v13 per Admin REST API | Già in go.mod (usato da `services/invitations`), zero nuove dipendenze | HTTP client raw (più codice, meno type safety) |
| D3 | Token caching con expiry check | Riduce chiamate auth ~10x, pattern standard OAuth2 | Fresh token per request (attuale — funziona ma inefficiente) |
| D4 | `OC_EXCLUDE_RUN_SERVICES=idp,idm,auth-basic,groups` | Keycloak gestisce tutto → nessun servizio identity interno necessario | Tenere servizi interni attivi "per sicurezza" (spreco risorse, confusione) |
| D5 | OIDC well-known URL rewrite nel proxy | Browser riceve URL pubblici, non Docker DNS interni | Config manuale per ogni client (fragile, error-prone) |
| D6 | PR unica con commit logici | Feature coerente, reviewer segue il filo. Split solo se >1500 righe | PR multiple separate (più overhead di review, dipendenze tra PR) |

## Analisi codice — problemi e qualità

### Codice solido (non toccare)
- `services/graph/pkg/identity/keycloak.go` — 307 righe, 16 metodi Backend, zerolog, OData filter. **OK**
- `services/proxy/pkg/staticroutes/oidc_well-known.go` — URL rewrite con closure pre-calcolato. **OK**
- `pkg/keycloak/gocloak.go` — interface GoCloak con `GetUserGroups` già presente (riga 17). **OK**
- `pkg/keycloak/client.go` — conversioni KC↔libregraph, fallback ID, CRUD completo. **OK** (tranne token caching)
- `pkg/keycloak/identity.go` — IdentityClient interface pulita. **OK** (manca solo GetUserGroups)

### Problemi da risolvere

| # | Problema | File:Riga | Fix |
|---|---------|-----------|-----|
| P1 | 6 `fmt.Printf` debug | `users/drivers/keycloak.go:57,60,63,105,134,137` | Rimuovere + eliminare `mapKeys()` helper |
| P2 | `GetUserGroups` ritorna `nil, nil` | `users/drivers/keycloak.go:179` | Collegare a `IdentityClient.GetUserGroups` |
| P3 | Codice morto righe 158-178 (workaround commentato) | `users/drivers/keycloak.go:158-178` | Eliminare, sostituire con implementazione reale |
| P4 | `getToken` fa `LoginClient` + `RetrospectToken` ogni chiamata | `client.go:153-168` | Token caching con `sync.Mutex` + expiry. Rimuovere `RetrospectToken` (inutile su token appena emesso) |
| P5 | `IdentityClient` manca `GetUserGroups` | `identity.go` | Aggiungere metodo, implementare in `ConcreteClient` usando `GoCloak.GetUserGroups` (già in gocloak.go:17) |
| P6 | Groups REVA driver inesistente | `services/groups/` | Creare, parallelo al users driver |

### Catena di dipendenze (ordine obbligato)
```
P5 (IdentityClient.GetUserGroups) → P2+P3 (users driver fix) → P6 (groups driver)
P1 (debug cleanup) — indipendente
P4 (token caching) — indipendente
```

## Piano esecutivo

### Fase 1 — Pulizia debug (~15 min) [P1]

**File**: `services/users/pkg/drivers/keycloak/keycloak.go`
- **Rimuovere** 6 `fmt.Printf` (righe 57, 60, 63, 105, 134, 137) — NON sostituire con logger
  - Configure è one-shot (rumore nei log se loggato)
  - GetUserByClaim/GetUsers hanno già logging nel layer superiore (graph backend)
- **Rimuovere** `mapKeys()` helper (righe 248-254) — usato solo dai Printf
- L'import `fmt` resta necessario per `fmt.Errorf`

**Verifica**: `go build ./services/users/...`

### Fase 2 — GetUserGroups end-to-end (~1h) [P5 → P2 + P3]

**Passo 2a** — Aggiungere a `IdentityClient` interface (`pkg/keycloak/identity.go`):
```go
GetUserGroups(ctx context.Context, realm, userID string) ([]*libregraph.Group, error)
```

**Passo 2b** — Implementare in `ConcreteClient` (`pkg/keycloak/identity.go`):
- Usa `c.keycloak.GetUserGroups()` (GoCloak interface, gocloak.go:17)
- Converte `[]*gocloak.Group` → `[]*libregraph.Group` via `keycloakGroupToLibregraph`

**Passo 2c** — Fix REVA users driver (`services/users/pkg/drivers/keycloak/keycloak.go`):
- **Eliminare** righe 158-179 (codice morto + workaround + TODO)
- **Sostituire** con implementazione reale che chiama `mgr.client.GetUserGroups` e mappa a `[]string` (nomi gruppi)

**Verifica**: Login → profilo utente mostra gruppi Keycloak reali

### Fase 3 — Groups REVA driver (~2h) [P6]

**File da creare**: `services/groups/pkg/drivers/keycloak/keycloak.go` (~200 righe)

Pattern identico al users driver: `init()` con `registry.Register("keycloak", New)`, config via `mapstructure`, `kc.IdentityClient`.

**Interface da implementare** (da `reva/v2/pkg/group`):
- `GetGroup(ctx, gid, skipMembers)` → `client.GetGroup` + `client.GetGroupMembers`
- `GetGroupByClaim(ctx, claim, value, skipMembers)` → search by name/id
- `FindGroups(ctx, query, skipMembers)` → `client.GetGroups` con search param
- `GetMembers(ctx, gid)` → `client.GetGroupMembers`

**File da modificare**:
- `services/groups/pkg/command/server.go` — import + registrazione driver `"keycloak"` (1 riga import)
- `services/groups/pkg/config/config.go` — struct `Keycloak` (URL, ClientID, ClientSecret, Realm)
- `services/groups/pkg/revaconfig/config.go` — mapping env vars → config REVA

**Pattern di riferimento**: `services/groups/pkg/drivers/ldap/` — template diretto, stessa interface

**Verifica**: Condivisione file per gruppo dalla web UI

### Fase 4 — Token caching (~45 min) [P4]

**File**: `pkg/keycloak/client.go`

Modifiche alla struct `ConcreteClient`: aggiungere `sync.Mutex`, `*gocloak.JWT`, `time.Time` per token cached.

Fix `getToken()` (attualmente righe 153-168):
- Riusa token se `time.Now().Before(tokenExpiry - 30s)` (margine di sicurezza)
- **Rimuovere** `RetrospectToken` — inutile subito dopo `LoginClient` (token appena emesso è per definizione attivo, risparmia 1 round-trip)
- Thread-safe con `sync.Mutex`
- Calcola expiry da `token.ExpiresIn`

**Verifica**: `docker logs keycloak` — riduzione drastica login client

### Fase 5 — Build, test E2E, commit, PR (~1-2h)

**Dockerfile.keycloak**: GIÀ modificato — rimosso download FE da GitHub. Asset in `services/web/assets/core/` (24MB, pre-scaricati). `COPY . .` li include.

**Build**: COMPLETATA — `sol/opencloud:keycloak` 339MB (2026-03-23 14:27). Commit `18e86834` incluso.

**Deploy** (da fare):
```bash
cd /data/massimiliano/opencloud && docker compose up -d
```

**Test E2E checklist**:
- [ ] `docker logs opencloud --tail 100` — zero errori
- [ ] Browser: `https://cloud.massimilianopili.com` → Keycloak SSO → file manager
- [ ] Upload + download file
- [ ] Crea cartella
- [ ] Verifica gruppi nel profilo utente
- [ ] Condividi file con gruppo
- [ ] Condividi file con utente

**Commit strategy** (conventional commits, PR unica):
```
feat(keycloak): add identity client with user and group CRUD
feat(graph): add Keycloak identity backend for graph service
feat(proxy): add OIDC well-known URL rewriting for external IDPs
feat(users): add Keycloak REVA users driver
feat(groups): add Keycloak REVA groups driver
perf(keycloak): add token caching to admin client
```

**PR upstream** (su opencloud-eu/opencloud):
- Prima: aprire **Discussion/Issue** per validare l'approccio
- Titolo: `feat: add Keycloak Admin API identity backend (zero LDAP)`
- Body: motivazione, architettura 3-layer, env vars, test evidence, screenshots
- Label: `Status:Needs-Review`

## File critici

| File | Ruolo | Stato |
|------|-------|-------|
| `services/graph/pkg/identity/keycloak.go` | Graph backend (16 metodi) | ✅ Completo |
| `pkg/keycloak/identity.go` | IdentityClient interface | ⚠️ Manca GetUserGroups |
| `pkg/keycloak/client.go` | API wrapper + token | ⚠️ Manca caching, RetrospectToken da rimuovere |
| `pkg/keycloak/gocloak.go` | GoCloak interface estesa | ✅ Completo |
| `services/users/pkg/drivers/keycloak/keycloak.go` | REVA users driver | ⚠️ Debug + groups nil + dead code |
| `services/groups/pkg/drivers/keycloak/keycloak.go` | REVA groups driver | ❌ Da creare |
| `services/proxy/pkg/staticroutes/oidc_well-known.go` | OIDC URL rewrite | ✅ Completo |
| `services/graph/pkg/config/config.go` | Config struct | ✅ Completo |
| `services/graph/pkg/config/parser/parse.go` | Validator | ✅ Completo |
| `services/graph/pkg/service/v0/service.go` | Backend switch | ✅ Completo |

## Fix opzionalità — OIDC well-known rewrite

La funzione `oIDCWellKnownRewrite` attualmente legge il body in memoria per tutti i casi (anche quando `needsRewrite = false`). Questo cambia il comportamento per chi usa LDAP/IdP interno.

**Fix**: quando `needsRewrite = false`, fare stream diretto (`io.Copy`) come il codice originale. Body-read solo quando serve il rewrite.

## Verifica finale

1. `go build ./...` — compilazione OK
2. `golangci-lint run ./...` — zero errori sui file modificati
3. Rebuild: `docker build -f Dockerfile.keycloak -t sol/opencloud:keycloak .`
4. Deploy: `cd /data/massimiliano/opencloud && docker compose up -d`
5. Browser: `https://cloud.massimilianopili.com` → E2E checklist completa
6. `docker logs opencloud --tail 100` — zero errori
7. `git log --oneline` — commit convenzionali corretti
