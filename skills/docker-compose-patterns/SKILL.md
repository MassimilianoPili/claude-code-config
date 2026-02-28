---
name: docker-compose-patterns
description: Docker Compose patterns for multi-service orchestration on shared Docker networks. Covers external networking, lazy DNS resolution, volume mounts, environment variable management, service dependencies, and health checks for self-hosted infrastructure.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [docker, docker-compose, containers, networking, infrastructure]
version: 1.0.0
---

# Docker Compose Patterns

Docker Compose patterns for orchestrating isolated service stacks that communicate over a shared Docker network. All examples are from the SOL server (~20 containers on Ubuntu 24.04).

## When to Use

- Creating a new `docker-compose.yml` for a service
- Debugging container networking or DNS resolution issues
- Adding a service to the shared network
- Configuring environment variables, volumes, or port exposure
- Understanding the lifecycle management of independent stacks

## Architecture Pattern: One Stack Per Service

All services use independent `docker-compose.yml` files, one per service directory, all sharing an external Docker network. This allows independent lifecycle management: restart one service without affecting others.

```text
/data/massimiliano/
  postgres/docker-compose.yml    # PostgreSQL 16
  redis/docker-compose.yml       # Redis 7
  keycloak/docker-compose.yml    # Keycloak IdP
  gitea/docker-compose.yml       # Gitea + act_runner
  proxy/docker-compose.yml       # Nginx + OAuth2 Proxy (x2) + Vector + GoAccess
  mongodb/docker-compose.yml     # MongoDB 8 + mongo-express
  ...
```

The shared network is created once:
```bash
docker network create shared
```

Every compose file declares it as external:
```yaml
networks:
  shared:
    external: true
```

## Key Patterns

### 1. External Shared Network

Every compose file ends with the shared network declaration. Every service joins it:

```yaml
services:
  myservice:
    image: some-image:latest
    container_name: myservice
    networks:
      - shared

networks:
  shared:
    external: true
```

Containers reach each other by name via Docker embedded DNS (e.g., `postgres`, `redis`, `keycloak`).

### 2. Network Aliases

When a container needs to be reachable under multiple DNS names (backward compatibility or entrypoint conventions):

```yaml
services:
  mongodb:
    image: mongo:8
    container_name: mongodb
    networks:
      shared:
        aliases:
          - mongo    # mongo-express entrypoint expects "mongo" hostname
```

### 3. Environment Variables from .env

Sensitive values are NEVER hardcoded. Use `${VAR}` interpolation, which reads from `.env` in the same directory:

```yaml
# docker-compose.yml
environment:
  POSTGRES_USER: ${POSTGRES_USER}
  POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

```bash
# .env (same directory, never committed to git)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=secret_value_here
```

Gitea uses the `GITEA__section__KEY` env var convention to override `app.ini` settings:
```yaml
environment:
  - GITEA__database__DB_TYPE=postgres
  - GITEA__database__HOST=postgres:5432
  - GITEA__database__PASSWD=${GITEA_DB_PASSWD}
  - GITEA__cache__HOST=redis://redis:6379/0
  - GITEA__session__PROVIDER_CONFIG=redis://redis:6379/1
```

### 4. Host Network Access

Services that need to reach processes running on the host (not in Docker) use `extra_hosts`:

```yaml
services:
  nginx:
    image: nginx:alpine
    extra_hosts:
      - "host.docker.internal:host-gateway"
```

Used by nginx to proxy to `dashboard-api` (port 7681) and `claude-proxy` (port 8090) running as systemd services on the host.

### 5. Volume Patterns

**Data persistence** (read-write):
```yaml
volumes:
  - ./data:/data/db                   # MongoDB
  - ./data:/var/lib/postgresql/data   # PostgreSQL
  - ./data:/data                      # Redis
  - ./data:/var/lib/artemis-instance  # Artemis
  - ./data:/var/lib/sqld              # libSQL
