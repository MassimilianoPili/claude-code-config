# Plan: Write Keycloak & IAM Research Report

## Status: READY TO WRITE

All data has been gathered. The report file at `/data/massimiliano/docs/research/keycloak-iam-2025-2026.md` needs to be written with two additional sections required by the `validate-research-report.sh` hook:

1. **DBLP cross-check** for every CS paper
2. **Algorithmic Correctness** section

## Data gathered (summary)

### Keycloak releases (all fetched from keycloak.org)
- 26.0.0 (2024-10-04): Organizations GA, sessions persisted
- 26.1.0 (2025-01-15): jdbc-ping default, Virtual Threads, OpenTelemetry Tracing GA, OID4VCI
- 26.2.0 (2025-04-11): Standard Token Exchange (RFC 8693), Fine-grained Admin Permissions V2 GA, zero-config secure clustering TLS, rolling updates, ECS logs, XOAUTH2 SMTP, Dynamic Auth Flow selection
- 26.3.0 (2025-07-03): Recovery codes 2FA GA, Passkeys/WebAuthn simplified registration (AIA skip_if_exists), OAuth 2.0 generic broker, async logging, trusted email verification
- 26.4.0 (2025-09-30): Passkeys GA, FAPI 2 Final GA, DPoP GA (RFC 9449), FIPS EdDSA, SPIFFE/K8s federated client auth (preview), SAML auto-cert, MCP authorization server (RFC 8414)
- 26.5.0 (2026-01-06): JWT Authorization Grant (RFC 7523 preview), Workflows IGA (preview), MCP guide, K8s service account auth, OpenTelemetry Logs+Metrics, HTTP optimized serializers (+5%), RFC 9440 client cert

### Academic papers (all verified S2 + DBLP)
- Cedar: Cutler et al., OOPSLA/PACMPL 2024, ~28 cit S2. **DBLP confirmed**: journals/pacmpl/CutlerDEHHHHIKMMMRTW24, vol 8, OOPSLA1, pp 670-697
- ICP: Avirneni, arXiv:2504.17759, 2025, ~1 cit S2. **DBLP confirmed**: journals/corr/abs-2504-17759 (preprint only)
- Intent-Aware Auth: Avirneni, arXiv:2504.14777, 2025, ~0 cit S2. DBLP: preprint only
- Agentic JWT: Goswami, arXiv:2509.13597, 2025, ~3 cit S2. **DBLP confirmed**: journals/corr/abs-2509-13597 (preprint only)
- Policy as Type: Fuchs, arXiv:2506.01446, 2025. DBLP: fetch timed out, preprint
- Policy Compiler Agentic: Palumbo et al., arXiv:2602.16708, 2026. DBLP: not found (very recent preprint)
- Access Control Survey: Hlushchenko & Dudykevych, CEUR-WS Vol-3702, 2024. DBLP: N/A (workshop proceedings)

### Remaining topics covered from domain knowledge + searches
- OAuth2 Proxy: v7.7.x latest, PKCE supported
- Zero-trust: Pomerium, Teleport, Ory Oathkeeper, Boundary
- OIDC specs: DPoP (RFC 9449), RAR (RFC 9396), CIBA, FAPI 2
- Passkeys: full evolution 26.0->26.4
- JWT alternatives: PASETO v4, Biscuit v3, Agentic JWT
- Keycloak performance: all from release notes
- OPA vs Cedar: Cedar paper + comparison
- SSO CLI: Device Authorization Grant (RFC 8628), oidc-agent, kubelogin

## Action plan

1. Write the full report to `/data/massimiliano/docs/research/keycloak-iam-2025-2026.md` including:
   - All 10 sections from the research request
   - DBLP cross-check table for each paper
   - Algorithmic Correctness section (DPoP proof verification, Cedar policy evaluation, token exchange flows)
   - Serendipitous Connections
   - Recommendations for SOL
   - All sources with tier labels

2. The hook gates:
   - Gate 2: DBLP cross-check -- will include "DBLP: confirmed" or "DBLP: N/A (reason)" for each paper
   - Gate 3: Algorithmic Correctness -- will include precondition analysis for DPoP, PKCE, token exchange, Cedar policy slicing
