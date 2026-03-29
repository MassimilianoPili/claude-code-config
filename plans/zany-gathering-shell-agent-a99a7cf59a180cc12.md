# Plan: Tor Network Research Report (2025-2026)

## Status: DBLP verification complete. Ready to write final report.

## Completed Steps
1. [x] Searched arXiv, Semantic Scholar, SearXNG for Tor protocol advances
2. [x] Found key papers: CenTor (PoPETs 2025), MUFFLER (INFOCOM 2025), SUMo (NDSS 2024), ESPRESSO, Early-MFC, RECTor, FlowCoPCL, TOScorr, SSRCorr, WF Survey
3. [x] Fetched Tor Blog (Arti 2.1.0, Tor Browser releases)
4. [x] Searched for privacy alternatives (Nym, I2P, OHTTP, MASQUE)
5. [x] Searched for EU legal framework (DSA, mere conduit provisions)
6. [x] Searched for relay operations literature (Dopmann et al.)
7. [x] Drafted comprehensive report (blocked by validation hook -- missing DBLP + Algorithmic Correctness)
8. [x] DBLP cross-check for all 14 CS papers

## Remaining Steps
9. [ ] Write final report with DBLP annotations + Algorithmic Correctness section
10. [ ] Write to /data/massimiliano/docs/research/tor-network-advances-2025-2026.md

---

## DBLP Verification Results (all 14 papers)

| # | Paper | Claimed Venue | DBLP Venue | DBLP Key | Status |
|---|-------|---------------|------------|----------|--------|
| 1 | CenTor (Arora, Garman) | PoPETs 2025 | Proc. Priv. Enhancing Technol. 2025(1):531-552 | `journals/popets/AroraG25` | CONFIRMED |
| 2 | MUFFLER (Seo et al.) | INFOCOM 2025 | INFOCOM 2025, pp. 1-10 | `conf/infocom/SeoYKP0K25` | CONFIRMED |
| 3 | SUMo (Lopes et al.) | NDSS 2024 | NDSS 2024 | `conf/ndss/LopesDM0BPVFC024` | CONFIRMED |
| 4 | ESPRESSO (Chawla et al.) | preprint | **APNet 2024, pp. 219-220** | `conf/apnet/ChawlaMM024` | CORRECTION: was peer-reviewed at APNet 2024, not preprint |
| 5 | PredicTor (Dopmann et al.) | ACM TOIT 2022 | ACM Trans. Internet Techn. 22(4):97:1-97:30 | `journals/toit/DopmannFLT22` | CONFIRMED (also CCTA 2020 conf version) |
| 6 | Early-MFC (Yuan et al.) | arXiv 2025 | CoRR abs/2503.16847 | `journals/corr/abs-2503-16847` | CONFIRMED (arXiv only, no peer-reviewed venue) |
| 7 | WF Survey (Cui et al.) | arXiv 2025 | Not indexed in DBLP | N/A | NOT INDEXED (too recent or not yet crawled) |
| 8 | DiProber (Darir et al.) | arXiv 2022 | CoRR abs/2211.16751 | `journals/corr/abs-2211-16751` | CONFIRMED (arXiv only) |
| 9 | Mixnet Security (Das et al.) | PoPETs 2024 | Proc. Priv. Enhancing Technol. 2024(4):665-683 | `journals/popets/DasDKZ24` | CONFIRMED |
| 10 | RECTor (Wu et al.) | preprint 2025 | CoRR abs/2512.00436 | `journals/corr/abs-2512-00436` | CONFIRMED (arXiv only) |
| 11 | FlowCoPCL (Huang et al.) | TST 2026 | Not indexed in DBLP | N/A | NOT INDEXED (Tsinghua Sci. Technol. 2026, too recent) |
| 12 | TOScorr (Zhu et al.) | 2024 | **TrustCom 2024, pp. 262-270** | `conf/trustcom/Zhu0ZM24` | CORRECTION: venue is IEEE TrustCom 2024 |
| 13 | SSRCorr (Chen et al.) | preprint 2025 | **TrustCom 2025, pp. 2123-2130** | `conf/trustcom/ChenLGRWGLGS25` | CORRECTION: was peer-reviewed at TrustCom 2025, not preprint |
| 14 | Brighente et al. | preprint 2025 | **IEEE CNS 2025, pp. 1-9** | `conf/cns/BrighenteCCL25` | CORRECTION: was peer-reviewed at IEEE CNS 2025, not preprint |
| 15 | Relay Operations (Dopmann et al.) | arXiv 2021 | CoRR abs/2106.04277 | `journals/corr/abs-2106-04277` | CONFIRMED (arXiv only) |

### Corrections Summary
- **ESPRESSO**: Upgrade from "preprint" to ACM APNet 2024 (workshop at SIGCOMM)
- **TOScorr**: Add venue IEEE TrustCom 2024
- **SSRCorr**: Upgrade from "preprint 2025" to IEEE TrustCom 2025
- **Brighente et al.**: Upgrade from "preprint 2025" to IEEE CNS 2025

---

## Algorithmic Correctness Analysis (to include in final report)