```

**Config files** (read-only):
```yaml
volumes:
  - ./nginx.conf:/etc/nginx/nginx.conf:ro
  - .:/home/nonroot/.cloudflared:ro              # Cloudflared config + credentials
  - /etc/timezone:/etc/timezone:ro               # Host timezone
  - /etc/localtime:/etc/localtime:ro
```

**Init scripts** (read-only, run once at first startup):
```yaml
volumes:
  - ./init:/docker-entrypoint-initdb.d:ro   # PostgreSQL init SQL scripts
```

**Docker socket** (for Docker management from container):
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro   # Portainer
  - /var/run/docker.sock:/var/run/docker.sock       # act_runner (needs write)
```

**SSH keys and Git config** (for development containers):
```yaml
volumes:
  - /home/massimiliano/.ssh:/home/massimiliano/.ssh:ro
  - /home/massimiliano/.gitconfig:/home/massimiliano/.gitconfig:ro
```

### 6. Port Exposure Patterns

**Internal only** (most services) -- no `ports:` section, accessible only via Docker network:
```yaml
services:
  redis:
    image: redis:7-alpine
    # No ports: -- only reachable via shared network as redis:6379
    networks:
      - shared
```

**Localhost only** -- database accessible from host but not from external network:
```yaml
ports:
  - "127.0.0.1:5432:5432"   # PostgreSQL
  - "127.0.0.1:8181:8080"   # libSQL HTTP API
```

**All interfaces** -- reverse proxy that accepts external traffic:
```yaml
ports:
  - "80:80"       # Tailscale HTTP
  - "8443:8443"   # Tailscale Keycloak
  - "8081:8081"   # Tailscale pgAdmin
  - "8082:8082"   # Tailscale Portainer
  - "8090:8090"   # Tailscale Claude Proxy
  - "8888:8888"   # Public (Cloudflare Tunnel)
```

**Specific protocol** -- SSH exposed on non-standard port:
```yaml
ports:
  - "222:22"   # Gitea SSH
```

**Expose only** (container-to-container, no host mapping):
```yaml
expose:
  - "8080"   # code-server, reachable within shared network only
```

### 7. Restart Policy

All production services use:
```yaml
restart: unless-stopped
```

This survives host reboots (Docker auto-starts containers) but respects manual `docker stop`.

### 8. Container Naming

Always set explicit names for predictable DNS resolution on the shared network:

```yaml
container_name: redis
container_name: postgres
container_name: keycloak
container_name: gitea
container_name: nginx
container_name: cloudflared
```

Without `container_name`, Docker generates names like `redis-redis-1` (project-service-replica).

### 9. Service Dependencies

Use `depends_on` for services within the same compose file:

```yaml
services:
  mongo-express:
    depends_on:
      - mongodb

  act-runner:
    depends_on:
      - gitea
```

For cross-stack dependencies (e.g., Keycloak depends on PostgreSQL), the `sol` orchestrator handles boot order.

### 10. Custom Commands

Override the default entrypoint/command for subpath configuration or special modes:

```yaml
services:
  keycloak:
    command: start-dev                              # Dev mode (no TLS required)

  portainer:
    command: --base-url /portainer                  # Subpath support

  cloudflared:
    command: tunnel run sol                          # Run named tunnel

  code-server-massimiliano:
    command: --auth none --bind-addr 0.0.0.0:8080 /data/massimiliano
```

### 11. Custom User/Permissions

Some containers run as non-root with specific UIDs. Files on the host must match ownership:

```yaml
# Cloudflared runs as UID 65532 (nonroot)
# Create files with matching ownership:
docker run --rm --user 65532:65532 -v /data/massimiliano/cloudflared:/work alpine sh -c 'cat > /work/file.yml'
```

```yaml
# Artemis runs as UID 1001
# Data directory must be owned by 1001:
chown -R 1001:1001 /data/massimiliano/artemis/data/
```

