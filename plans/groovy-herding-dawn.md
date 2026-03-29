# Piano: Allineamento lib MCP — COMPLETATO

## Risultato finale: 8/8 librerie su Maven Central

| Repo | Versione | Maven Central | Gitea | GitHub | CI |
|------|----------|---------------|-------|--------|-----|
| mcp-azure-tools | 1.0.0 | ✓ | ✓ | ✓ | ✓ (task 13, timeout polling ma pubblicato) |
| mcp-devops-tools | 0.0.2 | ✓ | ✓ | ✓ | ✓ (task 14) |
| mcp-ocp-tools | 0.0.1 | ✓ | ✓ | ✓ | ✓ (task 15) |
| mcp-docker-tools | 0.0.1 | ✓ | ✓ | ✓ | ✓ (task 16) |
| spring-ai-reactive-tools | 0.2.1 | ✓ | ✓ | ✓ | ✓ (task 17) |
| mcp-filesystem-tools | 0.0.2 | ✓ | ✓ | ✓ | ✓ (task 18) |
| mcp-mongo-tools | 0.0.2 | ✓ | ✓ | ✓ | ✓ (task 19) |
| mcp-sql-tools | 0.0.2 | ✓ | ✓ | ✓ | ✓ (task 20) |

## Fix applicati

1. `release.yml`: aggiunto step "Install Maven" (download Apache Maven 3.9.9) + `cache: "maven"` in tutti e 8 i repo
2. Bump versione per test flusso CI nelle 4 lib che erano già su Maven Central

## Nessuna azione residua
