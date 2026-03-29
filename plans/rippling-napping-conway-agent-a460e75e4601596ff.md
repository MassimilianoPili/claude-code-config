# Research: Self-Hosted Private Cloud Storage Solutions

## Research Summary

### Executive Summary

For a self-hosted Docker environment with Keycloak OIDC, nginx subpath routing, and tight RAM constraints (~5-6 GB available), **Seafile** is the strongest recommendation as the primary file sync/storage solution, with **ownCloud Infinite Scale (oCIS) / OpenCloud** as the most interesting emerging alternative worth monitoring. Nextcloud remains the most feature-rich option but carries significant RAM overhead and well-documented performance issues that make it a poor fit for a server already running ~40 containers.

**Epistemic status:** Strong consensus in self-hosting community (T7 -- Reddit r/selfhosted, HN threads, comparison blogs). Individual product documentation (T7 -- vendor docs) verified for each claim. No peer-reviewed literature exists on this topic.

**Confidence:** Medium-High -- based on vendor documentation, extensive community experience reports, and direct feature verification.

---

## 1. Nextcloud

### Overview
- **Language/Stack:** PHP 8.x + MySQL/MariaDB/PostgreSQL + Redis + Apache/nginx
- **Latest stable:** Nextcloud 31 (Hub 10, released late 2025)
- **License:** AGPLv3 (fully open source)
- **Docker Hub:** `nextcloud` -- 1B+ pulls, official image, updated March 2026

### Docker Deployment & RAM
- **Minimum containers:** 3-4 (Nextcloud + DB + Redis, optionally nginx)
- **RAM footprint:** 512 MB minimum per Nextcloud process (official docs). Practical usage: **400 MB - 3 GB+** depending on apps and usage patterns. Multiple community reports of RAM ballooning to 13-25 GB under photo browsing/preview generation. (T7 -- Nextcloud community forums, multiple reports 2022-2025)
- **Full stack with Collabora:** ~3 GB minimum recommended (T7 -- docker.recipes)
- **CPU:** PHP is CPU-intensive for file listing, thumbnail generation, sync checks
- **Gotcha:** Preview generation can max out CPU and RAM, causing OOM kills. Needs careful `memory_limit` tuning and optional Imaginary microservice for previews.

