# Fix: mcp-docker-tools — Unix socket connection

## Context

Verifica post-deploy di tutte le librerie MCP. 6 su 7 librerie funzionano correttamente.
**mcp-docker-tools** fallisce con `Connection refused: localhost/127.0.0.1:80` — il WebClient Reactor Netty
non usa il Unix socket nonostante la configurazione corretta (`MCP_DOCKER_HOST=unix:///var/run/docker.sock`).

**Root cause**: `HttpClient.create().remoteAddress(() -> new DomainSocketAddress(...))` non sovrascrive la
risoluzione URI del client HTTP. Reactor Netty risolve `http://localhost` → TCP `127.0.0.1:80`.

## Fix

### File: `/data/massimiliano/Vari/mcp-docker-tools/src/main/java/io/github/massimilianopili/mcp/docker/DockerConfig.java`

Sostituire l'approccio `remoteAddress()` con `HttpClient.from(TcpClient)` che bypassa la risoluzione HTTP:

```java
if (props.isUnixSocket()) {
    log.info("Docker WebClient: connessione via Unix socket {}", props.getUnixSocketPath());
    httpClient = HttpClient.create()
            .remoteAddress(() -> new DomainSocketAddress(props.getUnixSocketPath()));
}
```

→ cambiare in:

```java
if (props.isUnixSocket()) {
    log.info("Docker WebClient: connessione via Unix socket {}", props.getUnixSocketPath());
    TcpClient tcpClient = TcpClient.create()
            .remoteAddress(() -> new DomainSocketAddress(props.getUnixSocketPath()));
    httpClient = HttpClient.from(tcpClient);
}
```

Import aggiuntivo: `reactor.netty.tcp.TcpClient`

Se `HttpClient.from(TcpClient)` risulta deprecato nella versione corrente, alternativa:

```java
httpClient = HttpClient.create()
        .remoteAddress(() -> new DomainSocketAddress(props.getUnixSocketPath()))
        .resolver(DefaultAddressResolverGroup.INSTANCE); // no-op resolver
```

Oppure usare il pattern di `baseUrl` direttamente sul WebClient senza risolvere il host.

## Verifica

1. `cd /data/massimiliano/Vari/mcp-docker-tools && /opt/maven/bin/mvn clean install -Dgpg.skip=true`
2. `cd /data/massimiliano/Vari/mcp && /opt/maven/bin/mvn clean install -Dgpg.skip=true`
3. `sol deploy mcp`
4. Testare: `docker_ping`, `docker_version`, `docker_list_containers`

## Tool verification summary (pre-fix)

| Libreria | Stato | Note |
|----------|-------|------|
| mcp-gitea-tools | ✅ | param `name` (non `repo`) per il repo name |
| mcp-ollama-tools | ✅ | 5 modelli visibili |
| mcp-token-tools | ✅ | budget, report, record funzionanti |
| mcp-metacognition-tools | ✅ | predict_agent, surprise funzionanti |
| mcp-recovery-tools | ✅ | health_dashboard funzionante |
| mcp-sql-tools | ✅ | default = embeddings DB |
| **mcp-docker-tools** | **❌** | Unix socket connection refused |
