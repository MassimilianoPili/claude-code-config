# Plan: Fix CI/CD pipeline su TUTTI i repo maven-libs + deploy mcp-channel-tools

## Context

Audit dei 31 repo `maven-libs`:
- **29/31** hanno `mirror.yml` BROKEN (passo "Ensure GitHub repo exists" fallisce per mancanza di `GH_MIRROR_TOKEN`)
- **0/31** hanno `deploy-gitea.yml` (tag `g*` → deploy Gitea-only)
- **Solo 1** repo (`mcp-sql-tools`) ha `MIRROR_SSH_KEY` per-repo
- Il secret `GH_MIRROR_TOKEN` non esiste da nessuna parte (né org né per-repo)

**Obiettivi:**
1. Fixare mirror workflow su tutti i repo (aggiungendo i secret mancanti a livello org)
2. Aggiungere `deploy-gitea.yml` (tag `g*`) a tutti i repo
3. Deployare `mcp-channel-tools` via pipeline `g*`

---

## Fase 1: Aggiungere secret mancanti a livello org `maven-libs`

Secret da aggiungere all'org (una volta, vale per tutti i repo):

| Secret | Valore | Note |
|--------|--------|------|
| `GH_MIRROR_TOKEN` | GitHub PAT con scope `repo` | Per auto-create repo GitHub via API |
| `MIRROR_SSH_KEY` | `~/.ssh/id_ed25519` (contenuto) | Per git push a GitHub. Sposta da per-repo a org-level |

**MIRROR_SSH_KEY** — `~/.ssh/id_ed25519` (fingerprint `GitHub_sol`, read/write su GitHub). Settare a livello org:
```bash
curl -X PUT -H "Authorization: token a07addb1..." -H "Content-Type: application/json" \
  "http://172.20.0.27:3000/api/v1/orgs/maven-libs/actions/secrets/MIRROR_SSH_KEY" \
  -d "$(jq -n --arg k "$(cat ~/.ssh/id_ed25519)" '{data: $k}')"
```

**GH_MIRROR_TOKEN** — GitHub PAT `sol_gitea` (scope `repo`). Il valore del token va fornito dall'utente:
```bash
curl -X PUT -H "Authorization: token a07addb1..." -H "Content-Type: application/json" \
  "http://172.20.0.27:3000/api/v1/orgs/maven-libs/actions/secrets/GH_MIRROR_TOKEN" \
  -d '{"data":"<PAT_VALUE>"}'
```

**Stato attuale**:
- 14 repo hanno remote `github` (repo GitHub già esistenti → mirror funziona con sola SSH key)
- 17 repo non hanno remote `github` → serve auto-create con GH_MIRROR_TOKEN
- `GITEA_` prefix è riservato da Gitea — i nomi scelti funzionano

---

## Fase 2: Aggiungere `deploy-gitea.yml` a tutti i repo

### 2.1 Template `deploy-gitea.yml`

Identico per tutti i repo (nessuna personalizzazione necessaria):

```yaml
name: Deploy to Gitea Maven Registry
on:
  push:
    tags: ["g*"]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: "21"
          distribution: "temurin"
          cache: "maven"
          server-id: gitea
          server-username: MAVEN_USERNAME
          server-password: MAVEN_PASSWORD
      - name: Install Maven
        run: |
          curl -fsSL https://archive.apache.org/dist/maven/maven-3/3.9.9/binaries/apache-maven-3.9.9-bin.tar.gz | tar xz -C /opt
          echo "/opt/apache-maven-3.9.9/bin" >> $GITHUB_PATH
      - name: Deploy to Gitea Registry
        run: mvn deploy -DskipTests
        env:
          MAVEN_USERNAME: sol_root
          MAVEN_PASSWORD: ${{ secrets.MAVEN_REGISTRY_TOKEN }}
```

### 2.2 Prerequisiti per lib che deployano a Gitea

Ogni lib che vuole usare il tag `g*` deve avere `distributionManagement` nel `pom.xml`:
```xml
<distributionManagement>
    <repository>
        <id>gitea</id>
        <url>http://gitea:3000/api/packages/sol_root/maven</url>
    </repository>
</distributionManagement>
```

**Per le lib con `central-publishing-maven-plugin`**: non c'è conflitto. Il plugin Central si attiva solo quando le credenziali Central sono disponibili. Con tag `g*`, il workflow usa `server-id: gitea` e `mvn deploy` va al `distributionManagement`.

**Attenzione**: le lib con `central-publishing-maven-plugin` con `<extensions>true</extensions>` **sostituiscono** il deploy plugin standard. Serve verificare che `mvn deploy` con `distributionManagement` funzioni correttamente o se serve `-Dcentral-publishing.skip=true`.

### 2.3 Deploy batch con `gitall`

```bash
# Copiare deploy-gitea.yml in tutti i repo
for d in /data/massimiliano/Vari/mcp-*-tools/ /data/massimiliano/Vari/spring-ai-reactive-tools/ /data/massimiliano/Vari/mcp-protocol-patch/; do
  [ -d "$d/.git" ] || continue
  mkdir -p "$d/.gitea/workflows"
  cp /data/massimiliano/Vari/mcp-channel-tools/.gitea/workflows/deploy-gitea.yml "$d/.gitea/workflows/"
done

# Commit e push con gitall
gitall exec 'cd {} && git add .gitea/workflows/deploy-gitea.yml && git diff --cached --quiet || git commit -m "ci: add deploy-gitea.yml (tag g* → Gitea Maven Registry)" && git push'
```

