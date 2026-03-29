# Fix S3Config — ForcePathStyle duplicato

## Context

`simoge-mcp` in restart loop. Causa: AWS SDK v2.29.51 rifiuta `forcePathStyle` impostato sia su `S3AsyncClient.builder()` (riga 31) che implicitamente dalla Spring Boot auto-configuration. L'errore:

```
ForcePathStyle has been configured on both S3Configuration and the client/global level.
Please limit ForcePathStyle configuration to one location.
```

## File da modificare

- `/data/massimiliano/Vari/mcp-s3-tools/src/main/java/io/github/massimilianopili/mcp/s3/S3Config.java`

## Fix

**Riga 31**: rimuovere `.forcePathStyle(props.isPathStyle())` dal builder `S3AsyncClient` e usare invece `serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(...))`, come gia' fatto per il `S3Presigner` (righe 46-48). Questo evita il conflitto con eventuali property globali Spring Boot.

In alternativa (piu' semplice): rimuovere `.forcePathStyle()` dal builder e aggiungere `.serviceConfiguration()` — un solo posto per la config path-style.

```java
var builder = S3AsyncClient.builder()
        .endpointOverride(URI.create(props.getEndpoint()))
        .region(Region.of(props.getRegion()))
        .serviceConfiguration(S3Configuration.builder()
                .pathStyleAccessEnabled(props.isPathStyle())
                .build());
```

## Post-fix

1. Build: `mvn -f /data/massimiliano/Vari/mcp-s3-tools/pom.xml clean install -DskipTests`
2. Rebuild simoge-mcp: `cd /data/massimiliano/Vari/mcp && docker compose up -d --build simoge-mcp`
3. Verifica: `docker logs simoge-mcp --tail 20` — nessun errore S3, startup OK
4. Test: verificare che `graph_write` risponda

## Verification

```bash
docker logs simoge-mcp --tail 5 | grep -i "started\|error\|s3"
```
