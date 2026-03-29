# Research: CalDAV/CardDAV Support in OpenCloud

## Research Summary

### Executive Summary

OpenCloud does **not** have a native CalDAV/CardDAV implementation. Instead, since version 2.3.0 (and officially announced with OpenCloud 4.0.0 in December 2025), it integrates with **Radicale** -- a lightweight Python CalDAV/CardDAV server -- via an authenticating reverse proxy pattern. OpenCloud acts as a proxy that forwards authenticated requests to Radicale on `/caldav` and `/carddav` paths. There is no built-in calendar/contacts service in the Go codebase, and the OpenCloud team has explicitly stated this feature is community-maintained, not enterprise-supported. Several community members have expressed desire for a native Go implementation, but no such effort is underway.

**Epistemic status:** Well-documented, multiple official sources confirm the same picture.
**Confidence:** High -- based on official docs, GitHub issues, press releases, and community discussions.

---

## 1. Current State of CalDAV/CardDAV in OpenCloud

### Architecture: Radicale Sidecar Pattern

OpenCloud uses **Radicale** (Python, v3.x) as an external sidecar container. The integration works as follows:

1. OpenCloud acts as an **authenticating reverse proxy** -- it handles OIDC/app-token auth and forwards authenticated requests
2. Traffic on `https://<domain>/caldav` and `https://<domain>/carddav` is forwarded to the Radicale container
3. OpenCloud adds user identity information to the proxied requests
4. Radicale auto-creates default calendar and address book for each authenticated user
5. OpenCloud implements `.well-known/caldav` and `.well-known/carddav` endpoints for client auto-discovery

**Key limitations:**
- **No web UI** -- OpenCloud does not provide any calendar/contacts frontend. Users must use external clients (Thunderbird, DAVx5, iOS Calendar, etc.)
- **App Tokens required** -- since few CalDAV clients support OIDC, users must generate application-specific passwords from the OpenCloud settings page
- **Community-only feature** -- OpenCloud explicitly states: "not covered under our enterprise license, and we do not provide professional support for it. Maintained on best effort without warranty." (T7 -- OpenCloud docs v4.0)
- **Separate Python runtime** -- introduces a Python dependency into an otherwise pure-Go stack

### Official Docker Image

- **Image**: `opencloudeu/radicale` (on Docker Hub)
- **Source**: `github.com/opencloud-eu/container-radicale` (Go wrapper + Radicale, GPL-3.0)
- **Deployment**: via `opencloud-compose` example, adding `radicale/radicale.yml` to `COMPOSE_FILE`

### Timeline

| Date | Event |
|------|-------|
| 2020-12 | First community discussion on oCIS + CalDAV/CardDAV (ownCloud Central) |
| ~2023 | `radics3` bridge proof-of-concept by Klaas Freitag (CS3 auth plugin for Radicale) |
| 2025-02 | GitHub Issue #206: "Calendar and Contacts Backend Integration" -- decision to use Radicale |
| 2025-04 | GitHub Issue #736: "Release Radicale Docker File with minimal maintenance" |
| 2025-05 | OpenCloud press release: "Calendar and contact management available for the community" |
| 2025-12 | OpenCloud 4.0.0 release: Radicale integration officially announced with multi-tenancy support |
| 2026-02 | Community Discussion #2245: "CalDAV and CardDAV support are missing. While OpenCloud can integrate with Radicale, that means introducing an extra Python service." |

---

## 2. Open Issues and Roadmap

### Key GitHub Issues

