# Plan: Consolidate Claude Config — Remaining Steps

## Status

Steps 1-7 are DONE (projects on HDD, content moved, symlinks rewired, hook paths normalized, restic updated, claude-shared removed).

**One fix remaining**: `.gitignore` has `plugins/data/` listed which prevents git-tracking the plugin data directory. It should be tracked.

## Remaining fix

### Fix `.gitignore`

Current:
```
*.log
audit/
.env
*.key
*.pem
.claude.json
projects
plugins/cache/
plugins/data/      ← WRONG: should be tracked
```

Replace with:
```
# API key config
.claude.json

# Conversations (2.2GB, on HDD RAID1)
projects

# Plugin runtime (regenerated from marketplace)
plugins/cache/
plugins/marketplaces/
plugins/*.tmp

# Misc
*.log
audit/
.env
*.key
*.pem
```

### Commit

Stage all new files (agents/, plans/, plugins/data/, history.jsonl, etc.) and commit.

## Verification

1. All symlinks in `~/.claude/` → `claude-code-config` ✅
2. Hook paths normalized to direct repo paths ✅
3. Restic backs up `claude-code-config` ✅
4. `claude-shared` removed ✅
5. `plugins/data/` tracked by git (after .gitignore fix)
6. `git status` shows clean state after commit
