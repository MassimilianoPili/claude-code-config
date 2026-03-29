# WikiJS Mermaid Patch — Publication Strategy Report

## 1. WikiJS Project Status

### v2 (branch: `main`) — Maintenance Mode

- **Latest release**: `v2.5.312` (2026-02-12), still receiving updates
- **Build stack**: Vue 2.6.14, Webpack 4, Babel 7, Node >= 20
- **Package version in `package.json`**: `"version": "2.0.0"` (internal), `"releaseDate": "2026-01-01"`
- **State**: actively maintained for security and minor features, but no major architectural changes. The maintainer (NGPixel / Nicolas Giard) is focusing effort on v3.
- **Branches**: `main` (v2 stable), `vega` (v3 development), `scarlett` (unknown/experimental), `feat-toc`

### v3 (branch: `vega`) — In Development, Not Released

- **Complete rewrite**: Vue 3.5.18, Vite, Quasar 2.18, Pinia, TipTap editor, Monaco editor, pnpm
- **Structure**: monorepo with `ux/` (frontend) and `server/` (backend) directories
- **No release tags exist for v3** — the `vega` branch has no published release yet
- **No announced release date** found in any public channel
- **Status**: long-running development branch, actively committed to, but timeline is indefinite

---

## 2. Mermaid Version Situation

### v2: Mermaid 8.8.2 (Bundled, Frozen)

**Confirmed from `main` branch `package.json`**: `"mermaid": "8.8.2"` in `devDependencies`.

Mermaid 8.8.2 was released circa **December 2020**. It is now **5+ years old**. The current Mermaid stable release is in the 11.x range.

**Missing features in 8.8.2** (partial list of what users cannot use):
- ERD field names and types (added ~v9)
- `flowchart` directive (only `graph` works)
- `<-->` bidirectional arrows
- `&` chaining syntax in flowcharts
- Mindmaps (added v9.3)
- Timeline diagrams (added v10)
- Sankey diagrams (added v10.3)
- ZenUML (added v10.1)
- Block diagrams (added v10.7)
- Packet diagrams (added v10.9)
- Architecture diagrams (added v11)
- Kanban boards (added v11)
- Many syntax improvements to existing diagram types (sequence, class, state, etc.)

This is exactly what we documented in MEMORY.md: "WikiJS Mermaid: versione 8.8.2 bundled. Non supporta `&` chaining, `<-->`, `flowchart` directive. Usare `graph` + connessioni singole."

### v3: Mermaid NOT Bundled

**Critical finding**: the `vega` branch `ux/package.json` does **not list Mermaid at all** — neither in `dependencies` nor `devDependencies`. This means either:
1. Mermaid rendering is not yet implemented in v3
2. It will be loaded via CDN or a different mechanism (dynamic import)
3. Diagram rendering is planned as a plugin/extension system

This is significant: it means even migrating to v3 will not automatically solve the Mermaid problem. The v3 architecture is a complete departure from v2.

### Why a Simple Upgrade is Impossible (NGPixel's Statement)

From **PR #7714** (2025-07-27), NGPixel explicitly stated:

> "Mermaid 11.x requires many other components to be upgraded as well. You can't just update to 11.x and expect it to work, it won't. The implementation is different and it requires the build system to be upgraded as well. The build system can't be upgraded without breaking many other components in the process. So it's not as simple as you think it is."

The technical reasons:
- Mermaid 9+ switched to ESM-only, v2 WikiJS uses CommonJS + Webpack 4
- Mermaid 10+ requires newer D3.js (v2 bundles D3 6.2.0)
- The Babel/polyfill chain in v2 is tightly coupled to the Webpack 4 build pipeline
- Upgrading Mermaid would cascade into upgrading Webpack, Babel, and potentially Vue

---

## 3. Community Demand and Existing Issues

### GitHub Issues (13 total mentioning "mermaid")

| Issue/PR | Title | Status | Date |
|----------|-------|--------|------|
| **#7714** | "upgrade mermaid from 8.8.2 to 11.9.0" (PR) | **Closed, not merged** | 2025-07-27 |
| **#2060** | "Codeblock after Mermaid Diagram" (bug) | Closed (labeled `migrate` = deferred to v3) | 2020-06 |
| + 11 other issues | Various Mermaid rendering problems | Mixed | 2019-2025 |

The `migrate` label on #2060 confirms the pattern: Mermaid issues in v2 are triaged as "will be addressed in v3."

### PR #7714 — The Failed Upgrade Attempt

- **Author**: JamesLavin (community contributor)
- **Approach**: ran `yarn upgrade --latest mermaid` (naive version bump)
- **NGPixel's response**: labeled `needs-work`, explained the cascading dependency problem (quoted above)
- **Outcome**: PR closed by author after understanding the scope
- **Key takeaway**: a simple version bump PR will be rejected. The maintainer knows it requires build system changes.

### Community Workarounds

No structured community workarounds found. The practical options for v2 users are:
1. **Write Mermaid-compatible syntax** (our approach: use `graph` instead of `flowchart`, avoid `&` chaining, single-direction arrows)
2. **Client-side injection** via custom HTML: load Mermaid from CDN in an HTML page, bypassing the built-in renderer
3. **External rendering**: use Mermaid CLI (`mmdc`) to pre-render SVGs, embed as images
4. **Docker image patching**: rebuild the WikiJS Docker image with a modified `node_modules/mermaid` (fragile, breaks on updates)

---

## 4. WikiJS v3 Mermaid Support

### Current State: Unknown / Not Implemented

As confirmed above, Mermaid is absent from the v3 `ux/package.json`. The v3 frontend uses:
- **TipTap** (rich text editor, replacing CKEditor)
- **Monaco** (code editor, replacing CodeMirror 5)
- **markdown-it 14.1.0** (Markdown parser, upgraded from 11.0.1 in v2)

