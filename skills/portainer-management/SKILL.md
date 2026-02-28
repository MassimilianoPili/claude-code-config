---
name: portainer-management
description: Portainer CE patterns for Docker container management UI, OAuth2 Proxy authentication, WebSocket support, subpath deployment with --base-url, stack management, and read-only visitor access in self-hosted environments.
allowed-tools: Read, Write, Bash, Edit
category: infrastructure
tags: [portainer, docker, containers, management, ui, oauth2]
version: 1.0.0
---

# Portainer CE Management

## Overview

Portainer CE serves as the Docker management GUI on SOL server. It provides a web UI for container management, log viewing, stack deployment, and volume/network administration. Access is protected by OAuth2 Proxy with Keycloak SSO, ensuring all users authenticate through the central identity provider before reaching the Portainer interface.

## When to Use

- Managing Docker containers, stacks, volumes, and networks via web UI
- Understanding the Portainer deployment pattern with subpath and OAuth2 Proxy
- Debugging OAuth2 Proxy integration with WebSocket-dependent services
- Setting up read-only visitor access via Portainer native RBAC
- Troubleshooting cross-port OAuth2 redirect flows
- Adding or modifying the nginx reverse proxy configuration for Portainer

## Docker Compose Configuration

File: `/data/massimiliano/portainer/docker-compose.yml`

```yaml
services:
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    command: --base-url /portainer
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./data:/data
    networks:
      - shared

networks:
  shared:
    external: true
```

### Key Configuration Details

- **`--base-url /portainer`**: Portainer handles the subpath internally (Pattern B). Nginx passes the path as-is without rewriting — no `rewrite ... break` needed.
- **Docker socket read-only (`:ro`)**: Portainer reads container info but retains full management capability via the Docker API. The `:ro` flag prevents the container from writing to the socket file itself, but Docker API calls (start, stop, exec) still work.
- **`./data:/data`**: Persistent storage for Portainer settings, user database, stack definitions, and endpoint configuration.
- **No ports exposed**: Portainer is accessed exclusively via nginx reverse proxy. The internal port is 9000.

## Access Points

| Method | URL | Auth |
|--------|-----|------|
| Tailscale | `http://100.86.46.84:8082/portainer/` | OAuth2 Proxy (callback on :8081) |
| Public | `https://sol.massimilianopili.com/portainer/` | OAuth2 Proxy Public |

## Nginx Configuration

Portainer runs on a dedicated Tailscale port (:8082) with OAuth2 Proxy auth_request and WebSocket support.

### Tailscale Server Block (:8082)

```nginx
server {
    listen 8082;

    location /oauth2/ {
        set $oauth2_portainer_upstream http://oauth2-proxy:4180;
        proxy_pass $oauth2_portainer_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location = /oauth2/auth {
        set $oauth2_portainer_upstream http://oauth2-proxy:4180;
        proxy_pass $oauth2_portainer_upstream;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Content-Length "";
        proxy_pass_request_body off;
    }

    location /portainer/ {
        auth_request /oauth2/auth;
        error_page 401 =302 /oauth2/start?rd=http://100.86.46.84:8082$request_uri;

        auth_request_set $user $upstream_http_x_auth_request_user;
        auth_request_set $email $upstream_http_x_auth_request_email;
        auth_request_set $auth_user $upstream_http_x_auth_request_preferred_username;
        proxy_set_header X-Forwarded-User $user;
        proxy_set_header X-Forwarded-Email $email;

        set $portainer_upstream http://portainer:9000;
        proxy_pass $portainer_upstream;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Host $http_host;
        proxy_set_header X-Forwarded-Port 8082;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (container console, real-time updates, log follow)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    location = / {
        return 302 /portainer/;
    }
}
```

### Cross-Port OAuth2 Redirect

The OAuth2 Proxy instance runs on port 4180 and its callback URL is registered on `:8081` (shared with pgAdmin). However, Portainer is served on `:8082`. The `rd=` parameter must use an **absolute URL** to redirect back to the correct port after authentication:

```nginx
error_page 401 =302 /oauth2/start?rd=http://100.86.46.84:8082$request_uri;
```

Without the absolute URL, the redirect would go back to `:8081` after login, which serves pgAdmin instead of Portainer.

### Public Server Block (:8888)

On the public server block, both services share the same hostname so no cross-port redirect is needed:

```nginx
location /portainer/ {
    auth_request /oauth2/auth;
    error_page 401 =302 /oauth2/start?rd=$request_uri;

    auth_request_set $user $upstream_http_x_auth_request_user;
    auth_request_set $email $upstream_http_x_auth_request_email;
    proxy_set_header X-Forwarded-User $user;
    proxy_set_header X-Forwarded-Email $email;

    set $portainer_upstream http://portainer:9000;
    proxy_pass $portainer_upstream;
    proxy_set_header Host $http_host;
    proxy_set_header X-Forwarded-Host $http_host;
    proxy_set_header X-Forwarded-Proto https;

    # WebSocket
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

## WebSocket Requirement

Portainer relies on WebSocket connections for several critical features:

- **Real-time container status**: Dashboard updates without page refresh
- **Container console**: Interactive shell via `docker exec` through the browser
- **Log streaming**: Follow mode for container logs (`docker logs -f`)
- **Stack deployment progress**: Live feedback during stack operations

Without the WebSocket upgrade headers (`Upgrade`, `Connection`) in the nginx configuration, the Portainer UI will load and display static information, but all real-time features will silently fail. The browser console will show WebSocket connection errors.

Required nginx directives for WebSocket passthrough:

```nginx
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

