# Obsidian + OpenCloud + WikiJS: Tech Stack Feasibility Analysis

## Executive Summary

The stack **Obsidian "Remotely Save" + OpenCloud WebDAV** is **feasible but requires careful configuration**. The simplest approach -- and my strong recommendation -- is **Option 6: use the OpenCloud desktop/mobile sync client to sync a local folder, and point Obsidian at that local folder**. This sidesteps all plugin compatibility issues entirely.

---

## 1. Obsidian "Remotely Save" Plugin + WebDAV

### Status: WORKS, with caveats

**Source:** Remotely Save README (GitHub, fetched 2026-03-23) + `services_connectable_or_not.md`

**Key findings:**

- Remotely Save explicitly lists **ownCloud** as "Yes?" / connectable via WebDAV. The `?` indicates it has been tested but possibly not exhaustively. There is a dedicated tutorial at `docs/remote_services/webdav_owncloud/README.md`.
- The plugin explicitly lists support for: NextCloud, ownCloud, InfiniCloud, Synology, dufs, AList, Nginx, Apache, Caddy as tested WebDAV targets.
- **Critical setting for oCIS/OpenCloud:** The ownCloud tutorial specifies you MUST set **`Depth Header Sent To Servers = "only supports depth='1'"`** in Remotely Save settings. This is because oCIS (and by extension OpenCloud) does not support `Depth: infinity` WebDAV headers -- it only handles `Depth: 0` and `Depth: 1`.
- Mobile is supported. The plugin works on both iOS and Android Obsidian.

**Known issues (from README):**
- Large files (>= 50 MB) have performance issues on mobile due to Obsidian API limitations. Use "Skip Large Files" option.
- Sync is NOT real-time -- it runs on a schedule or manual trigger.
- The vault name must be identical across devices.
- Conflict detection exists but is basic in free version (PRO has "smart conflict handling").

**Reliability assessment:** Nextcloud WebDAV (which uses a very similar protocol stack to oCIS/OpenCloud) is the most widely tested WebDAV target. oCIS/OpenCloud uses a different storage backend (decomposedfs vs PHP) but exposes the same WebDAV protocol endpoints. The main risk is subtle protocol deviations in the oCIS Go implementation vs classic ownCloud PHP.

### Verdict: FEASIBLE, medium confidence

---

## 2. OpenCloud (oCIS) WebDAV Endpoint

### URL Format

**Source:** owncloud.dev/services/webdav/ (fetched, confirmed 2026-03-23) + owncloud.dev docs

oCIS/OpenCloud exposes **two** WebDAV service implementations:

1. **`ocdav` service** -- the primary WebDAV endpoint, handles file operations
2. **`webdav` service** -- handles thumbnails and search only (NOT file access)

The actual file-access WebDAV endpoints are served by **ocdav** and follow this format:

```
# New "spaces" DAV endpoint (recommended):
https://<host>/dav/spaces/<space-id>/<path>

# Legacy ownCloud-compatible endpoint:
https://<host>/remote.php/webdav/<path>

# Per-user legacy endpoint:
https://<host>/remote.php/dav/files/<username>/<path>
```

For **Remotely Save**, you want the legacy-compatible endpoint:
```
https://cloud.massimilianopili.com/remote.php/dav/files/<username>/
```
or
```
https://cloud.massimilianopili.com/remote.php/webdav/
```

Both should work. The `/remote.php/` prefix is maintained for backward compatibility even though oCIS is Go-based (no PHP).

### Auth Methods

From your `docker-compose.yml` line 29:
```
PROXY_ENABLE_BASIC_AUTH: "${PROXY_ENABLE_BASIC_AUTH:-false}"
```

Currently basic auth is **disabled** (defaults to false). For WebDAV clients that cannot do OIDC redirect flows (like Remotely Save), you have two options:

1. **Enable basic auth** (`PROXY_ENABLE_BASIC_AUTH=true`) -- simple but less secure
2. **Use app tokens** via the `auth-app` service (see section 3)

### Verdict: WELL-DOCUMENTED, high confidence on URL format

---

## 3. OpenCloud/oCIS App Passwords (App Tokens)

### Status: YES, supported via `auth-app` service

**Source:** doc.owncloud.com/ocis/next/deployment/services/s-list/auth-app.html (fetched 2026-03-23)

oCIS/OpenCloud has a dedicated **`auth-app` service** that provides app tokens -- the equivalent of Nextcloud's "app passwords". Key details:

**Setup required:**
```bash
# In your .env or docker-compose environment:
OC_ADD_RUN_SERVICES=auth-app    # or: START_ADDITIONAL_SERVICES=auth-app
PROXY_ENABLE_APP_AUTH=true       # mandatory -- allow app auth in the proxy
```

Note: The auth-app service is **NOT started automatically** by default (security reasons).

**Creating tokens:**

Option A -- CLI:
```bash
opencloud auth-app create --user-name=sol_root --expiration=8760h  # 1 year
```

