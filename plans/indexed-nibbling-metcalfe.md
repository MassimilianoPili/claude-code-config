# Plan: Fix graph_stats AGE bug + Dockerfile Playwright cache + Gitea Maven registry

## COMPLETATO — 2026-03-22

Tutti gli step eseguiti e verificati.

| Step | Stato |
|---|---|
| Fix `labels(n)` → `label(n)` (GraphTools.java, InfraTools.java) | ✅ |
| Release mcp-graph-tools 0.1.4 su Maven Central | ✅ |
| CI workflow: publish su Gitea Maven registry | ✅ (attivo dal prossimo tag) |
| settings-docker.xml (Gitea first, Central fallback) | ✅ |
| Dockerfile: Playwright cached layer (prima di COPY src/) | ✅ |
| docker-compose.yml: GITEA_TOKEN build arg | ✅ |
| MCP pom.xml dependency → 0.1.4 | ✅ |
| BuildKit cache pruned + rebuilt + deployed (mcp-simoge-mcp-8) | ✅ |
| `graph_stats` verificato (50,794 nodi, 41 label) | ✅ |
| KORE aggiornato (simoge-mcp + gitea-maven-publish) | ✅ |
| MCP transport type fix (`streamable-http` → `http` in .claude.json) | ✅ |
