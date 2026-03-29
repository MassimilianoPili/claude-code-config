# Plan: Update rotated secrets

## Context
User manually rotated the go-filemanager Keycloak client secret and revoked the Azure DevOps PAT.

## Step 1 — Update go-filemanager .env with new secret

**File**: `/data/massimiliano/Vari/go-filemanager/.env`
Replace `KEYCLOAK_CLIENT_SECRET=Uv0DOkM4XUdMurx53MVExroWPSejXHRj` with new value `R9xpZgoz58thxE6AGR8uOG47y8Jyyt8q`.

Then restart the container:
```bash
cd /data/massimiliano/Vari/go-filemanager && docker compose up -d --force-recreate
```

## Step 2 — Remove burned Azure PAT from MCP .env

**File**: `/data/massimiliano/Vari/mcp/.env`
The `MCP_DEVOPS_PAT` value is now invalid. Either:
- Remove/blank it (devops tools will be disabled)
- Replace with new PAT when user provides one

For now: blank it to avoid using a burned credential.

Redeploy:
```bash
cd /data/massimiliano/Vari/mcp && docker compose up -d --force-recreate
```

## Verification
1. go-filemanager container starts and auth works with new secret
2. MCP server starts (devops tools may fail gracefully without PAT)
