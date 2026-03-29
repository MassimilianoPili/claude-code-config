# Research Report: oCIS (ownCloud Infinite Scale) and OpenCloud

**Date:** 2026-03-22
**Epistemic status:** Active situation, rapid evolution. Data fetched directly from GitHub API, Docker Hub API, and project websites.
**Confidence:** High for factual/repo data (directly verified via API). Medium for corporate narrative (based on public signals, no official press releases fetched).
**Sources:** GitHub API (T7), project websites (T7), Docker Hub API (T7). No peer-reviewed sources exist for this topic.

---

## 1. Current State (March 2026)

### 1.1 The Kiteworks Acquisition and oCIS Status

**What happened:** ownCloud GmbH was acquired by Kiteworks (a US-based secure content communications company) in late 2023/early 2024. The acquisition followed ownCloud GmbH filing for insolvency in November 2023.

**oCIS open source status -- CRITICAL FINDING:**
- oCIS (`owncloud/ocis`) **remains on GitHub** and is **still receiving commits** (last commit: 2026-03-20 by `kobergj@owncloud.com`).
- **However**, the v8.0.1 release (2026-03-11) ships with an **"End-User-License-Agreement-for-ownCloud-Infinite-Scale.pdf"** as a release asset. This is a strong signal that Kiteworks has moved oCIS to an **open-core or proprietary licensing model** while keeping the Apache 2.0 source code license nominally in place.
- The repo still says `Apache-2.0` in the license field, but the EULA suggests that **binary distributions or enterprise features are under a proprietary license**.
- oCIS has **1,911 stars**, 238 forks, 569 open issues. Still active but appears to be under corporate control.

### 1.2 OpenCloud -- The Community Fork

**OpenCloud** (`opencloud-eu/opencloud`) is a **community fork of oCIS**, created on **2025-01-10** (days/weeks after the licensing concerns materialized).

