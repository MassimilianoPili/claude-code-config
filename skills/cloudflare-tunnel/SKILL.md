---
name: cloudflare-tunnel
description: Cloudflare Tunnel patterns for exposing self-hosted services to the internet via QUIC protocol, Docker nonroot deployment, ingress rules, DNS CNAME configuration, and sysctl UDP buffer tuning.
allowed-tools: Read, Write, Bash, Edit
category: networking
tags: [cloudflare, tunnel, networking, quic, dns, docker]
version: 1.0.0
---

# Cloudflare Tunnel — Skill Reference

## Overview

Cloudflare Tunnel (`cloudflared`) exposes the SOL server to the internet without opening
inbound ports on the firewall. All public traffic flows through Cloudflare's edge network
via the QUIC protocol, terminating HTTPS at Cloudflare before reaching the local nginx
reverse proxy. This eliminates the need for public IP exposure, port forwarding, or
managing TLS certificates on the server itself.

## When to Use

- Setting up or debugging the Cloudflare Tunnel
- Understanding the public traffic path from internet to local services
- Configuring ingress rules for new hostnames or services
- Troubleshooting QUIC connectivity, packet loss, or connection drops
- Adjusting sysctl parameters for UDP buffer tuning
- Managing tunnel credentials and nonroot file permissions
- Adding new public-facing subdomains through the tunnel

## Architecture

```text
Internet
  |
  v
Cloudflare Edge (PoP: fco01 / mxp03 / mxp06)
  |  HTTPS terminated here
  v
QUIC tunnel (4 redundant connections)
  |
  v
cloudflared container (UID 65532, nonroot)
  |  Docker network: shared
  v
nginx:8888 (public server block)
  |  path-based routing
  v
Individual service containers (gitea, keycloak, pgadmin, etc.)
```

### Key Characteristics

- **Zero inbound ports**: No firewall rules needed; cloudflared initiates outbound QUIC
- **HTTPS termination**: Cloudflare handles TLS; traffic between cloudflared and nginx is HTTP
- **Redundancy**: 4 simultaneous QUIC connections to different Cloudflare PoPs
- **Single entry point**: All public traffic funnels through nginx:8888
- **Path-based routing**: nginx handles `/git/`, `/auth/`, `/files/`, etc. internally

## Docker Compose

File: `/data/massimiliano/cloudflared/docker-compose.yml`

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run sol
    volumes:
      - .:/home/nonroot/.cloudflared
    networks:
      - shared

networks:
  shared:
    external: true
```

The volume mount maps the entire `/data/massimiliano/cloudflared/` directory into the
container at `/home/nonroot/.cloudflared`, where cloudflared expects to find `config.yml`
and the credentials JSON file.

## Tunnel Configuration

File: `/data/massimiliano/cloudflared/config.yml`

```yaml
tunnel: 6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec
credentials-file: /home/nonroot/.cloudflared/6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.json

ingress:
  - hostname: sol.massimilianopili.com
    service: http://nginx:8888
  - service: http_status:404
```

### Key Points

| Property | Value |
|----------|-------|
| Tunnel name | `sol` |
| Tunnel ID | `6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec` |
| DNS | CNAME `sol.massimilianopili.com` -> `6e7eafe0-...cfargotunnel.com` |
| Protocol | QUIC with 4 redundant connections to Italian PoPs |
| Ingress target | `http://nginx:8888` (public server block) |
| Fallback rule | `http_status:404` for unmatched hostnames |

The ingress rules are evaluated top-to-bottom. The final `http_status:404` catchall is
**mandatory** -- cloudflared refuses to start without it. All hostname-matched traffic
goes to `nginx:8888`, which then handles path-based routing to individual services.

## Nonroot Container

The cloudflared container runs as UID 65532 (the `nonroot` user from the distroless
base image). This has important implications for file ownership.

### File Permissions

```bash
# Files in /data/massimiliano/cloudflared/ must be owned by UID 65532
# Typical listing:
# -rw------- 65532 65532 cert.pem
# -rw------- 65532 65532 6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.json
# -rw-r--r-- 65532 65532 config.yml
```

### Creating or Modifying Files

Because the host user cannot directly write files owned by UID 65532, use a temporary
container:

```bash
docker run --rm --user 65532:65532 \
  -v /data/massimiliano/cloudflared:/work \
  alpine sh -c 'cat > /work/config.yml << "CFEOF"
tunnel: 6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec
credentials-file: /home/nonroot/.cloudflared/6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.json

ingress:
  - hostname: sol.massimilianopili.com
    service: http://nginx:8888
  - service: http_status:404
CFEOF'
```

This pattern ensures the resulting file has the correct ownership for the nonroot user.

## QUIC Protocol and sysctl Tuning

cloudflared uses the QUIC protocol (UDP-based) for tunnel connections. The Go QUIC
library (`quic-go`) requires adequate kernel UDP receive buffers.

### Required Kernel Parameter

File: `/etc/sysctl.d/50-udp-buffer-quic.conf`

```text
net.core.rmem_max = 7500000
```

### Applying the Setting

```bash
sudo sysctl -p /etc/sysctl.d/50-udp-buffer-quic.conf
```

### Verifying the Setting

