# Research Sweep Findings → claude_queue Tasks

## Context
201 academic-researcher agents completed across 11 waves. 49 research reports written to `docs/research/`. 122 Concepts + 30 Papers persisted in KORE. Now structuring ALL actionable findings into `claude_queue` tasks via `claude_task_enqueue` MCP tool so future Claude sessions can claim and execute them.

## Already Queued (from previous session — DO NOT duplicate)
Tasks #135-167 already cover: OpenAlex API key, KV cache q8, pooling verify, AGE matchingsel, Jenkins SAML, MinIO fork switch, pgvector subvector/iterative/halfvec, RRF hybrid search, TEI batch, Spring AI 1.1.3, Promtail→Alloy, docker socket proxy, APO pair selection, chunking 512, tool description audit, toxic skills audit, FSRS6, AGE entity_exists, graph-guided vector, MCP streamable HTTP, autotool graph selection, Tor full vanguards.

## NEW Tasks to Enqueue (from this sweep)
- Federated learning on local GPU (GAIA)
- D3.js + force-directed graph visualization advances (knowledge-graph UI)
- Gitea Actions vs GitHub Actions — CI/CD for self-hosted
- MinIO S3 patterns + object storage for AI artifacts
- Restic backup advances + deduplication
### GROUP 1 — IMMEDIATE SECURITY (priority 1, taskType "security")

| ref | task | context | report |
|-----|------|---------|--------|
| `redis-cve-2025-49844` | Upgrade Redis >= 7.2.11. CVE-2025-49844 CVSS 10.0 RCE via Lua GC, present 13 years. PoC from Pwn2Own Berlin. Verify: `docker exec redis redis-server --version` | SOL runs Redis 7 on shared network | `critical-cves-vulnerability-trends-2025-2026.md` |
| `go-cve-2025-68121` | Upgrade Go >= 1.24.13 and RECOMPILE all 5 Go binaries: proxy-ai, mcp-proxy, knowledge-graph, embedding-viz, wg-manager. CVE-2025-68121 CVSS 10.0 TLS session resumption bypass. SOL currently Go 1.22.2. | All Go services use crypto/tls | `critical-cves-vulnerability-trends-2025-2026.md` |
| `pg-cve-2026-2005` | Verify PostgreSQL >= 18.2. CVE-2026-2005 pgcrypto heap buffer overflow CVSS 8.8 RCE. Check: `docker exec postgres psql -c "SELECT version()"` | SOL runs PG18 custom build with AGE+pgvector | `critical-cves-vulnerability-trends-2025-2026.md` |
| `mongo-cve-2025-14847` | Upgrade MongoDB >= 8.0.17. CVE-2025-14847 MongoBleed CVSS 8.7 unauthenticated memory disclosure, in CISA KEV, exploitation in-the-wild. | SOL runs MongoDB 8 on shared network | `critical-cves-vulnerability-trends-2025-2026.md` |
| `sudo-cve-2025-32463` | Verify sudo >= 1.9.17p1. CVE-2025-32463 CVSS 9.3 LPE via chroot NSS manipulation, in CISA KEV, multiple PoCs. Check: `sudo --version` | Ubuntu 24.04 host | `critical-cves-vulnerability-trends-2025-2026.md` |
| `runc-triple-cve` | Verify runc >= 1.2.8. CVE-2025-31133/52565/52881 CVSS 7.3 each, container escape via bind mount + symlink race. Check: `runc --version` | ~48 Docker containers on SOL | `docker-container-security-2025-2026.md` |

### GROUP 2 — URGENT SECURITY/MIGRATION (priority 1, taskType "security")

| ref | task | context | report |
|-----|------|---------|--------|
| `keycloak-saml-cve-2026-2092` | Upgrade Keycloak >= 26.5.5. CVE-2026-2092 CVSS 7.7 encrypted assertion injection enables impersonation. Directly affects WikiJS + Jenkins SAML auth. Audit all 14 clients: enforce PKCE S256, disable Implicit/ROPC grants. | 14 Keycloak clients, 4 auth patterns | `critical-cves-vulnerability-trends-2025-2026.md`, `iam-advances-2025-2026.md` |
| `embedding-access-control` | Review pgvector embedding API exposure. Zero2Text (Feb 2026) achieves near-perfect text reconstruction from embeddings with ZERO training data. Standard DP defenses fail. GRASP achieves 82.9 F1 subgraph reconstruction on graph RAG. Ensure embeddings_search MCP tools have proper auth. | KORE pgvector 4096-dim embeddings | `privacy-engineering-advances-2025-2026.md` |
| `containerd-version-check` | Verify containerd version is patched. Check for CVE-2025-containerd series. Also verify Docker Engine version. `docker version` + `containerd --version` | Complement to runc-triple-cve | `docker-container-security-2025-2026.md` |