## Visitor (Read-Only) Access

Portainer uses native RBAC (Level 2 in the SOL access control strategy). No custom code is needed.

### Setup Steps

1. The `visitor` user logs in via OAuth2 Proxy (first login creates the user in Portainer)
2. An admin logs into Portainer → Settings → Users
3. Find the `visitor` user (auto-created from OAuth2 proxy headers)
4. Set the role to **Read-only user**

### What Read-Only Restricts

| Action | Allowed |
|--------|---------|
| View containers, stacks, volumes, networks | Yes |
| View container logs | Yes |
| Inspect container details | Yes |
| Start/stop/restart containers | No |
| Deploy/remove stacks | No |
| Execute console into containers | No |
| Create/delete volumes or networks | No |
| Modify Portainer settings | No |

## Portainer Capabilities

### Container Management
- View all running and stopped containers with status, image, and resource usage
- Start, stop, restart, kill, and remove containers
- View container logs with optional follow mode and timestamp filtering
- Execute interactive commands inside containers (console/exec)
- Inspect container details: environment variables, volumes, network bindings, labels

### Stack Management
- Deploy docker-compose stacks directly from the UI (paste YAML or upload file)
- Edit and redeploy existing stacks with updated configuration
- Pull latest images and recreate containers within a stack
- Monitor stack health and individual service status

### Volume and Network Management
- List, inspect, create, and delete Docker volumes
- List, inspect, create, and delete Docker networks
- View which containers are attached to each network

### Image Management
- List local Docker images with size and tag information
- Pull new images from registries
- Remove unused images

## Common Operations

```bash
# Restart Portainer
cd /data/massimiliano/portainer && docker compose up -d --force-recreate

# Check Portainer logs
docker logs portainer --tail 30

# Verify Portainer is on the shared network
docker network inspect shared --format '{{range .Containers}}{{.Name}} {{end}}' | tr ' ' '\n' | grep portainer

# Access Portainer (Tailscale)
# Browser: http://100.86.46.84:8082/portainer/

# Access Portainer (Public)
# Browser: https://sol.massimilianopili.com/portainer/

# Reset Portainer data (emergency — loses all settings and user config)
cd /data/massimiliano/portainer
docker compose down
rm -rf data/
docker compose up -d
# After reset: first user to access becomes admin, visitor role must be re-assigned
```

## Subpath Pattern (Pattern B)

Portainer is one of the services that handle the subpath internally. This is **Pattern B** in the SOL nginx architecture:

- **Pattern A** (prefix stripping): nginx removes `/prefix/` before forwarding (used by Gitea, File Manager, Claude Proxy, Dashboard API)
- **Pattern B** (no stripping): nginx passes the full path, the service handles it (used by Portainer, pgAdmin, mongo-express)

Portainer achieves this with the `--base-url /portainer` flag. All internal routes, static assets, and API calls are served under `/portainer/`. No `rewrite` directive is needed in nginx.

## Best Practices

1. Always use `--base-url /portainer` for subpath deployment — never try to strip the prefix in nginx
2. Mount Docker socket as read-only (`:ro`) — management still works via the Docker API
3. Include WebSocket headers in every nginx location block that serves Portainer
4. Set visitor users to "Read-only user" in Portainer RBAC after their first login
5. Use absolute URL in `rd=` parameter for cross-port OAuth2 redirects on Tailscale
6. Use `$http_host` (not `$host`) in proxy headers to preserve the port number
7. Never expose Portainer directly — always protect with OAuth2 Proxy
8. Restart Portainer with `docker compose up -d --force-recreate` (not `docker restart`)

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Real-time updates not working | Missing WebSocket headers in nginx | Add `proxy_http_version 1.1`, `Upgrade`, `Connection "upgrade"` |
| OAuth2 redirect loop | `rd=` parameter uses wrong port | Use absolute URL: `rd=http://100.86.46.84:8082$request_uri` |
| Container console not opening | WebSocket upgrade blocked by nginx | Verify WebSocket headers present in both Tailscale and public blocks |
| Portainer shows empty environment | Docker socket not mounted | Check `volumes` includes `/var/run/docker.sock:/var/run/docker.sock:ro` |
| User not visible in Portainer | User never logged in via OAuth2 | User must authenticate at least once through OAuth2 Proxy |
| 502 Bad Gateway | Container not on shared network or stopped | Run `docker network inspect shared`, restart with `--force-recreate` |
| Static assets 404 | Missing `--base-url` flag | Ensure `command: --base-url /portainer` is set in docker-compose.yml |
| Login redirects to pgAdmin | Relative `rd=` on port 8082 | Switch to absolute URL in `error_page` directive |
