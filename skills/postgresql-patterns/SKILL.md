---
name: postgresql-patterns
description: PostgreSQL administration patterns for shared multi-database instances, init scripts, user management, pgAdmin access, emergency queries, and backup/restore operations in Docker Compose self-hosted environments.
allowed-tools: Read, Write, Bash, Edit
category: database
tags: [postgresql, database, sql, pgadmin, docker, backup]
version: 1.0.0
---

# PostgreSQL Patterns — SOL Server

## Overview

PostgreSQL 16 Alpine serves as the shared relational database for multiple applications on
the SOL server. Two databases (`gitea` and `keycloak`) run on a single instance with
dedicated users. The instance is exposed only on localhost (`127.0.0.1:5432`) to prevent
external access. Administration happens via pgAdmin (protected by OAuth2 Proxy + Keycloak)
or via `docker exec` commands. All containers connect through the `shared` Docker network
using the hostname `postgres`.

## When to Use

- Creating a new database for a service joining the SOL stack
- Debugging database connection issues between containers and PostgreSQL
- Running emergency admin queries (promote users, fix redirect URIs, inspect state)
- Setting up init scripts for automatic database provisioning on first start
- Configuring pgAdmin access for web-based administration
- Performing manual or automated backup and restore operations
- Monitoring connections, long-running queries, and database sizes

## Docker Compose Configuration

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    ports:
      - "127.0.0.1:5432:5432"    # localhost ONLY — no external access
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - ./data:/var/lib/postgresql/data
      - ./init:/docker-entrypoint-initdb.d:ro
    networks:
      - shared

networks:
  shared:
    external: true
```

### Key Design Decisions

- **`127.0.0.1:5432:5432`** — binds to localhost only (not `0.0.0.0`), preventing external
  access. Containers reach PostgreSQL via Docker DNS (`postgres:5432`), not the host port.
- **`./init:/docker-entrypoint-initdb.d:ro`** — SQL scripts run automatically and
  alphabetically on FIRST container start only (empty data directory). They do NOT re-run.
- **Alpine variant** — smaller image footprint (~80 MB vs ~400 MB for the full image).
- **`shared` network** — external Docker network shared by all SOL stacks.

## Multi-Database Init Pattern

Files in `./init/` are executed alphabetically on the very first container start (empty
data directory). Each file creates a dedicated user and database for a service.

`01-gitea.sql`:
```sql
CREATE USER gitea WITH PASSWORD '<password>';
CREATE DATABASE gitea OWNER gitea;
```

To add a new database, create a numbered file (e.g., `03-newservice.sql`):
```sql
CREATE USER newservice WITH PASSWORD '<secure-password>';
CREATE DATABASE newservice OWNER newservice;
```

**IMPORTANT**: Init scripts only run when the data directory is empty. For existing
instances, run manually:
```bash
docker exec postgres psql -U ${POSTGRES_USER} -c \
  "CREATE USER newservice WITH PASSWORD '<secure-password>';"
docker exec postgres psql -U ${POSTGRES_USER} -c \
  "CREATE DATABASE newservice OWNER newservice;"
```

Then add the init script so provisioning is reproducible if the data directory is recreated.

## Databases on SOL Server

| Database   | Owner      | Used By   | Purpose                                    |
|------------|------------|-----------|---------------------------------------------|
| `gitea`    | `gitea`    | Gitea     | Users, repos, issues, PRs, SSH keys, actions |
| `keycloak` | `keycloak` | Keycloak  | Realms, users, clients, sessions, roles      |
| `postgres` | superuser  | (default) | System database — do not use for applications |

Each application connects with its own user. The `gitea` user cannot access `keycloak`
tables, and vice versa.

## Connection Patterns

### From Docker containers (via shared network)

```text
jdbc:postgresql://postgres:5432/keycloak     # Java/Keycloak
host=postgres port=5432 dbname=gitea         # Gitea
postgresql://<user>:<password>@postgres:5432/<database>   # Generic
```

### From host (localhost only)

```bash
docker exec postgres psql -U gitea -d gitea          # preferred
psql -h 127.0.0.1 -U gitea -d gitea                  # if psql installed on host
docker exec -it postgres psql -U ${POSTGRES_USER}     # interactive superuser session
docker exec postgres psql -U gitea -d gitea -c "SELECT count(*) FROM repository;"
```

## Emergency Admin Queries

These queries modify application state directly. Use with caution and restart the affected
application afterward if it caches state.

### Gitea: Promote user to admin
```bash
docker exec postgres psql -U gitea -d gitea -c \
  "UPDATE public.\"user\" SET is_admin = true WHERE lower_name = '<username>';"
```
Note: `public."user"` requires quoting because `user` is a reserved SQL keyword.
The preferred method is Keycloak group `gitea_admin` + SSO re-login.

### Gitea: Check admin status
```bash
docker exec postgres psql -U gitea -d gitea -c \
  "SELECT id, lower_name, is_admin FROM public.\"user\";"
```

### Keycloak: Add redirect URI to a client
```bash
docker exec postgres psql -U keycloak -d keycloak -c "
INSERT INTO redirect_uris (client_id, value)
SELECT c.id, '<new-uri>'
FROM client c
WHERE c.client_id = '<client-name>'
  AND c.realm_id = (SELECT id FROM realm WHERE name = 'sol');"
