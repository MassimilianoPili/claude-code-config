---
name: maven-build-patterns
description: Maven build patterns for multi-module projects, Maven Central publishing via OSSRH, GPG signing, release profiles, Spring Boot parent POM, BOM dependency management, and automated deployment with deploy-mcp script.
allowed-tools: Read, Write, Bash, Edit
category: devops
tags: [maven, java, build, deployment, maven-central, gpg, ossrh]
version: 1.0.0
---

# Maven Build Patterns

Maven build system for 8 Java libraries published to Maven Central (groupId: `io.github.massimilianopili`)
plus an MCP server application. Java 17 + Spring Boot 3.4.1 + Spring AI 1.0.0.

## When to Use

- Building or deploying MCP libraries to Maven Central
- Configuring a new Maven project for Maven Central publishing
- Setting up GPG signing for artifact deployment
- Understanding multi-module Maven project structure (e.g. mcp-azure-tools)
- Using the `deploy-mcp` script for multi-project local deploys
- Adding a new MCP tool library to the ecosystem
- Debugging Maven Central publishing failures

## Ecosystem Overview

### MCP Libraries (Maven Central)

8 libraries under `io.github.massimilianopili`, all Apache 2.0:

| Artifact | Version | Description | Submodules |
|----------|---------|-------------|------------|
| `spring-ai-reactive-tools` | 0.2.1 | Reactive `Mono<T>`/`Flux<T>` tool support for Spring AI | - |
| `mcp-azure-tools` | 1.0.0 | Azure cloud management (ARM, Graph, Key Vault, AKS, VMs...) | 9 submodules |
| `mcp-devops-tools` | 0.0.2 | Azure DevOps management (work items, repos, PRs, pipelines) | - |
| `mcp-ocp-tools` | 0.0.1 | OpenShift/Kubernetes management | - |
| `mcp-docker-tools` | 0.0.1 | Docker container management | - |
| `mcp-filesystem-tools` | 0.0.1 | File system operations | - |
| `mcp-mongo-tools` | 0.0.2 | MongoDB operations (multi-instance, find, aggregate, count) | - |
| `mcp-sql-tools` | 0.0.1 | SQL database operations (multi-DB, JDBC) | - |

### Directories

```text
/data/massimiliano/Vari/
├── spring-ai-reactive-tools/   # Reactive tool framework
├── mcp-azure-tools/            # 9 submodules (pom packaging)
├── mcp-devops-tools/
├── mcp-ocp-tools/
├── mcp-docker-tools/
├── mcp-filesystem-tools/
├── mcp-mongo-tools/
├── mcp-sql-tools/
└── mcp/                        # MCP server app (SNAPSHOT, consumes all libraries)
```

### MCP Server Application

`/data/massimiliano/Vari/mcp/pom.xml` — Spring Boot app (STDIO mode MCP server).
Parent: `spring-boot-starter-parent:3.4.1`. Uses `spring-ai-starter-mcp-server` + `webflux`.
Imports all 8 libraries as direct dependencies with explicit versions.
Spring AI BOM imported in `<dependencyManagement>` for versionless Spring AI deps.

## POM Structure Patterns

### Pattern A: Standalone Library (e.g. mcp-mongo-tools)

Nessun parent Spring Boot — la libreria dichiara tutto esplicitamente.
Properties: `java.version=17`, `spring-ai.version=1.0.0`, `spring-boot.version=3.4.1`.

