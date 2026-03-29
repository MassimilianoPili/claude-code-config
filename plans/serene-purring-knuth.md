# Piano: Fix MCP trust store + OAuth2 Discovery

## Context
Due problemi separati nella connessione MCP remota:
1. **OAuth2 Discovery 404** (COMPLETATO): mcp-proxy rispondeva 401 senza `WWW-Authenticate`, client cercava `/.well-known/oauth-authorization-server` → 404
2. **Java PKIX trust store** (DA FARE): il backend Spring Boot (`simoge-mcp`) non riesce a fare HTTPS in uscita (web_fetch, web_search) per certificati Cloudflare

## Problema trust store — Diagnosi

```
WebSearchTools: web_fetch failed for 'https://example.com':
PKIX path building failed: unable to find valid certification path to requested target
```

**Certificate chain** (da `openssl s_client`):
```
depth=3 CN=AAA Certificate Services (Comodo)  ← ROOT nel chain
depth=2 CN=SSL.com TLS Transit ECC CA R2
depth=1 CN=Cloudflare TLS Issuing ECC CA 3
depth=0 CN=example.com
```

**Root cause**: `AAA Certificate Services` (legacy Comodo root) NON è nel Java cacerts di Temurin 21.0.10.
Il trust store ha `SSL.com Root Certification Authority ECC` (path alternativo via cross-sign), ma Java segue rigidamente la chain del server senza cercare path alternativi.

**Evidenza**:
- `curl` dal container → 200 (usa OpenSSL, più flessibile)
- Java WebClient → PKIX failure
- `openssl s_client -verify_return_error` → OK (trova path alternativo)
- `keytool -list -cacerts | grep "aaa cert"` → nessun risultato

## Fix — Fase 2: Trust store

### Opzione consigliata: Configurare Reactor Netty per usare JDK SSL con trust store di sistema

In `SearchConfig.java`, configurare il `WebClient` con un `HttpClient` che usa il JDK SSL provider e importa i CA di sistema:

**File**: `/data/massimiliano/Vari/mcp-search-tools/src/main/java/io/github/massimilianopili/mcp/search/SearchConfig.java`

```java
@Bean("searchHttpClient")
public WebClient searchHttpClient() {
    var httpClient = reactor.netty.http.client.HttpClient.create()
            .secure(spec -> spec.sslContext(
                io.netty.handler.ssl.SslContextBuilder.forClient()
                    .trustManager(javax.net.ssl.TrustManagerFactory.getInstance(
                        javax.net.ssl.TrustManagerFactory.getDefaultAlgorithm()))
                    .build()));
    return WebClient.builder()
            .clientConnector(new ReactorClientHttpConnector(httpClient))
            .codecs(configurer -> configurer.defaultCodecs().maxInMemorySize(2 * 1024 * 1024))
            // ... headers come prima
            .build();
}
```

**Problema**: il cacerts JDK ha comunque lo stesso gap. Meglio l'opzione alternativa.

### Opzione alternativa (più semplice): JVM system property nel docker-compose

Aggiungere a `/data/massimiliano/Vari/mcp/docker-compose.yml` o `.env`:

```yaml
environment:
  - JAVA_TOOL_OPTIONS=-Djavax.net.ssl.trustStore=/etc/ssl/certs/java/cacerts
```

O nel Dockerfile, fare `update-ca-certificates` per sincronizzare i CA di sistema nel Java trust store.

### Opzione più robusta: Dockerfile fix

Nel Dockerfile del MCP server, aggiungere:
```dockerfile
RUN apt-get update && apt-get install -y ca-certificates-java && \
    update-ca-certificates && \
    cp /etc/ssl/certs/java/cacerts $JAVA_HOME/lib/security/cacerts
```

Questo sincronizza i CA di Ubuntu 22.04 (che includono `AAA Certificate Services`) nel Java trust store.

## Fix consigliato: Dockerfile — una riga

Nel Dockerfile (`/data/massimiliano/Vari/mcp/Dockerfile`), aggiungere `ca-certificates-java` al blocco `apt-get` esistente nella Stage 2:

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates-java \                              # ← AGGIUNTO
    libglib2.0-0 libnss3 libnspr4 ...
```

Il pacchetto `ca-certificates-java` installa `/etc/ssl/certs/java/cacerts` con TUTTI i CA di Ubuntu 22.04 (incluso `AAA Certificate Services`).

Poi aggiungere dopo il COPY del jar:
```dockerfile
# Sync OS CA certificates into JVM trust store
RUN cp /etc/ssl/certs/java/cacerts $JAVA_HOME/lib/security/cacerts
```

## Build & Deploy
```bash
cd /data/massimiliano/Vari/mcp
docker compose build --no-cache
sol deploy mcp
```

## Verifica
1. `docker exec mcp-simoge-mcp-10 keytool -list -cacerts -storepass changeit | grep -i "aaa cert"` → deve trovare `AAA Certificate Services`
2. Da dentro il container: tool `web_fetch` su un URL Cloudflare → nessun errore PKIX
3. `docker logs mcp-simoge-mcp-10 --tail 50 | grep PKIX` → nessun nuovo errore

## Stato
- [x] Fase 1: OAuth2 Discovery — COMPLETATA e deployata (mcp-proxy)
- [ ] Fase 2: Trust store — DA FARE (simoge-mcp)