```yaml
# code-server with host PID namespace for process visibility
services:
  code-server-massimiliano:
    pid: host   # htop/ps see host processes
```

## Real Examples from SOL Server

### Minimal Service (Redis)

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

### Service with .env and Aliases (MongoDB)

```yaml
services:
  mongodb:
    image: mongo:8
    container_name: mongodb
    restart: unless-stopped
    environment:
      MONGO_INITDB_ROOT_USERNAME: ${MONGO_ROOT_USER}
      MONGO_INITDB_ROOT_PASSWORD: ${MONGO_ROOT_PASSWORD}
    volumes:
      - ./data:/data/db
    networks:
      shared:
        aliases:
          - mongo

  mongo-express:
    image: mongo-express:1
    container_name: mongo-express
    restart: unless-stopped
    depends_on:
      - mongodb
    environment:
      ME_CONFIG_MONGODB_URL: mongodb://${MONGO_ROOT_USER}:${MONGO_ROOT_PASSWORD}@mongodb:27017/
      ME_CONFIG_SITE_BASEURL: /mongo/
      ME_CONFIG_BASICAUTH: "false"
    networks:
      - shared

networks:
  shared:
    external: true
```

### Database with Localhost Port and Init Scripts (PostgreSQL)

```yaml
services:
  postgres:
    image: postgres:16-alpine
    container_name: postgres
    restart: unless-stopped
    ports:
      - "127.0.0.1:5432:5432"
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

### Identity Provider with Cross-Service Dependencies (Keycloak)

```yaml
services:
  keycloak:
    image: quay.io/keycloak/keycloak:latest
    container_name: keycloak
    command: start-dev
    restart: unless-stopped
    environment:
      KC_DB: postgres
      KC_DB_URL: jdbc:postgresql://postgres:5432/keycloak
      KC_DB_USERNAME: keycloak
      KC_DB_PASSWORD: ${KC_DB_PASSWORD}
      KC_BOOTSTRAP_ADMIN_USERNAME: ${KC_BOOTSTRAP_ADMIN_USERNAME}
      KC_BOOTSTRAP_ADMIN_PASSWORD: ${KC_BOOTSTRAP_ADMIN_PASSWORD}
      KC_PROXY_HEADERS: xforwarded
      KC_HTTP_ENABLED: "true"
      KC_HOSTNAME: https://sol.massimilianopili.com/auth
      KC_HTTP_RELATIVE_PATH: /auth
      KC_HOSTNAME_BACKCHANNEL_DYNAMIC: "true"
    networks:
      - shared

networks:
  shared:
    external: true