docker restart keycloak  # MANDATORY after direct DB modifications
```

### Keycloak: List clients in the sol realm
```bash
docker exec postgres psql -U keycloak -d keycloak -c "
SELECT c.client_id, c.enabled, c.protocol
FROM client c JOIN realm r ON c.realm_id = r.id
WHERE r.name = 'sol' ORDER BY c.client_id;"
```

### Keycloak: List redirect URIs for a client
```bash
docker exec postgres psql -U keycloak -d keycloak -c "
SELECT c.client_id, ru.value AS redirect_uri
FROM redirect_uris ru
JOIN client c ON ru.client_id = c.id
JOIN realm r ON c.realm_id = r.id
WHERE r.name = 'sol' AND c.client_id = '<client-name>';"
```

### Check database sizes
```bash
docker exec postgres psql -U ${POSTGRES_USER} -c "
SELECT datname, pg_size_pretty(pg_database_size(datname))
FROM pg_database WHERE datistemplate = false
ORDER BY pg_database_size(datname) DESC;"
```

## pgAdmin Access

pgAdmin provides web-based GUI administration, protected by OAuth2 Proxy + Keycloak:
- **Tailscale**: `http://100.86.46.84:8081/pgadmin/`
- **Public**: `https://sol.massimilianopili.com/pgadmin/`

pgAdmin uses `SCRIPT_NAME=/pgadmin` for WSGI subpath awareness (Pattern B — nginx passes
path as-is).

### Server registration in pgAdmin

| Field    | Value                  |
|----------|------------------------|
| Host     | `postgres`             |
| Port     | `5432`                 |
| Username | from `.env`            |
| Password | from `.env`            |

Use `postgres` as hostname (Docker DNS), NOT `localhost` — pgAdmin runs inside Docker.

## Backup and Restore

### Manual dump
```bash
# Single database (plain SQL)
docker exec postgres pg_dump -U gitea gitea > /data/massimiliano/gitea_backup.sql

# Compressed dump (custom format, supports parallel restore)
docker exec postgres pg_dump -U gitea -Fc gitea > /data/massimiliano/gitea_backup.dump

# All databases
docker exec postgres pg_dumpall -U ${POSTGRES_USER} > /data/massimiliano/all_databases.sql
```

### Restore
```bash
cat gitea_backup.sql | docker exec -i postgres psql -U gitea -d gitea
cat gitea_backup.dump | docker exec -i postgres pg_restore -U gitea -d gitea
cat all_databases.sql | docker exec -i postgres psql -U ${POSTGRES_USER}
```

### Automated backup
The restic nightly backup (cron at 3:00 AM, `/usr/local/bin/backup-sol.sh`) includes the
PostgreSQL data directory. The script runs `pg_dump` as a pre-hook for consistency.

## Performance and Monitoring

### Active connections per database
```bash
docker exec postgres psql -U ${POSTGRES_USER} -c "
SELECT datname, state, count(*) FROM pg_stat_activity
GROUP BY datname, state ORDER BY datname, state;"
```

### Long-running queries
```bash
docker exec postgres psql -U ${POSTGRES_USER} -c "
SELECT pid, now() - query_start AS duration, state, query
FROM pg_stat_activity
WHERE state != 'idle' AND query_start IS NOT NULL
ORDER BY duration DESC LIMIT 10;"
```

### Terminate a stuck query
```bash
docker exec postgres psql -U ${POSTGRES_USER} -c "SELECT pg_cancel_backend(<pid>);"
docker exec postgres psql -U ${POSTGRES_USER} -c "SELECT pg_terminate_backend(<pid>);"
```

### Container resource usage
```bash
docker stats postgres --no-stream
```

## Best Practices

1. **Always bind to `127.0.0.1`** — never expose PostgreSQL externally.
2. **Use init scripts for reproducible provisioning** — add them even when creating
   databases manually, for disaster recovery.
3. **One user per database** — never share the superuser across applications.
4. **Prefer `docker exec postgres psql`** over direct host connection.
5. **Always restart Keycloak after direct DB modifications** — it caches aggressively.
6. **Use `.env` files for credentials** — never hardcode passwords in compose files.
7. **Quote reserved words** — Gitea uses `public."user"` as a table name.
8. **Test init scripts independently** — run through `psql` before placing in init dir.

## Troubleshooting

### Connection refused from container
Verify postgres is on the `shared` network:
```bash
docker network inspect shared --format '{{range .Containers}}{{.Name}} {{end}}' | grep postgres
```

### Init script did not run
Scripts only execute on first start (empty data dir). Run manually for existing instances:
```bash
docker logs postgres 2>&1 | grep "initdb"
```

### Permission denied on table
Ensure the correct database user. The `gitea` user cannot access `keycloak` tables:
```bash
docker exec postgres psql -U keycloak -d keycloak -c "SELECT ..."
```

### Keycloak changes not visible after DB modification
Keycloak caches aggressively. Always restart after direct modifications:
```bash
docker restart keycloak
```

### pgAdmin cannot connect
Verify server host is `postgres` (Docker DNS), not `localhost`. Both containers must be
on the `shared` network.

### Data directory permissions
PostgreSQL Alpine uses UID 70. If permission errors occur on startup:
```bash
ls -ln /data/massimiliano/postgres/data/ | head -5
sudo chown -R 70:70 /data/massimiliano/postgres/data/
```

### High connection count
```bash
docker exec postgres psql -U ${POSTGRES_USER} -c "SHOW max_connections;"
docker exec postgres psql -U ${POSTGRES_USER} -c "
SELECT count(*) AS total, datname FROM pg_stat_activity GROUP BY datname;"
```
