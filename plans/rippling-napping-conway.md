# Inventario: Keycloak Identity Backend per OpenCloud

## Panoramica

999 righe di codice in 13 file Go (5 nuovi, 8 modificati). Il lavoro si divide in 4 componenti logiche, ciascuna candidata a una PR separata o a una PR unica.

---

## Componente 1: pkg/keycloak — Client Keycloak esteso

**Scopo**: Estendere il client Keycloak esistente con CRUD completo user/group per supportare il graph identity backend e il REVA users driver.

| File | Tipo | Righe | Cosa fa |
|------|------|-------|---------|
| `pkg/keycloak/gocloak.go` | Mod | +17 | Estende l'interfaccia `GoCloak` con 7 metodi (GetUserByID, UpdateUser, DeleteUser, GetUserGroups, AddUserToGroup, CRUD groups) |
| `pkg/keycloak/identity.go` | **Nuovo** | 235 | Interfaccia `IdentityClient` (superset di `Client`), implementazione CRUD user/group su `ConcreteClient`, mapping `libregraphUserToKeycloak`, `keycloakGroupToLibregraph` |
| `pkg/keycloak/client.go` | Mod | +43 | Fix: `keycloakUserToLibregraph` popola `OnPremisesSamAccountName` da `u.Username`, fallback a Keycloak ID quando `OPENCLOUD_ID` attr mancante, `getKeyCloakID` con fallback al primo Identity disponibile |

**Stato**: Compila OK. Testato in produzione (token OK, user lookup OK).
**Note PR**: Backward compatible — `Client` interface non toccata, `IdentityClient` è nuova.

---

## Componente 2: Graph Identity Backend Keycloak

**Scopo**: Implementazione dell'interfaccia `Backend` (16 metodi) per il graph service, usando Keycloak Admin API al posto di LDAP.

| File | Tipo | Righe | Cosa fa |
|------|------|-------|---------|
| `services/graph/pkg/identity/keycloak.go` | **Nuovo** | 307 | `KeycloakBackend` struct, 16 metodi Backend, `resolveUser` (by username o Keycloak ID), `odataFilterToKeycloakParams`, `trimQuotes`. Include debug printf (da rimuovere). |
| `services/graph/pkg/config/config.go` | Mod | +2 | Aggiunge `Keycloak Keycloak` alla struct `Identity`, aggiorna desc Backend |
| `services/graph/pkg/config/parser/parse.go` | Mod | +23 | Aggiunge "keycloak" alla lista backend validi, `validateKeycloakSettings()` |
| `services/graph/pkg/service/v0/service.go` | Mod | +21 | `case "keycloak":` nel switch `setIdentityBackends()`, import `pkg/keycloak` |

**Stato**: Compila OK. Env var: `GRAPH_IDENTITY_BACKEND=keycloak`.
**Note PR**: La struct `Keycloak` nel config.go GIÀ ESISTEVA (usata da invitations service). Abbiamo solo referenziato quella esistente in `Identity`.
**Da pulire**: Rimuovere `fmt.Printf` debug, rimuovere import `gocloak` non usato.

---

## Componente 3: REVA Users Driver Keycloak

**Scopo**: Driver `keycloak` per il REVA user provider, che permette al servizio `users` di risolvere utenti via Keycloak Admin API invece di LDAP.

| File | Tipo | Righe | Cosa fa |
|------|------|-------|---------|
| `services/users/pkg/drivers/keycloak/keycloak.go` | **Nuovo** | 261 | Implementa `user.Manager` (5 metodi: Configure, GetUser, GetUserByClaim, GetUserGroups, FindUsers). Registra driver via `init()` → `registry.Register("keycloak", New)`. Mapping `toCS3User`. Include debug printf (da rimuovere). |
| `services/users/pkg/config/config.go` | Mod | +14 | Aggiunge `KeycloakDriver` struct con env vars `USERS_KEYCLOAK_*` |
| `services/users/pkg/revaconfig/config.go` | Mod | +9 | Aggiunge mapping `"keycloak"` nella mappa driver di revaconfig |
| `services/users/pkg/command/server.go` | Mod | +3 | Blank import `_ "...drivers/keycloak"` per triggerare `init()` |

**Stato**: Compila OK. Env var: `USERS_DRIVER=keycloak`.
**Testato**: GetUserByClaim ritorna sol_root OK da Keycloak, auth-machine OK.
**Da pulire**: Rimuovere `fmt.Printf` debug, implementare `GetUserGroups` (attualmente ritorna nil).

---

## Componente 4: OIDC Well-Known URL Rewrite

**Scopo**: Quando OpenCloud fa proxy del well-known OIDC da un IdP interno (Docker network), gli URL backchannel sono interni e irraggiungibili dal browser. Il fix riscrive gli URL interni con quelli pubblici.

| File | Tipo | Righe | Cosa fa |
|------|------|-------|---------|
| `services/proxy/pkg/staticroutes/oidc_well-known.go` | Mod | +38 | `oIDCWellKnownRewrite`: legge `IssuerPublic` dalla config, fa `bytes.ReplaceAll` per sostituire base URL interno con pubblico prima di servire la risposta |
| `services/proxy/pkg/config/config.go` | Mod | +1 | Aggiunge campo `IssuerPublic` alla struct OIDC con env `PROXY_OIDC_ISSUER_PUBLIC` |

**Stato**: Compila OK. Testato in produzione — well-known restituisce URL pubblici.
**Note PR**: Questa è una PR indipendente e molto utile per chiunque usi OpenCloud con IdP interni (Docker, Kubernetes). Il handler si chiama già "rewrite" ma non riscriveva — ora lo fa.

---

## File NON per la PR (deploy-specific)

| File | Motivo |
|------|--------|
| `Dockerfile.keycloak` | Build infra SOL |
| `Dockerfile.sol` | Build infra SOL |

---

## Da fare prima della PR

1. **Rimuovere tutti i `fmt.Printf` debug** (6 occorrenze in 2 file)
2. **Implementare `GetUserGroups`** nel REVA driver (attualmente ritorna nil)
3. **Creare REVA groups driver** (parallelo al users driver, ~200 righe)
4. **Unit test** per graph backend e REVA driver
5. **Rimuovere import `gocloak`** non usato dal graph identity backend
6. **Testare UpdateUser** end-to-end (attualmente warning non-fatale)
7. **Decidere struttura PR**: una unica o split per componente

## Stato del deploy SOL

- Auth-machine → REVA → Keycloak: **funziona** (utente autenticato)
- Graph backend → Keycloak: **funziona** (con warning su UpdateUser)
- Well-known rewrite: **funziona**
- CSP: **funziona** (IDP_DOMAIN)
- **Blocchi attuali**: (1) autoprovisioning update/sync richiede servizio groups, (2) role assignment OIDC richiede mapping ruoli Keycloak → OpenCloud
- **Workaround**: `PROXY_AUTOPROVISION_ACCOUNTS=false` + `PROXY_ROLE_ASSIGNMENT_DRIVER=default`