| Issue | Title | Status | Date |
|-------|-------|--------|------|
| [#206](https://github.com/opencloud-eu/opencloud/issues/206) | Calendar and Contacts Backend Integration | Decision: use Radicale | 2025-02 |
| [#736](https://github.com/opencloud-eu/opencloud/issues/736) | Release Radicale Docker File with minimal maintenance | Resolved (container-radicale published) | 2025-04 |
| [#2245](https://github.com/orgs/opencloud-eu/discussions/2245) | Why OpenCloud looks promising and what still holds me back | Discussion -- community wants native Go impl | 2026-02 |

### Community Sentiment

The recurring theme in community discussions (Reddit r/selfhosted, r/owncloud, r/opencloud, Hacker News, ownCloud Central) is:

1. **Users want CalDAV/CardDAV** -- it's one of the top-requested features for switching from Nextcloud
2. **Radicale integration is seen as a stopgap** -- "introducing an extra Python service" is architecturally unclean for a Go-native platform
3. **No native Go CalDAV/CardDAV is on the official roadmap** -- the team has been clear this is community territory
4. **No web calendar UI** exists or is planned in OpenCloud itself

### What's NOT Happening

- No RFC for a native CalDAV/CardDAV service in OpenCloud's Go codebase
- No integration with the REVA/CS3 layer for calendar data
- No plans for a calendar web UI in the OpenCloud frontend

---

## 3. OpenCloud Architecture (for Understanding Where CalDAV Would Fit)

### Go Microservice Architecture

OpenCloud is built on two main codebases:

1. **`opencloud-eu/opencloud`** -- The main server. Go microservices using a supervisor tree (suture). Services include: `web`, `graph`, `ocdav`, `ocs`, `storageusers`, `storagesystem`, `proxy`, `idp`, `settings`, `thumbnails`, `search`, etc.
2. **`opencloud-eu/reva`** -- Fork of CERN's REVA interoperability platform. WebDAV/gRPC/HTTP server that implements the CS3 APIs for storage provider abstraction.

**Key architectural patterns:**
- **Service registry**: NATS JetStream KV (default) or in-memory
- **CS3 APIs**: gRPC-based protocol for inter-service communication (storage, users, shares)
- **Libre Graph API**: Microsoft Graph-compatible REST API for the frontend
- **OIDC authentication**: OpenID Connect as primary auth mechanism
- **Decomposed storage**: File metadata decomposed into extended attributes on POSIX or S3

### Where a Native CalDAV/CardDAV Service Would Fit

A native implementation would likely:
1. Be a **new microservice** in the `opencloud-eu/opencloud` repo (e.g., `services/caldav/`)
2. Register with the service registry like other services
3. Handle HTTP requests on `/caldav` and `/carddav` paths (currently proxied to Radicale)
4. Use its own storage backend (PostgreSQL, decomposed filesystem, or a new CS3 resource type)
5. Integrate with the existing OIDC/proxy auth layer
6. Optionally expose data via the Libre Graph API for a future web UI

### What Would Need to Be Built

| Component | Description | Complexity |
|-----------|-------------|------------|
| CalDAV protocol handler | REPORT, MKCALENDAR, PROPFIND, etc. (RFC 4791) | High |
| CardDAV protocol handler | REPORT, PROPFIND for contacts (RFC 6352) | Medium |
| iCalendar parser | VCALENDAR, VEVENT, VTODO, VJOURNAL parsing | Medium (libs exist) |
| vCard parser | vCard 3.0/4.0 parsing | Medium (libs exist) |
| Storage backend | Calendar/contact persistence | Medium |
| Sync support | WebDAV-Sync (RFC 6578), ctag/etag | High |
| Scheduling | CalDAV Scheduling (RFC 6638) -- iTIP, free/busy | Very High |
| Service discovery | .well-known endpoints, SRV records | Low (already exists) |
| Auth integration | OIDC + App Token support | Low (already exists) |

---

## 4. Go Libraries for CalDAV/CardDAV Server-Side

### Tier 1: `emersion/go-webdav` (Best Option)

- **URL**: [github.com/emersion/go-webdav](https://github.com/emersion/go-webdav)
- **License**: MIT
- **Status**: Actively maintained (last release Oct 2025), most popular Go WebDAV/CalDAV/CardDAV library
- **Features**: Both client AND server implementations for WebDAV, CalDAV, and CardDAV
- **Server API**: Provides `caldav.Handler` and `carddav.Handler` that implement `http.Handler`
- **Backend interface**: You implement `caldav.Backend` and `carddav.Backend` interfaces for storage
- **Used by**: tokidoki (Drew DeVault's calendar server on sr.ht), and others
- **Maturity**: Good for basic operations; may need extensions for advanced features like scheduling

**Key interfaces to implement:**
```go
// caldav.Backend
type Backend interface {
    CalendarHomeSetPath(ctx context.Context) (string, error)
    ListCalendars(ctx context.Context) ([]Calendar, error)
    GetCalendar(ctx context.Context, path string) (*Calendar, error)
    CreateCalendar(ctx context.Context, calendar *Calendar) error
    DeleteCalendar(ctx context.Context, path string) error
    GetCalendarObject(ctx context.Context, path string, req *CalendarCompRequest) (*CalendarObject, error)
    ListCalendarObjects(ctx context.Context, path string, req *CalendarCompRequest) ([]CalendarObject, error)
    QueryCalendarObjects(ctx context.Context, path string, query *CalendarQuery) ([]CalendarObject, error)
    PutCalendarObject(ctx context.Context, path string, calendar *ical.Calendar, opts *PutCalendarObjectOptions) (string, error)
    DeleteCalendarObject(ctx context.Context, path string) error
}
```

### Tier 2: `samedi/caldav-go` / `lampalink/caldav`

- **URL**: [github.com/samedi/caldav-go](https://github.com/samedi/caldav-go) (original), [github.com/lampalink/caldav](https://github.com/lampalink/caldav) (fork)
- **License**: MIT
- **Status**: Less maintained than go-webdav. CalDAV only (no CardDAV).
- **Features**: RFC 4791 request handlers, pluggable storage backend
- **Note**: The lampalink fork adds some improvements over the original

### Tier 3: `swordlordcodingcrew/fennel`

- **URL**: [github.com/swordlordcodingcrew/fennel](https://github.com/swordlordcodingcrew/fennel)
- **Status**: A standalone CalDAV/CardDAV server written in Go (not a library)
- **Useful as**: Reference implementation, but probably too opinionated to embed

### Tier 4: `sr.ht/~sircmpwn/tokidoki`

- **URL**: [sr.ht/~sircmpwn/tokidoki](https://sr.ht/~sircmpwn/tokidoki/)
- **Status**: WIP CalDAV/CardDAV server by Drew DeVault, uses `emersion/go-webdav`
- **Useful as**: Reference for how to build a Go CalDAV server on top of go-webdav

### Supporting Libraries

| Library | Purpose | URL |
|---------|---------|-----|
| `emersion/go-ical` | iCalendar parser/encoder | github.com/emersion/go-ical |
| `emersion/go-vcard` | vCard parser/encoder | github.com/emersion/go-vcard |
| `golang.org/x/net/webdav` | Low-level WebDAV (stdlib extension) | Standard library |

### Recommendation

**Use `emersion/go-webdav`** as the foundation. It provides the protocol layer; you implement the storage backend. This is the same approach tokidoki uses and it's the most mature Go option. For iCalendar/vCard parsing, the companion `go-ical` and `go-vcard` libraries from the same author are well-tested.

---

## 5. Nextcloud CalDAV/CardDAV Implementation (Comparison)

### Architecture

Nextcloud's CalDAV/CardDAV is built on **SabreDAV** (PHP), the most popular WebDAV/CalDAV/CardDAV framework. (T7 -- DeepWiki, Nextcloud docs)

**Stack:**
```
HTTP Request
  -> Nextcloud routing (remote.php/dav/*)
    -> SabreDAV Server (PHP framework)
      -> CalDavBackend (Nextcloud's implementation of Sabre\CalDAV\Backend)
        -> MySQL/PostgreSQL/SQLite database
```

**Key components:**
- **SabreDAV**: PHP framework providing protocol compliance (WebDAV, CalDAV, CardDAV, ACL, Sync)
- **CalDavBackend.php**: ~3000+ line class implementing `Sabre\CalDAV\Backend\AbstractBackend` with `SyncSupport`, `SubscriptionSupport`, `SchedulingSupport`
- **CardDavBackend.php**: Similar backend for contacts
- **Plugin system**: SabreDAV plugins for ACL, scheduling, sharing, etc.
- **Database storage**: All calendar/contact data stored in SQL (calendarobjects, cards, etc.)

**What SabreDAV provides that you'd need to replicate in Go:**
1. Full RFC 4791 (CalDAV) compliance
2. Full RFC 6352 (CardDAV) compliance
3. RFC 6578 (WebDAV Sync) for efficient sync
4. RFC 6638 (CalDAV Scheduling) -- iTIP, free/busy, invitations
5. Calendar sharing and delegation
6. Calendar subscriptions (external ICS feeds)
7. ACL (Access Control Lists)

### Key Architectural Differences

| Aspect | Nextcloud (SabreDAV) | OpenCloud (Radicale) | Native Go (hypothetical) |
|--------|---------------------|---------------------|--------------------------|
| Language | PHP | Python (external) | Go |
| Protocol lib | SabreDAV (mature, ~15yr) | Radicale (mature, ~14yr) | go-webdav (younger, ~5yr) |
| Storage | SQL database | File-based (flat files) | SQL or decomposed FS |
| Web UI | Full calendar app | None | Would need building |
| Scheduling | Full RFC 6638 | Basic | Would need building |
| Sharing | Calendar sharing, delegation | Per-user only | Would need building |
| Integration | Deep (same process) | Shallow (proxy) | Deep (same process) |
| Auth | Same session/credentials | App tokens only | OIDC + app tokens |
| Maintenance | Nextcloud team | Community / best-effort | Contributor |

---

## 6. Actionable Path: Contributing Native CalDAV/CardDAV to OpenCloud

### Option A: Improve the Radicale Integration (Low Effort, High Impact)

What could be done without rewriting anything:
1. **Calendar web UI**: Build a Vue.js calendar component in the OpenCloud web frontend that talks to Radicale via CalDAV
2. **OIDC support in Radicale**: The `container-radicale` repo could be enhanced to support OIDC directly, removing the app-token workaround
3. **Multi-user features**: Radicale supports sharing -- expose it through the OpenCloud UI

### Option B: Native Go CalDAV/CardDAV Service (High Effort, Transformative)

**Phase 1 -- Minimum Viable CalDAV/CardDAV** (estimated 2-4 months for an experienced Go developer):
1. New service `services/caldav/` in the OpenCloud repo
2. Use `emersion/go-webdav` for protocol handling
3. Implement `caldav.Backend` and `carddav.Backend` with PostgreSQL storage
4. Integrate with OpenCloud's existing proxy/auth layer
5. Basic CRUD: create calendars/address books, add/edit/delete events/contacts
6. WebDAV Sync (RFC 6578) for efficient client synchronization

**Phase 2 -- Feature Parity** (3-6 months additional):
1. CalDAV Scheduling (RFC 6638) -- invitations, free/busy
2. Calendar sharing between users
3. Calendar subscriptions (external ICS)
4. ACL support

**Phase 3 -- Web UI** (2-4 months additional):
1. Calendar component in the OpenCloud web frontend
2. Contacts component
3. Integration with the Libre Graph API

### Contribution Strategy

1. **Start a discussion** on `github.com/orgs/opencloud-eu/discussions` proposing a native Go service
2. **Reference Discussion #2245** which already expresses community desire for this
3. **Prototype Phase 1** in a fork, using `emersion/go-webdav`
4. **Contact Klaas Freitag** (formerly ownCloud, now OpenCloud) who built the original `radics3` bridge -- he understands the CS3/REVA integration points
5. **Open a PR** against the `opencloud-eu/opencloud` repo once Phase 1 is functional

---

## Serendipitous Connections

### Connection to OpenCloud Keycloak Backend Contribution

This research directly connects to the existing OpenCloud contribution work documented in `project_opencloud_keycloak_backend.md`. The Keycloak identity backend (19 files, +1250 lines, commit `18e86834`) already provides the authentication infrastructure that a native CalDAV/CardDAV service would need. The OIDC integration patterns established there (dual-URL resolution, REVA user/group providers, token caching) would be reusable.

### Connection to KORE Knowledge Graph

CalDAV/CardDAV data (events, contacts) could be ingested into the KORE knowledge graph as structured nodes, connecting to existing Book/Author/Concept nodes. A "Person" node from CardDAV could link to an "Author" node from the paper archive, creating a unified knowledge view.

---

## Sources

| Tier | Source | URL |
|------|--------|-----|
| T7 | OpenCloud Docs v4.0 -- Radicale Integration | https://docs.opencloud.eu/docs/admin/configuration/radicale-integration/ |
| T7 | OpenCloud Press Release (May 2025) | https://opencloud.eu/en/news/opencloud-calendar-and-contact-management-available-community |
| T7 | OpenCloud Press Release (Dec 2025) | https://www.heise.de/en/news/OpenCloud-4-0-0-New-Release-Brings-Multi-Tenancy-11099875.html |
| T7 | GitHub Issue #206 | https://github.com/opencloud-eu/opencloud/issues/206 |
| T7 | GitHub Issue #736 | https://github.com/opencloud-eu/opencloud/issues/736 |
| T7 | GitHub Discussion #2245 | https://github.com/orgs/opencloud-eu/discussions/2245 |
| T7 | container-radicale repo | https://github.com/opencloud-eu/container-radicale |
| T7 | ownCloud Central CalDAV discussion | https://central.owncloud.org/t/owncloud-infinite-scale-and-caldav-calendars-carddav-contacts/29794 |
| T7 | go-webdav library | https://github.com/emersion/go-webdav |
| T7 | samedi/caldav-go | https://github.com/samedi/caldav-go |
| T7 | tokidoki | https://sr.ht/~sircmpwn/tokidoki/ |
| T7 | fennel | https://github.com/swordlordcodingcrew/fennel |
| T7 | Nextcloud CalDavBackend.php | https://github.com/nextcloud/server/blob/master/apps/dav/lib/CalDAV/CalDavBackend.php |
| T7 | SabreDAV integration guide | https://sabre.io/dav/caldav-carddav-integration-guide/ |
| T7 | REVA platform | https://github.com/opencloud-eu/reva |
| T7 | OpenCloud Architecture Docs | https://docs.opencloud.eu/docs/dev/server/ |
| T7 | radics3 (CS3 auth plugin for Radicale) | https://github.com/dragotin/radics3 |
| T7 | Reddit/HN/community discussions | Multiple URLs cited inline |
