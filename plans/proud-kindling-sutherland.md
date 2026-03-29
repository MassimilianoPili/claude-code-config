# Gap Analysis: KORE Concepts → Missing Tasks

## Context

Cross-referencing 125 KORE Concepts (with relevance tags) against 104 existing PENDING tasks reveals **15 actionable gaps** — concepts marked CRITICAL/URGENT/HIGH that have no corresponding task in the queue.

## CRITICAL/URGENT Gaps (no task exists)

| Concept | Relevance | Why Missing |
|---------|-----------|-------------|
| Jenkins SAML CVE-2025-64131 | URGENT | Security CVE, no task created |
| MinIO Archived - pgsty Fork | URGENT | One-line fix, no task created |
| MCP Description Quality 73% Smells | HIGH | Tool description audit for 286 tools |
| SHIELDA 36 Agent Exception Types | HIGH | Extend failure-advisor from 11→36 patterns |
| ToxicSkills Security Warning | HIGH | 26.1% skills have vulnerabilities |
| OWASP Top 10 Agentic Applications | HIGH | Map risks to simoge-mcp architecture |
| FSRS-6 Anki Scheduler | HIGH | Enable FSRS for 17K cards, immediate benefit |
| Grafana 12 Dynamic Dashboards | MEDIUM | Upgrade + deploy Docker dashboard |
| GROBID Academic Paper Parsing | MEDIUM | PDF parsing for paper_archive pipeline |
| Rootless Docker Mode | MEDIUM | Security improvement, low effort |
| OpenAlex Concepts→Topics | MEDIUM | Deprecation not covered by API key task |
| VictoriaLogs Loki Replacement | MEDIUM | Evaluate alongside VictoriaMetrics |
| pgBackRest for PITR | MEDIUM | Point-in-time recovery for PG18 |
| Python tenacity+structlog+uv | MEDIUM | paper_archive.py modernization (quick win) |
| Skill Description 2% Budget | MEDIUM | 103 skills may exceed context budget |

## Already Covered (skip)

These concepts have matching tasks:
- ToolSearchTools → simoge-mcp-spring-ai-113 (#132)
- Claude Code Deferred Tool Loading → covered by Spring AI ToolSearchTools
- Two-Tier MRL Indexing → pgvector-subvector-index (#119)
- Tree-Sitter Code Graph → code-embedding-ast-aware (#111)
- METR 19% Slowdown → awareness insight, not actionable task
- RTX 3090 FP8 Limitation → guard rail, not action

## New Tasks to Enqueue (15)

| # | ref | type | prio | task |
|---|-----|------|------|------|
| 1 | `jenkins-saml-cve-fix` | ops | 1 | URGENT: verify Jenkins SAML plugin version, update to 2.541.3 LTS. CVE-2025-64131. |
| 2 | `minio-pgsty-fork-switch` | ops | 1 | URGENT: switch docker-compose from minio/minio (archived) to pgsty/minio. One-line image change. |
| 3 | `mcp-tool-description-audit` | ops | 2 | Audit 286 MCP tool descriptions against 18-smell taxonomy. 73% of MCP servers have description quality issues. Highest-leverage for tool selection accuracy. |
| 4 | `toxic-skills-audit` | ops | 2 | Security audit all 103 skills and 47 plugins for prompt injection vectors. 26.1% of surveyed skills have vulnerabilities. |
| 5 | `anki-enable-fsrs6` | ops | 2 | Enable FSRS-6 scheduler in Anki for 17K cards. 99.6% superior to SM-2, 15-20% fewer reviews for same retention. Default since Anki Oct 2025. |
| 6 | `owasp-agentic-audit` | ops | 3 | Map OWASP Top 10 Agentic Application risks to simoge-mcp architecture. Add per-tool capability labels. Evaluate Llama Guard on GAIA. |
| 7 | `failure-advisor-shielda-36` | code | 3 | Extend failure-advisor.sh from 11 to 36 error patterns using SHIELDA taxonomy for comprehensive coverage. |
| 8 | `grobid-paper-parsing` | ops | 3 | Deploy GROBID as Docker sidecar for paper_archive pipeline. Extracts structured metadata (title, authors, refs) directly from PDFs. |
| 9 | `openalex-concepts-to-topics` | code | 3 | Migrate OpenAlex integration from deprecated Concepts entity to Topics taxonomy (4516 topics). Update import scripts. |
| 10 | `skill-description-optimization` | ops | 3 | Audit 103 Claude Code skill descriptions — ensure each <150 chars. Skills exceeding 2% token budget may be silently excluded from context. |
| 11 | `rootless-docker-eval` | research | 4 | Evaluate Rootless Docker mode for SOL. pasta networking faster than slirp4netns on Ubuntu 24.04. Low-effort security improvement. |
| 12 | `grafana-12-upgrade` | ops | 4 | Upgrade to Grafana 12. Deploy dashboard 13496 (Docker+System). Add PG datasource for session_events table. |
| 13 | `victorialogs-loki-eval` | research | 4 | Evaluate VictoriaLogs as Loki replacement alongside VictoriaMetrics for Prometheus. Significant memory savings on 16GB SOL. |
| 14 | `pgbackrest-pitr` | ops | 4 | Add pgBackRest for point-in-time recovery alongside existing restic+pg_dump. Uses existing MinIO as backup target. |
| 15 | `paper-archive-modernize` | code | 4 | Modernize paper_archive.py: add tenacity for retries (1h), structlog for structured logging (3h), uv for package management (30min). |

## Execution

Use `claude_task_enqueue` for each. createdBy: `chat-246`.

## Verification

```
db_query("SELECT count(*) FROM claude_tasks WHERE status='PENDING'")  -- expect ~119
```