```

### Complex Multi-Service Stack (Proxy)

```yaml
services:
  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports:
      - "80:80"
      - "8443:8443"
      - "8081:8081"
      - "8082:8082"
      - "8090:8090"
      - "8888:8888"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./home:/usr/share/nginx/home:ro
      - ./logs:/var/log/nginx
    networks:
      - shared

  oauth2-proxy:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: oauth2-proxy
    restart: unless-stopped
    environment:
      OAUTH2_PROXY_PROVIDER: keycloak-oidc
      OAUTH2_PROXY_OIDC_ISSUER_URL: http://keycloak:8080/auth/realms/sol
      OAUTH2_PROXY_CLIENT_ID: oauth2-proxy
      OAUTH2_PROXY_CLIENT_SECRET: ${OAUTH2_PROXY_CLIENT_SECRET}
      OAUTH2_PROXY_COOKIE_SECRET: ${OAUTH2_PROXY_COOKIE_SECRET}
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4180
      OAUTH2_PROXY_EMAIL_DOMAINS: "*"
      OAUTH2_PROXY_COOKIE_SECURE: "false"
      OAUTH2_PROXY_REDIRECT_URL: http://100.86.46.84:8081/oauth2/callback
      OAUTH2_PROXY_CODE_CHALLENGE_METHOD: S256
      OAUTH2_PROXY_SKIP_PROVIDER_BUTTON: "true"
      OAUTH2_PROXY_INSECURE_OIDC_SKIP_ISSUER_VERIFICATION: "true"
      OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL: "true"
      OAUTH2_PROXY_WHITELIST_DOMAINS: "100.86.46.84:*"
      OAUTH2_PROXY_SET_XAUTHREQUEST: "true"
    networks:
      - shared

  oauth2-proxy-public:
    image: quay.io/oauth2-proxy/oauth2-proxy:latest
    container_name: oauth2-proxy-public
    restart: unless-stopped
    environment:
      OAUTH2_PROXY_PROVIDER: keycloak-oidc
      OAUTH2_PROXY_OIDC_ISSUER_URL: http://keycloak:8080/auth/realms/sol
      OAUTH2_PROXY_CLIENT_ID: oauth2-proxy
      OAUTH2_PROXY_CLIENT_SECRET: ${OAUTH2_PROXY_CLIENT_SECRET}
      OAUTH2_PROXY_COOKIE_SECRET: ${OAUTH2_PROXY_PUBLIC_COOKIE_SECRET}
      OAUTH2_PROXY_HTTP_ADDRESS: 0.0.0.0:4181
      OAUTH2_PROXY_EMAIL_DOMAINS: "*"
      OAUTH2_PROXY_COOKIE_SECURE: "true"
      OAUTH2_PROXY_COOKIE_DOMAINS: ".massimilianopili.com"
      OAUTH2_PROXY_REDIRECT_URL: https://sol.massimilianopili.com/oauth2/callback
      OAUTH2_PROXY_WHITELIST_DOMAINS: ".massimilianopili.com"
      OAUTH2_PROXY_CODE_CHALLENGE_METHOD: S256
      OAUTH2_PROXY_SKIP_PROVIDER_BUTTON: "true"
      OAUTH2_PROXY_INSECURE_OIDC_SKIP_ISSUER_VERIFICATION: "true"
      OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL: "true"
      OAUTH2_PROXY_SET_XAUTHREQUEST: "true"
    networks:
      - shared

networks:
  shared:
    external: true
```

### CI/CD Runner with Docker Socket (Gitea)

```yaml
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    ports:
      - "222:22"
    environment:
      - GITEA__database__DB_TYPE=postgres
      - GITEA__database__HOST=postgres:5432
      - GITEA__database__NAME=gitea
      - GITEA__database__USER=gitea
      - GITEA__database__PASSWD=${GITEA_DB_PASSWD}
      - GITEA__server__ROOT_URL=https://sol.massimilianopili.com/git/
      - GITEA__cache__HOST=redis://redis:6379/0
      - GITEA__session__PROVIDER_CONFIG=redis://redis:6379/1
      - GITEA__queue__CONN_STR=redis://redis:6379/2
    volumes:
      - ./gitea-data:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    networks:
      - shared

  act-runner:
    image: gitea/act_runner:latest
    container_name: act-runner
    restart: unless-stopped
    depends_on:
      - gitea
    environment:
      GITEA_INSTANCE_URL: http://gitea:3000
      GITEA_RUNNER_REGISTRATION_TOKEN: <token>
      GITEA_RUNNER_NAME: sol-runner
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./runner-data:/data
    networks:
      - shared

networks:
  shared:
    external: true
```

### Custom Build with Host Access (code-server)

```yaml
services:
  code-server-massimiliano:
    build: .
    container_name: code-server-massimiliano
    restart: unless-stopped
    command: --auth none --bind-addr 0.0.0.0:8080 /data/massimiliano
    volumes:
      - ./config:/home/massimiliano/.config
      - ./local:/home/massimiliano/.local
      - /data/massimiliano:/data/massimiliano
      - /var/run/docker.sock:/var/run/docker.sock
      - /home/massimiliano/.ssh:/home/massimiliano/.ssh:ro
      - /home/massimiliano/.gitconfig:/home/massimiliano/.gitconfig:ro
    expose:
      - "8080"
    networks:
      - shared
    pid: host