Given that v3 is a full rewrite with modern tooling (Vite, ESM, Vue 3), it will be architecturally capable of bundling modern Mermaid (11.x) when diagram support is implemented. But:

- **No release date for v3**
- **No guarantee** Mermaid will be bundled (could be CDN, could be plugin)
- **Migration from v2 to v3** is a major operation (different DB schema, different auth, different everything)

### Implication for Our Patch

Our `page-helper-patch.js` addresses a **v2-specific problem** (YAML frontmatter quoting in git sync). This is orthogonal to the Mermaid issue but lives in the same ecosystem. Both are v2 problems that the maintainer considers "will be different in v3."

---

## 5. Contributing Guidelines and Best Approach

### Official Guidelines (from CONTRIBUTING.md)

- PRs welcome, should include tests and clear description
- Bigger PRs take longer to review — break into smaller chunks
- Feature requests go to the feature request board (https://wiki.js.org/feedback/), NOT GitHub Issues
- GitHub Issues are for bugs only
- Code review by NGPixel (sole maintainer, effectively)

### What We Know About NGPixel's Stance

From the PR #7714 interaction:
1. He is **aware** Mermaid is outdated
2. He considers it a **build system problem**, not a simple dependency bump
3. He is **not hostile** to the idea but will reject naive PRs
4. The `migrate` label pattern suggests Mermaid is a "v3 problem" in his mental model

### Best Approach for Contributing the YAML Patch

Our patch (`page-helper-patch.js`) is a **targeted, surgical fix** for a specific bug (YAML values containing colons breaking js-yaml parsing during git sync round-trip). This is qualitatively different from the Mermaid upgrade attempt:

- It changes **one function** (`injectPageMetadata`)
- It has **zero dependency changes**
- It fixes a **documented bug** (GitHub Discussion #6818)
- It is **backward compatible** (only adds quoting when needed)

This is exactly the kind of PR that has a chance of being merged in v2.

---

## 6. Recommendation: Publication Strategy

### Option A: Upstream PR to `main` (Recommended Primary Path)

**Pros:**
- Fixes the bug for all WikiJS v2 users
- Small, focused change — easy to review
- References an existing discussion (#6818)
- No dependency changes, no build system impact

**Steps:**
1. Fork `requarks/wiki` on GitHub
2. Create branch `fix/yaml-frontmatter-quoting` from `main`
3. Apply the patch to `server/helpers/page.js` (the original file our patch modifies)
4. Write tests (the codebase uses Jest — `"test": "... jest"`)
5. Open PR with:
   - Title: "Fix YAML frontmatter quoting for values containing special characters"
   - Body: reference Discussion #6818, explain the git sync round-trip failure
   - Show before/after for a title like `"My Page: A Guide"` producing invalid YAML
6. Keep the PR minimal — only the `injectPageMetadata` function change

**Risk**: NGPixel may still label it `migrate` and defer to v3. But the fix is so small and the bug so clear that there is a reasonable chance of merge.

**Estimated merge probability**: 40-60%. The main risk is not technical quality but maintainer bandwidth and v3 prioritization.

### Option B: Publish as a Standalone Patch/Guide (Complementary)

Regardless of upstream acceptance, publish the workaround:

1. **WikiJS Discussion #6818**: post the patch with clear instructions (bind-mount replacement in Docker)
2. **Blog post or Gist**: "Fixing WikiJS YAML Frontmatter for Git Sync" — helps others find it via search
3. **Docker Compose snippet**: show how to apply the patch via a volume mount (our current approach)

This is valuable even if the PR is merged, because many users run older WikiJS versions.

### Option C: Publish to WikiJS Feature Request Board

Not recommended for this — it is a **bug fix**, not a feature request. The correct channel is a GitHub PR or at minimum a GitHub Issue.

### What NOT to Do

- Do **not** bundle this with a Mermaid upgrade — that will get the PR rejected immediately
- Do **not** target the `vega` branch — the code structure is completely different
- Do **not** modify `yarn.lock` or any dependencies

### Summary Matrix

| Strategy | Effort | Impact | Probability of Acceptance |
|----------|--------|--------|---------------------------|
| **A. Upstream PR** | Low (1-2h) | High (all v2 users) | 40-60% |
| **B. Community post** | Low (30min) | Medium (searchable workaround) | 100% (self-published) |
| **A + B combined** | Low (2-3h) | Highest | Best coverage |

### Recommended Action Plan

1. **Immediately**: post the fix in Discussion #6818 as a community workaround (Option B)
2. **Then**: open a clean PR targeting `main` (Option A)
3. **In PR description**: link to the discussion, explain the Docker bind-mount workaround for users who cannot wait for merge
4. **Follow up**: if PR stalls for >30 days, the community post ensures the fix is discoverable regardless

---

## Serendipitous Connections

- The YAML quoting bug is structurally similar to **injection vulnerabilities** in template systems — unescaped special characters in user input breaking a structured format (YAML). The fix pattern (context-aware quoting) is the same as SQL parameterization or HTML entity encoding.
- Our MkDocs Material POC (`/data/massimiliano/mkdocs/`) sidesteps both the Mermaid and YAML issues entirely: it uses modern Mermaid (bundled by Material theme, currently 11.x), reads directly from disk (no git sync round-trip), and has no YAML frontmatter injection layer. This reinforces the MkDocs evaluation path as a long-term WikiJS replacement.

## Personal Project Connection

- **WikiJS** is core infrastructure on SOL. The patch is already deployed locally.
- **MkDocs Material** evaluation (in `mkdocs/`) is directly relevant as a potential replacement that avoids both the Mermaid and YAML problems permanently.