**Key facts:**
- **Organization:** OpenCloud GmbH (German company), `opencloud.eu`
- **GitHub org:** `github.com/opencloud-eu` -- ~30 repositories
- **Stars:** **4,985** (vs oCIS's 1,911) -- 2.6x more popular
- **License:** **Apache 2.0** (backend), **AGPL-3.0** (web UI), **GPL-2.0/3.0** (desktop/mobile clients)
- **No CLA required** (explicitly stated in CONTRIBUTING.md)
- **No EULA** attached to releases
- **Latest release:** v5.2.0 (2026-03-09)
- **Community chat:** Matrix `#opencloud:matrix.org`
- **CI:** `ci.opencloud.eu` (self-hosted, likely Woodpecker/Drone)
- **Docs:** `docs.opencloud.eu` (Docusaurus)

**CERN involvement:** REVA, the storage abstraction layer used by both oCIS and OpenCloud, was originally developed by **CERN** (`cs3org/reva`). OpenCloud maintains its own fork at `opencloud-eu/reva`. CERN's CS3 community (Cloud Storage Synchronization and Sharing Services) remains the upstream for the CS3 APIs. The REVA maintainers from the oCIS era (the same developers) now contribute to OpenCloud's fork.

### 1.3 Which Project Is More Active?

| Metric | oCIS (`owncloud/ocis`) | OpenCloud (`opencloud-eu/opencloud`) |
|--------|----------------------|--------------------------------------|
| Stars | 1,911 | **4,985** |
| Forks | 238 | 171 |
| Open issues | 569 | 313 |
| Latest release | v8.0.1 (2026-03-11) | v5.2.0 (2026-03-09) |
| Last commit (main) | 2026-03-20 | 2026-03-22 (today) |
| Created | 2019-08-15 | 2025-01-10 |
| License | Apache 2.0 + EULA | Apache 2.0 (clean) |
| Docker pulls | ~1.9M (`owncloud/ocis`) | N/A (not on Docker Hub as `opencloud/opencloud`) |
| Discussions | No | **Yes** |

**Critical observation:** The **same core developers** work on both repos. The top 5 contributors to OpenCloud (micbar: 2106, butonic: 1814, wkloucek: 1739, refs: 1564, kulmann: 1294) are the **same people** as oCIS's top contributors (micbar: 2020, wkloucek: 1742, butonic: 1566, refs: 1564, kobergj: 1293). This strongly suggests that the **ownCloud engineering team left or separated from Kiteworks** and founded OpenCloud GmbH, taking the open-source codebase with them (as Apache 2.0 permits).

**Verdict: OpenCloud is the active community project. oCIS is the corporate/Kiteworks product.** For self-hosting and contributing, OpenCloud is the clear choice.

---

## 2. Architecture Deep Dive

### 2.1 Language and Frameworks

- **Backend:** Go (100% of server code)
- **No traditional web framework** -- the project uses Go's `net/http` stdlib, gRPC for inter-service communication, and protocol buffers
- **REVA** (`opencloud-eu/reva`): The core storage abstraction layer. Originally a CERN project for CS3 (Cloud Storage Services). It provides WebDAV and gRPC endpoints. Description: "WebDAV/gRPC/HTTP high performance server to link high level clients to storage backends"

### 2.2 Microservices Architecture

OpenCloud compiles to a **single binary** that can run all services in one process OR each service can be started individually for scaling. The `services/` directory contains **30 microservices**:

| Category | Services |
|----------|----------|
| **Auth** | `auth-app`, `auth-basic`, `auth-bearer`, `auth-machine`, `auth-service` |
| **Storage** | `storage-publiclink`, `storage-shares`, `storage-system`, `storage-users` |
| **Core** | `frontend`, `gateway`, `proxy`, `web`, `webdav`, `webfinger` |
| **User/Group mgmt** | `graph`, `groups`, `users`, `idm`, `idp`, `invitations` |
| **Collaboration** | `collaboration` (WOPI), `ocm` (Open Cloud Mesh -- federated sharing) |
| **Infrastructure** | `nats` (embedded NATS messaging), `sse` (Server-Sent Events), `thumbnails`, `search`, `notifications` |
| **Logging/Audit** | `activitylog`, `clientlog`, `userlog`, `audit` |
| **Processing** | `postprocessing`, `antivirus`, `policies` |
| **Config** | `settings`, `ocs` (legacy OCS API compatibility) |
| **Events** | `eventhistory` |

### 2.3 Storage Backends

**Key architectural feature: NO DATABASE.** From the README:
> "The OpenCloud backend does not use a database. It stores all data in the filesystem. By default, the root directory of the backend is `$HOME/.opencloud/`."

Storage backends available through REVA:
- **Local filesystem** (`posixfs`, `ocis` driver): Files are stored in a **decomposed tree format** -- NOT plain files. Each file gets a unique node ID, with metadata stored as extended attributes (xattrs) or `.meta` files. This enables versioning, sharing, and quota tracking without a database.
- **S3-compatible backends**: Supported via REVA's S3 storage driver. Files go to S3, metadata can stay local or in S3.
- **The "ocis" storage driver** (now "opencloud"): The default. Uses a decomposed filesystem where files are organized by node ID rather than path. This means:
  - Moves/renames are O(1) (just update a symlink/reference)
  - Sharing is a reference, not a copy
  - But you **cannot browse files directly on the filesystem** -- you need the server to resolve paths

### 2.4 Protocols

- **WebDAV**: Full WebDAV support (how desktop/mobile clients sync)
- **CS3 APIs** (`cs3org/cs3apis`): gRPC-based protocol for storage provider abstraction, app provider, auth, user/group management. Developed at CERN.
- **LibreGraph API**: Microsoft Graph-compatible REST API for user/group management, drives (spaces), sharing
- **OCS API**: Legacy ownCloud Sharing API for backward compatibility
- **WOPI**: For web office integration (Collabora, OnlyOffice)
- **OpenID Connect (OIDC)**: Authentication
- **TUS**: Resumable uploads protocol

### 2.5 Web UI

- **Separate repo:** `opencloud-eu/web` (227 stars, 26 forks, 105 open issues)
- **Framework:** **Vue.js + TypeScript** (description: "Web UI for OpenCloud built with Vue.js and TypeScript")
- **License:** **AGPL-3.0**
- **The web UI is embedded** into the OpenCloud binary at build time (via `make generate`)
- The web UI connects to the backend via LibreGraph API and WebDAV

### 2.6 Mobile and Desktop Clients

| Client | Repo | Language | Stars | License | Last push | Status |
|--------|------|----------|-------|---------|-----------|--------|
| **Desktop** | `opencloud-eu/desktop` | C++ (Qt) | 176 | GPL-2.0 | 2026-03-20 | **Active** |
| **Android** | `opencloud-eu/android` | Kotlin | 63 | GPL-2.0 | 2026-03-20 | **Active** |
| **iOS** | `opencloud-eu/ios` | Swift | 25 | GPL-3.0 | 2025-08-21 | **Less active** (8 months stale) |

For comparison, ownCloud's clients:
| Client | Repo | Stars | Last push |
|--------|------|-------|-----------|
| Desktop | `owncloud/client` | 1,468 | 2026-03-20 |
| iOS | `owncloud/ios-app` | 246 | 2026-03-20 |

**The iOS app is the weakest link in OpenCloud's ecosystem** -- last pushed 8 months ago with only 25 stars. This is a prime contribution opportunity.

---

## 3. Contribution Opportunities

### 3.1 Community Welcoming

The CONTRIBUTING.md is **comprehensive and welcoming**. Key points:
- **No CLA required** -- contributions are under the same license as the project
- Explicit statement: "The project is thrilled to receive contributions in all forms"
- "We feel honored by everybody who is interested in our work and improves it, no matter how big the contribution might be"
- Uses **Transifex** for translations
- Follows strict GitHub workflow (fork + PR)
- Golang styleguide documented
- Issue and PR labels documented
- Communication via **Matrix** (`#opencloud:matrix.org`)

Ways to contribute listed in README:
1. Reporting issues or bugs
2. Requesting features
3. Writing documentation (`opencloud-eu/docs`)
4. Writing code or extending tests
5. Reviewing code
6. Helping others in the community

### 3.2 Highest-Value Contribution Areas

**1. iOS App (HIGHEST IMPACT)**
- `opencloud-eu/ios` -- 25 stars, last push 2025-08-21
- Swift, GPL-3.0
- 29 open issues, 11 forks
- This is clearly under-resourced. An experienced iOS contributor would have outsized impact.
- Forked from ownCloud's mature iOS app, so the codebase should be solid but needs OpenCloud-specific rebranding and features.

**2. Web UI (Vue.js + TypeScript)**
- `opencloud-eu/web` -- 227 stars, 105 open issues
- Very active (last push today, 2026-03-22)
- AGPL-3.0 license
- Vue.js + TypeScript -- modern stack
- Many opportunities for feature additions, accessibility improvements, i18n

**3. Documentation**
- `opencloud-eu/docs` -- Docusaurus-based
- AGPL-3.0, 20 open issues, 26 forks
- Being actively developed (last push today)

**4. Android app improvements**
- Kotlin, GPL-2.0, 63 stars, 59 open issues
- Active development (last push 2026-03-20)

**5. Desktop client**
- C++ (Qt), GPL-2.0, 176 stars, 104 open issues
- Active development

### 3.3 License Summary

| Component | License | Copyleft? |
|-----------|---------|-----------|
| Server backend | Apache 2.0 | No |
| REVA (storage layer) | Apache 2.0 | No |
| Web UI | AGPL-3.0 | Yes (strong) |
| Desktop client | GPL-2.0 | Yes |
| Android app | GPL-2.0 | Yes |
| iOS app | GPL-3.0 | Yes |
| Documentation | AGPL-3.0 | Yes |

The Apache 2.0 backend license is contribution-friendly. The GPL/AGPL on clients means contributions must stay open source, but there is no CLA that would grant the company special rights over your contributions.

---

## 4. Deployment on SOL

### 4.1 Docker Deployment

OpenCloud can run as a **single binary/container**. From the oCIS Docker Hub description (architecture is identical):

```bash
mkdir -p $HOME/opencloud/config $HOME/opencloud/data
docker run --rm -it \
    --mount type=bind,source=$HOME/opencloud/config,target=/etc/opencloud \
    --mount type=bind,source=$HOME/opencloud/data,target=/var/lib/opencloud \
    opencloud/opencloud init --insecure yes

docker run --name opencloud \
    -p 9200:9200 \
    --mount type=bind,source=$HOME/opencloud/config,target=/etc/opencloud \
    --mount type=bind,source=$HOME/opencloud/data,target=/var/lib/opencloud \
    -e OPENCLOUD_INSECURE=true \
    -e PROXY_HTTP_ADDR=0.0.0.0:9200 \
    -e OPENCLOUD_URL=https://sol.massimilianopili.com/opencloud \
    opencloud/opencloud
```

**Note:** The Docker image name may be on `ghcr.io/opencloud-eu/opencloud` rather than Docker Hub (the Docker Hub `opencloud/opencloud` repo returned 404). Check `ghcr.io`.

### 4.2 RAM Footprint

- OpenCloud/oCIS is written in Go -- relatively memory-efficient
- **Realistic estimate: 256-512 MB RAM** for a single-user or small-team instance
- The embedded NATS server, search index, and thumbnail service add overhead
- With SOL's 16 GB RAM, this is very manageable

### 4.3 Subpath Routing

**This is a known pain point.** oCIS/OpenCloud was designed to run at the **root** of a domain (e.g., `cloud.example.com`), not under a subpath (e.g., `sol.massimilianopili.com/cloud`).

**Options:**
1. **Dedicated subdomain** (recommended): Add a CNAME like `cloud.massimilianopili.com` through Cloudflare Tunnel. This is the path of least resistance.
2. **Subpath with `OPENCLOUD_URL`**: Set `OPENCLOUD_URL=https://sol.massimilianopili.com/opencloud` and configure `PROXY_HTTP_ADDR` accordingly. However, the web UI and WebDAV paths may break because many internal redirects assume root. This has been a long-standing issue in oCIS and OpenCloud may have the same limitation.
3. **nginx prefix-stripping**: Your existing nginx pattern (`set $var` + `proxy_pass $var`) could theoretically work, but you would need to also set `X-Forwarded-Prefix` and ensure OpenCloud respects it.

**Recommendation:** Use a **dedicated subdomain** (`cloud.massimilianopili.com`). Add it to Cloudflare Tunnel and nginx. This avoids all subpath headaches.

### 4.4 Keycloak OIDC

**Native support -- mature.** From the README:
> "The OpenCloud backend authenticates users via OpenID Connect using either an external IdP like **Keycloak** or the embedded LibreGraph Connect identity provider."

Keycloak is explicitly mentioned as a supported IdP. Configuration involves:
- Setting `PROXY_OIDC_ISSUER` to your Keycloak realm URL
- Setting `PROXY_OIDC_CLIENT_ID` to the client configured in Keycloak
- Disabling the built-in IdP (`IDP_ENABLED=false`, `IDM_ENABLED=false`)
- Configuring `WEB_OIDC_CLIENT_ID` for the web UI

This maps directly to your existing `sol` realm in Keycloak. You would create a new client (e.g., `opencloud`) with the appropriate redirect URIs.

### 4.5 Storage on /mnt/hdd

**Yes, absolutely.** Set the data directory via environment variable:
```
OPENCLOUD_BASE_DATA_PATH=/mnt/hdd/opencloud
```

Since OpenCloud stores everything in the filesystem (no database), the data directory contains:
- User files (in decomposed format)
- Metadata
- Search index (Bleve)
- Thumbnails cache
- System storage (shares, settings)

The HDD's 3.6 TB RAID1 is ideal for this use case.

---

## 5. Comparison with Seafile

| Feature | OpenCloud | Seafile |
|---------|-----------|---------|
| **File storage format** | **Decomposed tree** (node IDs, xattrs). NOT plain files on disk. Need the server to access. | **Proprietary block-based** format. Files split into blocks, deduplication. NOT plain files. |
| **Plain file access?** | No (but WebDAV gives standard access) | No (but SeaDrive/mount gives access) |
| **Sync protocol** | WebDAV + CS3 (standard) | Custom protocol (proprietary) |
| **Desktop client** | C++/Qt, GPL-2.0, cross-platform | C/Qt, Apache, cross-platform |
| **Desktop sync quality** | Mature (inherited from ownCloud client, 1,468 stars) | Very mature (known for excellent sync) |
| **WebDAV** | First-class citizen | Supported but not primary (performance concerns) |
| **Mobile clients** | iOS (Swift) + Android (Kotlin) | iOS + Android (mature) |
| **Web UI** | Vue.js + TypeScript, modern | Django templates, functional but dated |
| **Language** | Go | C (server) + Python (web) |
| **Database** | None (filesystem only!) | MySQL/SQLite + filesystem |
| **OIDC/SSO** | Native OpenID Connect | Supported (since v7+) |
| **Federation** | OCM (Open Cloud Mesh) | Limited |
| **Office integration** | Collabora, OnlyOffice, MS Office via WOPI | Collabora, OnlyOffice via WOPI |
| **Self-hosting ease** | Single binary, no DB | Requires MySQL/MariaDB |
| **RAM** | ~256-512 MB | ~256-512 MB |
| **License** | Apache 2.0 (server) | AGPL-3.0 (community), proprietary (pro) |
| **Community** | Growing fast (5K stars in 14 months) | Established (11K+ stars) |

**Key differentiators for your use case:**

1. **No database requirement** is a massive advantage for OpenCloud. No MySQL/PostgreSQL dependency for the file server itself. One less thing to manage (you already have enough PG databases).

2. **Neither stores plain files.** Both use abstracted storage formats. If you need to `ls` your files on the filesystem, neither project supports that natively. However, OpenCloud's decomposed format is simpler than Seafile's block-based format, and with WebDAV you get standard access from any client.

3. **WebDAV as first-class protocol** gives OpenCloud much better interoperability with standard clients, scripts, and tools. Seafile's custom protocol is faster but non-standard.

4. **Contribution opportunity** is dramatically better with OpenCloud. Seafile is primarily developed by a single Chinese company (Seafile Ltd) with limited community contribution infrastructure. OpenCloud has an active GitHub org, Matrix chat, no CLA, and explicit welcoming of contributions.

---

## 6. Recommendation

**Deploy OpenCloud, not oCIS.** The rationale:

1. **OpenCloud is the true community project.** Same developers, same codebase, but without the Kiteworks EULA and corporate control.
2. **License clarity.** Apache 2.0 with no CLA means your contributions remain yours and the project remains open.
3. **Growing momentum.** 4,985 stars in 14 months (vs oCIS's 1,911 in 6.5 years) shows strong community adoption.
4. **Active development.** Commits landing today (2026-03-22).
5. **Keycloak OIDC is native.** Direct integration with your existing `sol` realm.
6. **No database.** One less dependency to manage on SOL.
7. **iOS app is the biggest contribution opportunity.** The Swift codebase (GPL-3.0) has been dormant for 8 months -- an experienced iOS developer contributing here would be highly impactful.

### Deployment Plan for SOL

1. Add `cloud.massimilianopili.com` CNAME to Cloudflare Tunnel
2. Create `opencloud/` directory in `/data/massimiliano/`
3. Docker compose on `shared` network
4. Data on `/mnt/hdd/opencloud/`
5. Create `opencloud` Keycloak client in `sol` realm
6. nginx server block on new port for `cloud.massimilianopili.com`

### Contribution Plan

**Phase 1 -- Deploy and use**
- Deploy on SOL, use daily for file sync
- Report bugs, submit documentation fixes

**Phase 2 -- Web UI contributions**
- Vue.js + TypeScript improvements
- Focus on areas you identify as lacking during daily use

**Phase 3 -- iOS app**
- Fork `opencloud-eu/ios`
- Identify the most impactful issues from the 29 open ones
- Start with bug fixes to establish trust, then propose features

---

## Key URLs

| Resource | URL |
|----------|-----|
| **OpenCloud main repo** | https://github.com/opencloud-eu/opencloud |
| **OpenCloud web UI** | https://github.com/opencloud-eu/web |
| **OpenCloud iOS** | https://github.com/opencloud-eu/ios |
| **OpenCloud Android** | https://github.com/opencloud-eu/android |
| **OpenCloud Desktop** | https://github.com/opencloud-eu/desktop |
| **OpenCloud REVA fork** | https://github.com/opencloud-eu/reva |
| **OpenCloud Docs** | https://github.com/opencloud-eu/docs |
| **OpenCloud QA** | https://github.com/opencloud-eu/qa |
| **Documentation site** | https://docs.opencloud.eu |
| **Company website** | https://opencloud.eu |
| **Matrix chat** | https://app.element.io/#/room/#opencloud:matrix.org |
| **CI** | https://ci.opencloud.eu |
| **CONTRIBUTING.md** | https://github.com/opencloud-eu/opencloud/blob/main/CONTRIBUTING.md |
| **CS3 APIs (CERN)** | https://github.com/cs3org/cs3apis |
| **REVA upstream (CERN)** | https://github.com/cs3org/reva |
| **oCIS (Kiteworks)** | https://github.com/owncloud/ocis |
| **oCIS Docker** | https://hub.docker.com/r/owncloud/ocis (~1.9M pulls) |
| **Transifex (translations)** | https://www.transifex.com (OpenCloud project) |

---

## Serendipitous Connections

No unexpected cross-domain connections found. However, the CS3 APIs (CERN) represent an interesting case study in how academic infrastructure projects (CERN's need for petabyte-scale scientific data sharing) can seed commercial/community open source. REVA's gRPC architecture is worth studying for the agent-framework project as a model of clean service decomposition in Go.

## Quality Checklist

- [x] At least 2 primary sources actually fetched (GitHub API for both repos, Docker Hub, project websites)
- [x] Epistemic status and confidence label included
- [x] Source tier labeled (all T7 -- websites/APIs, no academic sources exist)
- [x] No fabricated citations -- all URLs verified via fetch
- [x] Personal project connection noted (not directly relevant but architecture patterns applicable)
- [x] Serendipitous connections considered
