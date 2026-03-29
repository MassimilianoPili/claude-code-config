# Fix: Registry cleanup + CI deploy pipeline per tutti i Maven libs

## Context

Due problemi collegati:
1. **Registry cleanup** (già implementato, codice pronto) — `claude:registry` e `ChannelSessionRegistry` accumulano entry stale. Fix: `TransportSessionAccessor` + `RegistryCleanupScheduler`. Codice già committato in `mcp-channel-tools`, compilato localmente.
2. **CI deploy bloccato** — due problemi nel workflow `deploy-gitea.yml` (tutti 31 repo):
   - **[RISOLTO]** Mancava `<repositories>` nel settings.xml → dipendenze interne non risolvibili
   - **[DA RISOLVERE]** Gitea registry ritorna 409 Conflict se la versione già esiste → il CI deve usare la versione dal tag git

## Approccio

### Step 1 — [FATTO] Fix `<repositories>` nel settings.xml

Già applicato a tutti 31 i repo. Il build Maven ora risolve le dipendenze interne.

### Step 2 — Fix versioning: tag git → versione Maven

Aggiungere uno step nel workflow che estrae la versione dal tag (`g0.1.1` → `0.1.1`) e la applica con `mvn versions:set`:

Aggiungere prima del `mvn deploy`:
```yaml
      - name: Set version from tag
        run: |
          VERSION=${GITHUB_REF_NAME#g}
          echo "Deploying version: $VERSION"
          mvn versions:set -DnewVersion=$VERSION -DgenerateBackupPoms=false -q
      - name: Deploy to Gitea Registry
        run: mvn deploy -DskipTests -Dcentral-publishing.skip=true -Dgpg.skip=true
```

### Step 3 — Applicare a tutti 31 i repo (stessa procedura di Step 1)

### Step 4 — Retriggerare `mcp-channel-tools`

Tag `g0.1.1` per deployare la versione corretta (0.1.1). Il consumer `mcp` deve anche aggiornare la sua dipendenza da `0.1.0` a `0.1.1` nel pom.xml.

### Step 5 — Commit `SessionEvictionConfig.java` + aggiorna pom.xml nel repo `mcp`, poi `sol deploy mcp`

## File da modificare

| File | Azione |
|------|--------|
| 31x `deploy-gitea.yml` | Aggiungere step `versions:set` dal tag |
| `mcp/pom.xml` | Aggiornare `mcp-channel-tools` da `0.1.0` a `0.1.1` |

## File già pronti (da step precedente)

Questi file sono già committati in `mcp-channel-tools` e compilati localmente:
- `TransportSessionAccessor.java` (nuovo)
- `RegistryCleanupScheduler.java` (nuovo)
- `ChannelNotificationSender.java` (refactored)
- `ChannelAutoConfiguration.java` (aggiornato)

E in `mcp` (main app, non ancora committato):
- `SessionEvictionConfig.java` (refactored per usare accessor)

## Verifica

1. Fix workflow → push → tag `g0.1.2` → CI deploy succeed
2. `sol deploy mcp` — Docker build succeed
3. Dopo ~2 min, verificare:
   - `channel_sessions` — solo sessioni attive
   - `claude_who` — solo sessioni attive
   - Log: `docker logs <container> --tail 50 | grep "Registry cleanup"`
