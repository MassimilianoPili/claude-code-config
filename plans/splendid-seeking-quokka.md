# Migrate ~/.claude symlinks: claude-shared → claude-code-config

## Context
All `~/.claude/` symlinks currently point to `claude-shared`, but that repo is being decommissioned. `claude-code-config` is the canonical config repo (already has hooks, settings.json, skills, agents, plugins, plans). The stale `CLAUDE_PLUGIN_ROOT` path (via `claude-shared/plugins`) causes stop hook failures every session.

## Step 1: Re-symlink ~/.claude directories
Replace 6 symlinks from `claude-shared` → `claude-code-config`:

```bash
rm ~/.claude/plugins   && ln -s /data/massimiliano/claude-code-config/plugins ~/.claude/plugins
rm ~/.claude/agents    && ln -s /data/massimiliano/claude-code-config/agents ~/.claude/agents
rm ~/.claude/plans     && ln -s /data/massimiliano/claude-code-config/plans ~/.claude/plans
rm ~/.claude/skills    && ln -s /data/massimiliano/claude-code-config/skills ~/.claude/skills
rm ~/.claude/history.jsonl     && ln -s /data/massimiliano/claude-code-config/history.jsonl ~/.claude/history.jsonl
rm ~/.claude/history.jsonl.bak && ln -s /data/massimiliano/claude-code-config/history.jsonl.bak ~/.claude/history.jsonl.bak
```

## Step 2: Create projects symlink in claude-code-config
`/mnt/hdd/claude-projects` already has the full conversation data (250 project dirs). `claude-shared/projects` only has 2.1M (stale subset).

```bash
cd /data/massimiliano/claude-code-config && ln -s /mnt/hdd/claude-projects projects
```

## Step 3: Normalize 31 hook paths in settings.json
File: `/data/massimiliano/claude-code-config/settings.json`
- **From**: `/data/massimiliano/.claude/hooks/` (31 occurrences)
- **To**: `/data/massimiliano/claude-code-config/hooks/`

This removes the indirection through `~/.claude/` symlinks — hooks resolve directly.

## Step 4: Update .gitignore in claude-code-config
File: `/data/massimiliano/claude-code-config/.gitignore`
Add: `projects` (symlink to HDD, shouldn't be committed)

## Step 5: Update restic-backup script
File: `/data/massimiliano/shell-scripts/bin/restic-backup` line 47
- **From**: `/data/massimiliano/claude-shared \`
- **To**: `/data/massimiliano/claude-code-config \`

## Step 6: Decommission claude-shared
After verifying everything works:
1. Confirm `claude-shared/plugins/` content matches `claude-code-config/plugins/`
2. Confirm `claude-shared/projects/` is a subset of `/mnt/hdd/claude-projects`
3. Remove or rename `claude-shared` directory

## Step 7: Commit
Stage in `claude-code-config` repo: `.gitignore`, `settings.json`, `projects` symlink.

## Verification
1. `ls -la ~/.claude/{plugins,agents,plans,skills,history.jsonl}` — all point to `claude-code-config`
2. `grep '/data/massimiliano/.claude/hooks/' settings.json` — 0 matches
3. `grep 'claude-shared' shell-scripts/bin/restic-backup` — 0 matches
4. Start a new Claude Code session — no stop hook errors