Option B -- API:
```bash
# First get a bearer token from browser dev console, then:
curl --request POST 'https://cloud.massimilianopili.com/auth-app/tokens?expiry=8760h' \
     --header 'accept: application/json' \
     --header 'authorization: Bearer {oidc-token}'
```

**How tokens work:**
- Once generated, tokens are passed as **Basic Auth** credentials in the WebDAV request
- The token acts as the password; the username is the oCIS username
- Tokens have configurable expiration (default 72h, can set to months/years)
- Tokens can be listed (GET) and deleted (DELETE) via the API

**This is the recommended approach for Remotely Save:**
1. Enable `auth-app` service + `PROXY_ENABLE_APP_AUTH=true`
2. Generate a long-lived app token for your user
3. In Remotely Save WebDAV settings, enter:
   - Server: `https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/`
   - Username: `sol_root`
   - Password: `<generated-app-token>`

### Verdict: SUPPORTED, high confidence. This is the correct auth approach.

---

## 4. Alternatives to Remotely Save

### 4a. Obsidian Git plugin

**NOT recommended for this use case.** The Remotely Save `services_connectable_or_not.md` explicitly marks Git as "Never -- Technically very hard, if not impossible, to be implemented" for their plugin. The separate "Obsidian Git" community plugin exists but:
- Requires a git repo as the vault backend
- Does NOT integrate with WebDAV/OpenCloud at all
- Mobile support is very limited (no native git on iOS)
- Would require a completely different architecture (git repo as sync medium)

### 4b. Self-hosted LiveSync (CouchDB-based)

Another popular Obsidian sync plugin. Uses CouchDB, not WebDAV. Would require deploying a CouchDB instance. More complex than needed when you already have OpenCloud.

### 4c. Obsidian S3 sync via Remotely Save

Since you already have **MinIO** running on SOL, you could use Remotely Save's S3 backend instead of WebDAV. This avoids oCIS WebDAV protocol quirks entirely. But it also means the files are in an S3 bucket rather than visible in OpenCloud's file browser.

### 4d. Syncthing

Not an Obsidian plugin, but a file sync daemon. Could sync the vault folder between devices. Requires Syncthing on every device (including mobile). Works well on Android, no iOS support.

### Verdict: Remotely Save + WebDAV remains the best option given OpenCloud is already deployed.

---

## 5. WikiJS Git Sync Reliability (External Modifications)

### Status: WORKS, with known limitations

**Source:** docs.requarks.io/storage/git (fetched 2026-03-23) + personal experience with your deployment

**How it works:**
- WikiJS git sync runs on a **schedule** (default: every 5 minutes, configurable)
- Sync direction can be: Push only, Pull only, or **Bi-directional**
- When set to bi-directional, it does `git pull` then `git push` on each cycle
- External modifications pushed to the remote repo ARE picked up on the next sync cycle

**Known issues with external modifications:**

1. **First-time import:** When you first enable git sync on a repo that already has content, you must manually click "Import Everything" in the admin panel. Incremental sync only processes commits since the last known local commit.

2. **Frontmatter handling:** WikiJS uses a specific YAML frontmatter format:
   ```yaml
   ---
   title: Page Title
   description: Page description
   published: true
   date: 2024-01-01T00:00:00.000Z
   tags: tag1, tag2
   editor: markdown
   dateCreated: 2024-01-01T00:00:00.000Z
   ---
   ```
   If you modify files externally and the frontmatter is missing or malformed, WikiJS may:
   - Create the page with a generated title (from filename)
   - Lose metadata (tags, description)
   - **Your existing `page-helper-patch.js` was specifically created to handle YAML frontmatter quoting issues during git sync export** -- confirming this is a real pain point

3. **File path = page path:** WikiJS maps `folder/page.md` to `/folder/page` URL path. No flexibility here.

4. **Encoding:** WikiJS expects UTF-8. Non-UTF-8 files may cause issues.

5. **Not real-time:** Minimum practical sync interval is ~2 minutes. External changes take up to one sync cycle to appear.

6. **Conflict risk:** If WikiJS and an external editor modify the same file between sync cycles, the behavior depends on git merge. Usually last-writer-wins.

### Verdict: WORKS for read/import of external .md files. Frontmatter is the main pain point.

---

## 6. THE SIMPLER APPROACH (Critical Question)

### Can Obsidian open a vault directly from WebDAV? NO.

Obsidian (desktop and mobile) can **only** open vaults from the local filesystem. There is no native WebDAV, SMB, or remote filesystem support. The mobile apps (iOS/Android) are even more restrictive -- they can only access their own sandbox or iCloud (iOS) / local storage (Android).

### The recommended simpler approach: OpenCloud desktop/mobile sync client + local Obsidian vault

**This is the approach I strongly recommend.** Here's why:

1. **OpenCloud/oCIS has official desktop and mobile sync clients** (forked from ownCloud clients):
   - Desktop: available for Linux, macOS, Windows
   - Mobile: Android app available, iOS in development

