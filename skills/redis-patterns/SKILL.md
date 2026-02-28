---
name: redis-patterns
description: Redis patterns for database partitioning, caching with TTL, session storage, background job queues, and Go/Spring Boot client integration in Docker Compose self-hosted environments.
allowed-tools: Read, Write, Bash, Edit
category: database
tags: [redis, cache, session, docker, go-redis, spring]
version: 1.0.0
---

# Redis Patterns — Server SOL

## Overview

Redis 7 Alpine as shared in-memory data store on SOL server. No authentication (internal Docker
network only). Used by Gitea (cache, sessions, queues) and server-api (status caching).

All services connect by container name (`redis:6379`). No ports are exposed to the host —
access is restricted to containers on the `shared` Docker network.

## When to Use

- Adding caching to a new or existing service on SOL
- Configuring session storage backed by Redis
- Understanding Redis DB partitioning conventions
- Setting up background job queues
- Debugging cache misses, stale data, or queue issues
- Integrating a Go, Spring Boot, or Node.js service with Redis

## Docker Compose Configuration

```yaml
services:
  redis:
    image: redis:7-alpine
    container_name: redis
    restart: unless-stopped
    volumes:
      - ./data:/data
    networks:
      - shared

networks:
  shared:
    external: true
```

Minimal config — no ports exposed, no authentication (internal only). Data persisted via RDB
snapshots in `./data/`. No custom `redis.conf`; AOF not enabled — acceptable for cache/session
use cases where occasional data loss on crash is tolerable.

## Database Partitioning

Redis supports 16 databases (0-15). SOL server uses dedicated databases per service to avoid
key collisions and allow independent flushing:

| DB | Used By | Purpose | Connection String |
|----|---------|---------|-------------------|
| 0 | Gitea | Cache | `redis://redis:6379/0` |
| 1 | Gitea | Sessions | `redis://redis:6379/1` |
| 2 | Gitea | Queues/background jobs | `redis://redis:6379/2` |
| 3 | server-api | Service status cache (10s TTL) | `redis:6379` DB 3 |
| 4-15 | Available | For new services | — |

**Convention**: Assign databases sequentially. Document new assignments in this table before
deploying. This prevents two services from accidentally sharing a database.

## Connection Patterns

### Go (go-redis v9)

```go
import "github.com/redis/go-redis/v9"

rdb := redis.NewClient(&redis.Options{
    Addr: "redis:6379",
    DB:   3, // Use assigned DB number
})

// Verify connectivity at startup
if err := rdb.Ping(ctx).Err(); err != nil {
    log.Fatalf("Redis connection failed: %v", err)
}

// Cache with TTL
rdb.Set(ctx, "service_status", jsonData, 10*time.Second)

// Read from cache
cached, err := rdb.Get(ctx, "service_status").Bytes()
if err == nil {
    // Cache hit
} else if err == redis.Nil {
    // Cache miss — fetch from source
}

// Invalidate
rdb.Del(ctx, "service_status")
```

### Spring Boot (spring-boot-starter-data-redis)

```yaml
spring:
  data:
    redis:
      host: redis
      port: 6379
      database: 4 # Next available DB
      timeout: 2000ms
```

```java
@Autowired
private StringRedisTemplate redisTemplate;

// Set with TTL
redisTemplate.opsForValue().set("key", "value", Duration.ofMinutes(5));

// Get (returns null on miss)
String value = redisTemplate.opsForValue().get("key");

// Invalidate
redisTemplate.delete("key");
```

### Gitea Environment Variables

Gitea uses three separate databases for isolation between cache, sessions, and queues:

```yaml
environment:
  GITEA__cache__ADAPTER: redis
  GITEA__cache__HOST: "redis://redis:6379/0?pool_size=100&idle_timeout=180s"
  GITEA__session__PROVIDER: redis
  GITEA__session__PROVIDER_CONFIG: "redis://redis:6379/1?pool_size=100&idle_timeout=180s"
  GITEA__queue__TYPE: redis
  GITEA__queue__CONN_STR: "redis://redis:6379/2?pool_size=100&idle_timeout=180s"
```

### Node.js (ioredis)

```javascript
const Redis = require('ioredis');
const redis = new Redis({ host: 'redis', port: 6379, db: 5 });

await redis.set('key', JSON.stringify(value), 'EX', 300); // 5 min TTL
const raw = await redis.get('key');
const value = raw ? JSON.parse(raw) : null;
await redis.del('key');
```