### GROUP 3 — HIGH INFRASTRUCTURE (priority 2, taskType "ops")

| ref | task | context | report |
|-----|------|---------|--------|
| `victoriametrics-replace-prometheus` | Replace Prometheus with VictoriaMetrics: 10x memory reduction (19GB→2.2GB). PromQL-compatible drop-in. On 16GB SOL, highest-impact monitoring change. Steps: docker-compose with vmsingle, migrate Grafana datasource, update prometheus.yml scrape configs. | SOL monitoring stack: Prometheus + Grafana + Loki | `self-hosted-infrastructure-advances-2025-2026.md` |
| `pgbackrest-pg18-wal` | Deploy pgBackRest 2.58 for PG18 WAL archiving. RPO down to seconds vs current restic filesystem-level nightly backup. Configure: stanza-create, archive-push, automated full+diff backup schedule. | SOL backup: restic 3:00AM nightly, no PG-specific backup | `backup-dr-infrastructure-resilience-2025-2026.md` |
| `backup-offsite-gaia` | Configure restic backup target on gaia (100.109.3.40) as offsite copy. SOL currently has NO offsite backup — violates 3-2-1 rule. restic init over SSH, cron job for daily sync. | SOL+GAIA on Tailscale mesh | `backup-dr-infrastructure-resilience-2025-2026.md` |
| `backup-immutable-tier` | Configure MinIO Object Lock (or Garage equivalent) for immutable backup copies. Ransomware resistance. Note: restic prune incompatible with Object Lock — requires separate locked archive copy via rclone sync. | Depends on MinIO migration decision (#164) | `backup-dr-infrastructure-resilience-2025-2026.md` |
| `restic-upgrade-018` | Upgrade restic to 0.18.1. Chunking attack mitigation (content-defined chunking vulnerability), improved compression, cold storage S3 support. | SOL backup cron at 3:00AM | `backup-dr-infrastructure-resilience-2025-2026.md` |
| `trivy-scanner-deploy` | Deploy Trivy v0.69.x as Docker container on SOL. Single binary covers: containers, IaC, dependencies, SBOM, secrets. Schedule weekly scan of all running images. | 48 container images on SOL | `security-auditing-compliance-2025-2026.md` |
| `cis-ubuntu-2404-audit` | Run CIS Benchmark Level 1 Server audit on Ubuntu 24.04 using Ubuntu Security Guide (USG). 252 rules. L1 is appropriate for SOL; L2 may interfere with Docker networking. | Ubuntu 24.04 kernel 6.8.0-106 | `linux-kernel-security-2025-2026.md` |
| `opentofu-evaluate` | Evaluate OpenTofu v1.9 for SOL infrastructure declarative management. Key differentiator: native state encryption (AES-GCM). Could manage Docker infra declaratively with encrypted local state. Low priority — Docker Compose + shell scripts remain sufficient. | Current: Docker Compose + sol/deploy-mcp scripts | `infrastructure-lifecycle-management-2025-2026.md` |

### GROUP 4 — HIGH CODE/FEATURES (priority 2, taskType "code")

| ref | task | context | report |
|-----|------|---------|--------|
| `bt-gpm-evaluate` | Evaluate General Preference Model (Zhang et al ICML 2025) for preference-sort. GPM handles intransitive preferences where BT fails. Implement prototype: preference embeddings in latent space. arXiv:2410.02197 | preference-sort project, 33 MCP libraries ranked | `combinatorics-graph-theory-2025-2026.md` |
| `kelly-pair-selection` | Implement Kelly-criterion-based optimal pair selection for preference-sort. Present comparisons where expected information gain is highest (most uncertain pairs). Fractional Kelly = regularized BT. 30-50% fewer comparisons needed. | Complements #143 APO pair selection | `research-sweep-report-2026-03-21.md` |
| `hodge-ranking-decomposition` | Implement Hodge decomposition for preference-sort cycle detection. Splits pairwise data into gradient (consistent) + curl (cyclic inconsistency) components. Detects and quantifies intransitive preference cycles. From Isufi et al topological signal processing. | preference-sort + topology research | `topology-geometric-analysis-2025-2026.md` |
| `tda-mapper-kore` | Apply Mapper algorithm (from TDA) to KORE pgvector embedding space. Produces topological summary graph revealing domain boundaries, cross-domain bridges, and knowledge gaps. Use GIOTTO-TDA or TopoX suite. | KORE ~50K nodes, 5 domains, 4096-dim embeddings | `topology-geometric-analysis-2025-2026.md` |
| `agent-18-patterns` | Study and apply Liu et al Agent Design Pattern Catalogue (arXiv:2405.10467, JSS 2024, ICSA 2025). 18 patterns for FM-based agents. Map to agent-framework HTN/SHOP2 architecture. Also: AgentOps Pattern Catalogue for operational patterns. | agent-framework project, Java 21, Spring Boot | `research-sweep-report-2026-03-21.md` |
| `checkmate-pddl-agent` | Evaluate CHECKMATE PEP paradigm (Planner-Executor-Perceptor) for agent-framework. Combines LLM agents with PDDL classical planning. +20% over Claude Code baseline, -50% cost. arXiv Dec 2025. | agent-framework HTN planning | `offensive-security-pentesting-2025-2026.md` |
| `rlhf-impossibility-prefsort` | Review RLHF impossibility results for preference-sort implications. Kleine Buening et al NeurIPS 2025: strategyproof RLHF = k-times worse. Falahati et al AAAI 2026: Arrow-like impossibility for recursive BT curation. Check if these limits affect ranking stability. | preference-sort + mechanism design | `mechanism-design-advances-2025-2026.md` |
| `commonhaus-evaluate` | Evaluate Commonhaus Foundation for 33 MCP Maven Central libraries. Members: Hibernate, Jackson, OpenRewrite. Projects keep brand+infra. Succession planning. Not urgent now — relevant if adoption grows (>1K GitHub stars). | 33 Java MCP libraries, GroupId io.github.massimilianopili | `research-sweep-report-2026-03-21.md` |
| `gql-age-evaluation` | Evaluate GQL (ISO/IEC 39075:2024) implications for AGE. First new ISO DB language in 35yr. GQL strictly less expressive than recursive SQL (Gheerbrant et al PVLDB 2025). No AGE-specific query planning papers exist. Kuzu morsel-driven parallelism may inform AGE optimization. | KORE on AGE, PG18 | `database-theory-query-optimization-2025-2026.md` |

### GROUP 5 — MEDIUM SECURITY HARDENING (priority 3, taskType "ops")

| ref | task | context | report |
|-----|------|---------|--------|
| `rootless-docker-evaluate` | Evaluate migration to rootless Docker. Rootless is now recommended default for production (OCI Spec v1.3). User namespace remapping maps container UID 0 to unprivileged host. ID-mapped mounts eliminate chown overhead. Test on non-critical container first. | 48 containers, Docker daemon as root | `docker-container-security-2025-2026.md` |
| `cosign-image-signing` | Implement Sigstore Cosign keyless image signing for SOL Docker images. Rekor v2 GA. Cosign v3 default keyless via Fulcio+OIDC. No key management needed. Sign on gitea-actions build, verify on deploy. | Gitea CI/CD, act_runner | `docker-container-security-2025-2026.md` |
| `landlock-service-sandbox` | Evaluate Landlock LSM for service sandboxing. 6 ABI versions, TCP sandboxing (kernel 6.7+). `landrun` tool for ad-hoc sandboxing without root. Apply to most exposed services first (nginx, keycloak). | Ubuntu 24.04 kernel 6.8 supports ABI 1-4 | `linux-kernel-security-2025-2026.md` |
| `falco-runtime-security` | Deploy Falco as privileged container on shared network for runtime container security. 11.2% CPU overhead but better fit than Tetragon for non-K8s Docker. Detection-only (no enforcement). | SOL standalone Docker, no K8s | `security-auditing-compliance-2025-2026.md` |
| `keycloak-passkeys-upgrade` | Plan Keycloak upgrade to 26.4+ for passkeys GA. FIDO2/WebAuthn phishing-resistant auth. NIST SP 800-63-4 mandates phishing-resistant at AAL2. 15B passkey accounts globally. | Keycloak realm sol, 14 clients | `iam-advances-2025-2026.md` |
| `oauth21-pkce-audit` | Audit all 14 Keycloak clients: enforce PKCE (S256) on all. Disable Implicit grant and ROPC where unused. OAuth 2.1 (draft-15) mandates PKCE, drops Implicit/ROPC. MCP adopted OAuth 2.1. | 14 Keycloak clients, some may still use Implicit | `iam-advances-2025-2026.md` |
| `attck-v18-review` | Review MITRE ATT&CK v18 (Oct 2025) detection strategies for SOL. Most significant update ever: structured Detection Strategies replace Data Sources. Coverage expanded to CI/CD, cloud DBs. Map SOL attack surface against new techniques. | SOL exposed via Cloudflare Tunnel | `offensive-security-pentesting-2025-2026.md` |
| `owasp-2025-audit` | Audit SOL services against OWASP Top 10:2025. New: A03 Supply Chain Failures, A10 Mishandling Exceptional Conditions. Security Misconfiguration surged to #2. Check all nginx routes, Go/Java services. | ~30 nginx routes, 4 auth patterns | `offensive-security-pentesting-2025-2026.md` |
| `nis2-cra-compliance` | Assess NIS2/CRA compliance requirements. EU mandates SBOM by Sep 2026, vulnerability reporting within 24h. Fines up to EUR 15M/2.5% turnover. Generate SBOM with Trivy for all SOL services. Relevant if hosting for external users. | EU regulations, SOL as personal server | `security-auditing-compliance-2025-2026.md` |
| `suricata-8-evaluate` | Evaluate Suricata 8.0 deployment on SOL. HTTP rewritten in Rust, JA4+ native, 100% DNS tunneling detection. Docker deployment straightforward. Low priority — SOL is behind Cloudflare Tunnel. | SOL network defense | `network-defense-2025-2026.md` |
| `tpot-honeypot-evaluate` | Evaluate T-Pot 24.04.1 honeypot deployment. LLM-powered honeypots (Beelzebub SSH, Galah HTTP) can use local Ollama on gaia. Low priority — interesting for security research. | SOL + GAIA, Ollama available | `network-defense-2025-2026.md` |

### GROUP 6 — MEDIUM RESEARCH-DRIVEN FEATURES (priority 3-4, taskType "research")

| ref | task | context | report |
|-----|------|---------|--------|
| `semgrep-multimodal-eval` | Evaluate Semgrep Multimodal (Mar 2026): deterministic rules + LLM reasoning. Claims 8x true positives, 50% noise reduction. Test on SOL Go/Java repos. CodeQL 2.25.0 now has Rust queries too. | SOL Java + Go codebases | `secure-coding-2025-2026.md` |
| `pq-tls-assessment` | Assess PQ-TLS readiness. 60% Cloudflare traffic is PQ-protected (X25519MLKEM768). Apple iOS 26 enabled PQ by default. WireGuard has no mainline PQ — Rosenpass is the mature solution. DSS Wrapper will need ML-DSA/FN-DSA support. | SOL Cloudflare Tunnel + WireGuard + DSS Wrapper | `applied-post-quantum-cryptography-2025-2026.md` |
| `kore-slimer-it-ner` | Evaluate SLIMER-IT zero-shot NER for Italian text in KORE pipeline. Outperforms SOTA on unseen entity types. Could extract entities from Italian Kindle highlights for AGE knowledge graph. Also: Minerva-7B as Italian-native LLM. | KORE Kindle import pipeline, Italian text | `research-sweep-report-2026-03-21.md` |
| `dr-drill-gaia-restore` | Conduct DR drill: restore SOL backup to gaia or VM. Document restoration order (postgres→keycloak→nginx→services). Test pgBackRest PITR if deployed. Consider Relax-and-Recover (ReaR) for bootable rescue ISO. | No DR drill ever conducted | `backup-dr-infrastructure-resilience-2025-2026.md` |
| `chainguard-jre-mcp` | Evaluate Chainguard/Wolfi base image for simoge-mcp Spring Boot container. 97.6% CVE reduction vs standard images. Currently using standard JRE image. Drop-in replacement. | simoge-mcp Docker image, Java 21 | `docker-container-security-2025-2026.md` |
| `sops-age-env-encryption` | Evaluate SOPS+AGE for .env file encryption at rest. SOL .env files contain secrets (gitignored but unencrypted on disk). SOPS encrypts individual values, AGE provides keyless encryption. | ~15 .env files with secrets | `docker-container-security-2025-2026.md` |
| `buildkit-secrets-audit` | Audit Dockerfiles for secret handling. Ensure all build-time credentials use BuildKit `--mount=type=secret` (tmpfs, never enters layers). Avoid `ENV` for secrets (visible in `docker inspect`). | SOL Dockerfiles (postgres, code-server, tor, etc) | `docker-container-security-2025-2026.md` |

### GROUP 7 — LOW AWARENESS/TRACKING (priority 5, taskType "awareness")

| ref | task | context | report |
|-----|------|---------|--------|
| `research-kore-wiki-sync` | Sync 49 research reports from docs/research/ to WikiJS and/or KORE embeddings. Currently: reports on disk only. Could: embed for semantic search, create WikiJS pages, link to AGE concepts. | 49 files, ~3.1MB, docs/research/ | All reports |
| `transformer-phase-transition` | AWARENESS: Rigollet ICM 2026 shows transformer attention is interacting particle system with mean-field limit. Phase transition = representation collapse above critical context length. Implications for long-context LLM architecture. | Theoretical understanding | `stat-mech-phase-transitions-2025-2026.md` |
| `ai-theorem-proving-watch` | AWARENESS: Seed-Prover 99.6% miniF2F, 5/6 IMO 2025. AlphaProof Nature 2025. Lean Mathlib >2.1M lines. Nesterov 40yr problem solved with GPT-5 Pro assist. Watch for practical theorem proving tools. | Formal verification research | `formal-verification-plt-2025-2026.md` |
| `desi-dynamic-dark-energy` | AWARENESS: DESI DR2 dynamic dark energy at 3.1-4.2 sigma. S8 tension resolved (KiDS-Legacy). Hubble tension persists 5 sigma. Muon g-2 and W mass anomalies both resolved. CMB-S4 cancelled. | Physics frontiers | Multiple physics reports |
| `financial-italian-tax-optimize` | AWARENESS: Optimal Italian tax order: max fondo pensione (EUR 5300/yr), then PIR (EUR 30K/yr, CG exempt after 5yr), then taxable. TFR default suboptimal (2.4% vs 4.5%). SWR 3.9% (Morningstar 2026). Factor tilts: international small value 7.95% annualized. | Personal finance | `research-sweep-report-2026-03-21.md` |
| `ramsey-langlands-awareness` | AWARENESS: Ramsey R(k)<3.993^k first exponential improvement in 89 years. Geometric Langlands proved (~800 pages). PFR conjecture proved (info-theoretic, ~15 pages). Guth-Maynard breaks Ingham 84yr record. | Pure mathematics landmarks | Multiple math reports |

## Execution Plan

### Step 1: Enqueue GROUP 1 (6 tasks, priority 1, taskType "security")
Sequential `claude_task_enqueue` calls. createdBy = "chat-231". No dependencies.

### Step 2: Enqueue GROUP 2 (3 tasks, priority 1, taskType "security")
keycloak-saml-cve depends on runc-triple-cve being verified first (container restart safety).

### Step 3: Enqueue GROUP 3 (8 tasks, priority 2, taskType "ops")
pgbackrest-pg18-wal depends on pg-cve-2026-2005 (verify PG version first).
backup-offsite-gaia has no deps.
backup-immutable-tier depends on #164 (minio-pgsty-fork-switch).

### Step 4: Enqueue GROUP 4 (9 tasks, priority 2, taskType "code")
bt-gpm-evaluate, kelly-pair-selection, hodge-ranking-decomposition all relate to preference-sort — can run in parallel but share context.
agent-18-patterns and checkmate-pddl-agent relate to agent-framework.

### Step 5: Enqueue GROUP 5 (11 tasks, priority 3, taskType "ops")
All independent. keycloak-passkeys depends on keycloak-saml-cve being completed first.

### Step 6: Enqueue GROUP 6 (7 tasks, priority 3-4, taskType "research")
All independent. dr-drill depends on pgbackrest being deployed.

### Step 7: Enqueue GROUP 7 (6 tasks, priority 5, taskType "awareness")
Informational only — no code changes. research-kore-wiki-sync is the most actionable.

## Verification

After enqueueing:
```
claude_task_list("PENDING")     # Should show all new tasks
claude_task_list("RANKED")      # Should show BT-ordered priority
```

Count: **6 + 3 + 8 + 9 + 11 + 7 + 6 = 50 new tasks** to enqueue.

Total queue after: ~50 existing + 50 new = ~100 tasks.

## Constraints
- Use `claude_task_enqueue` MCP tool for each task
- Set `createdBy` = "chat-231" (this session)
- payloadJson must include: task, context, constraints, report (source research report)
- Do NOT duplicate tasks already in queue (#135-167, #117-127, #132-133, #136-137, #141-143, #156, #165-167)
- Security tasks (GROUP 1-2) get priority 1
- Include dependency chains where order matters
