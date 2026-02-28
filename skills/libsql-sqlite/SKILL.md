---
name: libsql-sqlite
description: libSQL (Turso/sqld) server patterns for SQLite-compatible HTTP API, hrana protocol, Docker deployment, web console access, and client integration for lightweight embedded database use cases.
allowed-tools: Read, Write, Bash, Edit
category: database
tags: [libsql, sqlite, turso, sqld, database, http-api, hrana]
version: 1.0.0
---

# libSQL / SQLite Patterns — SOL Server

## Overview

libSQL server (sqld) on SOL server — SQLite-compatible database with HTTP API (hrana protocol). Lightweight alternative to PostgreSQL/MongoDB for small datasets. Web console for browsing via OAuth2 Proxy.

## When to Use

- Deploying a lightweight database for a small service
- Using SQLite syntax over HTTP API
- Accessing the libSQL web console
- Integrating libSQL with application code

## Docker Compose Configuration

```yaml
services:
  libsql-server:
    image: ghcr.io/tursodatabase/libsql-server:latest
    container_name: libsql-server
    restart: unless-stopped
    environment:
      SQLD_NODE: primary
      SQLD_DB_PATH: /var/lib/sqld
    volumes:
      - ./data:/var/lib/sqld
    ports:
      - "127.0.0.1:8181:8080"
    networks:
      - shared

networks:
  shared:
    external: true
```

### Key Configuration

- `SQLD_NODE: primary` — runs as primary node (not replica)
- `SQLD_DB_PATH: /var/lib/sqld` — SQLite database files stored here
- `127.0.0.1:8181:8080` — HTTP API exposed on localhost only
- Port 5001: hrana WebSocket protocol (internal Docker network only)

## Access Points

| Method | URL | Auth |
|--------|-----|------|
| Web Console (Tailscale) | `http://100.86.46.84/libsql/` | OAuth2 Proxy |
| HTTP API (localhost) | `http://127.0.0.1:8181` | None |
| HTTP API (Docker) | `http://libsql-server:8080` | None |
| hrana Protocol (Docker) | `libsql://libsql-server:5001` | None |

**NOT exposed publicly** — Tailscale + localhost only.

## nginx Configuration

libSQL uses Pattern A (prefix stripping with `rewrite ... break`):

```nginx
# Tailscale server block (:80)
location /libsql/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    auth_request_set $user $upstream_http_x_auth_request_user;
    auth_request_set $email $upstream_http_x_auth_request_email;
    proxy_set_header X-Forwarded-User $user;
    proxy_set_header X-Forwarded-Email $email;

    set $libsql_upstream http://libsql-server:8080;
    rewrite ^/libsql/(.*) /$1 break;
    proxy_pass $libsql_upstream;
}
```

The `set $var` + `proxy_pass $var` pattern enables lazy DNS resolution via Docker embedded DNS (`resolver 127.0.0.11 valid=10s`). This prevents nginx from crashing if the libsql-server container is not running — it returns 502 only on the `/libsql/` route without affecting other services.

OAuth2 Proxy protects the web console. The `auth_request` directive delegates authentication to the shared OAuth2 Proxy instance (Keycloak OIDC).

## HTTP API Usage (hrana v2 pipeline)

### Health check

```bash
curl -s http://127.0.0.1:8181/health
```

### Execute a simple query

```bash
curl -s http://127.0.0.1:8181/v2/pipeline \
  -H 'Content-Type: application/json' \
  -d '{
    "requests": [
      { "type": "execute", "stmt": { "sql": "SELECT 1 + 1 AS result" } },
      { "type": "close" }
    ]
  }'
```

### Create table, insert, and query

```bash
# Create table
curl -s http://127.0.0.1:8181/v2/pipeline -H 'Content-Type: application/json' -d '{
  "requests": [
    { "type": "execute", "stmt": { "sql": "CREATE TABLE IF NOT EXISTS notes (id INTEGER PRIMARY KEY, content TEXT, created_at DATETIME DEFAULT CURRENT_TIMESTAMP)" } },
    { "type": "close" }
  ]
}'

# Insert with parameterized query
curl -s http://127.0.0.1:8181/v2/pipeline -H 'Content-Type: application/json' -d '{
  "requests": [
    { "type": "execute", "stmt": { "sql": "INSERT INTO notes (content) VALUES (?)", "args": [{ "type": "text", "value": "Hello from libSQL" }] } },
    { "type": "close" }
  ]
}'

# Query data
curl -s http://127.0.0.1:8181/v2/pipeline -H 'Content-Type: application/json' -d '{
  "requests": [
    { "type": "execute", "stmt": { "sql": "SELECT * FROM notes ORDER BY created_at DESC LIMIT 10" } },
    { "type": "close" }
  ]
}'
```

### Pipeline with multiple statements

The v2 pipeline API allows batching multiple statements in a single request. Each request in the array is executed sequentially within the same connection:

```bash
curl -s http://127.0.0.1:8181/v2/pipeline \
  -H 'Content-Type: application/json' \
  -d '{
    "requests": [
      { "type": "execute", "stmt": { "sql": "BEGIN" } },
      { "type": "execute", "stmt": { "sql": "INSERT INTO notes (content) VALUES (?)", "args": [{ "type": "text", "value": "First" }] } },
      { "type": "execute", "stmt": { "sql": "INSERT INTO notes (content) VALUES (?)", "args": [{ "type": "text", "value": "Second" }] } },
      { "type": "execute", "stmt": { "sql": "COMMIT" } },
      { "type": "close" }
    ]
  }'
```