```bash
sysctl net.core.rmem_max
# Expected output: net.core.rmem_max = 7500000
```

**Without this tuning**: `quic-go` cannot allocate sufficiently large receive buffers,
causing packet drops under load. Symptoms include intermittent connection failures,
tunnel reconnections, and degraded performance during traffic spikes. This fix was
applied on 2026-02-26 after observing connection instability.

## DNS Configuration

In the Cloudflare DNS dashboard for `massimilianopili.com`:

| Type | Name | Content | Proxy Status |
|------|------|---------|-------------|
| CNAME | sol | `6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.cfargotunnel.com` | Proxied (orange cloud) |

The "Proxied" status is essential -- it enables Cloudflare's edge to terminate HTTPS and
route traffic through the tunnel. A "DNS only" (grey cloud) record would expose the
server's IP directly and bypass the tunnel entirely.

## Adding a New Public Hostname

To expose a new subdomain through the tunnel:

1. **Add DNS CNAME** in Cloudflare dashboard:
   - Type: CNAME
   - Name: `new` (for `new.massimilianopili.com`)
   - Content: `6e7eafe0-7cf0-468e-ba87-31d9bb2be9ec.cfargotunnel.com`
   - Proxy status: Proxied

2. **Add ingress rule** in `config.yml` (before the catchall):
   ```yaml
   ingress:
     - hostname: new.massimilianopili.com
       service: http://nginx:8888
     - hostname: sol.massimilianopili.com
       service: http://nginx:8888
     - service: http_status:404
   ```

3. **Restart cloudflared**:
   ```bash
   cd /data/massimiliano/cloudflared && docker compose up -d --force-recreate
   ```

4. **Add nginx configuration**: Create a server block or location in nginx.conf for
   the new hostname/path, then recreate nginx:
   ```bash
   cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
   ```

## Common Operations

```bash
# Check tunnel status (look for "Registered tunnel connection connIndex=N")
docker logs cloudflared --tail 20

# Follow logs in real time
docker logs cloudflared -f

# Restart the tunnel
cd /data/massimiliano/cloudflared && docker compose up -d --force-recreate

# Check how many QUIC connections are registered
docker logs cloudflared 2>&1 | grep -i "registered"
# Expected: 4 lines (connIndex=0 through connIndex=3)

# Verify the container is on the shared network
docker network inspect shared --format '{{range .Containers}}{{.Name}} {{end}}' | grep cloudflared

# Verify sysctl UDP buffer
sysctl net.core.rmem_max
```

## Best Practices

1. **Always keep the catchall rule**: The last ingress entry must be `service: http_status:404`
   -- cloudflared will not start without it
2. **Single nginx entry point**: Route all tunnel traffic through `nginx:8888` and let
   nginx handle path-based routing; do not point multiple ingress rules at different backends
3. **Nonroot file ownership**: Use `docker run --user 65532:65532` when creating or editing
   files in the cloudflared directory
4. **sysctl before start**: Ensure the UDP buffer sysctl is applied before starting
   cloudflared, especially after a server reboot
5. **Monitor connection count**: Healthy state is 4 registered connections; fewer indicates
   connectivity issues with Cloudflare PoPs
6. **Restart order matters**: After config changes, restart cloudflared first, then verify
   connections before testing from the internet

## Troubleshooting

### Tunnel Not Connecting
- Check credentials file exists and is owned by UID 65532
- Verify `config.yml` references the correct tunnel ID and credentials path
- Ensure the container is on the `shared` Docker network

### Packet Loss Under Load
- Verify `net.core.rmem_max >= 7500000` with `sysctl net.core.rmem_max`
- If not set, apply the sysctl and restart cloudflared
- Check `dmesg` for UDP buffer overflow messages

### DNS Not Resolving
- Verify the CNAME record exists in Cloudflare dashboard
- Ensure proxy status is "Proxied" (orange cloud), not "DNS only"
- Allow up to 5 minutes for DNS propagation

### 502 Bad Gateway from Cloudflare
- nginx:8888 is not running or not reachable from the cloudflared container
- Check `docker logs nginx --tail 20` for errors
- Verify both containers are on the `shared` network

### Connection Drops / Reconnections
- Check if all 4 connections are registered in logs
- Verify QUIC is not being blocked by an upstream firewall or ISP
- Review sysctl UDP buffer settings
- Check server load -- high CPU can cause QUIC timeout

### Container Fails to Start
- Missing or corrupt credentials JSON file
- Wrong file permissions (must be readable by UID 65532)
- Invalid YAML syntax in `config.yml`
- Missing catchall rule in ingress configuration

## Related Files

| File | Purpose |
|------|---------|
| `/data/massimiliano/cloudflared/docker-compose.yml` | Docker Compose stack definition |
| `/data/massimiliano/cloudflared/config.yml` | Tunnel configuration and ingress rules |
| `/data/massimiliano/cloudflared/cert.pem` | Tunnel origin certificate |
| `/data/massimiliano/cloudflared/6e7eafe0-...json` | Tunnel credentials (secret) |
| `/etc/sysctl.d/50-udp-buffer-quic.conf` | Kernel UDP buffer tuning for QUIC |
| `/data/massimiliano/proxy/nginx.conf` | nginx reverse proxy (port 8888 = public block) |
