# Post-recovery: restart services with stale connections

## Context
Postgres was recreated after PG upgrade + restore. Some services have stale JDBC/TCP connections.

## Restart needed

1. **keycloak** — `EOFException` on PGStream, broken JDBC connections
2. **preference-sort** — unhealthy status

```bash
cd /data/massimiliano/keycloak && docker compose restart keycloak
cd /data/massimiliano/Vari/preference-sort && docker compose restart preference-sort
```

## No restart needed
- Gitea — responding OK
- WikiJS — healthy, rendering pages
- simoge-mcp — just rebuilt, working
- knowledge-graph, server-api — recovered after initial Keycloak delay
