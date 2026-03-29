# Research Summary: Best Linux Distribution for Local LLM Inference on NVIDIA RTX 3090

## Executive Summary

**Ubuntu 24.04 LTS is the clear first choice** for a self-hosted LLM inference server with NVIDIA RTX 3090, Ollama in Docker, and dual-boot with Windows. It is the distribution that NVIDIA, Ollama, vLLM, Lambda Labs, and virtually every GPU cloud provider standardizes on. No other distro comes close in terms of combined driver support maturity, container toolkit testing, community documentation density, and production track record.

The second tier (Debian 12, Rocky Linux 9, Fedora) are all viable but involve meaningful trade-offs in either documentation availability, driver freshness, or container toolkit testing coverage.

**Epistemic status:** Strong consensus across industry and community sources
**Confidence:** High -- convergent evidence from NVIDIA official docs, GPU cloud providers, inference framework docs, and practitioner guides (T1/T7 mix)

---

## Ranked Recommendations

### 1. Ubuntu 24.04 LTS (Noble Numbat) -- STRONG RECOMMENDATION

**Why it wins across every dimension:**

- **NVIDIA official Tier-1 support**: nvidia-container-toolkit tested on Ubuntu 20.04, 22.04, 24.04 on both x86_64 and arm64 (T1 -- [NVIDIA Container Toolkit Supported Platforms](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/supported-platforms.html))
- **GPU cloud industry standard**: Lambda Labs runs Lambda Stack on Ubuntu (20.04/22.04/24.04 LTS). Lambda's on-demand cloud instances default to Ubuntu 22.04 LTS. CoreWeave, RunPod, and Vast.ai all use Ubuntu as their primary or default OS (T7 -- [Lambda Stack](https://lambda.ai/lambda-stack-deep-learning-software))
- **Ollama reference platform**: The most detailed RTX 3090 + Ollama + Docker guide is tested on Ubuntu 24.04.3 LTS, achieving 80-97% GPU utilization and 17-90 tok/s (T7 -- [llm_on_rtx_3090](https://github.com/keturk/llm_on_rtx_3090))
- **vLLM requirement**: vLLM requires "64-bit Linux with GLIBC >= 2.31" -- Ubuntu 24.04 ships GLIBC 2.39, well above the minimum. All vLLM Docker images are Ubuntu-based (T7 -- [vLLM Installation](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/))
- **Driver installation**: `ubuntu-drivers autoinstall` handles Secure Boot signing automatically. NVIDIA 570-open and 575 drivers available in official repos (T7 -- [Ubuntu NVIDIA 575 Driver](https://ubuntuhandbook.org/index.php/2025/07/ubuntu-adding-nvidia-575-driver-support-for-24-04-22-04-lts/))
- **Dual-boot**: The most tested and documented dual-boot scenario with Windows. GRUB handles it natively
- **Kernel**: Ships 6.8 (HWE upgrades available to 6.11+). NVIDIA open kernel modules support kernels 4.15+, so this is never a constraint (T7 -- [NVIDIA Open GPU Kernel Modules](https://eunomia.dev/blog/2025/10/14/nvidia-open-gpu-kernel-modules-comprehensive-source-code-analysis/))
- **Community**: Largest body of troubleshooting resources for NVIDIA + Docker + LLM inference issues

**Known issues:**
- Occasional NVIDIA driver conflicts after kernel updates (solvable with `ubuntu-drivers` or pinning)
- Snap-based packages can conflict with Docker workflows (disable snap for ollama if using Docker deployment)

**Verdict:** If you want the path of least resistance and maximum compatibility, this is it.

### 2. Debian 12 (Bookworm) -- VIABLE BUT LESS CONVENIENT

- **NVIDIA support**: Listed in nvidia-container-toolkit supported platforms (Debian 11 explicitly; Debian 12 works via same repo)
- **Stability**: Conservative base, great for servers. Kernel 6.1 LTS
- **Trade-offs**: NVIDIA drivers require adding non-free repos. Less automated driver installation than Ubuntu. Fewer RTX 3090 + Ollama guides exist for Debian specifically
- **Container toolkit**: Works, but Ubuntu gets more testing

**When to choose Debian:** If you strongly prefer a minimalist, no-snap, no-corporate-addon base and are comfortable managing NVIDIA drivers manually.

### 3. Rocky Linux 9 / AlmaLinux 9 -- ENTERPRISE-GRADE

- **NVIDIA support**: RHEL 9.x is in the nvidia-container-toolkit supported platforms table. Rocky/Alma are binary-compatible
- **Production pedigree**: Red Hat used RHEL 9.6 for MLPerf Inference v5.1 benchmarks, achieving reproducible high-throughput LLM inference (T7 -- [Red Hat MLPerf](https://www.redhat.com/en/blog/efficient-and-reproducible-llm-inference-red-hat-mlperf-inference-v51-results))
- **Trade-offs**: Older packages (kernel 5.14), requires EPEL for many utilities. Fewer community guides for single-GPU home server setups. CUDA installation well-documented but more manual
- **Container toolkit**: Supported. Uses `dnf install cuda-drivers`

**When to choose Rocky:** If you are building infrastructure that mirrors enterprise/datacenter patterns and want SELinux hardening out of the box. Overkill for a single-GPU home server.

### 4. Fedora 40/41/42 -- CUTTING EDGE, MORE FRICTION

- **NVIDIA support**: NVIDIA supports "the latest Fedora release version" for CUDA. nvidia-container-toolkit not explicitly listed in supported platforms table but works via RPM Fusion
- **Performance claim**: One source claims inference runs ~20% faster on Fedora 43 vs Windows 11, but this is a single unverified community claim (T7 -- [Talentelgia](https://www.talentelgia.com/blog/top-5-linux-distro-for-ai/))
- **Trade-offs**: Rolling kernel updates can break NVIDIA driver compatibility (documented Fedora 41 performance regression with newer kernels). Shorter support lifecycle (13 months per release). RPM Fusion required for proprietary drivers
- **Reported issue**: "Low performance in newer kernels" thread on NVIDIA forums specifically mentions Fedora 41 (T7 -- [NVIDIA Forums](https://forums.developer.nvidia.com/t/low-performance-in-newer-kernels/327952))

**When to choose Fedora:** If you want the absolute latest kernel features and are willing to debug occasional driver breakage after updates. Not ideal for a "set and forget" inference server.

### 5. openSUSE Leap 15.x -- VIABLE BUT NICHE

- **NVIDIA support**: Open Suse/SLES 15.x listed in nvidia-container-toolkit supported platforms (x86_64 only)
- **Trade-offs**: Smallest community for ML/LLM workloads. Fewest guides and troubleshooting resources. YaST is powerful but unfamiliar to most ML practitioners

**When to choose openSUSE:** If you already run a SUSE shop. Otherwise, no compelling advantage.

### 6. NixOS -- NOT RECOMMENDED FOR THIS USE CASE

- **Critical issues**: Multiple open bugs with nvidia-container-toolkit on NixOS 25.05 and 25.11:
  - `docker --gpus all` fails with "could not select device driver '' with capabilities: [[gpu]]" ([NixOS/nixpkgs#419597](https://github.com/nixos/nixpkgs/issues/419597))
  - NVIDIA runtime works with Podman but NOT Docker ([NixOS/nixpkgs#337873](https://github.com/NixOS/nixpkgs/issues/337873))
  - Configuration API changed: `virtualisation.docker.enableNvidia` deprecated for `hardware.nvidia-container-toolkit.enable`, but the new API has bugs
  - Many Docker Compose files (including Ollama's) rely on nvidia runtime method, which is broken on NixOS
- **Reproducibility is great in theory** but NVIDIA's proprietary stack fundamentally conflicts with NixOS's declarative model

**Verdict:** Avoid for GPU inference. The NVIDIA+Docker integration is actively broken on recent NixOS versions.

### 7. Fedora Silverblue / Immutable Distros -- VIABLE BUT EXTRA COMPLEXITY

- **Status**: NVIDIA GPU in containers works via Container Device Interface (CDI) on Silverblue
- **Trade-offs**: Requires `rpm-ostree` layering for NVIDIA drivers (non-trivial). The immutable model adds conceptual overhead for a system whose primary job is running Docker containers (which are already immutable)
- **Practical note**: If your entire workload runs in Docker anyway, the host OS immutability adds little value -- the containers themselves provide isolation

**Verdict:** Possible, but solving a problem you don't have. The containerized Ollama already gives you reproducibility.

---

## Comparison Table

| Distro | NVIDIA Driver Support | nvidia-container-toolkit | Kernel | LLM Community Docs | Dual-Boot | Production Use | Recommendation |
|--------|----------------------|--------------------------|--------|--------------------|-----------|--------------|----|
| **Ubuntu 24.04 LTS** | Tier 1 (official repos, auto-install, Secure Boot) | Officially tested | 6.8 (HWE to 6.11+) | Extensive | Excellent | Lambda, AWS, GCP, RunPod | **FIRST CHOICE** |
| Debian 12 | Good (non-free repos required) | Supported (Debian 11 tested) | 6.1 LTS | Moderate | Good | Server-focused orgs | Good if you prefer minimalism |
| Rocky Linux 9 | Good (RHEL-compatible) | Officially tested (RHEL 8/9/10) | 5.14 | Limited for home use | OK | Enterprise, Red Hat MLPerf | Overkill for single GPU |
| Fedora 41/42 | Good (RPM Fusion) | Works but not in official table | 6.11-6.12 | Growing | Good | Some enthusiasts | Risk of driver breakage |
| openSUSE Leap 15 | Supported (x86_64 only) | Officially tested | 5.14/6.4 | Sparse | OK | SUSE shops | No compelling advantage |
| NixOS | Problematic | Actively broken (Docker) | Latest | Growing but niche | Complex | Not recommended | **AVOID** |
| Fedora Silverblue | Works (rpm-ostree layer) | Via CDI | Latest | Minimal | Complex | Niche | Unnecessary complexity |

---

## Answers to Specific Questions

### Q1: What do NVIDIA, Ollama, and LLM inference providers officially support?

- **NVIDIA**: Ubuntu 20.04/22.04/24.04, RHEL 8/9/10, Debian 11, Amazon Linux 2/2023, openSUSE/SLES 15.x, CentOS 8 (T1 -- NVIDIA official docs)
- **Ollama**: No explicit distro requirement; Docker image is the primary deployment. All guides/testing done on Ubuntu (T7 -- Ollama docs)
- **vLLM**: "64-bit Linux, GLIBC >= 2.31". Docker images are Ubuntu-based. Docs/guides target Ubuntu 22.04/24.04 (T7 -- vLLM docs)
- **TGI (HuggingFace)**: Docker-first deployment. Base images are Ubuntu. No explicit distro restriction
- **llama.cpp**: Compiles on anything with a C++ compiler. Distro-agnostic. But CUDA builds are most tested on Ubuntu

### Q2: What do production GPU clusters use?

- **Lambda Labs**: Ubuntu (20.04/22.04/24.04 LTS). Lambda Stack is Ubuntu-only
- **CoreWeave**: Kubernetes on Ubuntu (inferred from their container orchestration stack)
- **RunPod**: Ubuntu-based templates as default
- **Vast.ai**: Ubuntu-based images as primary
- **AWS Deep Learning AMI**: Ubuntu 22.04/24.04
- **Red Hat/MLPerf**: RHEL 9.6 for benchmarking (enterprise path)

**Consensus: Ubuntu dominates the GPU cloud industry.**

### Q3: NVIDIA driver support comparison

| Distro | Installation Method | Auto Secure Boot | Driver Freshness | Pain Level |
|--------|-------------------|------------------|-----------------|------------|
| Ubuntu 24.04 | `ubuntu-drivers autoinstall` | Yes | 570-open, 575 in repos | Low |
| Debian 12 | Manual (non-free repo + apt) | No (manual MOK) | Slightly behind Ubuntu | Medium |
| Fedora 41 | RPM Fusion + dnf | Partial (akmod) | Latest (sometimes too new) | Medium-High |
| Rocky Linux 9 | `dnf install cuda-drivers` | RHEL-like, manual | Conservative | Medium |
| openSUSE Leap | One-Click Install / zypper | Partial | Conservative | Medium |

### Q4: Container toolkit support

Ubuntu 24.04 is in the "officially tested" matrix for nvidia-container-toolkit on x86_64, ppc64le, AND arm64. RHEL 8/9/10 are also officially tested. Debian, Fedora, and openSUSE work but with less explicit testing coverage.

### Q5: Known issues with RTX 3090 + Docker + Ollama

- **Docker GPU runtime misconfiguration**: Using `deploy: resources: reservations: devices` syntax sometimes fails. Fix: use `runtime: nvidia` with `NVIDIA_VISIBLE_DEVICES=all` instead (T7 -- [llm_on_rtx_3090](https://github.com/keturk/llm_on_rtx_3090))
- **GPU initialization failures**: Reported on Ubuntu and other distros. Usually a driver version mismatch (T7 -- [Ollama GitHub #7593](https://github.com/ollama/ollama/issues/7593))
- **Maximum model size**: 32B parameters at Q4 quantization. 70B+ causes CPU offloading. Your planned Qwen3.5-27B at Q4 should fit in 24GB VRAM
- **GPU detection loss after driver update**: Reported on Ubuntu 20.04, fixed by reinstalling drivers (T7 -- [Ollama GitHub #9842](https://github.com/ollama/ollama/issues/9842))

These issues are **distro-agnostic** -- they stem from NVIDIA driver/CUDA/container-toolkit version mismatches, not from the OS itself.

### Q6: Does kernel version matter for GPU inference performance?

**Short answer: No, not significantly.**

- NVIDIA's open kernel modules support kernels 4.15+ (T7 -- NVIDIA docs). Performance differences between kernel versions are negligible for GPU inference
- The inference compute happens on the GPU; the kernel's role is limited to memory management, PCIe communication, and scheduling -- all well-optimized across modern kernels
- **One exception**: Very new kernels (Fedora bleeding edge) can cause **regressions** due to incompatibility with NVIDIA's proprietary driver stack. A stable kernel (Ubuntu 6.8, Debian 6.1) is actually preferable
- Performance optimization happens in the CUDA/TensorRT/inference runtime layer, not in the kernel

**The kernel matters for stability, not performance. A stable LTS kernel is better than the latest.**

### Q7: NixOS and immutable distros

- **NixOS**: Actively broken for Docker + NVIDIA GPU. Multiple open issues on nixpkgs (2025-2026). Works with Podman but not Docker. Since Ollama Docker images expect Docker runtime, this is a dealbreaker
- **Fedora Silverblue**: Technically viable via CDI method, but adds unnecessary complexity. Your workload is already containerized (Ollama in Docker), so host immutability provides minimal additional value
- **Verdict**: Neither is recommended for this use case

---

## VRAM Planning: Your Specific Models

| Model | Parameters | Quantization | Estimated VRAM | Fits RTX 3090 (24GB)? |
|-------|-----------|-------------|----------------|----------------------|
| Qwen3-Embedding-8B | 8B | FP16 | ~16 GB | Yes |
| Qwen3-Reranker-4B | 4B | FP16 | ~8 GB | Yes |
| Qwen3.5-27B | 27B | Q4_K_M | ~16-18 GB | Yes (tight) |
| Qwen3.5-27B | 27B | Q5_K_M | ~20-22 GB | Marginal |
| Qwen3.5-27B | 27B | FP16 | ~54 GB | No (CPU offload) |

**Important**: You cannot run all three models simultaneously. Ollama loads/unloads models on demand. With `OLLAMA_NUM_PARALLEL=1` and sequential model loading, this setup works well. The 64GB system RAM provides good overflow capacity.

---

## Serendipitous Connections

**Connection to Server SOL architecture**: Your existing Server SOL runs Ubuntu 24.04 with Docker on a `shared` network. Using the same distro on the new inference server means:
- Identical nvidia-container-toolkit installation procedure
- Same Docker Compose patterns (runtime: nvidia)
- Ollama container can join the same Tailscale network and be accessed via `proxy-ai` reverse proxy
- The MCP `web_fetch` smart extractors already support Semantic Scholar/arXiv/OpenAlex -- the embedding models (Qwen3-Embedding-8B) could replace or augment the current `mxbai-embed-large` via Ollama on the new server
- If you later want to run vLLM instead of Ollama, Ubuntu 24.04 is also the reference platform

**Connection to Ranking Todo project**: The Bradley-Terry preference model computations are CPU-bound, but if you ever move to neural preference models, the same NVIDIA GPU + Docker setup would serve that workload too.

---

## Final Recommendation

**Install Ubuntu 24.04.2 LTS (Server edition, minimal install).**

Specific setup sequence:
1. Install Ubuntu 24.04 alongside Windows (UEFI, separate partitions, GRUB bootloader)
2. `sudo ubuntu-drivers autoinstall` (handles Secure Boot automatically)
3. Install Docker Engine (not Docker Desktop, not snap)
4. Install nvidia-container-toolkit from NVIDIA's apt repo
5. Deploy Ollama via Docker Compose with `runtime: nvidia`
6. Connect to Tailscale
7. Pull models: `ollama pull qwen3-embedding-8b`, etc.

This is the most documented, most tested, most supported path. Every component in this stack -- NVIDIA drivers, container toolkit, Docker, Ollama, Tailscale -- has Ubuntu 24.04 as its primary or reference platform.

---

## Sources

### T1 -- Official Documentation
- [NVIDIA Container Toolkit Supported Platforms](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/supported-platforms.html)
- [NVIDIA Container Toolkit Installation Guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
- [NVIDIA Driver Installation Guide r595](https://docs.nvidia.com/datacenter/tesla/pdf/Driver_Installation_Guide.pdf)
- [CUDA Installation Guide for Linux](https://docs.nvidia.com/cuda/pdf/CUDA_Installation_Guide_Linux.pdf)
- [vLLM GPU Installation](https://docs.vllm.ai/en/stable/getting_started/installation/gpu/)
- [Ollama Docker Documentation](https://docs.ollama.com/docker)
- [Red Hat MLPerf Inference v5.1 Results](https://www.redhat.com/en/blog/efficient-and-reproducible-llm-inference-red-hat-mlperf-inference-v51-results)

### T5/T7 -- Practitioner Guides and Community
- [llm_on_rtx_3090 -- Battle-tested guide for Ubuntu 24.04 + RTX 3090 + Ollama](https://github.com/keturk/llm_on_rtx_3090)
- [Lambda Stack Deep Learning Software](https://lambda.ai/lambda-stack-deep-learning-software)
- [Ubuntu 24.04 + NVIDIA Drivers + Ollama](https://projectable.me/ubuntu-24-04-nvidia-drivers-ollama/)
- [Ollama Ubuntu 24.04 NVIDIA Install: Driver Pitfalls](https://itecsonline.com/post/ollama-ubuntu-nvidia)
- [vLLM on Ubuntu 24.04](https://itecsonline.com/post/vllm-ubuntu-install)
- [Top Linux Distros for NVIDIA Support](https://simeononsecurity.com/articles/the-best-linux-distros-with-nvidia-support/)
- [Ubuntu NVIDIA 575 Driver Support](https://ubuntuhandbook.org/index.php/2025/07/ubuntu-adding-nvidia-575-driver-support-for-24-04-22-04-lts/)
- [Turning Ubuntu Into a Local AI Workstation](https://innovops.medium.com/turning-ubuntu-into-a-local-ai-workstation-nvidia-rtx-ollama-08ac2f27834a)
- [Deploying Open Language Models on Ubuntu](https://ubuntu.com/blog/deploying-open-language-models-on-ubuntu)

### T7 -- Community Forums and Issue Trackers
- [NixOS nvidia-container-toolkit broken on 25.05](https://github.com/nixos/nixpkgs/issues/419597)
- [NixOS nvidia-container-toolkit broken on 25.11](https://github.com/NixOS/nixpkgs/issues/467809)
- [NixOS nvidia works with Podman but not Docker](https://github.com/NixOS/nixpkgs/issues/337873)
- [NVIDIA Forums: Low performance in newer kernels](https://forums.developer.nvidia.com/t/low-performance-in-newer-kernels/327952)
- [Ollama GPU detection issue #9842](https://github.com/ollama/ollama/issues/9842)
- [Ollama GPU initialization issue #7593](https://github.com/ollama/ollama/issues/7593)
- [Level1Techs: Choosing Linux distro for AI LLM system](https://forum.level1techs.com/t/need-help-choosing-the-linux-distro-for-my-ai-llm-system/240866)
