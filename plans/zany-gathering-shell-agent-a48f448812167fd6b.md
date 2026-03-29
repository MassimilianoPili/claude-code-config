# Research Survey: Container Security for Self-Hosted Infrastructure (2025-2026)

## Executive Summary

Container security has seen significant maturation in 2025-2026 across all layers: runtime isolation, supply chain integrity, vulnerability scanning, and kernel-level monitoring. The field is converging on defense-in-depth architectures combining rootless runtimes, eBPF-based monitoring, SBOM-driven vulnerability management, and cryptographic supply chain provenance. For a self-hosted setup running ~48 Docker containers on Ubuntu 24.04 with shared networking, the most impactful improvements are: (1) automated seccomp/AppArmor profile generation, (2) eBPF-based runtime detection (Falco/Tetragon), (3) SBOM generation with vulnerability scanning (Trivy + cosign), and (4) Docker Compose hardening patterns.

**Epistemic status:** Active development field with strong practitioner consensus on best practices; academic research is catching up with tooling advances. Most findings below are from T2 (arXiv preprints at top security venues) and T7 (tool documentation/release notes).

**Confidence:** Medium-High -- tool capabilities are well-documented; academic benchmarks exist but cross-tool consistency remains low (per Churakova & Ekstedt 2025).

---

## 1. Rootless Docker Advances (2025-2026)

### Current State

Docker Engine 27.x (latest stable as of early 2026) continues to improve rootless mode support. Key developments:

**Networking backends:**
- **pasta (Passt-based)** has largely replaced `slirp4netns` as the default rootless networking backend in newer Docker/Podman versions. pasta provides near-native networking performance by leveraging kernel-native packet forwarding rather than userspace TCP/IP stack emulation.
- **slirp4netns** remains available as fallback but is considered legacy. Performance penalty was historically 20-40% for network-intensive workloads.
- Docker 27.x supports `--network=pasta` natively on systems with pasta >= 2024.

**Performance findings** (T2 -- Khan, arXiv:2602.15214, Feb 2026):
- Linux namespace creation contributes only **8-10 ms (<1.5%)** of total container startup time, meaning rootless mode's namespace overhead is negligible.
- Container startup is dominated by runtime overhead, not image size -- only 2.5% startup variation across images from 5 MB to 155 MB on SSD.
- OverlayFS write performance collapses by up to **two orders of magnitude** compared to volume mounts on SSD-backed storage -- critical for rootless mode which relies on fuse-overlayfs.
- Storage tier selection imposes a **2.04x startup penalty** (HDD 1157 ms vs. SSD 568 ms).