networks:
  shared:
    external: true
```

## Orchestrator: sol Script

The `sol` script (`/data/massimiliano/shell-scripts/bin/sol`) manages all services with proper boot order:

```bash
# Boot order respects dependencies
BOOT_ORDER=(postgres redis keycloak gitea pgadmin portainer filemanager claude-proxy server-api kp-manager cloudflared proxy)

# Commands
sol status                  # Show all container states
sol restart <service>       # Restart service (+ auto-restart nginx if upstream)
sol restart all             # Restart all in dependency order
sol logs <service>          # Last 50 lines
sol logs -f <service>       # Follow logs in real-time
sol logs <service> 100      # Last 100 lines

# Aliases: nginx=proxy, db=postgres, kc=keycloak, cf=cloudflared, files=filemanager, claude=claude-proxy
```

When restarting an upstream service (keycloak, gitea, pgadmin, portainer, filemanager, etc.), `sol` automatically restarts nginx afterwards to invalidate DNS cache.

## Nginx Lazy DNS Resolution

Nginx uses Docker embedded DNS with the `set $var` + `proxy_pass $var` pattern. This prevents nginx from crashing if an upstream container is not running:

```nginx
resolver 127.0.0.11 valid=10s;   # Docker embedded DNS

location /git/ {
    set $gitea_upstream http://gitea:3000;
    rewrite ^/git/(.*) /$1 break;
    proxy_pass $gitea_upstream;
}
```

A stopped container causes 502 only on its route, without impacting other services.

## Best Practices

1. **Always** use `external: true` for the shared network -- never let Compose create project-scoped networks
2. **Never** hardcode secrets -- use `.env` files (excluded from version control)
3. **Always** set `container_name:` for predictable DNS resolution
4. Prefer `-alpine` images when available (smaller footprint, faster pulls)
5. Use `:ro` for config and credential volume mounts
6. Restart nginx with `--force-recreate` after upstream changes (bind mount inode issue)
7. Use `127.0.0.1:PORT:PORT` for services that should only be accessible from the host
8. Use `expose:` (not `ports:`) for containers only accessed via the shared network
9. Keep one compose file per service directory for independent lifecycle management
10. Use the `sol` orchestrator for multi-service operations (respects boot order)

## Common Operations

```bash
# Create shared network (once, after Docker install)
docker network create shared

# Start a single service
cd /data/massimiliano/<service> && docker compose up -d

# Restart with config changes (IMPORTANT: never use nginx -s reload with bind mounts)
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate

# Restart via orchestrator (auto-handles nginx restart for upstreams)
sol restart keycloak

# Check which containers are on the shared network
docker network inspect shared --format '{{range .Containers}}{{.Name}} {{end}}'

# View logs
docker logs <container> --tail 50
docker logs <container> -f

# Rebuild a custom image and restart
cd /data/massimiliano/code-server && docker compose up -d --build --force-recreate
```

## Troubleshooting

- **Container cannot reach another container**: Verify both are on `shared` network with `docker network inspect shared`
- **nginx 502 on a specific route**: Upstream container was restarted and nginx cached the old IP. Wait 10s (DNS TTL) or recreate nginx: `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate`
- **Permission denied on volume**: Check that the container user UID matches the file ownership on the host (e.g., UID 65532 for cloudflared, UID 1001 for artemis)
- **Port conflict**: Use `docker ps --format '{{.Names}} {{.Ports}}'` to find which container holds the port
- **Config changes not picked up by nginx**: Bind mounts use inode tracking. If the editor created a new file (new inode), the container sees the old content. Always use `--force-recreate` instead of `nginx -s reload`
- **Container not starting**: Check `docker compose logs` in the service directory for error messages. Common causes: missing `.env` file, volume path does not exist, port already in use
