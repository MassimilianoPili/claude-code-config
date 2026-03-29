# Fix: simoge-mcp startup failure — S3 ForcePathStyle conflict

## Context

`simoge-mcp` is completely down. The Spring Boot context fails to initialize because `S3Config` bean creation throws:

> ForcePathStyle has been configured on both S3Configuration and the client/global level. Please limit ForcePathStyle configuration to one location.

**Root cause**: AWS SDK `2.29.51` introduced `forcePathStyle()` at the S3 client builder level. The SDK now auto-resolves path-style from profile/system properties too. Setting `pathStyleAccessEnabled()` in `S3Configuration` AND having ANY client/global-level config triggers this validation error.

**Impact**: ALL 241 MCP tools are down, not just S3 tools. Spring context rollback destroys everything.

## Fix

### File: `/data/massimiliano/Vari/mcp-s3-tools/src/main/java/io/github/massimilianopili/mcp/s3/S3Config.java`

Replace `serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(...).build())` with `forcePathStyle()` on the builder for both beans:

**s3AsyncClient** (line 28-33): Use `.forcePathStyle(props.isPathStyle())` on `S3AsyncClient.builder()`, remove `.serviceConfiguration(...)`.

**s3Presigner** (line 45-50): Use `.serviceConfiguration(S3Configuration.builder().pathStyleAccessEnabled(props.isPathStyle()).build())` — S3Presigner does NOT have `forcePathStyle()` on its builder, so keep `serviceConfiguration` here. The conflict only occurs on `S3AsyncClient`.

**Alternative (simpler)**: Remove `serviceConfiguration` from `S3AsyncClient` only, keep it on `S3Presigner`. The new SDK method `S3AsyncClient.builder().forcePathStyle(true)` is the canonical way.

## Build & Deploy

1. Edit `S3Config.java`
2. `cd /data/massimiliano/Vari/mcp-s3-tools && mvn clean install -DskipTests`
3. `cd /data/massimiliano/Vari/mcp && mvn clean package -DskipTests`
4. `cd /data/massimiliano/Vari/mcp && docker compose up -d --build simoge-mcp`
5. Verify: `docker logs simoge-mcp --tail 20` — should show "Started McpServerApplication"

## Verification

- `docker logs simoge-mcp | grep "S3 AsyncClient"` — should show endpoint/region/pathStyle
- Test graph_write via MCP tools
- Check all 241 tools registered without context rollback