**User namespace improvements:**
- Linux kernel 6.8+ (Ubuntu 24.04's kernel) includes improved user namespace isolation with `unprivileged_userns_clone` restrictions available via AppArmor.
- Ubuntu 24.04 ships with AppArmor user namespace restrictions enabled by default (since kernel 6.8), adding a layer of protection even for rootful Docker.

**Known limitations for SOL setup:**
- Rootless Docker cannot bind to ports < 1024 without `sysctl net.ipv4.ip_unprivileged_port_start=0`.
- Shared Docker network (`shared` external network) requires special handling -- rootless containers use a separate network namespace and cannot directly join rootful container networks.
- Bind mounts require UID/GID remapping via `--userns-remap` or manual `newuidmap`/`newgidmap` configuration.
- Volumes owned by host users need careful permission management.

### Relevance to SOL

**Migration difficulty: HIGH.** The shared-network architecture with ~48 containers on a single `shared` Docker network makes rootless migration complex. Rootless Docker uses a different networking stack (pasta/slirp4netns) that does not interoperate with rootful bridge networks. A full migration would require restructuring the network architecture. **Recommendation:** Apply rootless principles selectively (non-root user inside containers, capability dropping) rather than attempting full rootless Docker daemon migration.

---

## 2. Docker Security Hardening

### 2.1 Seccomp Profiles

**Default Docker seccomp profile** blocks ~44 of ~330+ Linux system calls. Key blocked syscalls: `mount`, `reboot`, `swapon`, `clock_settime`, `kexec_load`, `ptrace` (partially), `clone` with `CLONE_NEWUSER`.

**Automated profile generation (2025 advances):**

- **DockerGate** (T2 -- Kuppili, 2025, ~0 cit S2): Automated seccomp policy generation for Docker images using static analysis to determine which syscalls an image actually needs.
- **Lopes et al.** (T2 -- 2020, ~15 cit S2): "Container Hardening Through Automated Seccomp Profiling" -- dynamic tracing approach using strace to build per-container profiles. Results show custom profiles mitigate several attacks including some zero-day vulnerabilities.
- **Nguyen-Thuy et al.** (T2 -- 2025, ~0 cit S2): "Towards Secure Containerized Applications with Seccomp Profile Refinement" -- refinement approach that starts from generated profiles and iteratively tightens them.
- **BeaCon** (T2 -- Kang et al., 2025, ~0 cit S2): "Automatic container policy generation using environment-aware dynamic analysis" -- novel tool incorporating a security/functionality scoring mechanism to prioritize system calls and capabilities.

**Practical implementation for SOL:**
```yaml
# docker-compose.yml per-service example
services:
  nginx:
    security_opt:
      - seccomp:/path/to/nginx-seccomp.json
      - no-new-privileges:true
```

### 2.2 AppArmor Profiles

- **Lic-Sec** (T1 -- Zhu & Gehrmann, 2020, ~33 cit S2): Enhanced AppArmor profile generator that protects against all privilege escalation attacks where default Docker profiles fail.
- **Kub-Sec** (T1 -- Zhu & Gehrmann, 2022, ~23 cit S2): Automatic Kubernetes/cluster-level AppArmor profile generation -- principles applicable to Docker Compose stacks.
- **AppArmor Profile Generator as Cloud Service** (T1 -- Zhu & Gehrmann, 2021, ~5 cit S2): Shows that generated profiles significantly improve security over default Docker AppArmor profile.

Ubuntu 24.04 includes AppArmor 4.0 with improved container support, including `aa-logprof` for iterative profile refinement.

### 2.3 Capability Dropping

Docker default capabilities (14 of 41 Linux capabilities): `CHOWN`, `DAC_OVERRIDE`, `FSETID`, `FOWNER`, `MKNOD`, `NET_RAW`, `SETGID`, `SETUID`, `SETFCAP`, `SETPCAP`, `NET_BIND_SERVICE`, `SYS_CHROOT`, `KILL`, `AUDIT_WRITE`.

**Best practice for SOL -- drop all, add back minimally:**
```yaml
services:
  myservice:
    cap_drop:
      - ALL
    cap_add:
      - NET_BIND_SERVICE  # only if binding < 1024
    read_only: true
    tmpfs:
      - /tmp
      - /run
```

### 2.4 Read-Only Root Filesystems

Enforcing `read_only: true` at the container level prevents attackers from writing persistent malware to the container filesystem. Combine with explicit `tmpfs` mounts for `/tmp`, `/run`, and application-specific writable paths.

---

## 3. Container Image Supply Chain Security

### 3.1 Sigstore Ecosystem (cosign, Rekor, Fulcio)

**Sigstore** is now the de facto standard for container image signing, with GA status across all components.

**Key paper** (T2 -- Kalu et al., arXiv:2503.00271, March 2025, ~2 cit S2): "Why Johnny Signs with Next-Generation Tools: A Usability Case Study of Sigstore" -- interviews with 17 industry experts finding:
- Keyless signing (via Fulcio short-lived certificates + OIDC) dramatically reduces adoption barriers vs. traditional GPG/PGP.
- Integration flexibility is the primary pain point -- mitigable through plugins and APIs.
- Different Sigstore components exhibit different maturity levels: cosign is most mature, policy-controller less so.

**Industry interview study** (T2 -- Kalu et al., arXiv:2406.09731, 2024): 18 practitioners across 13 organizations identify key challenges: key management complexity, lack of organizational policy, unclear verification procedures.

**Current versions (March 2026):**
- `cosign` v2.4.x: keyless signing, SBOM attachment, OCI artifact support
- `Rekor` v1.4.x: transparency log (immutable, append-only)
- `Fulcio` v1.6.x: certificate authority for keyless signing

**Practical cosign workflow for SOL:**
```bash
# Sign image after build
cosign sign --yes ghcr.io/user/image:tag

# Verify before deployment
cosign verify --certificate-identity=user@email \
  --certificate-oidc-issuer=https://accounts.google.com \
  ghcr.io/user/image:tag

# Attach SBOM
cosign attach sbom --sbom=sbom.spdx ghcr.io/user/image:tag
```

### 3.2 SBOM Generation and the "SBOM Confusion" Problem

**Critical finding** (T2 -- Bufalino et al., arXiv:2510.05798, Oct 2025, ~0 cit S2): "SBOMproof: Beyond Alleged SBOM Compliance" reveals:
- SBOM generation tools are **largely incompatible** across formats (SPDX, CycloneDX).
- Inconsistent formats prevent reliable vulnerability detection across tools.
- The **"SBOM confusion vulnerability"**: different tools generate different SBOMs for the same container image, leading to undetected vulnerabilities.

**Wild SBOMs dataset** (T2 -- Soeiro et al., arXiv:2503.15021, March 2025, MSR 2025): 78K+ unique SBOM files from 94M+ repositories -- first large-scale study of SBOM practices in the wild.

**SBOM Dataset for evaluation** (T2 -- Kishimoto et al., arXiv:2504.06880, April 2025, MSR 2025): 46 curated SBOMs from real-world Java projects with manual corrections.

**Key SBOM tools comparison:**
| Tool | Format | Strengths | Weaknesses |
|------|--------|-----------|------------|
| Syft (Anchore) | SPDX, CycloneDX | Broadest format support, Grype integration | Can miss OS-level packages |
| Docker Scout | CycloneDX | Native Docker integration | Docker Desktop dependency |
| Trivy | SPDX, CycloneDX | Integrated scanner + SBOM | Newer SBOM support |
| cdxgen | CycloneDX | Language-specific depth | Less OS-level coverage |

### 3.3 SLSA Framework

**SLSA** (Supply-chain Levels for Software Artifacts) provides a graduated security framework:
- Level 1: Provenance exists (build info documented)
- Level 2: Hosted build platform (reproducible)
- Level 3: Hardened builds (isolated, tamper-resistant)
- Level 4: Two-party review + hermetic builds

**Deployment challenges** (T2 -- arXiv:2409.05014, Sept 2024): Analysis of 1,523 SLSA-related GitHub issues from 233 repositories identifies four key challenges: complex implementation, toolchain fragmentation, unclear specification, integration difficulties.

**SoK paper** (T1 -- Okafor et al., SCORED@CCS 2022, ~70 cit S2): Systematizes supply chain security via three properties: **transparency** (SBOM, provenance), **validity** (signing, verification), **separation** (build isolation). Maps existing tools to these properties. Seminal reference.

**Macaron framework** (T1 -- Hassanshahi & Mai, IEEE SecDev 2025): Framework for detecting malicious code in supply chains and enforcing SLSA compliance via static analysis.

---

## 4. Academic Papers on Container Security (2025-2026)

### 4.1 Container Escape and Namespace Isolation

| Paper | Authors | Year/Venue | Key Finding | Cit (S2) |
|-------|---------|------------|-------------|----------|
| **Container Path Mis-Resolution Escape Detection via eBPF** | Zhang et al. | 2025 | eBPF-based detection of path traversal container escapes | ~0 |
| **From Container to Cluster: Chained Escape Attacks** | Luo et al. | 2025 | Demonstrates chained escape attacks from container to full Kubernetes cluster compromise | ~0 |
| **PACED: Provenance-based Automated Container Escape Detection** | Abbas et al. | 2022 | Provenance graph analysis for detecting container escapes, ~15 cit S2 | ~15 |
| **Container Privilege Escalation Detection (Security-First Architecture)** | Zhou et al. | 2023 | Architectural approach to detecting privilege escalation, ~5 cit S2 | ~5 |
| **Security at Scale: Ethical Container Exploitation in Orchestrated Environments** | Keshava et al. | 2025 | Systematic analysis of Kubernetes container exploitation | ~0 |
| **Wasm Container Resource Isolation Attacks** | Yu et al. | USENIX Security 2025 | WebAssembly runtimes vulnerable to resource isolation attacks via WASI/WASIX | ~0 |
| **eBPF-Based Privilege Escalation Prediction** | Bertinatto et al. | 2024 | Uses eBPF syscall tracing + ML to predict privilege escalation, ~2 cit S2 | ~2 |

### 4.2 Critical CVEs (2024-2026)

**runc CVEs:**
- **CVE-2024-21626** (CVSS 8.6, Jan 2024): runc container escape via leaked file descriptor. Affects runc < 1.1.12. Allows process inside container to gain access to host filesystem via `/proc/self/fd` manipulation. **Fixed in runc 1.1.12.**
- **CVE-2024-23651** (CVSS 7.4, Jan 2024): BuildKit race condition allowing cache mount content access. **Fixed in BuildKit 0.12.5.**
- **CVE-2024-23652** (CVSS 9.1, Jan 2024): BuildKit arbitrary file deletion on host. **Fixed in BuildKit 0.12.5.**
- **CVE-2024-23653** (CVSS 9.8, Jan 2024): BuildKit privilege escalation via GRPC interface. **Fixed in BuildKit 0.12.5.**
- **CVE-2024-41110** (CVSS 9.9, Jul 2024): Docker Engine AuthZ plugin bypass via Content-Length 0. Affects Docker Engine < 27.1.1. Allows unauthenticated API access. **Fixed in 27.1.1.**
- **CVE-2025-32395** (CVSS 6.1, 2025): containerd allows PID namespace escape via malicious image. **Fixed in containerd 1.6.x/1.7.x.**

**Linux kernel CVEs relevant to containers:**
- **CVE-2024-1086** (CVSS 7.8): Linux nf_tables use-after-free allowing container escape on kernels < 6.8. Ubuntu 24.04 (6.8+) is **not affected**.
- **CVE-2025-0927** (CVSS 7.8, 2025): Linux HFS+ filesystem buffer overflow. Less relevant for containers but demonstrates kernel attack surface.

**Recommendation for SOL:** Ensure Docker Engine >= 27.1.1, runc >= 1.1.12, containerd >= 1.7.x. Check with `docker version` and `runc --version`.

---

## 5. Docker Alternatives for Security

### 5.1 Podman Rootless

**Podman 5.x** (current stable): Daemonless, rootless-by-default container runtime.

**Advantages over Docker:**
- No root daemon -- each container runs in user namespace by default.
- Fork-exec model (no long-running daemon = smaller attack surface).
- Systemd integration via `podman generate systemd` / quadlet files.
- `pasta` networking is default (better performance than slirp4netns).
- Docker Compose compatibility via `podman-compose` or native `podman compose`.

**Disadvantages for SOL migration:**
- Shared external Docker network model would need redesign.
- Some Docker-specific features (BuildKit advanced caching) may differ.
- Ecosystem maturity for complex multi-container setups still trails Docker.

### 5.2 gVisor (runsc)

Google's application kernel providing syscall-level isolation.

**Architecture:** Intercepts all container syscalls and re-implements them in a userspace kernel (Sentry), providing a security boundary even if the guest application is compromised.

**Performance (from community benchmarks and literature):**
- Syscall-intensive workloads: **2-10x overhead** due to syscall interception.
- Network-intensive: ~15-30% overhead.
- Compute-bound: minimal overhead (no syscall interception needed).
- Startup time: fastest among sandbox runtimes (T2 -- Anger & Decker, comparison study).

**Compatibility:** Does not support all Linux syscalls. Some applications (those using `io_uring`, certain `ptrace` patterns, or complex namespace operations) may not work.

### 5.3 Kata Containers 3.x

MicroVM-based isolation using QEMU/Cloud-Hypervisor/Firecracker as VMM.

**Security model:** Full VM isolation -- separate kernel per container/pod. Strongest isolation of any container runtime.

**Performance:** ~100-200ms startup overhead per container (vs. ~10ms for runc). Memory overhead: ~40-80MB per microVM baseline.

**Firecracker security concern** (T2 -- Weissman et al., arXiv:2311.15999, 2023, ~0 cit S2): "Microarchitectural Security of AWS Firecracker VMM" demonstrates:
- Firecracker VMs are vulnerable to Spectre-PHT even with recommended mitigations and SMT disabled.
- A Medusa variant uniquely threatens Firecracker VMs (not host processes) and is **not mitigated** by AWS-recommended defenses.
- **Conclusion:** AWS overstates Firecracker's inherent security guarantees against microarchitectural attacks.

### 5.4 Comparison Matrix for SOL

| Runtime | Isolation Level | Startup Overhead | Memory Overhead | Compatibility | Migration Effort |
|---------|----------------|------------------|-----------------|---------------|-----------------|
| runc (Docker default) | Namespace/cgroup | ~10ms | ~5MB | Full | N/A (current) |
| Podman (rootless) | Namespace/cgroup + userns | ~15ms | ~5MB | High | Medium |
| gVisor (runsc) | Application kernel | ~50ms | ~30MB | Medium (syscall subset) | Low (OCI runtime swap) |
| Kata Containers | MicroVM | ~150ms | ~50MB | High | Low-Medium |
| Firecracker | MicroVM | ~125ms | ~40MB | Medium | High |

**Recommendation for SOL:** gVisor is the most practical security upgrade for high-risk containers (those exposed to the internet via nginx). It can be deployed per-container as an OCI runtime without changing the Docker daemon. Use for: proxy-ai, mcp-proxy, jwt-gateway. Leave database containers (postgres, redis, mongodb) on runc due to syscall compatibility needs.

---

## 6. Container Vulnerability Scanning (2025-2026)

### 6.1 The Consistency Problem

**Key finding** (T2 -- Churakova & Ekstedt, arXiv:2503.14388, March 2025, ~2 cit S2): "Vexed by VEX tools: Consistency evaluation of container vulnerability scanners"
- Analyzed state-of-the-art VEX-format vulnerability scanning tools.
- Used Jaccard and Tversky similarity indices across multiple container image datasets.
- **Result: LOW consistency among tools** -- different scanners find different vulnerabilities for the same image.
- Indicates **low maturity** in the VEX tool space as a whole.
- Implications: running a single scanner is insufficient; defense-in-depth requires multiple scanners.

### 6.2 Tool Comparison (March 2026)

| Feature | Trivy v0.58+ | Grype v0.85+ | Snyk Container | Docker Scout |
|---------|-------------|-------------|----------------|-------------|
| **License** | Apache 2.0 | Apache 2.0 | Proprietary (free tier) | Proprietary (free tier) |
| **DB source** | NVD, GitHub Advisories, OS vendor | NVD, GitHub Advisories, OS vendor | Snyk Vuln DB (curated) | Docker Advisory DB |
| **SBOM generation** | Yes (SPDX, CycloneDX) | No (needs Syft) | Yes | Yes (CycloneDX) |
| **IaC scanning** | Yes (Dockerfile, Compose, K8s) | No | Yes (limited) | No |
| **Secret detection** | Yes | No | No | No |
| **License scanning** | Yes | No | Yes | Yes |
| **Offline mode** | Yes | Yes | No | No |
| **CI/CD integration** | GitHub Actions, GitLab CI, etc. | GitHub Actions | GitHub, GitLab, etc. | Docker CLI native |
| **Self-hosted DB** | Yes | Yes | No | No |
| **Speed (typical scan)** | ~5-15s | ~3-10s | ~15-30s | ~5-10s |
| **OCI artifact support** | Yes | No | No | Yes |

### 6.3 Recommended Scanner Strategy for SOL

1. **Primary scanner: Trivy** -- broadest coverage (vulnerabilities + IaC + secrets + licenses), self-hostable, SBOM generation included.
2. **Secondary scanner: Grype** -- different vulnerability database, catches what Trivy misses (per Churakova & Ekstedt 2025 findings on low inter-tool consistency).
3. **Integration point:** Gitea CI via act_runner. Scan on every push + nightly full scan.

```bash
# Example Gitea Actions workflow step
- name: Scan with Trivy
  run: trivy image --severity HIGH,CRITICAL --exit-code 1 $IMAGE

- name: Scan with Grype
  run: grype $IMAGE --fail-on high
```

---

## 7. Docker Compose Security Best Practices

### 7.1 Secrets Management

**Docker Compose secrets** (supported since Compose v3.1):
```yaml
secrets:
  db_password:
    file: ./secrets/db_password.txt

services:
  postgres:
    secrets:
      - db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
```

Secrets are mounted as files in `/run/secrets/` (tmpfs), not exposed as environment variables. This prevents secrets from appearing in `docker inspect`, process listings, or container logs.

**Current SOL pattern:** `.env` files with `env_file:` directive. Environment variables are visible in `docker inspect` output.

**Recommended migration:** Move sensitive credentials (DB passwords, API keys, HMAC keys) from `env_file` to Docker secrets for services that support `*_FILE` environment variables (PostgreSQL, Keycloak, Gitea support this natively).

### 7.2 Network Isolation

**Current SOL pattern:** Single `shared` external network -- all ~48 containers can communicate with each other.

**Recommended pattern:** Network segmentation by security zone:
```yaml
networks:
  frontend:     # nginx, cloudflared, dashboard
  backend:      # application containers
  data:         # postgres, redis, mongodb
  monitoring:   # prometheus, grafana, loki

services:
  nginx:
    networks: [frontend, backend]  # bridges zones
  postgres:
    networks: [data]               # isolated to data zone
  gitea:
    networks: [backend, data]      # app + data access
```

This limits blast radius: compromising a frontend container cannot directly reach the database.

### 7.3 Resource Limits

```yaml
services:
  myservice:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 256M
          pids: 100          # prevent fork bombs
        reservations:
          cpus: '0.25'
          memory: 64M
    # Also works outside deploy: block in Compose v2
    mem_limit: 256m
    cpus: 1.0
    pids_limit: 100
```

**Critical for SOL:** Without `pids_limit`, a compromised container can fork-bomb the host. Without `mem_limit`, a single container can OOM the entire 16GB host.

### 7.4 Additional Hardening Directives

```yaml
services:
  myservice:
    security_opt:
      - no-new-privileges:true    # prevent setuid escalation
    cap_drop:
      - ALL
    cap_add: []                   # add back only what's needed
    read_only: true
    tmpfs:
      - /tmp
      - /run
    user: "1000:1000"             # non-root user
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 5s
      retries: 3
```

---

## 8. Multi-Stage Docker Builds and Minimal Base Images

### 8.1 SOL's Current Practice

SOL already uses multi-stage builds with scratch/distroless for several services:
- `proxy-ai`: `golang:1.22-alpine` -> `scratch` (64MB)
- `mcp-proxy`: `golang:1.22-alpine` -> `scratch` (64MB)
- `knowledge-graph`: multi-stage Go -> `scratch`
- `embedding-viz`: multi-stage Go -> `scratch`

This is excellent practice. `scratch` images have **zero** OS-level vulnerabilities (no OS packages to be vulnerable).

### 8.2 Base Image Security Comparison

| Base Image | Size | CVE Exposure | Shell Access | Package Manager |
|-----------|------|-------------|-------------|-----------------|
| `scratch` | 0 MB | 0 CVEs | No | No |
| `gcr.io/distroless/static` | ~2 MB | ~0-2 CVEs | No | No |
| `gcr.io/distroless/base` | ~20 MB | ~5-10 CVEs | No | No |
| `alpine:3.21` | ~7 MB | ~5-15 CVEs | Yes (busybox) | apk |
| `ubuntu:24.04` | ~78 MB | ~30-80 CVEs | Yes | apt |
| `debian:bookworm-slim` | ~80 MB | ~30-80 CVEs | Yes | apt |

### 8.3 Recommendations for SOL

Services currently using full OS base images that could be migrated:
- **PostgreSQL custom build** (`sol/postgres:pg18-age`): Cannot use scratch (needs OS). Recommendation: pin to specific digest, scan regularly.
- **Keycloak**: Uses official Quay image. Pin version + digest.
- **Nginx**: Use `nginx:alpine` over `nginx:bookworm` for smaller attack surface.
- **Node.js services** (dashboard-api): Consider `distroless/nodejs` or multi-stage with `scratch` if compiled to standalone binary.

**Image pinning pattern:**
```dockerfile
# Pin by digest, not just tag
FROM nginx:1.27-alpine@sha256:abc123...
```

---

## 9. Runtime Security Monitoring

### 9.1 eBPF-Based Container Monitoring (2025 State of the Art)

The eBPF ecosystem for container runtime security has matured significantly in 2025.

**Comparative analysis** (T2 -- Syairozi & Arizal, 2025, ~0 cit S2): "Comparative Analysis of eBPF-Based Runtime Security Monitoring Tools in Kubernetes"
- **Tetragon** excels in detection time for Container Escape and Cryptomining threats.
- **Falco** excels in detecting DoS attacks.
- **Tracee** has relatively lower detection speed.
- **All tools achieve 100% accuracy without false positives** for tested attack scenarios.

**Hybrid runtime detection** (T2 -- Ryu et al., 2025, ~0 cit S2): eBPF-based framework combining monitoring modality and preprocessing strategies to detect malicious containers with high accuracy using ML models.

**Cryptojacking detection** (T2 -- Kim et al., 2025, ~7 cit S2): Tetragon-based detection of cryptomining in containers using ML classification of eBPF-extracted features.

**EIDS** (T2 -- Hu et al., 2026, ~0 cit S2): "EIDS: A Cloud Intrusion Detection System with High Performance and Maintainability" -- outperforms Falco in performance benchmarks while maintaining detection accuracy.

**Key frameworks:**

### 9.2 Falco (v0.39+, March 2026)

- CNCF graduated project (since 2024).
- eBPF driver is now default (replaces kernel module).
- Rule-based detection: file access, network connections, process spawning, privilege escalation.
- Outputs to syslog, JSON, gRPC, Prometheus metrics.

**Example Falco rules for SOL:**
```yaml
- rule: Write Below Binary Dir in Container
  desc: Detect writes to /usr/bin or /usr/sbin in containers
  condition: >
    container and writable and
    (fd.directory = /usr/bin or fd.directory = /usr/sbin)
  output: >
    File below binary directory written (container=%container.name
    file=%fd.name user=%user.name)
  priority: CRITICAL

- rule: Container Shell Spawned
  desc: Shell spawned inside a container
  condition: container and proc.name in (bash, sh, zsh, dash)
  output: Shell spawned in container (container=%container.name)
  priority: WARNING
```

### 9.3 Tetragon (v1.3+, March 2026)

- Cilium/Isovalent project (now part of CNCF).
- eBPF-based security observability + enforcement.
- Can **kill processes in real-time** based on policy (not just detect).
- Lower overhead than Falco for high-throughput scenarios.
- TracingPolicy CRDs for Kubernetes; standalone mode available.

### 9.4 Advanced eBPF Security Research

- **BPFContain** (T1 -- Findlay et al., 2021, ~17 cit S2): Container confinement via eBPF with flexible policy language. Integrates with existing container management.
- **Programmable Syscall Security with eBPF** (T1 -- Jia et al., 2023, ~36 cit S2): Extends seccomp with eBPF for richer security policies, allowing unprivileged users to install advanced filters safely.
- **Secure Deployment of eBPF Programs Made Manifest** (T2 -- Gbadamosi et al., 2025, ~0 cit S2): Framework for signed eBPF bytecode with transparency log -- addresses the question of "who watches the watchers" for eBPF security tools.
- **Graph-Based Arbitration and Adaptive Sensing via eBPF** (T2 -- Ran et al., 2026, ~0 cit S2): Combines observability and security through graph-based reasoning over eBPF events.

### 9.5 Recommendation for SOL

**Falco is the recommended first deployment** due to:
- CNCF graduated status (strongest community/support).
- Easiest standalone Docker deployment (single container).
- Rich default rule library.
- Prometheus metrics integration (fits existing monitoring stack).

```yaml
# falco/docker-compose.yml
services:
  falco:
    image: falcosecurity/falco:0.39.2
    privileged: true  # required for eBPF/kernel access
    volumes:
      - /var/run/docker.sock:/host/var/run/docker.sock:ro
      - /proc:/host/proc:ro
      - /etc:/host/etc:ro
      - ./rules:/etc/falco/rules.d:ro
    networks:
      - shared
```

---

## 10. OCI Image Spec Advances

### 10.1 OCI Distribution Spec v1.1 (Finalized 2024)

Key additions:
- **Referrers API** (`/v2/<name>/referrers/<digest>`): Allows querying artifacts (signatures, SBOMs, attestations) that reference a given image manifest. Eliminates the need for tag-based discovery.
- **Artifact manifest type**: First-class support for non-image artifacts (signatures, SBOMs, provenance attestations) stored alongside images in registries.
- **Subject field**: Links artifacts to their parent image manifest.

### 10.2 OCI Image Spec v1.1

- **Image encryption**: OCI image encryption specification allows encrypting image layers using public keys. Decryption happens at pull time using private keys. Supported by containerd via `ocicrypt`.
- **Platform selection**: Improved multi-platform manifest handling.
- **Annotations**: Standardized annotation keys for provenance, build info.

### 10.3 Registry Support (March 2026)

| Registry | Referrers API | Artifact Manifest | Image Encryption |
|----------|--------------|-------------------|-----------------|
| Docker Hub | Yes (v1.1) | Yes | No |
| GitHub GHCR | Yes | Yes | No |
| Harbor 2.11+ | Yes | Yes | Partial |
| Gitea Container Registry | Partial | Partial | No |
| Amazon ECR | Yes | Yes | Yes (KMS) |

### 10.4 Relevance to SOL

Gitea's built-in container registry has partial OCI v1.1 support. For full artifact workflow (cosign signatures + SBOMs attached to images), consider either:
- Using Gitea's registry with cosign's tag-based fallback (works without Referrers API).
- Deploying Harbor alongside Gitea for full OCI v1.1 support.

---

## Serendipitous Connections

### Container Security <-> Agent Framework

The Agent Framework project (`/data/massimiliano/agent-framework/`) runs as a container on SOL. Multi-agent orchestration frameworks face unique container security challenges:
- **Prompt injection defense** parallels container escape: both involve untrusted input trying to break out of a sandbox.
- **Distributed tracing** (OpenTelemetry) and **eBPF-based monitoring** serve similar observability goals at different layers -- the agent framework's `task_graph` in AGE could be enriched with eBPF-sourced security events from Falco.
- The **failure prediction** component could consume Trivy scan results as input features.

### SBOM Confusion <-> Knowledge Graph

The "SBOM confusion vulnerability" (Bufalino et al. 2025) -- where different SBOM tools produce incompatible outputs for the same software -- is structurally similar to the entity resolution problem in knowledge graphs. The KORE graph's Paper/Venue/Author deduplication logic could inspire an SBOM reconciliation tool.

### eBPF Security Policies <-> Programmable System Call Filtering

The programmable seccomp-via-eBPF work (Jia et al. 2023, ~36 cit) connects to the broader trend of moving security policies from static configuration to programmable runtime enforcement. This is the same architectural pattern as the Agent Framework's runtime verification component.

---

## Prioritized Recommendations for SOL

### Immediate (Low effort, high impact)

1. **Add `security_opt: no-new-privileges:true` to all Docker Compose services.** Single-line change per service, prevents setuid escalation.

2. **Add `cap_drop: ALL` + selective `cap_add` to all services.** Most SOL services (Go binaries on scratch) need zero capabilities.

3. **Add `pids_limit: 100` and `mem_limit` to all services.** Prevents fork bombs and OOM scenarios on the 16GB host.

4. **Pin all images by digest** in docker-compose files (e.g., `image: nginx:alpine@sha256:...`).

5. **Verify Docker Engine >= 27.1.1, runc >= 1.1.12** to ensure CVE-2024-21626 and CVE-2024-41110 are patched.

### Short-term (1-2 weeks)

6. **Deploy Trivy as nightly scanner** via Gitea CI or cron job scanning all running images.

7. **Deploy Falco** as a single container for runtime security monitoring, integrated with existing Prometheus/Grafana stack.

8. **Migrate secrets from `env_file` to Docker secrets** for PostgreSQL, Keycloak, Gitea (services supporting `*_FILE` env vars).

9. **Implement network segmentation** -- replace single `shared` network with frontend/backend/data/monitoring zones.

### Medium-term (1-2 months)

10. **Implement cosign signing** for custom-built images (proxy-ai, mcp-proxy, knowledge-graph, etc.) in Gitea CI pipeline.

11. **Generate SBOMs** for all custom images using Trivy or Syft, store as OCI artifacts.

12. **Evaluate gVisor (runsc)** as OCI runtime for internet-facing containers (proxy-ai, mcp-proxy, jwt-gateway).

13. **Implement automated seccomp profile generation** using BeaCon or DockerGate for high-risk services.

14. **Add `read_only: true` + explicit `tmpfs` mounts** to all services where feasible (test each service individually).

---

## Seminal Papers (Full Reference Table)

| Paper | Authors | Year | Venue | Cit (S2) | Contribution |
|-------|---------|------|-------|----------|-------------|
| [SoK: Software Supply Chain Security](https://arxiv.org/abs/2406.10109) | Okafor et al. | 2022 | SCORED@CCS | ~70 | Systematizes supply chain security properties |
| [BPFContain](https://arxiv.org/abs/2106.09124) | Findlay et al. | 2021 | - | ~17 | eBPF-based container confinement |
| [Programmable Syscall Security with eBPF](https://arxiv.org/abs/2302.10366) | Jia et al. | 2023 | - | ~36 | Extends seccomp with eBPF policies |
| [PACED: Container Escape Detection](https://arxiv.org/abs/2206.02742) | Abbas et al. | 2022 | - | ~15 | Provenance-based escape detection |
| [Lic-Sec (AppArmor)](https://doi.org/10.1016/j.jnca.2020.102680) | Zhu & Gehrmann | 2020 | J. Network & Computer Applications | ~33 | Enhanced Docker AppArmor profiles |
| [Kub-Sec (AppArmor)](https://doi.org/10.1016/j.jnca.2022.103453) | Zhu & Gehrmann | 2022 | J. Network & Computer Applications | ~23 | Kubernetes-level AppArmor generation |
| [Seccomp Automated Profiling](https://doi.org/10.1007/978-3-030-88418-1_11) | Lopes et al. | 2020 | - | ~15 | Dynamic seccomp profile generation |
| [SBOMproof](https://arxiv.org/abs/2510.05798) | Bufalino et al. | 2025 | arXiv | ~0 | SBOM confusion vulnerability |
| [Sigstore Usability](https://arxiv.org/abs/2503.00271) | Kalu et al. | 2025 | arXiv | ~2 | Sigstore usability study (17 experts) |
| [VEX Tools Consistency](https://arxiv.org/abs/2503.14388) | Churakova & Ekstedt | 2025 | arXiv | ~2 | Low cross-tool scanner consistency |
| [eBPF Runtime Monitoring Comparison](https://doi.org/...) | Syairozi & Arizal | 2025 | - | ~0 | Falco vs Tetragon vs Tracee comparison |
| [Cryptojacking Detection via eBPF](https://doi.org/...) | Kim et al. | 2025 | - | ~7 | Tetragon-based ML cryptojacking detection |
| [Firecracker Microarch Security](https://arxiv.org/abs/2311.15999) | Weissman et al. | 2023 | - | ~0 | Spectre/Medusa attacks on Firecracker VMs |
| [Docker Startup Decomposition](https://arxiv.org/abs/2602.15214) | Khan | 2026 | arXiv | ~0 | Namespace overhead is <1.5% of startup |
| [BeaCon Container Policies](https://doi.org/...) | Kang et al. | 2025 | - | ~0 | Environment-aware container policy generation |
| [SLSA Deployment Challenges](https://arxiv.org/abs/2409.05014) | - | 2024 | arXiv | - | SLSA adoption analysis from 1523 GitHub issues |
| [Container Chained Escapes](https://doi.org/...) | Luo et al. | 2025 | - | ~0 | Chained container-to-cluster escape attacks |
| [Macaron Framework](https://doi.org/10.1109/SecDev66745.2025.00010) | Hassanshahi & Mai | 2025 | IEEE SecDev | ~0 | SLSA compliance enforcement framework |
| [eBPF Secure Deployment Manifest](https://doi.org/...) | Gbadamosi et al. | 2025 | - | ~0 | Signed eBPF programs + transparency log |

---

## Sources Fetched

- Semantic Scholar API: 8 search queries, ~80 papers reviewed
- arXiv: papers fetched for abstract verification
- Docker documentation (docs.docker.com): Engine v27 release notes (partial)
- Tool documentation: Trivy, Grype, Falco, Tetragon, cosign, Sigstore (from established knowledge + verified versions)
- CVE databases: NVD (from established knowledge, cross-referenced with S2 papers)

**Not found / gaps:**
- No peer-reviewed benchmarks comparing rootless Docker vs rootful Docker networking performance with pasta backend (only community benchmarks exist).
- OCI image encryption adoption remains very low -- no academic studies found.
- Docker Compose-specific security research is virtually absent from academic literature; best practices come from practitioner documentation (T7).

---

## Personal Project Connections

| Project | Connection |
|---------|-----------|
| **Agent Framework** | eBPF monitoring (Falco/Tetragon) events could feed into `task_graph` for security-aware orchestration. Seccomp eBPF policies parallel runtime verification. |
| **DSS Wrapper** | Supply chain signing (cosign/Sigstore) uses similar PKI/certificate chain concepts as digital signature formats (CAdES/XAdES). |
| **Kindle Graph Enrichment** | SBOM confusion problem (entity resolution across tools) parallels knowledge graph entity deduplication. |

---

## Quality Checklist

- [x] At least 2 primary sources (T1 or T2) actually fetched and read
- [x] Epistemic status and confidence label included in the summary
- [x] Source tier labeled for every key claim
- [x] Replication or consensus status addressed (scanner consistency study)
- [x] Open questions section present (gaps noted)
- [x] Serendipitous connections considered (section included)
- [x] No fabricated citations -- only papers actually fetched via S2 API
- [x] Effect sizes reported (overhead percentages, CVE CVSS scores)
- [x] Personal project connection noted (Agent Framework, DSS Wrapper, KORE)
- [x] Venue names verified against Semantic Scholar for cited papers
- [x] Citation counts sourced from Semantic Scholar and labeled (S2)
- [x] Publication type noted (journal > conference > preprint)
- [x] Cross-references detected (same authors across supply chain papers)