## Cache Pattern (server-api)

Real example from server-api — cache Docker container status for 10 seconds to reduce
Docker API calls from the dashboard's polling:

```go
const cacheKey = "service_status"
const cacheTTL = 10 * time.Second

func fetchStatus(ctx context.Context, rdb *redis.Client) ([]byte, error) {
    // Try cache first
    if cached, err := rdb.Get(ctx, cacheKey).Bytes(); err == nil {
        return cached, nil
    }

    // Cache miss — fetch from Docker API
    resp, err := dockerDo("GET", "/containers/json?all=1")
    if err != nil {
        return nil, err
    }
    // ... process response into status map

    out, _ := json.Marshal(status)
    rdb.Set(ctx, cacheKey, out, cacheTTL)
    return out, nil
}
```

Invalidation on write operations (write-through pattern):

```go
// After stop/start/restart/delete container:
func handleContainerAction(w http.ResponseWriter, r *http.Request) {
    // ... perform Docker action
    rdb.Del(r.Context(), cacheKey) // Invalidate so next read gets fresh data
}
```

## CLI Operations

```bash
# Connect to Redis CLI (interactive)
docker exec -it redis redis-cli

# Select specific database
docker exec -it redis redis-cli -n 3

# List all keys in DB 3
docker exec redis redis-cli -n 3 KEYS '*'

# Get a specific key value
docker exec redis redis-cli -n 3 GET "service_status"

# Check TTL remaining on a key
docker exec redis redis-cli -n 3 TTL "service_status"

# Check memory usage
docker exec redis redis-cli INFO memory

# Check per-database key counts
docker exec redis redis-cli INFO keyspace

# Monitor commands in real-time (useful for debugging)
docker exec redis redis-cli MONITOR

# Flush a specific database (e.g., clear server-api cache)
docker exec redis redis-cli -n 3 FLUSHDB

# Flush ALL databases (DANGER — clears Gitea sessions too)
# docker exec redis redis-cli FLUSHALL

# Check Redis version and uptime
docker exec redis redis-cli INFO server | grep -E 'redis_version|uptime'

# Measure latency
docker exec redis redis-cli --latency -c 100
```

## Best Practices

1. **Always specify DB number** — never use default (0) for new services; it belongs to Gitea cache
2. **Document DB assignments** in the partitioning table above before deploying
3. **Use TTL on all cache keys** — avoid unbounded memory growth; prefer short TTLs (10s-5min)
4. **No authentication needed** — Redis is on internal Docker network only, not exposed to host
5. **Invalidate cache after mutations** — use the write-through pattern (delete key after write)
6. **Handle connection errors gracefully** — fall back to direct source if Redis is down
7. **Use Alpine image** for smaller footprint (~30 MB vs ~130 MB full image)
8. **Persist data** via `./data:/data` volume mount (RDB snapshots, default schedule)
9. **Avoid KEYS in production code** — use SCAN for iteration; KEYS blocks the server
10. **Set maxmemory if needed** — add `--maxmemory 256mb --maxmemory-policy allkeys-lru`

## Troubleshooting

**Connection refused from container**:
- Verify redis is running: `docker ps | grep redis`
- Verify it is on the `shared` network: `docker network inspect shared | grep redis`
- Check DNS from the connecting container: `docker exec <container> nslookup redis`

**Wrong data or stale cache**:
- Confirm correct DB number (common mistake: DB 0 instead of assigned DB)
- Check TTL: `docker exec redis redis-cli -n <db> TTL <key>` — value -1 means no expiry
- Flush the specific DB: `docker exec redis redis-cli -n <db> FLUSHDB`

**Memory issues**:
- Check usage: `docker exec redis redis-cli INFO memory` (look at `used_memory_human`)
- Find large keys: `docker exec redis redis-cli --bigkeys`
- Set limit: add `command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru`

**Gitea slow or falling back to in-memory**:
- Check Gitea logs: `docker logs gitea 2>&1 | grep -i redis`
- If Redis was restarted, Gitea sessions are lost (users need to re-login) — expected behavior

**Debugging live traffic**:
- `docker exec redis redis-cli MONITOR` — all commands in real-time
- `docker exec redis redis-cli SLOWLOG GET 10` — slow queries
- `docker exec redis redis-cli CLIENT LIST` — connected clients