---

## Fase 3: Fixare `mirror.yml` — aggiungere tag `g*`

Il `mirror.yml` attuale triggera solo su `tags: ["v*"]`. Aggiungere `"g*"`:

```bash
# Aggiungere g* al trigger tags in mirror.yml
for d in /data/massimiliano/Vari/mcp-*-tools/ /data/massimiliano/Vari/spring-ai-reactive-tools/ /data/massimiliano/Vari/mcp-protocol-patch/; do
  f="$d/.gitea/workflows/mirror.yml"
  [ -f "$f" ] || continue
  # Aggiungere g* se non presente
  grep -q '"g\*"' "$f" || sed -i 's/tags: \["v\*"\]/tags: ["v*", "g*"]/' "$f"
done

# Commit e push
gitall exec 'cd {} && git add .gitea/workflows/mirror.yml && git diff --cached --quiet || git commit -m "ci: mirror.yml trigger on g* tags too" && git push'
```

---

## Fase 4: Aggiungere `distributionManagement` ai pom.xml

Per usare il tag `g*`, ogni lib deve avere `distributionManagement`. Aggiungere a tutti i `pom.xml` che non ce l'hanno:

```bash
for d in /data/massimiliano/Vari/mcp-*-tools/ /data/massimiliano/Vari/spring-ai-reactive-tools/ /data/massimiliano/Vari/mcp-protocol-patch/; do
  pom="$d/pom.xml"
  [ -f "$pom" ] || continue
  grep -q "distributionManagement" "$pom" && continue
  # Inserire prima di </project>
  sed -i '/<\/project>/i\
    <distributionManagement>\
        <repository>\
            <id>gitea</id>\
            <url>http://gitea:3000/api/packages/sol_root/maven</url>\
        </repository>\
    </distributionManagement>' "$pom"
done

# Commit e push
gitall exec 'cd {} && git add pom.xml && git diff --cached --quiet || git commit -m "ci: add distributionManagement for Gitea Maven Registry" && git push'
```

---

## Fase 5: Deploy mcp-channel-tools

Con la pipeline pronta:

```bash
cd /data/massimiliano/Vari/mcp-channel-tools
git tag g0.1.0
git push origin g0.1.0
# → Gitea Actions: deploy-gitea.yml → mvn deploy → Gitea Maven Registry
```

Verificare:
```bash
# Check Gitea Actions run
curl -s -H "Authorization: token <TOKEN>" \
  "http://172.20.0.27:3000/api/v1/repos/maven-libs/mcp-channel-tools/actions/runs?limit=3"

# Check jar nel registry
curl -s "http://172.20.0.27:3000/api/packages/sol_root/maven" | grep channel
```

---

## Fase 6: Deploy mcp-redis-tools + simoge-mcp

```bash
# Push redis-tools changes
cd /data/massimiliano/Vari/mcp-redis-tools
git add -A && git commit -m "feat: add Redis Pub/Sub PUBLISH after LPUSH in claude_send/claude_broadcast" && git push
git tag v0.1.2 && git push origin v0.1.2  # Central release

# Deploy simoge-mcp (dopo che jar sono nel registry)
cd /data/massimiliano/Vari/mcp
sol deploy mcp
```

---

## Fase 7: Reload nginx + deploy-mcp script

```bash
# Nginx
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate

# deploy-mcp: aggiungere channel
# In ALL_PROJECTS array di /data/massimiliano/shell-scripts/bin/deploy-mcp
```

---

## Ordine di esecuzione

1. **Secret org** — GH_MIRROR_TOKEN + MIRROR_SSH_KEY (richiede GitHub PAT dall'utente)
2. **deploy-gitea.yml** — copiare in tutti i repo + commit + push
3. **mirror.yml g* tag** — sed + commit + push
4. **distributionManagement** — sed nei pom.xml + commit + push
5. **Tag g0.1.0** su mcp-channel-tools → verificare pipeline
6. **Tag v0.1.2** su mcp-redis-tools → Central release
7. **sol deploy mcp** → Docker build con channel-tools
8. **nginx reload** + deploy-mcp script update

---

## Verifica

1. **Secret org** — `curl .../orgs/maven-libs/actions/secrets` mostra GH_MIRROR_TOKEN e MIRROR_SSH_KEY
2. **Pipeline deploy-gitea** — tag g0.1.0 su channel-tools → success
3. **Pipeline mirror** — push su un repo → success (auto-create + push a GitHub)
4. **Gitea Maven Registry** — jar channel-tools presente
5. **Docker build** — `sol deploy mcp` risolve channel-tools da Gitea
6. **Channel capability** — simoge-mcp dichiara `claude/channel`
7. **Webhook** — `curl -X POST http://100.86.46.84/webhooks/ci -d '{"test":true}'`
