---
name: tailscale-networking
description: Tailscale VPN mesh networking patterns for secure internal access, MagicDNS, SSHFS remote mounts, subnet routing, and dual-network architecture with Cloudflare Tunnel for self-hosted infrastructure.
allowed-tools: Read, Write, Bash, Edit
category: networking
tags: [tailscale, vpn, networking, sshfs, wireguard, remote-access]
version: 1.0.0
---

# Tailscale Networking

## Overview

Tailscale provides secure internal access to the SOL server via WireGuard mesh VPN. The server is accessible at `100.86.46.84` on the Tailscale network. All internal services (that don't need public access) are accessed via Tailscale. Public access goes through Cloudflare Tunnel.

## When to Use

- Setting up Tailscale access to SOL services
- Configuring SSHFS remote mounts over Tailscale
- Understanding the dual-network architecture (Tailscale internal + Cloudflare public)
- Debugging connectivity issues between Tailscale peers
- Deciding which services should be internal-only vs publicly exposed

## Dual-Network Architecture

The SOL server uses two independent ingress paths. Both terminate at the same nginx reverse proxy but hit different server blocks with distinct auth and port configurations.

```text
Internal access (Tailscale):
  Client --> Tailscale VPN (WireGuard) --> 100.86.46.84 --> nginx :80/:8443/:8081/:8082/:8090 --> services

Public access (Cloudflare):
  Browser --> Cloudflare Edge (PoP) --> QUIC tunnel --> nginx :8888 --> services
```

Key differences between the two paths:

| Aspect | Tailscale (internal) | Cloudflare (public) |
|--------|---------------------|---------------------|
| Protocol | WireGuard (encrypted) | QUIC + TLS (Cloudflare terminates HTTPS) |
| Nginx ports | :80, :8443, :8081, :8082, :8090 | :8888 (single server block) |
| Auth cookie | HTTP, domain `100.86.46.84` | HTTPS secure, domain `.massimilianopili.com` |
| OAuth2 Proxy | Instance on port 4180 | Instance on port 4181 |
| Restricted services | All available | libSQL console, Artemis console NOT exposed |

## SOL Server on Tailscale

- **Tailscale IP**: `100.86.46.84`
- **MagicDNS hostname**: `sol`
- **Exposed ports**: 80, 222 (Gitea SSH), 8443, 8081, 8082, 8090
- **OS**: Ubuntu 24.04
- **RAM**: 7.6 GB

All Docker containers run on the `shared` network and are reached through nginx path-based routing.

## Internal vs Public Services

| Service | Tailscale URL | Public URL | Notes |
|---------|--------------|------------|-------|
| Dashboard | `http://100.86.46.84/` | `https://sol.massimilianopili.com/` | Static HTML, no auth |
| Gitea | `http://100.86.46.84/git/` | `https://sol.massimilianopili.com/git/` | Keycloak SSO |
| Keycloak Admin | `http://100.86.46.84:8443/auth/admin/` | `https://sol.massimilianopili.com/auth/admin/` | Own login |
| pgAdmin | `http://100.86.46.84:8081/pgadmin/` | `https://sol.massimilianopili.com/pgadmin/` | OAuth2 Proxy |
| Portainer | `http://100.86.46.84:8082/portainer/` | `https://sol.massimilianopili.com/portainer/` | OAuth2 Proxy |
| File Manager | `http://100.86.46.84/files/` | `https://sol.massimilianopili.com/files/` | OIDC native |
| Claude Proxy | `http://100.86.46.84/claude/` | `https://sol.massimilianopili.com/claude/` | JWT Bearer |
| Server API | `http://100.86.46.84/server/` | `https://sol.massimilianopili.com/server/` | JWT Bearer |
| Dashboard API | `http://100.86.46.84/api/` | `https://sol.massimilianopili.com/api/` | JWT Bearer |
| code-server | `http://100.86.46.84/ide/` | `https://sol.massimilianopili.com/ide/` | OAuth2 Proxy |
| mongo-express | `http://100.86.46.84/mongo/` | `https://sol.massimilianopili.com/mongo/` | OAuth2 Proxy |
| libSQL Console | `http://100.86.46.84/libsql/` | **Not exposed publicly** | Tailscale only |
| Artemis Console | `http://100.86.46.84/mq/` | **Not exposed publicly** | Tailscale only |

Direct access ports (bypassing nginx path routing):
- `http://100.86.46.84:8090/` -- Claude Proxy API direct
- `http://100.86.46.84:9090/` -- File Manager direct

## SSHFS Remote Mount

Mount the SOL server's Claude shared storage on local machines over Tailscale.

### Linux

```bash
# Create mount point
mkdir -p ~/claude-shared

# Mount via SSHFS over Tailscale
sshfs massimiliano@100.86.46.84:/data/massimiliano/claude-shared ~/claude-shared \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3

# Create symlinks for Claude Code shared storage
ln -sf ~/claude-shared/projects ~/.claude/projects
ln -sf ~/claude-shared/plans ~/.claude/plans
ln -sf ~/claude-shared/history.jsonl ~/.claude/history.jsonl
ln -sf ~/claude-shared/skills ~/.claude/skills
ln -sf ~/claude-shared/agents ~/.claude/agents
```

### macOS

```bash
# Install macFUSE + sshfs first (brew install macfuse sshfs)
mkdir -p ~/claude-shared
sshfs massimiliano@100.86.46.84:/data/massimiliano/claude-shared ~/claude-shared \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,volname=claude-shared
```

### Windows (WinFsp + SSHFS-Win)

```bash
# Map network drive Z: in Explorer or via command line
net use Z: \\sshfs\massimiliano@100.86.46.84\data\massimiliano\claude-shared

# Create junctions for Claude Code
cmd /c mklink /J "%USERPROFILE%\.claude\projects" "Z:\projects"
cmd /c mklink /J "%USERPROFILE%\.claude\plans" "Z:\plans"
cmd /c mklink /J "%USERPROFILE%\.claude\skills" "Z:\skills"
cmd /c mklink /J "%USERPROFILE%\.claude\agents" "Z:\agents"
copy Z:\history.jsonl "%USERPROFILE%\.claude\history.jsonl"
```

### Important SSHFS Notes

- Always use the `reconnect` option for resilience against network interruptions
- `ServerAliveInterval=15` with `ServerAliveCountMax=3` detects disconnects within 45 seconds
- Do NOT open two Claude Code sessions on different machines writing to the same `.jsonl` UUID file simultaneously -- risk of data interleaving and corruption
- Shared storage location on server: `/data/massimiliano/claude-shared/`
- Included in nightly restic backup (no exclusion rules)

## SSH Configuration

### Server-side SSH config (`~/.ssh/config` on SOL)

```text
Host gitea-local
    HostName 100.86.46.84
    Port 222
    User git
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

Host github.com
    HostName github.com
    User git
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
```

### Client-side SSH config (local machine)

```text
Host sol
    HostName 100.86.46.84
    User massimiliano
    ForwardAgent yes
```

Agent forwarding (`ForwardAgent yes`) lets you use your local SSH keys on the remote server without copying them. This is preferred over storing keys on the server.

### SSH Agent on SOL

The server uses `gpg-agent` with SSH emulation for passphrase caching:
- Cache TTL: 8 hours (28800 seconds)
- Pinentry: `pinentry-curses` (headless server)
- Socket: `/run/user/1000/gnupg/S.gpg-agent.ssh`
- `SSH_AUTH_SOCK` is set in `.bashrc` before the interactive guard (for non-interactive shells like Claude Code)

At first `git push` after reboot (or after 8h), the passphrase is requested once, then cached.

## Tailscale SSH

Tailscale can provide SSH access without traditional SSH key management:

```bash
# Direct SSH via Tailscale IP
ssh massimiliano@100.86.46.84

# Using MagicDNS (if enabled in Tailscale admin)
ssh massimiliano@sol
```

## Common Operations

```bash
# --- Tailscale diagnostics ---

# Check Tailscale daemon status and peer list
tailscale status

# Get this machine's Tailscale IPv4
tailscale ip -4

# Ping another Tailscale device (measures latency)
tailscale ping sol
tailscale ping <device-name>

# Check MagicDNS resolution
nslookup sol

# --- SSHFS operations ---

# Mount remote directory
sshfs massimiliano@100.86.46.84:/data/massimiliano ~/sol-data -o reconnect

# Unmount
fusermount -u ~/sol-data    # Linux
umount ~/sol-data           # macOS

# Check if mount is active
mount | grep sshfs

# --- SSH key management on SOL ---

# Load SSH key into gpg-agent (asks passphrase once)
ssh-ensure

# Silent check (for scripts, exit 0 = key loaded)
ssh-ensure --quiet

# List loaded keys
ssh-add -l

# Reload gpg-agent after config changes
gpg-connect-agent reloadagent /bye
```

## Nginx Server Blocks by Port

Understanding which nginx server block handles each port is essential for debugging:

| Port | Purpose | Key locations |
|------|---------|--------------|
| :80 | Tailscale: all services | `= /` (dashboard), `/git/`, `/files/`, `/claude/`, `/server/`, `/api/`, `/mongo/`, `/libsql/`, `/ide/`, `/mq/` |
| :8443 | Tailscale: Keycloak admin | `/auth/` |
| :8081 | Tailscale: pgAdmin + OAuth2 | `/pgadmin/`, `/oauth2/` |
| :8082 | Tailscale: Portainer + OAuth2 | `/portainer/`, `/oauth2/` |
| :8090 | Tailscale: Claude Proxy + Keycloak PKCE | `/v1/`, `/health`, `/auth/realms/` |
| :8888 | Public (Cloudflare Tunnel) | All paths unified |

## OAuth2 Proxy Instances

Two separate OAuth2 Proxy instances handle authentication for each network:

**Tailscale instance** (port 4180):
- Callback: `http://100.86.46.84:8081/oauth2/callback`
- Cookie: HTTP (non-secure), domain `100.86.46.84`
- Protects: pgAdmin, Portainer, mongo-express, libSQL, code-server, Artemis

**Public instance** (port 4181):
- Callback: `https://sol.massimilianopili.com/oauth2/callback`
- Cookie: HTTPS secure, domain `.massimilianopili.com`
- Protects: same services on the public endpoint

Both use Keycloak backchannel (`http://keycloak:8080/auth/realms/sol`) for token exchange.

## Best Practices

1. **Always use Tailscale for admin access** -- never expose admin ports (8443, 8081, 8082) directly to the internet
2. **Keep sensitive services Tailscale-only** -- libSQL console and Artemis console are intentionally not exposed via Cloudflare
3. **Use SSHFS with `reconnect`** for resilient remote mounts that survive brief network interruptions
4. **Prefer MagicDNS** (`sol`) over the raw IP (`100.86.46.84`) when possible for readability
5. **Use agent forwarding** from your local machine instead of storing SSH private keys on the server
6. **Don't run parallel Claude sessions** on different machines writing to the same shared `.jsonl` files
7. **PostgreSQL is localhost-only** -- access it via Tailscale SSH tunnel or pgAdmin, never expose the port

## Troubleshooting

### Cannot reach 100.86.46.84
- Verify Tailscale is running on both client and server: `tailscale status`
- Check if the server appears in your Tailscale admin console
- Try `tailscale ping sol` to test direct connectivity
- Ensure no firewall is blocking WireGuard UDP traffic (port 41641)

### SSHFS disconnects frequently
- Add `-o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3` to the mount command
- Check network stability between Tailscale peers: `tailscale ping sol`
- Verify SSH daemon is running on the server: `systemctl status ssh`

### SSH key passphrase asked repeatedly
- Run `ssh-ensure` on the server to load the key into gpg-agent (8h cache)
- Verify `SSH_AUTH_SOCK` is set: `echo $SSH_AUTH_SOCK`
- Check gpg-agent is running: `gpg-connect-agent /bye`

### MagicDNS not resolving
- Check Tailscale admin console for DNS settings
- Verify MagicDNS is enabled in the tailnet settings
- Fall back to the IP address (`100.86.46.84`) as a workaround

### Service not accessible via Tailscale
- Verify nginx is running: `docker ps | grep nginx`
- Check nginx is listening on the expected port: `docker exec nginx ss -tlnp`
- Inspect nginx logs: `docker logs nginx --tail 20`
- Verify the target container is on the `shared` network: `docker network inspect shared`

### Cloudflare Tunnel not working (public access)
- Check cloudflared logs: `docker logs cloudflared --tail 10`
- Look for "Registered tunnel connection" in the output
- Verify UDP buffer size: `sysctl net.core.rmem_max` (should be >= 7500000)
- The tunnel uses QUIC -- UDP must not be blocked
