# Plan: CV Case Study Refresh — Task #60

## Context

The current CV (`/data/massimiliano/Vari/MassimilianoPili.github.io/cv/`) is a classic **Europass-style** chronological format that severely undersells Massimiliano's capabilities:
- Only lists 1 real job (Accenture, Sep 2023–present) with generic bullet points
- Mentions basic tech (Spring Boot, Angular, Java, C, Matlab, Visual Basic)
- Completely omits: Server SOL (48 containers), 25 Maven Central libraries, Go development, graph databases, AI/MCP ecosystem, open source work
- Uses Europass digital competences tables (unhelpful for tech roles)

**Goal**: Transform into a **case study format** (Context → Problem → Approach → Result → Impact) that shows *what problems were solved*, not just *what technologies were used*. Both IT and EN versions. Source of truth in Markdown, multi-format output.

---

## Step 1 — Create project directory and scaffolding

Create `/data/massimiliano/Vari/cv/` with the structure from the plan:

```
cv/
├── cv-master-en.md        # English master document
├── cv-master-it.md        # Italian master document
├── sections/
│   ├── header.md          # Name, contacts, summary (bilingual)
│   ├── competenze.md      # One-liner skills per area
│   ├── infrastruttura.md  # Case studies: infra & cloud
│   ├── backend.md         # Case studies: backend & API
│   ├── devops.md          # Case studies: DevOps & CI/CD
│   ├── ai.md              # Case studies: AI & knowledge management
│   ├── sicurezza.md       # Case studies: security
│   ├── leadership.md      # Case studies: architecture & mentoring
│   └── timeline.md        # Synthetic chronological experience
├── Makefile               # Build: md → PDF, md → HTML
└── README.md              # Build instructions
```

**Files to read**: none new (all read already)

---

## Step 2 — Draft case studies from known experience

Using the current CV content + KORE knowledge + CLAUDE.md, draft 8-10 case studies.
This is where user input is critical — I'll draft from what I know and mark gaps with `[TODO: confirm metric]`.

### Proposed case studies:

**Infrastruttura & Cloud (2-3)**:
1. **Server SOL — Self-hosted infrastructure**: 48 containers, shared Docker network, nginx path-based routing, 4 auth patterns, Cloudflare Tunnel + Tailscale dual access, ~0 EUR/month
2. **Accenture — OpenShift migration**: OCP 3→4 governance, CI/CD pipelines (Azure DevOps)

**Backend & API (2-3)**:
3. **MCP Libraries — Open source on Maven Central**: 25 Spring AI MCP Server libraries, Java 21, automated CI/CD (tag → Maven Central in <5min)
4. **Accenture — Microservice modernization**: Java 6→17 migration, Spring MVC 5.3 → Spring Boot 3.x, DB migration (SQL Server, Oracle, MongoDB)
5. **MCP Server — 290-tool integration platform**: Single Spring Boot app exposing ~290 tools via MCP protocol

**AI & Knowledge Management (1-2)**:
6. **KORE — Knowledge graph + vector search**: Apache AGE (50K+ nodes) + pgvector, semantic search, embedding pipeline, Ollama local inference
7. **Anki embedding pipeline**: OCR + STT + embedding for 17K flashcards, multi-GPU distributed processing

**DevOps & CI/CD (1)**:
8. **Automated release pipeline**: Gitea Actions, Maven Central publishing, GitHub mirror push, zero-downtime deploy with scale trick

**Security (1)**:
9. **SSO architecture**: Keycloak realm with 16 clients, 4 auth patterns (OIDC, SAML, OAuth2 Proxy, JWT Bearer), visitor read-only access

**Leadership (1)**:
10. **Mentoring**: Daily pair-programming mentor for 3 junior engineers at Accenture

### User contribution needed:
- **Accenture case studies**: I only have the CV bullet points — need specific problems solved, decisions made, and quantitative metrics
- **Math degree**: status (completed? ongoing? dropped?)
- **Any freelance/side work** not on the current CV

---

## Step 3 — Write header and summary

Draft a 2-3 line professional summary that captures the overall profile:
- Software engineer with infrastructure and AI expertise
- Bridges enterprise development (Accenture) with open-source innovation (25 Maven Central libraries, self-hosted infra)
- Focus on problem solving, not technology listing

---

## Step 4 — Build system (Makefile + templates)

Set up multi-format output:
- **PDF**: pandoc + LaTeX or Typst (check what's installed on SOL)
- **HTML**: pandoc + custom CSS (can reuse/evolve the existing `style.css`)
- **Plain text**: pandoc → plain text

Check available tools:
```bash
which pandoc typst pdflatex xelatex
```

---

## Step 5 — Generate both language versions

- Write EN master first (primary for tech roles)
- Translate to IT (preserving structure, adapting idioms)
- Both share the same structure, differ only in language

---

## Step 6 — Build and verify

- Run `make` to generate PDF + HTML
- Verify PDF fits in 2 pages
- Verify HTML renders correctly
- Compare with existing web version at `massimilianopili.com/cv/en/`

---

## Verification

- [ ] 8-10 case studies with quantitative metrics
- [ ] Each thematic area has at least 1-2 cases
- [ ] PDF: professional, readable, max 2 pages
- [ ] HTML: responsive, maintains current hosting structure
- [ ] Both IT and EN versions complete
- [ ] `make` builds successfully
- [ ] Case studies pass the "what do you do?" test (answers = problems solved, not tech list)

---

## Critical files

| File | Action |
|------|--------|
| `/data/massimiliano/Vari/cv/` | **Create** directory |
| `/data/massimiliano/Vari/cv/cv-master-en.md` | **Create** English master |
| `/data/massimiliano/Vari/cv/cv-master-it.md` | **Create** Italian master |
| `/data/massimiliano/Vari/cv/sections/*.md` | **Create** section files |
| `/data/massimiliano/Vari/cv/Makefile` | **Create** build system |
| `/data/massimiliano/Vari/MassimilianoPili.github.io/cv/en/index.html` | **Update** web version (later) |
| `/data/massimiliano/Vari/MassimilianoPili.github.io/cv/index.html` | **Update** web version (later) |

## Pending: Academic research results

The academic-researcher agent is running a deep analysis on:
- Case study CV effectiveness vs chronological
- ATS compatibility of non-chronological formats
- Optimal metrics for software engineering CVs
- European/Italian market specifics (Europass still expected?)
- Hybrid approaches that satisfy both ATS and human readers

Results will refine the approach before implementation.