2. **The workflow:**
   - Install the OpenCloud desktop client on your computer(s)
   - Configure it to sync a folder (e.g., `~/OpenCloud/Obsidian/`) with your OpenCloud server
   - Point Obsidian at `~/OpenCloud/Obsidian/` as the vault location
   - The sync client handles all the WebDAV/OIDC complexity transparently
   - Files are always local (fast), sync happens in the background
   - Conflict detection is handled by the oCIS client (rename conflicting files)

3. **On mobile (Android):**
   - Install the OpenCloud Android app
   - Use its "Available offline" feature for the Obsidian vault folder
   - Point Obsidian mobile at the synced folder
   - (On iOS, this is harder due to sandboxing -- you may still need Remotely Save there)

4. **Advantages over Remotely Save:**
   - No plugin dependency or configuration
   - Real-time sync (the desktop client watches for file changes)
   - Battle-tested sync algorithm (ownCloud client has 10+ years of production use)
   - Proper conflict handling with rename-on-conflict
   - Files visible in OpenCloud web UI
   - Works for any app, not just Obsidian

5. **Disadvantages:**
   - Requires installing the oCIS/OpenCloud client on each device
   - On iOS, the sandbox model may prevent Obsidian from accessing oCIS-synced files (Remotely Save may still be needed as fallback for iOS)

### The hybrid approach (best of both worlds):

- **Desktop:** OpenCloud sync client + local Obsidian vault (recommended)
- **Android:** OpenCloud app "available offline" + Obsidian pointing at synced folder
- **iOS:** Remotely Save plugin with WebDAV + app tokens (because iOS sandboxing prevents cross-app file access)

---

## Summary: Recommended Architecture

```
                    OpenCloud (oCIS)
                    cloud.massimilianopili.com
                    /remote.php/dav/files/sol_root/Obsidian/
                          |
            +-------------+-------------+
            |             |             |
     Desktop Client   Android App   Remotely Save
     (sync to ~/OC/)  (offline sync) (WebDAV+apptoken)
            |             |             |
     Obsidian Desktop  Obsidian Android  Obsidian iOS
     (local vault)    (local vault)    (local vault)
```

### Implementation Steps

1. **Enable auth-app service** in OpenCloud:
   ```
   START_ADDITIONAL_SERVICES=auth-app
   PROXY_ENABLE_APP_AUTH=true
   ```

2. **Generate an app token** for `sol_root` (long-lived, e.g., 1 year)

3. **Create an `Obsidian` folder** in OpenCloud web UI

4. **Desktop:** Install oCIS desktop client, sync the Obsidian folder, point Obsidian at it

5. **Mobile (iOS fallback):** Configure Remotely Save with:
   - WebDAV server: `https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/`
   - Username: `sol_root`
   - Password: `<app-token>`
   - Depth header: `only supports depth='1'`

6. **WikiJS integration** (if desired): Set up git sync on the same repo, with bi-directional sync. But note this adds complexity and frontmatter pain. Consider whether you actually need WikiJS to render the same content, or if OpenCloud web preview is sufficient.

---

## WikiJS Integration: Worth It?

Given that you already have:
- **Knowledge Graph** (notes.massimilianopili.com) for structured knowledge
- **MkDocs** (port 8892) for documentation rendering
- **WikiJS** for wiki content

Adding Obsidian vault content to WikiJS via git sync creates a **three-way sync problem** (Obsidian <-> OpenCloud <-> Git <-> WikiJS) that is fragile. Consider instead:
- Keep Obsidian vault in OpenCloud only (personal notes, drafts)
- When content is ready for publication, manually move/copy to WikiJS or MkDocs
- This avoids the frontmatter mismatch problem entirely

---

## Serendipitous Connections

- **Kindle Graph Enrichment project**: Obsidian vault highlights could be a second source of clippings/annotations alongside My Clippings.txt. A script to parse Obsidian's `[[wikilink]]` syntax and extract concept relationships could feed into the AGE knowledge graph.
- **Preference Sort (Ranking Todo)**: Obsidian's "Dataview" plugin can query note metadata. If notes contain ratings or preferences, these could feed into the Bradley-Terry model.

---

## Sources

| Source | Tier | What was fetched |
|--------|------|------------------|
| Remotely Save README.md (GitHub) | Primary source | Plugin features, WebDAV support, limitations |
| Remotely Save `services_connectable_or_not.md` | Primary source | ownCloud listed as "Yes?" connectable |
| Remotely Save `webdav_owncloud/README.md` | Primary source | Depth header requirement, setup steps |
| oCIS auth-app docs (doc.owncloud.com) | Primary source | App tokens creation, API, CLI, Basic Auth usage |
| oCIS webdav service docs (owncloud.dev) | Primary source | Service architecture, endpoint descriptions |
| WikiJS git storage docs (docs.requarks.io) | Primary source | Bi-directional sync, import, FAQ |
| Your OpenCloud deployment (.env, docker-compose.yml) | Local config | Current setup, Keycloak backend, domain |
