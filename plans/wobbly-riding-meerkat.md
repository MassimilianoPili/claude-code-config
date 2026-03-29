# Piano: Pubblicazione mcp-embeddings-tools v0.0.1 su Maven Central

## Contesto

La libreria è pronta: pom.xml completo (GPG + central-publishing plugin), workflow CI/CD configurato, repo Gitea + GitHub creati, commit pushato. Manca solo il tag per triggerare la pipeline.

L'esplorazione ha confermato che tutto è in ordine:
- pom.xml: groupId, licenses, developers, scm, tutti i plugin richiesti
- Workflow: identico al pattern collaudato di mcp-mongo-tools
- Secrets org-level (`maven-libs`): già configurati (usati dalle altre 8 librerie)
- Database `embeddings`: init script presente in `postgres/init/02-embeddings.sh`
- Credenziali Maven Central: presenti in `~/.m2/settings.xml`

## Azioni

### 1. Creare tag v0.0.1 e push su Gitea

```bash
cd /data/massimiliano/Vari/mcp-embeddings-tools
git tag v0.0.1
git push origin v0.0.1
```

Questo triggera: act_runner → Java 21 + Maven 3.9.9 + GPG → `mvn deploy -DskipTests` → Sonatype Central Portal (autoPublish) → Maven Central.

### 2. Monitorare la pipeline

Verificare lo stato del workflow su Gitea Actions:
```bash
# Check act_runner logs
docker logs act-runner --tail 30 -f
```

### 3. Push tag su GitHub mirror

```bash
git push github main --tags
```

### 4. Verifica finale

Dopo ~15-30 min, verificare su Maven Central:
- `https://repo1.maven.org/maven2/io/github/massimilianopili/mcp-embeddings-tools/0.0.1/`

## File coinvolti

Nessuna modifica a file — solo operazioni Git (tag + push).
