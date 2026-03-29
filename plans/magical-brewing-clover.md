# Piano: Cleanup driver DB + Push e Deploy

## Contesto

La migrazione Java 21 e' completata (build OK, bytecode 65). Prima del push, l'utente chiede di completare la separazione delle competenze: i driver DB (`h2`, `ojdbc11`, `postgresql`) devono vivere SOLO nelle librerie che li usano, non nel server. Ogni libreria porta i propri driver come `compile` (transitivi), e il flag `mcp.*.enabled` li attiva/disattiva.

---

## Step 0: Cleanup driver — dalle librerie al server (zero driver nel server)

### Stato attuale

| Driver | mcp-sql-tools | mcp-vector-tools | mcp-embeddings-tools | mcp-graph-tools | mcp (server) |
|--------|:---:|:---:|:---:|:---:|:---:|
| h2 | `optional` | - | - | - | `runtime` |
| ojdbc11 | `optional` | - | - | - | `runtime` |
| postgresql | `optional` | `compile` | `compile` | `provided` | - |
| JDBC starter | `compile` | `compile` | `compile` | `provided` | - |

### Target (dopo la modifica)

| Driver | mcp-sql-tools | mcp-vector-tools | mcp-embeddings-tools | mcp-graph-tools | mcp (server) |
|--------|:---:|:---:|:---:|:---:|:---:|
| h2 | **`compile`** | - | - | - | **RIMOSSO** |
| ojdbc11 | **`compile`** | - | - | - | **RIMOSSO** |
| postgresql | **`compile`** | `compile` | `compile` | `provided` | - |
| JDBC starter | `compile` | `compile` | `compile` | `provided` | - |

### Modifiche

**1. `mcp-sql-tools/pom.xml`** — h2, ojdbc11, postgresql: da `optional` a `compile` (rimuovere `<optional>true</optional>`)

**2. `mcp/pom.xml`** — rimuovere interamente la sezione driver:
```xml
<!-- RIMUOVERE: -->
<dependency><groupId>com.h2database</groupId><artifactId>h2</artifactId><scope>runtime</scope></dependency>
<dependency><groupId>com.oracle.database.jdbc</groupId><artifactId>ojdbc11</artifactId><scope>runtime</scope></dependency>
<!-- + commenti associati -->
```

### Logica di attivazione

Ogni driver arriva transitivamente dalla sua libreria. Il flag `mcp.*.enabled` gia' presente controlla l'auto-configuration:

| Flag | Libreria | Driver portati |
|------|----------|---------------|
| `mcp.sql.enabled=true` | mcp-sql-tools | h2, ojdbc11, postgresql, JDBC |
| `mcp.vector.enabled=true` | mcp-vector-tools | postgresql, JDBC |
| `mcp.embeddings.enabled=true` | mcp-embeddings-tools | postgresql, JDBC |

Con `mcp.sql.enabled=false`, i bean SQL non vengono creati. I jar dei driver sono sul classpath ma inattivi (~8 MB in piu' nel fat jar, zero overhead a runtime — il JVM carica le classi lazily).

**mcp-graph-tools** resta con `provided`: il backend AGE (PostgreSQL) e' opzionale, Neo4j usa il suo driver Bolt.

### File da modificare

```
/data/massimiliano/Vari/mcp-sql-tools/pom.xml        (h2, ojdbc11, postgresql: optional → compile)
/data/massimiliano/Vari/mcp/pom.xml                   (rimuovere h2, ojdbc11)
```

---

## Step 1: Commit (14 repo)

9 gia' committati (mongo, vector, embeddings, graph, playwright, devops, ocp, docker, jira).
5 da committare: spring-ai-reactive-tools, mcp-sql-tools, mcp-filesystem-tools, mcp-azure-tools, mcp.

Messaggio: `feat: migrate to Java 21, virtual threads, dependency cleanup`

| Repo | File da committare |
|------|--------------------|
| spring-ai-reactive-tools | `pom.xml`, `src/.../ParallelToolCallingManager.java` |
| mcp-sql-tools | `pom.xml`, `src/.../SqlToolsAutoConfiguration.java` |
| mcp-filesystem-tools | `pom.xml`, `src/.../FileSystemToolsAutoConfiguration.java` |
| mcp-azure-tools | `pom.xml` + 9 child `*/pom.xml` |
| mcp (server) | `pom.xml`, `src/main/resources/application.properties`, `src/main/resources/application-light.properties` |

NO: `CLAUDE.md`, `target/`, `logs/`.

---

## Step 2: Push origin + github (14 repo)

```bash
git push origin main && git push github main
```

---

## Step 3: Tag per Maven Central (13 librerie)

| Repo | Tag |
|------|-----|
| spring-ai-reactive-tools | `v0.3.0` (PRIMA — tutti ne dipendono) |
| mcp-sql-tools | `v0.1.0` |
| mcp-mongo-tools | `v0.1.0` |
| mcp-vector-tools | `v0.2.0` |
| mcp-embeddings-tools | `v0.1.0` |
| mcp-graph-tools | `v0.1.0` |
| mcp-filesystem-tools | `v0.1.0` |
| mcp-playwright-tools | `v0.1.0` |
| mcp-devops-tools | `v0.1.0` |
| mcp-ocp-tools | `v0.1.0` |
| mcp-docker-tools | `v0.1.0` |
| mcp-jira-tools | `v0.1.0` |
| mcp-azure-tools | `v1.1.0` |

`mcp/` NON viene taggato (SNAPSHOT locale).

---

## Step 4: Rebuild MCP server jar + verifica build

```bash
cd /data/massimiliano/Vari/mcp-sql-tools && mvn clean install -Dgpg.skip=true -DskipTests
cd /data/massimiliano/Vari/mcp && mvn clean package -Dgpg.skip=true -DskipTests
```
