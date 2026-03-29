# Task #184 — CVE-2026-2092 Keycloak SAML Encrypted Assertion Injection (CVSS 7.7)

## Context
CVE-2026-2092: SAML encrypted assertion injection enables user impersonation.
Directly affects WikiJS (SAML write) and Jenkins (SAML). Fix: Keycloak >= 26.5.5.
Current: **26.5.4**. Target: **26.5.6** (latest patch).

## Steps

### 1. Update image tag
- `/data/massimiliano/keycloak/docker-compose.yml` line 3
- `quay.io/keycloak/keycloak:26.5.4` → `quay.io/keycloak/keycloak:26.5.6`

### 2. Deploy
- `sol deploy keycloak` (or `docker compose up -d keycloak` — Keycloak is NOSCALE, no zero-downtime)
- Wait for healthcheck (up to 120s start_period)

### 3. Verify
- `docker exec keycloak /opt/keycloak/bin/kc.sh --version` → 26.5.6
- Healthcheck passes (GET /auth/health/ready → UP)

## File to modify
- `/data/massimiliano/keycloak/docker-compose.yml` (line 3, one-line change)
