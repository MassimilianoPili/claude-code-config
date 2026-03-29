# Deploy Obsidian Mobile with WikiJS Documentation via OpenCloud

## Context

The user wants to browse and edit WikiJS documentation from their phone using Obsidian. The vault lives in OpenCloud (already deployed at `cloud.massimilianopili.com` with Keycloak SSO). WikiJS already has git sync to Gitea configured (deploy key exists). The sync pipeline connects these existing pieces.

**No new containers.** Leverages existing WikiJS + Gitea + OpenCloud.

---

## Architecture

```
/data/massimiliano/docs/  ──import-docs.js──→  WikiJS (DB)
                                                   ↕ git sync (already configured)
                                              Gitea repo
                                                   ↕ sync script (NEW)
                                              OpenCloud (WebDAV)
                                                   ↕ OpenCloud mobile app (Android) or Remotely Save (iOS)
                                              Obsidian mobile (phone)
```

**Bidirectional flow**:
- **Read**: WikiJS → git → sync to OpenCloud → phone sync → Obsidian sees it
- **Write**: Edit in Obsidian → phone sync → OpenCloud → script commits to git → WikiJS pulls

**Phone access** (two options depending on OS):
- **Android**: OpenCloud app syncs `Wiki/` folder locally → Obsidian opens local vault (simplest)
- **iOS**: Remotely Save plugin with WebDAV (iOS sandboxing prevents direct folder access)

---

## Phase 1 — Enable App Auth in OpenCloud

### 1.1 Enable `auth-app` service

Add to `/data/massimiliano/opencloud/.env`:
```
START_ADDITIONAL_SERVICES=auth-app
```

Add to `/data/massimiliano/opencloud/custom/sol.yml` environment:
```yaml
PROXY_ENABLE_APP_AUTH: "true"
```

Restart OpenCloud: `cd /data/massimiliano/opencloud && docker compose up -d`

### 1.2 Generate app password

```bash
docker exec opencloud opencloud auth-app create \
  --user-name=sol_root --expiration=8760h
```

This returns a token usable as Basic Auth password for WebDAV.

### 1.3 Verify WebDAV access

```bash
curl -u sol_root:<app-token> \
  https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/
```

**Note**: oCIS WebDAV URL uses `/remote.php/dav/files/<username>/` (ownCloud compat shim).

### 1.4 Create Wiki folder

```bash
curl -X MKCOL -u sol_root:<app-token> \
  https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/Wiki/
```

---

## Phase 2 — Clone WikiJS Git Repo

**Status**: WikiJS git sync is **already active** — pushing to `sol_root/sol-docs` (private, 54MB, last synced 2026-03-23). Remote: `git@gitea:sol_root/sol-docs.git`. SSH key at `/wiki/data/secure/git-ssh.pem`. ~34+ wiki pages synced.

### 2.1 Clone repo locally
```bash
mkdir -p /data/massimiliano/obsidian
git clone git@gitea-local:sol_root/sol-docs.git /data/massimiliano/obsidian/wiki-repo
```

### 2.2 Verify content
- Check .md files and directory structure match WikiJS pages
- Verify frontmatter format (needed for sync script compatibility)

---

## Phase 3 — Gitea ↔ OpenCloud Sync Script

### 3.1 Create `/data/massimiliano/kindle/wiki_obsidian_sync.py`

**Pattern**: follows [paper_archive.py](/data/massimiliano/kindle/paper_archive.py) — stdlib only (`urllib.request`), no external deps.

**Sync logic**:

1. **Git → OpenCloud (export)**:
   - `git pull` the WikiJS repo (local clone at `/data/massimiliano/obsidian/wiki-repo/`)
   - Compare .md files with OpenCloud via PROPFIND (ETag or Last-Modified)
   - PUT new/changed files to `https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/Wiki/`
   - DELETE files removed from git
   - Preserve directory structure (MKCOL for subdirectories)

