# Plan: Full MCP Redeploy

## Context
simoge-mcp (~290 tools) and mcp-proxy have staged but uncommitted changes across 4 repos. The server references bumped library versions that need to be published first. Both containers are healthy but running stale images (pre-staged-changes). Goal: commit all pending changes, publish updated libs, rebuild and redeploy both MCP containers.

**TDT ordering**: publish dependencies → build consumer → deploy. Never build the server until its deps are in the registry.

## Step 1: Commit + push + publish libs — DONE

All 4 repos committed and pushed. Libs published via Gitea Actions CI (tag `g*` trigger):

| Library | Version | Registry | CI Run |
|---------|---------|----------|--------|
| mcp-search-tools | 0.2.0 | OK | #655 success |
| mcp-vector-tools | 0.5.0 | OK | #657 success |
| mcp-ssh-tools | 0.2.1 | OK | (pre-existing) |
| mcp-claude-queue-tools | 0.1.1 | OK | (pre-existing) |
| mcp-sql-tools | 0.1.2 | **PENDING** | #659 in_progress (retagged) |

## Step 2: Wait for sql-tools CI, then verify

```bash
curl -sf -o /dev/null -w '%{http_code}' "http://localhost/git/api/packages/sol_root/maven/io/github/massimilianopili/mcp-sql-tools/0.1.2/mcp-sql-tools-0.1.2.pom"
```
Must return 200 before proceeding to Docker build.

## Step 3: Build Docker images

### 3a. Build simoge-mcp
```bash
cd /data/massimiliano/Vari/mcp
docker compose build --no-cache simoge-mcp
```
Expected: ~3-5 min (Maven deps cached, Playwright chromium cached). The `--no-cache` ensures the new Dockerfile TLS fix is picked up.

### 3b. Build mcp-proxy
```bash
cd /data/massimiliano/Vari/mcp-proxy
docker compose build mcp-proxy
```
Expected: ~30s (Go static binary, tiny image).

## Step 4: Deploy with `sol`

```bash
sol deploy mcp
sol deploy mcp-proxy
```

Both are NOSCALE — simple swap (force-recreate). mcp-proxy handles reconnection automatically via proactive MCP init. Nginx auto-restarts after deploy.

**Alternative** (if sol deploy handles both):
```bash
sol deploy mcp mcp-proxy
```

## Step 5: Verify

1. **Health checks**: both containers should be healthy within 90s
   ```bash
   docker ps --filter name=mcp --format '{{.Names}}\t{{.Status}}'
   ```

2. **Smoke test MCP server**:
   ```bash
   curl -sf http://localhost:8099/actuator/health | jq .status
   ```

3. **Smoke test MCP proxy**:
   ```bash
   curl -sf http://localhost:8098/health
   ```

4. **Smoke test SSE endpoint** (via nginx):
   ```bash
   curl -sf -H "X-API-Key: $(mcp-token)" http://localhost:8098/sse &
   sleep 2 && kill %1
   ```

5. **Verify new features work**:
   - OAuth metadata: `curl http://localhost:8098/.well-known/oauth-protected-resource`
   - Graph-augmented search: use `embeddings_search_hybrid` via MCP

6. **Check no regressions**: run a few MCP tool calls from this Claude session to verify connectivity.

## Critical files
- `/data/massimiliano/Vari/mcp/pom.xml` — dependency versions
- `/data/massimiliano/Vari/mcp/Dockerfile` — TLS cert fix
- `/data/massimiliano/Vari/mcp/docker-compose.yml` — SSH agent mount
- `/data/massimiliano/Vari/mcp/src/.../SpiAdapterConfig.java` — graph search adapter
- `/data/massimiliano/Vari/mcp/src/.../KoreLookupService.java` — KORE graph expansion
- `/data/massimiliano/Vari/mcp-search-tools/` — SPI interface change
- `/data/massimiliano/Vari/mcp-vector-tools/` — hybrid search expansion
- `/data/massimiliano/Vari/mcp-proxy/main.go` — OAuth metadata endpoints
- `/data/massimiliano/shell-scripts/bin/deploy-mcp` — lib publish script
- `/data/massimiliano/shell-scripts/bin/sol` — deploy orchestrator

## Rollback
If deploy fails:
```bash
sol rollback mcp latest~1
sol rollback mcp-proxy latest~1
```
