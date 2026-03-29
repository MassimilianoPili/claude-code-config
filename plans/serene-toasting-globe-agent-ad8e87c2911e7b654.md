# Research: Zero-Downtime Docker Deployments on Single Host

## Research Summary

**Epistemic status:** Strong practitioner consensus -- these are well-documented, production-proven patterns
**Confidence:** High -- multiple independent sources confirm the same approaches, with real-world deployment counts reported
**Primary sources:** GitHub repos, Docker documentation, DevOps blogs (T5-T7), practitioner case studies

---

## 1. Build-then-Swap vs Blue-Green

### Verdict: Blue-Green is the dominant pattern for single-host Docker Compose

Three distinct approaches have emerged in practice:

**A) Blue-Green with nginx upstream switching** (most common for nginx users)
- Two service definitions in compose (e.g., `app-blue` on :3011, `app-green` on :3012)
- nginx upstream with `backup` directive, traffic switch via `sed` + `nginx -s reload`
- One practitioner reports 156 deployments over 6 months, 99.97% uptime, 0s user-visible downtime
- Rollback: restart the stopped container + reverse nginx config (~45 seconds)
- Source: [DEV.to blue-green guide](https://dev.to/sangwoo_rhie/zero-downtime-blue-green-deployment-with-github-actions-docker-multi-stage-builds-and-nginx-695)

**B) Scale trick with nginx reload** (the Tines pattern)
- Single service definition, `docker compose up -d --scale service=2 --no-recreate`
- Health-check new container via curl retry loop
- `nginx -s reload` to pick up both containers
- Stop + remove old container, scale back to 1, reload nginx again
- Production-proven: "6 months without issue" at Tines
- Source: [Tines blog](https://www.tines.com/blog/simple-zero-downtime-deploys-with-nginx-and-docker-compose/)

**C) docker-rollout plugin** (automates pattern B)
- Docker CLI plugin that wraps the scale trick
- Requires Traefik or nginx-proxy (Docker socket-aware proxies)
- Source: [github.com/wowu/docker-rollout](https://github.com/wowu/docker-rollout)

### Recommendation for SOL

Pattern B (scale trick + nginx reload) fits best because:
- SOL already uses nginx with lazy DNS resolution (`set $var` + `resolver 127.0.0.11`)
- No need to add Traefik or nginx-proxy
- The existing `--force-recreate` convention can be replaced with the scale-then-kill sequence
- Pattern A (dedicated blue/green services) doubles compose file complexity

---

## 2. Docker Compose Native Capabilities

### Verdict: Docker Compose has NO native rolling update support in standalone mode

Key findings:

- **`deploy.update_config`** with `order: start-first` exists in the Compose specification but is **only enforced in Swarm mode** (`docker stack deploy`). In standalone `docker compose up`, these fields are **silently ignored**.
- Source: [Docker Compose deploy spec](https://docs.docker.com/reference/compose-file/deploy/) -- the spec does not distinguish standalone vs Swarm, but multiple forum threads confirm non-enforcement.
- GitHub issue [docker/compose#5013](https://github.com/docker/compose/issues/5013) -- `--update-order` support requested but not implemented for standalone.

**Useful standalone flags:**

| Flag | What it does | Zero-downtime relevance |
|------|-------------|------------------------|
| `--no-deps` | Only affect the specified service, not dependencies | Prevents cascading restarts |
| `--no-recreate` | Don't recreate containers that already exist | Essential for scale trick |
| `--wait` | Wait for services to be healthy before returning | Blocks script until ready |
| `--wait-timeout N` | Timeout for `--wait` (added ~2023) | Prevents infinite hang |
| `--force-recreate` | Recreate even if config unchanged | Current SOL convention, causes downtime |
| `--pull always` | Pull image before starting | Combines pull+up |
| `--remove-orphans` | Clean up orphan containers | Housekeeping |

**Critical insight:** `docker compose up -d` already does incremental updates -- it only recreates containers whose config or image has changed. The problem is that recreation = stop-then-start, which causes a gap. There is no `start-first` mode in standalone Compose.

---

## 3. Healthcheck-based Readiness

### Best practice configuration:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 10s
  timeout: 5s
  retries: 3
  start_period: 30s    # Grace period for slow JVM startup
  start_interval: 5s   # Check frequency during grace period (Docker 25+)
```

**Key parameters:**
- `start_period`: During this window, failed checks do NOT count against retries. A successful check ends the grace period early.
- `start_interval` (Docker Engine 25+, Compose 2.22+): Separate, faster interval during start_period. Allows checking every 2s during startup while using 30s interval in steady state.

**Integration with reverse proxies:**

| Proxy | How it uses healthchecks | Mechanism |
|-------|------------------------|-----------|
| **nginx** (vanilla) | Does NOT read Docker healthchecks | Must poll manually or use scale trick |
| **nginx-proxy** | Reads Docker events via socket | Auto-updates upstream, respects healthy status |
| **Traefik** | Docker provider via socket | Excludes unhealthy containers from routing automatically |
| **Caddy** (with docker-proxy) | Similar to Traefik | Admin API for dynamic upstream updates |

**For SOL's nginx setup:** Since nginx is vanilla (no Docker socket integration), the healthcheck serves two purposes:
1. `docker compose up --wait` blocks until healthy
2. External scripts can poll `docker inspect --format='{{.State.Health.Status}}'`

The nginx lazy DNS pattern (`set $var` + `resolver 127.0.0.11`) already provides partial resilience -- if a container is restarting, DNS re-resolves on the next request. The gap is during the restart window itself.

---

## 4. Traefik / nginx Patterns

### Traefik approach (label-based, Docker socket watching)

```yaml
services:
  traefik:
    image: traefik:v3.x
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    ports:
      - "80:80"

  myapp:
    image: myapp:latest
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.myapp.rule=PathPrefix(`/app`)"
      - "traefik.http.services.myapp.loadbalancer.healthcheck.path=/health"
      - "traefik.http.services.myapp.loadbalancer.healthcheck.interval=5s"
    # NO ports: or container_name:
```

**Advantages:** Automatic service discovery, automatic healthcheck-gated routing, works with docker-rollout out of the box.

**Disadvantages:** Requires Docker socket access (security concern), adds another moving part, Traefik has known issues where first healthcheck failure permanently removes instance (GitHub [#8570](https://github.com/traefik/traefik/issues/8570)).

### nginx approach (manual but predictable)

SOL already uses the best nginx pattern for resilience:
```nginx
resolver 127.0.0.11 valid=10s;
set $backend http://myservice:8080;
proxy_pass $backend;
```

For zero-downtime, this needs to be combined with:
1. Scale trick (section 1B above), OR
2. Blue-green with `sed` upstream switching + `nginx -s reload`

**nginx -s reload behavior:** "Old worker processes stop accepting new connections and continue servicing current requests until all such requests are serviced." This is the key -- reload is itself a zero-downtime operation.

### Recommendation for SOL

**Do NOT switch to Traefik.** The nginx setup is already well-optimized with ~30 routes, 4 auth patterns, lazy DNS. Adding Traefik would require rewriting all routing configuration. The scale trick + nginx reload achieves the same result with zero architectural changes.

---

## 5. The Scale Trick -- Details and Caveats

### The exact sequence:

```bash
SERVICE=myapp
OLD_ID=$(docker ps -f name=$SERVICE -q | tail -n1)

# 1. Scale to 2 (new container starts alongside old)
docker compose up -d --no-deps --scale $SERVICE=2 --no-recreate $SERVICE

# 2. Wait for new container to be healthy
NEW_ID=$(docker ps -f name=$SERVICE -q | head -n1)
# ... health check loop ...

# 3. Reload nginx (now routes to both containers)
docker exec nginx nginx -s reload

# 4. Stop old container
docker stop $OLD_ID && docker rm $OLD_ID

# 5. Scale back to 1 (preserves new container)
docker compose up -d --no-deps --scale $SERVICE=1 --no-recreate $SERVICE

# 6. Final nginx reload (clean up routing)
docker exec nginx nginx -s reload
```

### Critical caveats:

1. **`container_name` MUST be removed.** Docker cannot create two containers with the same name. Containers will be named `project_service_1`, `project_service_2` instead. This is the single biggest blocker for SOL -- many services likely have `container_name` set.

2. **`ports` MUST be removed** (or use a range). Two containers cannot bind the same host port. Services should be accessed through the nginx proxy, not directly via host ports.

3. **`--no-recreate` is essential.** Without it, `docker compose up` would recreate the existing container with the new image, defeating the purpose.

4. **Image must be pre-pulled.** If `docker compose up` triggers a build or pull, the old container continues running but the delay is visible. Pre-pull with `docker compose pull` or `docker compose build` first.

5. **Stateful services need care.** If the service writes to a named volume, two instances writing simultaneously can cause corruption. For stateless HTTP services, this is not an issue.

6. **DNS resolution timing.** With Docker's embedded DNS, the resolver may cache the old IP for up to `valid=10s`. The nginx reload forces re-resolution.

### Does it work with container_name set?

**No.** Docker will error with "container name already in use." This is a hard constraint, not a workaround-able issue.

---

## 6. Reverse Proxy Queue/Buffer Patterns

### Verdict: Yes, this is a recognized pattern with multiple names

The pattern used by SOL's `mcp-proxy` (queuing requests during backend restart, replaying after reconnect) is a recognized architectural pattern with several names:

| Name | Context | Source |
|------|---------|--------|
| **Deferred request queue** | ServiceQ project terminology | [ServiceQ](https://github.com/gptankit/serviceq) |
| **Request buffering / holding** | General proxy terminology | NGINX docs, Envoy Gateway |
| **Connection draining** | The graceful shutdown side | NGINX, AWS ALB |
| **Store-and-forward proxy** | Messaging-style terminology | General distributed systems |
| **Retry buffer** | Resilience engineering | Circuit breaker literature |

**ServiceQ** is the closest open-source analog to mcp-proxy's behavior: it buffers failed requests in a FIFO queue and replays them when the upstream becomes healthy again. Key difference: ServiceQ is designed for fire-and-forget workloads where the client does not block on the response.

**Is it sufficient for zero-downtime?** It depends on the definition:
- **For the client:** Yes, if the queue timeout is longer than the restart window. The client sees latency increase, not errors.
- **For strict zero-downtime:** No purists would call it zero-downtime because request latency spikes during the buffer window. But for practical purposes (especially MCP/SSE where clients already handle reconnects), it is sufficient.

**mcp-proxy's approach is actually more sophisticated** than most examples found: it does proactive MCP handshake init after reconnect, synthetic keepalives during downtime, and request queuing with TTL. This is closer to what service meshes (Istio, Linkerd) do than simple reverse proxies.

---

## 7. Image Pre-pull / Pre-build

### Best practices found:

**Separation principle:** Always separate image preparation from container lifecycle.

```bash
# Step 1: Build/pull (can take minutes, zero impact on running services)
docker compose build myapp          # For locally-built images
docker compose pull myapp           # For registry images

# Step 2: Swap (takes seconds)
docker compose up -d --no-deps myapp
```

**For registry-based images:**
```bash
docker compose pull --quiet         # Pre-pull all services
docker compose up -d                # Recreate only changed services
```

**For locally-built images (SOL's Go multi-stage builds):**
```bash
# Build produces new image layer, old container keeps running
docker compose build --no-cache myapp
# Only now does the restart happen
docker compose up -d --no-deps myapp
```

**Key insight from Docker docs:** `docker compose up -d` is faster than `docker compose stop && docker compose up -d`. The `up` command detects changes and only recreates affected containers. Never use `docker compose down` for updates (it removes networks and volumes).

**For SOL specifically:** The `sol` deploy script should be structured as:
1. `git pull` (get new code)
2. `docker compose build` (compile Go binary in multi-stage, creates new image)
3. `docker compose up -d --no-deps <service>` (swap container, ~2-5 seconds downtime)
4. Or: use scale trick from section 5 for true zero-downtime

---

## 8. Rollback Strategies

### Three approaches found in practice:

**A) Tag-based rollback (recommended)**
```bash
# Deploy with explicit tags
docker compose -f docker-compose.yml up -d  # Uses image: myapp:v1.2.3

# Rollback: change tag and redeploy
# In .env or compose file: IMAGE_TAG=v1.2.2
docker compose up -d --no-deps myapp
```

**B) Docker image hash rollback (manual)**
```bash
# Before deploy, note current image hash
CURRENT=$(docker inspect --format='{{.Image}}' myapp)

# After bad deploy, retag old hash
docker tag $CURRENT myapp:latest
docker compose up -d --no-deps myapp
```

**C) Keep old container (blue-green rollback)**
```bash
# During deploy: docker stop old, don't docker rm
# Rollback: docker start old, stop new, reload nginx
docker start $OLD_CONTAINER_ID
docker stop $NEW_CONTAINER_ID
nginx -s reload
```

**Recommendation for SOL:** Approach C is the fastest rollback (~30 seconds). Combined with the blue-green pattern:
- Deploy stops old container but does not remove it
- If new container fails healthcheck, old container is restarted immediately
- After successful deploy + grace period (e.g., 5 minutes), old container is removed

For registry-based images, approach A with semantic version tags provides the best audit trail.

---

## 9. Well-Known Tools

| Tool | Stars | What it does | Fit for SOL |
|------|-------|-------------|-------------|
| **[docker-rollout](https://github.com/wowu/docker-rollout)** | ~3.7K | Docker CLI plugin, automates scale trick | Partial -- requires removing container_name and ports |
| **[Kamal](https://kamal-deploy.org/)** (was MRSK) | ~11K | Full deploy tool, uses Traefik, by 37signals | Overkill -- would replace entire deploy pipeline |
| **[docker-compose-wait](https://github.com/ufoscout/docker-compose-wait)** | ~1.7K | Wait for dependencies to be ready | Useful for startup ordering, not zero-downtime |
| **ServiceQ** | ~200 | Request-buffering load balancer | Pattern reference, not directly usable |
| **Dokku** | ~30K | Heroku-like PaaS on single host | Overkill -- complete platform replacement |
| **[Portainer](https://portainer.io)** | Already on SOL | Has "recreate" button with pull | No zero-downtime support |

### Assessment

**docker-rollout** is the most practical tool for SOL's use case, IF the container_name and port constraints can be resolved. Since SOL uses nginx as the proxy (not Traefik/nginx-proxy), docker-rollout's automatic proxy integration would not work -- but the script logic it implements is exactly the scale trick from section 5.

**Kamal** is interesting but opinionated: it wants to manage the entire deploy lifecycle including Traefik, SSH, and container registry. Not a good fit for an existing nginx-based setup.

**Best approach for SOL:** Write a custom `sol-deploy` function (or enhance the existing `sol` script) that implements the Tines pattern (section 1B) directly. This gives full control without external dependencies.

---

## 10. Spring Boot / JVM Startup Optimization

### Benchmark data for context:

| Configuration | Startup time | Notes |
|---------------|-------------|-------|
| Spring Boot vanilla (200+ beans, 1 CPU) | 6-8 seconds | Typical Docker with CPU limits |
| Spring Boot vanilla (200+ beans, 4 CPU) | 2-3 seconds | With adequate CPU |
| Spring Boot + CDS/AppCDS | 3-4 seconds (1 CPU) | ~40% reduction |
| Spring Boot + AOT processing | ~2 seconds (4 CPU) | Needs spring-boot-maven-plugin AOT |
| GraalVM native image | 0.05-0.3 seconds | 50-100x faster, but throughput tradeoffs |
| JDK 24 AOT Cache (JEP 483) | ~1 second | Newest approach, supersedes AppCDS |

### For simoge-mcp (286 tools, Spring Boot + Spring AI):

**Estimated startup:** 8-15 seconds is realistic for 286 beans with Spring AI auto-configuration. MCP tool registration and reactive transport setup add overhead beyond basic bean creation.

**Practical optimizations (ranked by effort/impact):**

1. **Allocate adequate CPUs** (lowest effort, highest impact): Ensure the container has at least 2-4 CPUs during startup. Spring Boot parallelizes bean initialization.
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '4.0'    # During startup
         memory: 1g
   ```

2. **AppCDS / CDS** (moderate effort): Create a class list during a training run, bake the shared archive into the Docker image.
   ```dockerfile
   # Training stage
   FROM eclipse-temurin:21 AS trainer
   COPY app.jar /app.jar
   RUN java -XX:ArchiveClassesAtExit=/app.jsa -jar /app.jar --exit-after-init

   # Runtime stage
   FROM eclipse-temurin:21
   COPY --from=trainer /app.jsa /app.jsa
   COPY app.jar /app.jar
   ENTRYPOINT ["java", "-XX:SharedArchiveFile=/app.jsa", "-jar", "/app.jar"]
   ```
   Expected improvement: ~40% startup reduction.

3. **Spring AOT processing** (moderate effort, Spring Boot 3.x): Add `spring-boot-maven-plugin` AOT goal. Generates optimized bean definitions at build time.
   Expected improvement: ~30% additional reduction on top of CDS.

4. **JDK 24 AOT Cache** (if migrating to JDK 24): Supersedes AppCDS. Single command creates full AOT cache.
   ```bash
   java -XX:AOTCache=app.aot -jar app.jar
   ```

5. **GraalVM native image** (high effort): Near-instant startup (50ms) but significant tradeoffs:
   - Build time: 5-15 minutes
   - No runtime JIT optimization (lower peak throughput)
   - Reflection configuration required (Spring AI uses heavy reflection)
   - Not recommended for long-running server processes where JIT matters

### Recommendation for SOL

For simoge-mcp specifically, the zero-downtime deploy pattern (scale trick) makes startup time less critical -- the old container handles requests while the new one starts. The real constraint is **total deploy time**, not startup time.

Priority order:
1. Implement zero-downtime deploy (eliminates user-visible impact of slow startup)
2. Add AppCDS to Docker image (reduces total deploy time by ~40%)
3. Ensure container has adequate CPU allocation during startup

---

## Serendipitous Connections

### Connection to mcp-proxy architecture
The mcp-proxy already implements the most sophisticated pattern found in this research: request queuing with TTL, proactive handshake replay, and synthetic keepalives. This is architecturally identical to what service meshes (Istio sidecar proxy) do for zero-downtime deploys. The mcp-proxy pattern could be generalized to other SOL services.

### Connection to Agent Framework
The agent-framework (Spring Boot, :8085, 42 Flyway migrations) is the service that would benefit most from zero-downtime deploys -- it has the longest startup time due to database migrations + heavy Spring context. The CDS/AppCDS optimization would have the highest impact here.

### Connection to Preference Sort (Ranking Todo project)
The preference-sort service uses Bradley-Terry model calculations that can be interrupted by restarts. Zero-downtime deploys would ensure ranking sessions are never interrupted mid-comparison.

---

## Practical Recommendation for SOL

### Phased approach:

**Phase 0 -- Prerequisites (minimal changes)**
- Audit all docker-compose.yml files: which services have `container_name`?
- Audit which services expose `ports:` directly vs going through nginx
- For services that MUST keep container_name (e.g., nginx itself, postgres), zero-downtime is not needed (they are infrastructure, not frequently deployed)

**Phase 1 -- Low-hanging fruit**
- Change `sol` deploy script: `docker compose build` THEN `docker compose up -d` (separate build from restart)
- Add `HEALTHCHECK` to all application Dockerfiles (Go services, Spring Boot services)
- Use `docker compose up -d --wait --wait-timeout 120` instead of bare `up -d`

**Phase 2 -- Scale trick for key services**
- Remove `container_name` from frequently-deployed services (proxy-ai, mcp, knowledge-graph, etc.)
- Remove direct `ports:` mappings where nginx is the sole entry point
- Implement the Tines-style deploy script as a `sol` subcommand

**Phase 3 -- JVM optimization**
- Add AppCDS to simoge-mcp and agent-framework Docker images
- Benchmark startup time improvement
- Consider Spring AOT if startup is still > 10 seconds

---

## Sources

### Primary (production-proven patterns)
- [Tines: Zero downtime deploys with Nginx and Docker Compose](https://www.tines.com/blog/simple-zero-downtime-deploys-with-nginx-and-docker-compose/) -- 6 months production, the Tines scale trick
- [DEV.to: Blue-Green Deployment](https://dev.to/sangwoo_rhie/zero-downtime-blue-green-deployment-with-github-actions-docker-multi-stage-builds-and-nginx-695) -- 156 deployments, 99.97% uptime
- [docker-rollout GitHub](https://github.com/wowu/docker-rollout) -- ~3.7K stars, Docker CLI plugin
- [jmh.me: Zero downtime Docker Compose deploy](https://jmh.me/blog/zero-downtime-docker-compose-deploy) -- Caddy-based variant, load testing results
- [Kamal (was MRSK)](https://kamal-deploy.org/) -- 37signals production tool

### Docker documentation
- [Docker Compose deploy specification](https://docs.docker.com/reference/compose-file/deploy/) -- update_config is Swarm-only
- [Docker Compose up reference](https://docs.docker.com/reference/cli/docker/compose/up/) -- --wait, --wait-timeout flags
- [docker/compose#5013](https://github.com/docker/compose/issues/5013) -- update-order not supported in standalone

### JVM / Spring Boot optimization
- [Makariev: Spring Boot CDS + Native Image](https://www.makariev.com/blog/spring-boot-cds-native-image-dockerfile/) -- Dockerfile patterns, benchmarks
- [Spring.io: How Fast is Spring](https://spring.io/blog/2018/12/12/how-fast-is-spring/) -- Bean count vs startup time baseline
- [Spring.io: Runtime efficiency](https://spring.io/blog/2023/10/16/runtime-efficiency-with-spring/) -- CDS, AOT, native comparison

### Community discussion
- [HN: docker-rollout discussion](https://news.ycombinator.com/item?id=34690947) -- Real-world critiques, alternatives
- [Supun.io: Easy zero-downtime](https://supun.io/zero-downtime-deployments-docker-compose) -- docker-rollout + Traefik walkthrough
- [ServiceQ](https://github.com/gptankit/serviceq) -- Deferred request queue pattern

### Reverse proxy patterns
- [NGINX documentation: proxy buffering](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [der-Lehmann: docker-nginx-zero-downtime](https://github.com/der-Lehmann/docker-nginx-zero-downtime-deployment) -- GitHub reference implementation
- [Docker Compose rollback](https://kkovacs.eu/docker-compose-rollback/) -- Manual rollback procedure
