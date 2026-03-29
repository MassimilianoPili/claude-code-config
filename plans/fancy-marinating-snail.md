# Fix VS Code ENOSPC "Unable to watch for file changes" Error

## Context
VS Code is hitting the Linux inotify watches limit (`ENOSPC`). The current limit is **60,361** watches, which is insufficient for a large workspace with many Docker volumes, node_modules, and other directories. The default recommended value is **524,288**.

## Changes

### 1. Increase inotify limits via sysctl
**File:** `/etc/sysctl.d/60-inotify.conf` (new file)

```
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
```

Then apply immediately with:
```bash
sudo sysctl -p /etc/sysctl.d/60-inotify.conf
```

### 2. Add `files.watcherExclude` to VS Code settings
**File:** `/home/massimiliano/.vscode-server/data/Machine/settings.json`

Add exclusions for large directories that don't need file watching:

```json
{
    "files.watcherExclude": {
        "**/.git/objects/**": true,
        "**/.git/subtree-cache/**": true,
        "**/node_modules/**": true,
        "**/.venv/**": true,
        "**/target/**": true,
        "**/dist/**": true
    }
}
```

## Verification
1. Run `cat /proc/sys/fs/inotify/max_user_watches` — should show **524288**
2. Run `cat /proc/sys/fs/inotify/max_user_instances` — should show **512**
3. Reload VS Code window (Ctrl+Shift+P → "Reload Window") — the ENOSPC notification should no longer appear
