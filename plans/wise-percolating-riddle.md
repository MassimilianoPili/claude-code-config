# Plan: Consolidate Claude Config into Single Git Repo

## Context

Currently Claude Code config is split across **3 locations** with symlinks going in mixed directions:
- `claude-code-config/` — git repo (settings.json, hooks/, skills/)
- `claude-shared/` — separate git repo (agents/, plans/, plugins/, history.jsonl, projects/)
- `~/.claude/` — runtime dir with symlinks to both

The `skills` symlink already goes backwards (`claude-shared/skills → claude-code-config/skills`), proving these should be one repo. Goal: **one repo, all symlinks point FROM runtime dirs TO the repo**.

Projects (2.2GB conversations) move to `/mnt/hdd/` (RAID1) and are symlinked from the repo.

## Final layout

```
claude-code-config/              ← single git repo, source of truth
├── .claude.json                 (gitignored — API key config)
├── settings.json
├── hooks/                       ← 27 shell scripts
├── skills/                      ← 105 skill dirs
├── agents/                      ← moved from claude-shared
├── plans/                       ← moved from claude-shared
├── plugins/                     ← partial: data/ + metadata files
│   ├── data/                    (git-tracked)
│   ├── installed_plugins.json   (git-tracked)
│   ├── known_marketplaces.json  (git-tracked)
│   ├── blocklist.json           (git-tracked)
│   ├── cache/                   (gitignored — regenerated)
│   └── marketplaces/            (gitignored — regenerated)
├── projects/                    ← symlink → /mnt/hdd/claude-projects (gitignored)
├── history.jsonl                ← moved from claude-shared
├── git-hooks/
├── .gitea/
└── README.md

~/.claude/                       ← runtime dir, all content symlinks → repo
├── agents      → claude-code-config/agents
├── plans       → claude-code-config/plans
├── skills      → claude-code-config/skills
├── plugins     → claude-code-config/plugins
├── history.jsonl     → claude-code-config/history.jsonl
├── history.jsonl.bak → claude-code-config/history.jsonl.bak
├── settings.json     → claude-code-config/settings.json
├── settings.local.json          (local, not in repo)
├── .credentials.json            (local, not in repo)
└── [cache, debug, file-history, etc.]  (ephemeral, local)

/data/massimiliano/.claude/      ← project-scoped dir
├── hooks        → claude-code-config/hooks
├── settings.json → claude-code-config/settings.json
└── settings.local.json          (local)
```

## Steps

### 1. Move projects to HDD

```bash
mv /data/massimiliano/claude-shared/projects /mnt/hdd/claude-projects
```

### 2. Move content from claude-shared → claude-code-config

```bash
cd /data/massimiliano/claude-code-config

# Git-tracked content
mv /data/massimiliano/claude-shared/agents agents
mv /data/massimiliano/claude-shared/plans plans
mv /data/massimiliano/claude-shared/history.jsonl .
mv /data/massimiliano/claude-shared/history.jsonl.bak .

# Plugins — data + metadata (not cache/marketplaces)
mkdir -p plugins/data
cp -a /data/massimiliano/claude-shared/plugins/data/* plugins/data/
cp /data/massimiliano/claude-shared/plugins/installed_plugins.json plugins/
cp /data/massimiliano/claude-shared/plugins/known_marketplaces.json plugins/
cp /data/massimiliano/claude-shared/plugins/blocklist.json plugins/

# Plugins — cache + marketplaces (regenerable, but needed at runtime)
mv /data/massimiliano/claude-shared/plugins/cache plugins/cache
mv /data/massimiliano/claude-shared/plugins/marketplaces plugins/marketplaces

# Symlink projects from HDD
ln -s /mnt/hdd/claude-projects projects
```

### 3. Update `.gitignore`

Replace current `.gitignore` with:
```
# API key config
.claude.json

# Conversations (2.2GB, on HDD)
projects

# Plugin runtime (regenerated from marketplace)
plugins/cache/
plugins/marketplaces/
plugins/*.tmp

# Existing
*.log
audit/
.env
*.key
*.pem
```

### 4. Normalize hook paths in settings.json

Replace all 30 occurrences of `/data/massimiliano/.claude/hooks/` with `/data/massimiliano/claude-code-config/hooks/` (the one `tool-outcome-tracker.sh` already uses this path).

### 5. Update symlinks in `~/.claude/`

```bash
# Remove old symlinks (all currently point to claude-shared)
rm ~/.claude/agents ~/.claude/plans ~/.claude/skills ~/.claude/plugins
rm ~/.claude/history.jsonl ~/.claude/history.jsonl.bak

# New symlinks — all to claude-code-config
ln -s /data/massimiliano/claude-code-config/agents ~/.claude/agents
ln -s /data/massimiliano/claude-code-config/plans ~/.claude/plans
ln -s /data/massimiliano/claude-code-config/skills ~/.claude/skills
ln -s /data/massimiliano/claude-code-config/plugins ~/.claude/plugins
ln -s /data/massimiliano/claude-code-config/history.jsonl ~/.claude/history.jsonl
ln -s /data/massimiliano/claude-code-config/history.jsonl.bak ~/.claude/history.jsonl.bak
# settings.json symlink already correct
```

### 6. Update restic backup path

In `/data/massimiliano/shell-scripts/bin/restic-backup`, replace:
```
/data/massimiliano/claude-shared
```
with:
```
/data/massimiliano/claude-code-config
/mnt/hdd/claude-projects
```

### 7. Decommission claude-shared

```bash
# Verify nothing left that matters
ls /data/massimiliano/claude-shared/
# Should only have: .git/, .gitignore, maybe empty dirs

# Remove (after verifying everything works)
rm -rf /data/massimiliano/claude-shared
```

### 8. Commit in claude-code-config

Stage all moved files, commit with descriptive message.

## Files to modify

- `/data/massimiliano/claude-code-config/.gitignore`
- `/data/massimiliano/claude-code-config/settings.json` (30 hook path replacements)
- `/data/massimiliano/shell-scripts/bin/restic-backup` (backup path)
- Symlinks: `~/.claude/{agents,plans,skills,plugins,history.jsonl,history.jsonl.bak}`

## Verification

1. `ls -la ~/.claude/` — all content symlinks → claude-code-config
2. `ls -la /data/massimiliano/.claude/` — hooks + settings → claude-code-config
3. Start `claude` from `/data/massimiliano/` — hooks fire, skills load, plugins available
4. Write a plan file — confirms plans/ writable through symlink chain
5. `ls /mnt/hdd/claude-projects/` — conversations accessible
6. `restic-backup` dry run — new paths picked up
7. `cd /data/massimiliano/claude-code-config && git status` — new files staged, nothing unexpected