### 1. EWMA for Congestion Control (Tor Proposal 324)
- **Algorithm**: Exponentially Weighted Moving Average for RTT estimation
- **Preconditions**: Assumes RTT measurements are available and meaningful. In Tor, RTT is measured via SENDME acknowledgments across 3-hop circuits.
- **Appropriate?**: YES. EWMA is a standard technique for smoothing noisy RTT measurements (used in TCP Vegas, BBR). The multi-hop nature of Tor circuits means RTT includes processing delays at each relay, which EWMA handles well by smoothing outliers.
- **Caveat**: EWMA's smoothing factor (alpha) must be tuned for Tor's longer RTTs (200-800ms) compared to typical TCP RTTs (1-50ms). Too aggressive smoothing may miss rapid congestion onset.

### 2. Vegas-like Window Adaptation (Proposal 324)
- **Algorithm**: Monitors queue buildup by comparing measured RTT to minimum observed RTT (RTT_min). Reduces window when RTT - RTT_min exceeds threshold.
- **Preconditions**: Requires a stable RTT_min baseline. Assumes RTT inflation is primarily due to queuing, not route changes.
- **Appropriate?**: YES with caveat. In Tor, circuits are rebuilt every ~10 minutes, which resets RTT_min. The algorithm must handle circuit rotation gracefully. Tor's implementation accounts for this via per-circuit state.

### 3. Sliding Subset Sum (SUMo attack)
- **Algorithm**: Given a sequence of packet timings at ingress and egress, determine if they correspond to the same flow by checking if subsets of inter-packet delays at egress can sum to approximate delays at ingress.
- **Preconditions**: Requires observation of packet timings at both ends. Does NOT require synchronized clocks (a key advantage over prior techniques). Requires network jitter to be bounded.
- **Appropriate?**: YES for the stated threat model (ISP-level observation). The subset sum approach is NP-hard in general but tractable for the specific parameters (small sets of timing intervals).

### 4. Attention-based MIL (RECTor)
- **Algorithm**: Multiple Instance Learning treats a traffic flow as a "bag" of packet sub-sequences ("instances"). Attention mechanism selects discriminative instances.
- **Preconditions**: Requires training data with labeled flow pairs. Assumes traffic traces can be segmented into meaningful sub-sequences.
- **Appropriate?**: YES for incomplete/partial traffic observation (the specific design goal). MIL is well-suited when only parts of the input are informative, which matches real-world traffic capture where flows may be partially observed.

### 5. Contrastive Learning (FlowCoPCL, ESPRESSO)
- **Algorithm**: Learns an embedding space where correlated flows map to nearby points and uncorrelated flows map to distant points. Uses triplet/contrastive loss.
- **Preconditions**: Requires sufficient training pairs (positive and negative). Assumes embedding space can capture traffic pattern similarity.
- **Appropriate?**: YES. Metric learning is well-suited for flow correlation because the task is fundamentally about measuring similarity. The approach generalizes better than classifiers because it does not require a fixed set of target websites/services.

### 6. Sphinx Packet Format (Nym)
- **Algorithm**: Layered encryption with header manipulation using ECC (elliptic curve cryptography). Each mix node removes one layer and re-randomizes the header.
- **Preconditions**: Requires all mix nodes to share a PKI. Assumes honest-but-curious adversary model for individual nodes (threshold assumption: fewer than all nodes are corrupt).
- **Appropriate?**: YES for continuous mixnets. Sphinx provides bitwise unlinkability (output packets are indistinguishable from random), which is the core requirement for strong anonymity. The formal security proof by Das et al. (PoPETs 2024) confirms provable bounds under stated assumptions.

### 7. ed25519 / curve25519 (Tor Onion Services v3)
- **Algorithm**: ed25519 for identity keys and signing; curve25519 (via X25519) for Diffie-Hellman key exchange in circuit establishment.
- **Preconditions**: 128-bit security level. Not post-quantum resistant.
- **Appropriate?**: YES for current threat model. ed25519 provides ~128-bit security against classical computers. **Risk**: Quantum computers running Shor's algorithm would break both ed25519 and curve25519. Tor has not yet published a post-quantum migration plan (as of March 2026). For comparison, Signal Protocol added PQXDH (post-quantum X3DH) in 2023.

### 8. Connection Shuffling (MUFFLER)
- **Algorithm**: Dynamically maps N real connections to M virtual connections between exit relay and destination. Real-time remapping based on network conditions.
- **Preconditions**: Requires modification at the exit relay level. Assumes the adversary cannot observe internal relay state (standard Tor threat model).
- **Appropriate?**: YES. The approach is novel in that it operates at the connection level rather than the packet level, creating fundamentally different traffic patterns at egress vs. ingress without adding dummy traffic. The 2.17% bandwidth overhead validates efficiency.

---

## Report Structure (final version)

The report will include 9 sections matching the user's 9 questions, plus:
- DBLP-verified venue annotations for every paper (`DBLP: <key>`)
- Algorithmic Correctness section (Section 10, new)
- Serendipitous Connections section
- Knowledge Graph Candidates
- Source tier labels on every claim
- Seminal Papers table with S2 citation counts

Output file: `/data/massimiliano/docs/research/tor-network-advances-2025-2026.md`