### Parameter types

The `args` array supports typed values:

| Type | Example |
|------|---------|
| `text` | `{ "type": "text", "value": "hello" }` |
| `integer` | `{ "type": "integer", "value": "42" }` |
| `float` | `{ "type": "float", "value": 3.14 }` |
| `blob` | `{ "type": "blob", "base64": "AQID" }` |
| `null` | `{ "type": "null" }` |

## Client Integration

### JavaScript/TypeScript (@libsql/client)

```javascript
import { createClient } from '@libsql/client';

const client = createClient({
  url: 'http://libsql-server:8080',  // from Docker network
  // or url: 'http://127.0.0.1:8181', // from host
});

// Simple query
const result = await client.execute('SELECT * FROM notes');
console.log(result.rows);

// Parameterized insert
await client.execute({
  sql: 'INSERT INTO notes (content) VALUES (?)',
  args: ['New note'],
});

// Transaction
const tx = await client.transaction();
await tx.execute({ sql: 'INSERT INTO notes (content) VALUES (?)', args: ['tx note 1'] });
await tx.execute({ sql: 'INSERT INTO notes (content) VALUES (?)', args: ['tx note 2'] });
await tx.commit();
```

### Python (libsql-experimental)

```python
import libsql_experimental as libsql

conn = libsql.connect("http://127.0.0.1:8181")
conn.execute("CREATE TABLE IF NOT EXISTS items (id INTEGER PRIMARY KEY, name TEXT)")
conn.execute("INSERT INTO items (name) VALUES (?)", ["test"])
result = conn.execute("SELECT * FROM items").fetchall()
conn.close()
```

### Java (JDBC-compatible)

```java
// Using the libsql JDBC driver
String url = "jdbc:libsql://libsql-server:8080";
Connection conn = DriverManager.getConnection(url);
PreparedStatement ps = conn.prepareStatement("SELECT * FROM notes WHERE id = ?");
ps.setInt(1, 1);
ResultSet rs = ps.executeQuery();
```

### Go (go-libsql)

```go
import "github.com/tursodatabase/go-libsql"

db, err := sql.Open("libsql", "http://libsql-server:8080")
if err != nil {
    log.Fatal(err)
}
defer db.Close()

rows, err := db.Query("SELECT id, content FROM notes")
```

## SQLite Compatibility

libSQL is a fork of SQLite with extensions:
- Full SQLite SQL syntax (DDL, DML, views, triggers, CTEs)
- WAL mode by default for concurrent reads
- ALTER TABLE, JSON functions (`json()`, `json_extract()`), FTS5 full-text search
- HTTP API (hrana protocol) layered on top of the SQLite engine

Key differences from raw SQLite:
- Server-based (not embedded file-based) — accessed via HTTP or hrana protocol
- Supports concurrent connections from multiple clients
- Has replication support (primary/replica topology via `SQLD_NODE`)
- No filesystem lock contention — the server manages all access

## Common Operations

```bash
# Check server health
curl -s http://127.0.0.1:8181/health

# View container logs
docker logs libsql-server --tail 30

# Follow logs in real time
docker logs libsql-server -f

# Restart the service
cd /data/massimiliano/libsql && docker compose up -d --force-recreate

# Check database size on disk
du -sh /data/massimiliano/libsql/data/

# List database files
ls -la /data/massimiliano/libsql/data/

# Verify container is on the shared network
docker network inspect shared --format '{{range .Containers}}{{.Name}} {{end}}' | grep libsql

# Backup (WAL mode ensures consistency during copy)
cp -r /data/massimiliano/libsql/data/ /tmp/libsql-backup-$(date +%Y%m%d)/
```

## Best Practices

1. Use libSQL for lightweight datasets that don't need PostgreSQL's features (JSONB, advanced indexing, full ACID with concurrent writes)
2. Expose HTTP API only on localhost (`127.0.0.1`) — never bind to `0.0.0.0`
3. Protect the web console with OAuth2 Proxy (Keycloak SSO)
4. Always use parameterized queries (`args` array) to prevent SQL injection
5. Backup by copying the data directory — WAL mode ensures read consistency during copy
6. Use the hrana protocol (`libsql://`) for WebSocket-based connections from Docker containers
7. For transactions, use the pipeline API with explicit `BEGIN`/`COMMIT` or the client library's transaction API
8. Keep the `close` request at the end of every pipeline to release the connection

## Troubleshooting

- **Connection refused from Docker container**: Use `http://libsql-server:8080` (not `localhost` or `127.0.0.1`)
- **Connection refused from host**: Verify port mapping is `127.0.0.1:8181:8080` and container is running
- **Web console blank or 502**: Check that the container is on the `shared` network and OAuth2 Proxy `/oauth2/` location exists on the same nginx server block
- **Data not persisting after restart**: Verify the volume mount `./data:/var/lib/sqld` is correct in docker-compose.yml
- **nginx 502 on /libsql/**: Container is likely stopped or was recreated (DNS cache). Wait 10s for DNS TTL or force-recreate nginx
- **Concurrent write errors**: libSQL handles concurrency better than raw SQLite via server-level locking, but sustained heavy write loads may benefit from PostgreSQL instead
- **Large database file**: SQLite WAL can grow large under write pressure. A checkpoint happens automatically, but you can trigger one via `PRAGMA wal_checkpoint(TRUNCATE)`