### OIDC/Keycloak Integration
- **Native OIDC:** Yes, via `user_oidc` app (official Nextcloud app). Supports Keycloak natively.
- **Quality:** Works but has reported issues with redirects behind reverse proxies (T7 -- GitHub issue #1267, Dec 2025). Requires careful configuration of `overwrite.cli.url` and `trusted_proxies`.
- **Alternative:** OAuth2 Proxy in front of Nextcloud also works.

### Reverse Proxy / Subpath Support
- **Subpath routing:** **PROBLEMATIC.** Nextcloud historically has poor support for subpath deployment (`/nextcloud/`). The official recommendation is subdomain-based deployment. Subpath requires `overwritewebroot` configuration and many apps break. (T7 -- Nextcloud admin docs, community reports)
- **DEALBREAKER for this setup:** Running Nextcloud at `sol.massimilianopili.com/nextcloud/` would require significant workarounds and is fragile.

### Sync Clients
- **Desktop:** Windows, macOS, Linux -- mature, reliable, official
- **Mobile:** iOS, Android -- official apps, auto-upload for photos
- **Quality:** Desktop client works well. iOS app has recurring reports of sync failures, locked WebDAV files, and data loss. (T7 -- HN comment by palata, Nov 2025)

### File Versioning
- **Built-in:** Yes, configurable retention policies. Versions stored as full copies (storage-heavy).

### Storage Backend
- Local filesystem, S3/MinIO (primary storage or external), SMB/CIFS, WebDAV, FTP, SFTP
- Can use existing MinIO instance on SOL

### Large Files
- Chunked uploads supported. Default chunk size 10 MB. Handles multi-GB files but can be slow.

### WebDAV
- Full WebDAV support (core protocol)

### Sharing
- Public links, password-protected, expiry dates, folder sharing, federated sharing between Nextcloud instances

### Collaborative Editing
- OnlyOffice and Collabora integration (adds significant RAM: Collabora ~1-2 GB, OnlyOffice ~2-4 GB)

### Community & Maturity
- **Largest community** in self-hosted cloud space. Very active development.
- GitHub: 30K+ stars. Regular releases (major every ~6 months).
- **Known issue:** Performance has been a persistent complaint. HN thread "Why Nextcloud feels slow to use" (Nov 2025, 457 points, 350 comments) documents widespread frustration. (T7 -- ounapuu.ee blog post + HN discussion)

### Verdict for SOL
**NOT RECOMMENDED** for this setup. The combination of RAM hunger (competing with ~40 existing containers), subpath routing problems (dealbreaker for nginx path-based architecture), and persistent performance issues makes Nextcloud a poor fit. Would require a dedicated subdomain via Cloudflare Tunnel.

---

## 2. Seafile

### Overview
- **Language/Stack:** Python (Seahub web UI) + C (file server core) + MySQL/MariaDB/SQLite
- **Latest stable:** Seafile 13 CE (2025)
- **License:** AGPLv3 (Community Edition), proprietary (Professional Edition)
- **Docker Hub:** `seafileltd/seafile-mc` -- official Docker Compose deployment

### Docker Deployment & RAM
- **Containers:** 3 (Seafile + MariaDB + Memcached/Redis)
- **RAM footprint:** **~200-400 MB** for the Seafile server itself. Official docs say minimum 2 GB system RAM including OS. The C-based file server is extremely efficient. (T7 -- Seafile admin docs, multiple community benchmarks)
- **Block-based storage:** Only syncs changed blocks, not entire files. Much faster sync than Nextcloud.
- **One benchmark:** 11 GB sync in ~10 minutes. (T7 -- LogicWeb comparison, Nov 2025)

### OIDC/Keycloak Integration
- **Native OAuth/OIDC:** Yes, built-in OAuth support in Community Edition. Configurable via `seahub_settings.py` with standard OAuth2 endpoints.
- **Keycloak specifically:** Community tutorial exists (Seafile Forum, Oct 2024). Configuration via `ENABLE_OAUTH`, `OAUTH_*` settings.
- **Quality:** Works with standard OIDC providers. Some users report needing careful endpoint configuration. CE edition supports OAuth; some advanced SAML features require Pro edition.

### Reverse Proxy / Subpath Support
- **Subpath routing:** **SUPPORTED.** Seafile has explicit documentation for running under a subpath (e.g., `/seafile/`). Requires setting `FILE_SERVER_ROOT`, `SERVE_STATIC`, and nginx location blocks. More straightforward than Nextcloud.
- **Good fit for SOL's nginx path-based architecture.**

### Sync Clients
- **Desktop:** Windows, macOS, Linux (SeaDrive for virtual drive, Seafile Client for sync)
- **Mobile:** iOS, Android -- official apps
- **Quality:** Desktop client considered faster and more reliable than Nextcloud's. SeaDrive (virtual drive) is particularly praised -- files appear locally but download on-demand. (T7 -- XDA article "I completely uprooted my Nextcloud server and switched to Seafile", Sep 2025)
- **Linux caveat:** SeaDrive on Linux slightly less convenient than Windows version per community reports.

### File Versioning
- **Built-in:** Yes, block-level deduplication means versioning is storage-efficient. Configurable retention. "Beyond what you'll find in Nextcloud" per comparison reviews. (T7 -- The Digital Project Manager, 2026)

### Storage Backend
- Local filesystem (block-based, not plain files on disk -- see gotcha below)
- S3/MinIO support in Professional Edition only (NOT in CE)
- **GOTCHA:** Seafile stores files in its own block format, NOT as plain files on the filesystem. You cannot browse stored files directly on disk. This is a fundamental architectural choice that enables deduplication and fast sync but means vendor lock-in for the storage format.

### Large Files
- Excellent handling. Block-based sync means only changed blocks transfer. Resumable uploads.

### WebDAV
- Supported via SeafDAV extension. Needs explicit enabling.

### Sharing
- Public links with passwords and expiry, internal sharing, library-based access control

### Collaborative Editing
- OnlyOffice and Collabora integration available (same RAM considerations as Nextcloud)

### Community & Maturity
- Smaller community than Nextcloud but dedicated. GitHub: ~13K stars.
- Active development, regular releases. German company (Seafile GmbH).
- Used by CERN (CERNBox was historically related to Seafile/Reva ecosystem).

### Verdict for SOL
**RECOMMENDED.** Best fit for the constraints:
- Low RAM footprint (~300-400 MB server + ~200 MB MariaDB + ~100 MB Memcached = ~600-700 MB total)
- Subpath routing works
- OAuth/OIDC with Keycloak supported
- Fast, reliable sync clients
- Block-level versioning is storage-efficient

**Main concern:** Proprietary storage format (no plain files on disk). S3/MinIO backend requires Pro edition. Files would live on the 4TB HDDs in Seafile's block format.

---

## 3. ownCloud Infinite Scale (oCIS) / OpenCloud

### Overview
- **Language/Stack:** Go -- single binary, microservices architecture
- **Latest stable:** oCIS 7.x (2025). But **CRITICAL CONTEXT:** ownCloud was acquired by Kiteworks in 2024. Most of the oCIS development team left and forked oCIS into **OpenCloud** (opencloud.eu), which is now the community-driven continuation. (T7 -- HN, Reddit r/owncloud Jul 2025, CERN CERNBox Workshop Mar 2025)
- **License:** Apache 2.0 (oCIS and OpenCloud)
- **Docker Hub:** `owncloud/ocis` (Kiteworks version), OpenCloud has its own images

### The oCIS / OpenCloud Split (Critical Context)
- **ownCloud (Kiteworks):** Acquired, future unclear for community. Still publishing oCIS updates as of early 2026 but focus shifting to enterprise/Kiteworks platform.
- **OpenCloud:** Fork by original oCIS developers. Apache 2.0 license. Active development, Helm charts, Docker Compose examples. CERN (CERNBox) is aligned with this fork.
- **Recommendation:** If choosing this path, go with **OpenCloud** (more community momentum, CERN backing, original developers).
- **Vulnerability note:** OpenCloud developers found and patched a high-severity vulnerability in Feb 2026 that also affected oCIS. (T7 -- opencloud.eu)

### Docker Deployment & RAM
- **Containers:** 1 (single binary/container -- massive advantage). Can optionally split into microservices.
- **RAM footprint:** **~100-300 MB** for the single-binary deployment. Go is extremely memory-efficient.
- **LOWEST footprint of all options.** Runs on Raspberry Pi.

### OIDC/Keycloak Integration
- **Native OIDC:** **FIRST-CLASS.** oCIS/OpenCloud was designed from the ground up around OIDC. It ships with its own IDP (LibreIDC) but the recommended production setup is Keycloak.
- **Official Keycloak deployment example:** `docs/ocis/deployment/ocis_keycloak.md` in the GitHub repo.
- **Environment variables:** `OCIS_OIDC_ISSUER`, `PROXY_OIDC_REWRITE_WELLKNOWN`, `PROXY_OIDC_ACCESS_TOKEN_VERIFY_METHOD`
- **BEST OIDC integration of all options.**

### Reverse Proxy / Subpath Support
- **Subpath routing:** **PROBLEMATIC.** oCIS is designed to run on its own domain/subdomain. Subpath deployment is not a primary supported configuration. Some users report success with careful Traefik/nginx configuration but it requires extensive env var tuning.
- **Would likely need a dedicated subdomain** (e.g., `cloud.massimilianopili.com`) or a dedicated Cloudflare Tunnel ingress.

### Sync Clients
- **Desktop:** Uses ownCloud desktop client (Windows, macOS, Linux). Mature, based on Qt. Virtual file system support (similar to SeaDrive).
- **Mobile:** iOS, Android -- ownCloud apps. Functional but smaller community than Nextcloud.
- **OpenCloud:** Currently inherits oCIS clients. Long-term client development plans unclear.

### File Versioning
- Built-in versioning support. Stores files as plain files on the decomposed storage (not block-based like Seafile).

### Storage Backend
- Local filesystem (decomposed storage -- files are stored as plain files with metadata, accessible on disk)
- S3/MinIO supported natively (even in community/free edition)
- **Advantage over Seafile:** S3 support without Pro license

### Large Files
- Good handling, chunked uploads via TUS protocol

### WebDAV
- Full WebDAV support (core protocol)

### Sharing
- Public links, password protection, expiry, federated sharing via OCM (Open Cloud Mesh)

### Collaborative Editing
- OnlyOffice and Collabora integration available

### Community & Maturity
- **In flux.** The oCIS/OpenCloud split is recent and the ecosystem is still settling.
- OpenCloud is early but promising. CERN backing is significant.
- GitHub (oCIS): ~1.5K stars. OpenCloud: growing but young.
- **Risk:** Early adopter territory for OpenCloud. oCIS under Kiteworks may become less community-friendly.

### Verdict for SOL
**INTERESTING BUT NOT YET READY.** Best OIDC integration, lowest RAM, but:
- Subpath routing issues (would need dedicated subdomain)
- OpenCloud is young (risk of breaking changes)
- Client situation unclear post-fork
- Would recommend monitoring for 6-12 months before adopting

---

## 4. FileRun

### Overview
- **Language/Stack:** PHP + MySQL/MariaDB
- **License:** **PROPRIETARY** -- free for personal use (up to 10 users), paid for business
- **NOT open source.** Source code not available.

### Docker Deployment & RAM
- **Containers:** 2 (FileRun + MariaDB)
- **RAM footprint:** ~200-400 MB. Lightweight PHP app.

### OIDC/Keycloak Integration
- **No native OIDC support.** Authentication is internal. Would need OAuth2 Proxy in front.
- **Significant limitation for SSO requirements.**

### Reverse Proxy / Subpath Support
- Supports reverse proxy. Subpath possible with configuration.

### Sync Clients
- **NO dedicated sync client.** Relies on WebDAV + third-party apps (FolderSync on Android, etc.)
- **DEALBREAKER for desktop sync requirement.**

### File Versioning
- Basic versioning support

### Storage Backend
- Local filesystem (plain files -- can browse on disk)

### Verdict for SOL
**NOT RECOMMENDED.** No OIDC support, no sync client, proprietary license. The "OneDrive-like UI" is nice but the feature gaps are too large.

---

## 5. Syncthing

### Overview
- **Language/Stack:** Go -- P2P architecture, no central server required
- **License:** MPL 2.0 (fully open source)
- **Fundamentally different paradigm:** No central server, no web UI for file browsing, no sharing links.

### Docker Deployment & RAM
- **Containers:** 1
- **RAM footprint:** ~50-100 MB. Extremely lightweight.

### OIDC/Keycloak Integration
- **Not applicable.** Syncthing uses device-based authentication (device IDs + keys). No web login, no OIDC.

### Reverse Proxy / Subpath Support
- Web GUI for admin only (can be proxied). No file browsing web UI.

### Sync Clients
- **Desktop:** Windows, macOS, Linux -- native apps, system tray integration
- **Mobile:** Android (Syncthing-Fork, well-maintained). **NO iOS app** -- Apple restrictions on background sync make it impractical.
- **iOS DEALBREAKER for OneDrive/Dropbox replacement.**

### File Versioning
- Configurable: simple, staggered, external, trash can versioning.

### Storage Backend
- Local filesystem only. Plain files on disk.

### Sharing
- **No sharing.** P2P sync between your own devices only. Cannot create shareable links.

### Verdict for SOL
**NOT SUITABLE as primary cloud storage replacement.** Excellent for device-to-device sync (e.g., syncing a Documents folder between laptop and server), but lacks web UI, sharing, OIDC, and iOS support. Could complement another solution but cannot replace OneDrive/Dropbox alone.

---

## 6. Other Notable Alternatives

### Pydio Cells
- **Language:** Go + React
- **License:** AGPLv3 (CE), proprietary (Enterprise)
- **OIDC:** Native OpenID Connect support, works with Keycloak
- **RAM:** ~500 MB - 1 GB
- **Status:** Still maintained but smaller community than Seafile/Nextcloud. Development has slowed.
- **Sync clients:** Desktop clients available but less polished than Nextcloud/Seafile
- **Verdict:** Viable but community is too small. Not enough momentum.

### Cloudreve
- **Language:** Go + React
- **GitHub:** ~25K stars (mostly Chinese community)
- **License:** GPL v3
- **Storage:** Local, S3, OneDrive, Google Drive, remote servers
- **Sync:** No desktop sync client (web-only)
- **Verdict:** No sync client, limited English documentation.

### FileBrowser Quantum
- New fork (late 2025) of the unmaintained FileBrowser project
- Adding OIDC/SSO and 2FA
- **Too early** -- still in development. No sync clients.

---

## Comparative Analysis

| Feature | Nextcloud | Seafile CE | oCIS/OpenCloud | FileRun | Syncthing |
|---------|-----------|------------|----------------|---------|-----------|
| **RAM (server)** | 500MB-3GB+ | 200-400MB | 100-300MB | 200-400MB | 50-100MB |
| **RAM (full stack)** | 1-3GB+ | 600-700MB | 100-300MB | 400-600MB | 50-100MB |
| **Docker complexity** | 3-4 containers | 3 containers | 1 container | 2 containers | 1 container |
| **Keycloak OIDC** | Via app (good) | Native OAuth (good) | First-class (best) | None | N/A |
| **Subpath routing** | Poor | Good | Poor | OK | N/A |
| **Desktop sync** | Good | Excellent | Good | None | Good |
| **iOS app** | OK (buggy) | Good | OK | None | None |
| **Android app** | Good | Good | Good | None | Good |
| **File versioning** | Yes (storage-heavy) | Yes (efficient) | Yes | Basic | Yes |
| **WebDAV** | Yes | Yes (extension) | Yes | Yes | No |
| **S3/MinIO backend** | Yes | Pro only | Yes (free) | No | No |
| **Sharing (public links)** | Excellent | Good | Good | Good | None |
| **OnlyOffice/Collabora** | Yes | Yes | Yes | Limited | No |
| **Large files** | OK | Excellent | Good | OK | Good |
| **Files on disk** | Yes (plain) | No (blocks) | Yes (decomposed) | Yes (plain) | Yes (plain) |
| **License** | AGPLv3 | AGPLv3 | Apache 2.0 | Proprietary | MPL 2.0 |
| **Community size** | Very large | Medium | Small (growing) | Small | Large |
| **Maturity** | Mature | Mature | Evolving | Mature | Mature |
| **2026 momentum** | Active | Active | Active (OpenCloud) | Slowing | Active |

---

## Recommendation for SOL

### Primary: **Seafile Community Edition**

**Why:**
1. **RAM:** ~600-700 MB total stack vs 1-3 GB+ for Nextcloud. On a server with ~5-6 GB available, this matters enormously.
2. **Subpath routing:** Works at `sol.massimilianopili.com/seafile/` -- fits the existing nginx path-based architecture.
3. **Keycloak OIDC:** Native OAuth support, community tutorial for Keycloak specifically.
4. **Sync performance:** Block-based sync is dramatically faster than Nextcloud's file-based sync.
5. **Sync clients:** Desktop clients (Windows/Mac/Linux) + SeaDrive virtual drive + iOS/Android.
6. **Maturity:** Stable, well-tested, years of production deployments.

**Tradeoffs to accept:**
- Files stored in proprietary block format (not browsable on disk). Backup via Seafile's export tools or database dump + block storage copy.
- S3/MinIO backend requires Pro edition. Files will live directly on the 4TB HDDs.
- Smaller app ecosystem than Nextcloud (no Talk, no Calendar, no Contacts -- but those aren't requirements here).

### Deployment sketch for SOL:

```
/data/massimiliano/seafile/
  docker-compose.yml    # seafile + mariadb + memcached
  .env                  # SEAFILE_DB_PASSWD, SEAFILE_ADMIN_*
  seafile-data/         # Block storage -> symlink or mount to /mnt/hdd/seafile-data
  seafile-mysql/        # MariaDB data
```

Existing infrastructure reuse:
- **PostgreSQL:** Seafile uses MySQL/MariaDB (not PostgreSQL). Needs its own MariaDB container or could potentially use the existing PostgreSQL with some configuration (Seafile 12+ has experimental PostgreSQL support, but MariaDB is recommended).
- **Redis/Memcached:** Could potentially reuse existing Redis, but Seafile traditionally uses Memcached.
- **Keycloak:** Create new OIDC client `seafile` in realm `sol`.
- **Nginx:** Add location blocks for `/seafile/` with proxy_pass to seafile container.
- **Storage:** Mount one of the 4TB HDDs at the seafile-data directory.

### Secondary (monitor): **OpenCloud**

Watch the OpenCloud project (opencloud.eu) over the next 6-12 months. If it:
- Stabilizes client support
- Gets proper subpath routing documentation
- Builds a larger community

...it could become a compelling upgrade path. Its Go architecture, single-binary deployment, first-class OIDC, S3 support, and Apache 2.0 license are all superior to Seafile on paper. The concern is solely maturity and ecosystem stability post-fork.

### Explicitly not recommended:
- **Nextcloud:** RAM too high, subpath routing broken, persistent performance issues
- **FileRun:** No OIDC, no sync client, proprietary
- **Syncthing:** No web UI, no sharing, no iOS, different paradigm

---

## Serendipitous Connections

- **Preference Sort (Bradley-Terry):** If evaluating multiple cloud storage solutions with subjective criteria (UI quality, sync reliability), the preference-sort system could formalize pairwise comparisons.
- **Knowledge Graph (KORE):** The infrastructure decision (service choice, auth integration, storage architecture) should be persisted in AGE as a `Decision` node linked to `DockerService`, `KeycloakClient`, and `NginxRoute` nodes once deployment is done.
- **MinIO integration:** Seafile Pro's S3 backend could leverage the existing MinIO instance. If eventually upgrading to Pro, this would enable tiered storage (hot data on NVMe, cold data on HDD via MinIO).

---

## Sources

All claims sourced from:
- (T7) Nextcloud official documentation: docs.nextcloud.com
- (T7) Seafile admin documentation: haiwen.github.io/seafile-admin-docs
- (T7) ownCloud/oCIS documentation: doc.owncloud.com
- (T7) OpenCloud project: opencloud.eu
- (T7) Hacker News discussion "Why Nextcloud feels slow to use" (Nov 2025, 457 pts) -- id:45798681
- (T7) Reddit r/selfhosted -- multiple threads on cloud storage comparisons (2024-2026)
- (T7) Seafile community forum -- Keycloak SSO tutorial (Oct 2024)
- (T7) LogicWeb comparison article (Nov 2025)
- (T7) XDA Developers -- Seafile migration article (Sep 2025)
- (T7) CERN CERNBox Workshop slides (Mar 2025) -- oCIS/OpenCloud lineage
- (T7) Docker Hub pull counts and update timestamps (Mar 2026)

No T1-T3 academic sources exist for this topic (it is a practical infrastructure decision, not a research question).