Dipendenze chiave con scope appropriato:
- `spring-ai-model` con `<scope>provided</scope>` (l'utente lo porta)
- `spring-boot-autoconfigure` con `<optional>true</optional>` (auto-config opzionale)
- dipendenze specifiche (es. `spring-boot-starter-data-mongodb`) con `<scope>provided</scope>`

### Pattern B: Multi-Module Parent (e.g. mcp-azure-tools)

Parent POM con `<packaging>pom</packaging>`, 9 moduli:
`mcp-azure-core`, `mcp-azure-compute`, `mcp-azure-network`, `mcp-azure-data`,
`mcp-azure-messaging`, `mcp-azure-security`, `mcp-azure-monitoring`, `mcp-azure-integration`, `mcp-azure-all`.

Il parent usa `<pluginManagement>` per definire versioni e config dei plugin,
poi i sottomoduli li ereditano. Il parent dichiara anche `central-publishing-maven-plugin`
e `maven-gpg-plugin` in `<plugins>` (non solo pluginManagement) per applicarli al parent stesso.

`<dependencyManagement>` centralizza le versioni: `mcp-azure-core` usa `${project.version}`,
le altre dipendenze (spring-ai-model, webflux, reactive-tools, slf4j) con scope `provided`.

`mcp-azure-all` e' un modulo aggregatore che importa tutti gli altri come dipendenze transitive.
Il server MCP dichiara solo `mcp-azure-all` per ottenere tutto il bundle Azure.

### Pattern C: Spring Boot App (e.g. mcp-server)

Usa `spring-boot-starter-parent` come parent e `spring-boot-maven-plugin` per il fat JAR.
Include il `maven-compiler-plugin` con `<parameters>true</parameters>` per preservare
i nomi dei parametri a runtime (necessario per Spring AI tool parameter discovery).

## Maven Central Publishing

### Publishing Plugin

Tutte le librerie usano `central-publishing-maven-plugin` 0.7.0 (Central Portal) — NON il vecchio
`nexus-staging-maven-plugin` (OSSRH Nexus):

```xml
<plugin>
    <groupId>org.sonatype.central</groupId>
    <artifactId>central-publishing-maven-plugin</artifactId>
    <version>0.7.0</version>
    <extensions>true</extensions>
    <configuration>
        <publishingServerId>central</publishingServerId>
        <autoPublish>true</autoPublish>
        <waitUntil>published</waitUntil>
    </configuration>
</plugin>
```

`autoPublish: true` pubblica automaticamente dopo la validazione.
`waitUntil: published` blocca il build fino a pubblicazione completata.

### GPG Signing

Sempre attivo (non in un profile separato). Plugin `maven-gpg-plugin:3.2.7`, phase `verify`.
`--pinentry-mode loopback` consente passphrase via env variable (headless CI/CD + server SOL).
GPG key: Ed25519, KEY_ID `1253822965B71B45`.

### Sources e Javadoc JAR

Richiesti da Maven Central, sempre attivi (non in un profile):
- `maven-source-plugin:3.3.1` — goal `jar-no-fork`
- `maven-javadoc-plugin:3.11.2` — goal `jar`, con `<doclint>none</doclint>` per evitare errori strict

### Maven Settings (`~/.m2/settings.xml`)

```xml
<settings>
  <servers>
    <server>
      <id>central</id>
      <username>CENTRAL_PORTAL_USERNAME</username>
      <password>CENTRAL_PORTAL_TOKEN</password>
    </server>
  </servers>
</settings>
```

Il `publishingServerId` nei POM corrisponde al `<id>central</id>` in settings.xml.

### Maven Central Requirements Checklist

Per pubblicare su Maven Central, ogni artifact deve avere:
1. `groupId`, `artifactId`, `version` (no SNAPSHOT)
2. `<name>`, `<description>`, `<url>`
3. `<licenses>` (Apache 2.0)
4. `<developers>` (nome, email, url)
5. `<scm>` (url, connection, developerConnection)
6. Sources JAR, Javadoc JAR, GPG signatures (`.asc`)

## BOM Pattern (Spring AI)

Il server MCP importa lo Spring AI BOM in `<dependencyManagement>`:

```xml
<dependency>
    <groupId>org.springframework.ai</groupId>
    <artifactId>spring-ai-bom</artifactId>
    <version>${spring-ai.version}</version>
    <type>pom</type>
    <scope>import</scope>
</dependency>
```

Le dipendenze Spring AI si dichiarano poi senza versione.
Le librerie invece NON usano il BOM — dichiarano `spring-ai-model` con versione esplicita
e scope `provided`, perche' sono librerie (non applicazioni).

## Tool Annotations

- **`@Tool`** (Spring AI nativo): metodi sincroni — usato da sql, filesystem, mongo tools
- **`@ReactiveTool`** (spring-ai-reactive-tools): metodi asincroni `Mono<T>`/`Flux<T>` — usato da devops, azure, api proxy tools
- **`@ToolParam`** (Spring AI): descrizione parametri per lo schema MCP

## deploy-mcp Script

Script CLI per deploy multi-progetto. Path: `/data/massimiliano/shell-scripts/bin/deploy-mcp`.

```bash
deploy-mcp                    # Deploy tutti i 7 progetti
deploy-mcp mongo sql          # Deploy solo quelli specificati
deploy-mcp --dry-run          # Mostra cosa farebbe senza eseguire
deploy-mcp --with-tests       # Deploy con test (default: skipTests)
deploy-mcp --list             # Lista progetti disponibili
```

Progetti gestiti: `mongo`, `sql`, `devops`, `filesystem`, `azure`, `docker`, `ocp`.
Ogni progetto mappa a `/data/massimiliano/Vari/mcp-{name}-tools/`.

Maven path: `/opt/maven/bin/mvn` (fallback: `which mvn`).
Comando default: `mvn clean deploy -DskipTests`.

**NOTA**: `spring-ai-reactive-tools` non e' nel set `deploy-mcp` — va deployato separatamente:
```bash
cd /data/massimiliano/Vari/spring-ai-reactive-tools && /opt/maven/bin/mvn clean deploy
```

## CI/CD: Gitea Actions Release

Template workflow: `/data/massimiliano/gitea/config/release-template.yml`.
Trigger: push tag `v*` su Gitea. Java 21 + Temurin, `mvn deploy -P release -DskipTests`.

Secrets Gitea (repo o org level):

| Secret | Descrizione |
|--------|-------------|
| `OSSRH_USERNAME` | Username Central Portal (Sonatype) |
| `OSSRH_TOKEN` | Token Central Portal |
| `GPG_PRIVATE_KEY` | Chiave privata GPG (armored, `gpg --export-secret-keys -a`) |
| `GPG_PASSPHRASE` | Passphrase della chiave GPG |

**NOTA**: il workflow CI usa `-P release`, mentre i POM delle librerie sul server
non usano un profile `release` (i plugin sono sempre attivi). Il template puo' essere adattato.

### Git remotes

Ogni libreria ha due remotes:
- `origin` — Gitea locale (`git@gitea-local:massimiliano/<repo>.git`)
- `github` — GitHub mirror (`git@github.com:massimilianopili/<repo>.git`)

Push su entrambi con `gitall push` o manualmente.

## Common Operations

```bash
# Build locale (senza deploy)
cd /data/massimiliano/Vari/mcp-mongo-tools
/opt/maven/bin/mvn clean package -DskipTests

# Install locale (senza GPG, per test locali)
/opt/maven/bin/mvn clean install -Dgpg.skip=true

# Deploy singola libreria su Maven Central
/opt/maven/bin/mvn clean deploy

# Deploy multi-progetto con script
deploy-mcp mongo sql devops

# Build server MCP
cd /data/massimiliano/Vari/mcp
/opt/maven/bin/mvn clean package -DskipTests
/opt/java/bin/java -jar target/mcp-server-0.0.1-SNAPSHOT.jar  # Esecuzione STDIO

# Build modulo specifico (multi-module)
cd /data/massimiliano/Vari/mcp-azure-tools
/opt/maven/bin/mvn clean package -pl mcp-azure-compute -am -DskipTests
# -pl: solo il modulo specificato. -am: build anche le dipendenze (also-make)

# Verifiche utili
/opt/maven/bin/mvn help:effective-pom                    # POM effettivo
/opt/maven/bin/mvn versions:display-dependency-updates   # Aggiornamenti disponibili
/opt/maven/bin/mvn dependency:tree                       # Albero dipendenze
/opt/maven/bin/mvn dependency:resolve                    # Risolvere dipendenze mancanti
```

## Troubleshooting

### GPG signing fallisce
```bash
gpg --list-keys io.github.massimilianopili  # Chiave presente?
gpg --list-secret-keys                       # Chiave privata presente?
echo "test" | gpg --clearsign                # Test firma manuale
# Se pinentry fallisce: verificare --pinentry-mode loopback nel POM
```

### Central Portal 401 Unauthorized
- Verificare username/token in `~/.m2/settings.xml`
- Il `<id>central</id>` deve corrispondere a `<publishingServerId>central</publishingServerId>`
- Token scaduto? Rigenerare su https://central.sonatype.com

### Build multi-module fallisce per ordine
- Usare `-am` (also-make) per compilare le dipendenze del modulo target
- Debug ordine reactor: `/opt/maven/bin/mvn validate`

### Dipendenza non trovata
```bash
/opt/maven/bin/mvn dependency:resolve -Dartifact=io.github.massimilianopili:mcp-mongo-tools:0.0.2
/opt/maven/bin/mvn dependency:purge-local-repository -DmanualInclude=io.github.massimilianopili:mcp-mongo-tools
```

### Javadoc errors bloccano il build
Con `<doclint>none</doclint>` non dovrebbe succedere. Skip temporaneo: `-Dmaven.javadoc.skip=true`

### Java version mismatch
Tutti i POM dichiarano Java 17. Verificare: `/opt/java/bin/java -version` e `/opt/maven/bin/mvn -version`.

## Best Practices

1. **Sempre `central-publishing-maven-plugin`** per Maven Central (non nexus-staging)
2. **`-DskipTests` per deploy CI/CD** — i test vanno in un job separato
3. **Versioni centralizzate** nel parent POM via `<properties>` e `<dependencyManagement>`
4. **BOM import** per Spring AI nel server app, versioni esplicite nelle librerie
5. **Tag `v*`** per trigger CI/CD Gitea Actions
6. **GPG e credenziali** come Gitea secrets, mai committati
7. **`deploy-mcp`** per deploy batch locale, singolo `mvn clean deploy` per singola libreria
8. **`-Dgpg.skip=true`** per install locali senza firma
9. **`<doclint>none</doclint>`** per evitare fallimenti javadoc su commenti mancanti
10. **`--pinentry-mode loopback`** per GPG su server headless (CI/CD e SOL)