2. **OpenCloud → Git (import)**:
   - PROPFIND OpenCloud Wiki/ for all .md files
   - GET files that are newer than local repo copies (or don't exist locally)
   - Copy to local repo, preserving path structure
   - `git add + commit + push` if changes detected
   - WikiJS picks them up on next git sync cycle (~5 min)

**Frontmatter handling**:
- Preserve WikiJS YAML frontmatter exactly as-is on export
- On import (Obsidian → git): if Obsidian modified frontmatter, normalize it to WikiJS format before committing
- The existing `page-helper-patch.js` already handles YAML quoting issues

**WebDAV operations**: stdlib `urllib.request` with Basic auth (app token from Phase 1).

**CLI**:
```
wiki_obsidian_sync.py [--export|--import|--sync|--dry-run|--stats]
  --export   Git repo → OpenCloud
  --import   OpenCloud → Git repo
  --sync     Both directions (export first, then import)
  --dry-run  Show what would change
  --stats    Show file counts
```

### 3.2 Create `/data/massimiliano/shell-scripts/bin/wiki-obsidian`

Wrapper: reads OC credentials from `obsidian/.env`.

### 3.3 Create `/data/massimiliano/obsidian/.env`

```
OC_WEBDAV_URL=https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/Wiki
OC_USER=sol_root
OC_APP_TOKEN=<from-phase-1>
WIKI_REPO_DIR=/data/massimiliano/obsidian/wiki-repo
```

---

## Phase 4 — Systemd Timer (5-minute sync)

**`~/.config/systemd/user/wiki-obsidian-sync.service`**:
```ini
[Unit]
Description=Bidirectional WikiJS ↔ OpenCloud sync for Obsidian
After=network.target

[Service]
Type=oneshot
ExecStart=/data/massimiliano/shell-scripts/bin/wiki-obsidian --sync --quiet
StandardOutput=journal
StandardError=journal
```

**`~/.config/systemd/user/wiki-obsidian-sync.timer`**:
```ini
[Unit]
Description=WikiJS ↔ OpenCloud sync every 5 minutes

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Persistent=true

[Install]
WantedBy=timers.target
```

---

## Phase 5 — Configure Obsidian Mobile

### Android (recommended):
1. Install **OpenCloud app** from Play Store
2. Connect to `cloud.massimilianopili.com` (Keycloak SSO login)
3. Set `Wiki/` folder to sync locally
4. Install **Obsidian** from Play Store
5. Open vault → point to the locally synced `Wiki/` folder
6. Graph view, backlinks, search all work natively

### iOS (fallback):
1. Install Obsidian
2. Install **Remotely Save** community plugin
3. Configure: WebDAV, `https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/Wiki/`, sol_root + app token
4. Set Depth Header to `"only supports depth='1'"`
5. Sync → pages populate

---

## Phase 6 (Future) — KORE Integration

Once the WikiJS ↔ Obsidian pipeline works:
- Export KORE reference cards as .md files to a `KORE/` subfolder in OpenCloud
- Import Obsidian-created notes back to AGE as Concept nodes
- Incremental addition, not a separate project

---

## Files to Create

| File | Purpose |
|------|---------|
| `/data/massimiliano/obsidian/.env` | OpenCloud credentials + repo path |
| `/data/massimiliano/obsidian/wiki-repo/` | Local git clone of WikiJS repo |
| `/data/massimiliano/kindle/wiki_obsidian_sync.py` | Bidirectional sync script |
| `/data/massimiliano/shell-scripts/bin/wiki-obsidian` | Wrapper |
| `~/.config/systemd/user/wiki-obsidian-sync.service` | Systemd oneshot |
| `~/.config/systemd/user/wiki-obsidian-sync.timer` | 5-minute timer |

## Files to Modify

| File | Change |
|------|--------|
| `/data/massimiliano/opencloud/.env` | Add `START_ADDITIONAL_SERVICES=auth-app` |
| `/data/massimiliano/opencloud/custom/sol.yml` | Add `PROXY_ENABLE_APP_AUTH: "true"` |

## No New Containers

Everything uses existing WikiJS + Gitea + OpenCloud. Only OpenCloud gets a config change to enable app auth.

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Frontmatter format mismatch (Obsidian vs WikiJS) | Sync script normalizes frontmatter before git commit; test with a few pages first |
| Conflict (edit in WikiJS AND Obsidian) | Export runs first (git → OC), import second — git merge handles conflicts; sync script logs warnings |
| OpenCloud app password not working | Fallback: `PROXY_ENABLE_BASIC_AUTH=true` (less secure but works) |
| WikiJS git sync breaks | Already working (sol-docs repo, updated today) — monitor after adding import direction |
| `START_ADDITIONAL_SERVICES` already in use | Currently unset; if later needed for antivirus etc., comma-separate: `auth-app,antivirus` |

---

## Verification

1. **App auth**: `docker exec opencloud opencloud auth-app create --user-name=sol_root --expiration=8760h` → token
2. **WebDAV**: `curl -u sol_root:<token> https://cloud.massimilianopili.com/remote.php/dav/files/sol_root/` → listing
3. **Wiki folder**: MKCOL → 201
4. **WikiJS git sync**: already active — `sol_root/sol-docs`, verify clone matches WikiJS pages
5. `wiki-obsidian --export --dry-run` → lists pages to sync
6. `wiki-obsidian --export` → pages appear in OpenCloud
7. Open OpenCloud web UI → verify Wiki/ has .md files
8. Open Obsidian mobile → vault populated → graph view works
9. Edit a page in Obsidian → phone sync → `wiki-obsidian --import` → change in git → WikiJS updates
10. `systemctl --user enable --now wiki-obsidian-sync.timer`

---

## Key Reference Files

- [wikijs/import-docs.js](wikijs/import-docs.js) — WikiJS GraphQL API patterns
- [wikijs/disk-common-patch.js](wikijs/disk-common-patch.js) — Git sync import logic
- [wikijs/page-helper-patch.js](wikijs/page-helper-patch.js) — YAML frontmatter handling
- [kindle/paper_archive.py](kindle/paper_archive.py) — Pattern for stdlib Python scripts
- [opencloud/.env](opencloud/.env) — OpenCloud config
- [opencloud/custom/sol.yml](opencloud/custom/sol.yml) — OpenCloud SOL overlay
