# Plan: Full MCP Redeploy

## Context
simoge-mcp (~290 tools) and mcp-proxy have staged but uncommitted changes across 4 repos. The server references bumped library versions that need to be published first. Both containers are healthy but running stale images (pre-staged-changes). Goal: commit all pending changes, publish updated libs, rebuild and redeploy both MCP containers.

**TDT ordering**: publish dependencies → build consumer → deploy. Never build the server until its deps are in the registry.

## Step 1: Commit staged changes in dependency libraries

Order matters — libs first, server last.

### 1a. mcp-search-tools (`/data/massimiliano/Vari/mcp-search-tools/`)
- 3 staged files: pom.xml (0.1.0→0.2.0), WebSearchTools.java, SemanticLookup.java (SPI extension)
- `git commit` → `git push`

### 1b. mcp-vector-tools (`/data/massimiliano/Vari/mcp-vector-tools/`)
- 2 staged files: pom.xml (0.4.0→0.5.0), HybridSearchTools.java
- `git commit` → `git push`

### 1c. mcp-proxy (`/data/massimiliano/Vari/mcp-proxy/`)
- 1 staged file: main.go (OAuth metadata + WWW-Authenticate)
- `git commit` → `git push`

### 1d. mcp/ server (`/data/massimiliano/Vari/mcp/`)
- 5 staged files: Dockerfile, docker-compose.yml, pom.xml, SpiAdapterConfig.java, KoreLookupService.java
- `git commit` → `git push`

## Step 2: Publish updated libraries to Gitea Maven registry

```bash
deploy-mcp search vector
```

This publishes mcp-search-tools 0.2.0 and mcp-vector-tools 0.5.0 to the Gitea registry. The other bumped deps (sql 0.1.2, ssh 0.2.1, claude-queue 0.1.1) should already be in the registry — verify first.

**Verify all 5 bumped versions exist:**
```bash
for lib in "mcp-sql-tools/0.1.2" "mcp-ssh-tools/0.2.1" "mcp-vector-tools/0.5.0" "mcp-search-tools/0.2.0" "mcp-claude-queue-tools/0.1.1"; do
  curl -sf "http://gitea:3000/api/packages/sol_root/maven/com.massimilianopili.mcp/${lib}/pom" > /dev/null && echo "OK: $lib" || echo "MISSING: $lib"
done
```

If any are MISSING → `deploy-mcp <name>` for those too.

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
