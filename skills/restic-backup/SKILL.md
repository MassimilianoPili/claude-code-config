---
name: restic-backup
description: Restic backup patterns for automated nightly backups, retention policies, PostgreSQL pg_dump pre-hooks, cron scheduling, restore operations, and backup verification for self-hosted Docker infrastructure.
allowed-tools: Read, Write, Bash, Edit
category: devops
tags: [restic, backup, restore, cron, postgresql, disaster-recovery]
version: 1.0.0
---

# Restic Backup — SOL Server

## Overview

Restic provides encrypted, deduplicated backups for the SOL server. A nightly cron job at 3:00 AM backs up all service data including PostgreSQL dumps. The backup script lives at `/usr/local/bin/backup-sol.sh`.

Restic's content-addressable storage means only changed data is uploaded on each run, making incremental backups fast and storage-efficient even for large datasets.

## When to Use

- Understanding the backup strategy and what is covered
- Restoring data from backups (full or partial)
- Adding new directories or services to the backup
- Debugging backup failures or investigating missing snapshots
- Verifying backup integrity after infrastructure changes
- Setting up retention policies for new backup targets

## Backup Strategy

### What is backed up

- `/data/massimiliano/` — All service data (Docker compose files, persistent volumes, configs, code)
- `/data/massimiliano/claude-shared/` — Claude Code conversations, skills, plans, agents
- PostgreSQL dumps via pre-hook (`pg_dumpall` before backup starts)
- Service configuration files and `.env` secrets
- Shell scripts toolkit (`/data/massimiliano/shell-scripts/`)
- Nginx config, dashboard HTML, Cloudflare tunnel config

### What is excluded (examples)

- Docker images (can be re-pulled from registries)
- Build artifacts (`target/`, `build/`, `dist/`)
- Dependency caches (`node_modules/`, `vendor/`, `.m2/repository/`)
- Git object stores (`.git/` — repos can be re-cloned from Gitea/GitHub)
- Temporary and log files

## Cron Schedule

Backup runs nightly at 3:00 AM via cron:

```cron
0 3 * * * /usr/local/bin/backup-sol.sh >> /var/log/backup-sol.log 2>&1
```

The output is appended to `/var/log/backup-sol.log` for monitoring and debugging.

## Backup Script Pattern

Typical `/usr/local/bin/backup-sol.sh` structure:

```bash
#!/bin/bash
set -euo pipefail

export RESTIC_REPOSITORY="/path/to/repo"  # or s3:bucket/path, sftp:host:path
export RESTIC_PASSWORD_FILE="/path/to/.restic-password"

LOG_PREFIX="[backup-sol]"

echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') Starting backup..."

# Pre-hook: dump PostgreSQL databases
echo "$LOG_PREFIX Dumping PostgreSQL..."
docker exec postgres pg_dumpall -U postgres > /data/massimiliano/backups/pg_dump_all.sql

# Run backup
echo "$LOG_PREFIX Starting restic backup..."
restic backup /data/massimiliano \
  --exclude='*/node_modules' \
  --exclude='*/target' \
  --exclude='*/.git' \
  --exclude='*/vendor' \
  --exclude='*/.m2/repository' \
  --exclude='*/build' \
  --exclude='*/dist' \
  --tag nightly

# Apply retention policy
echo "$LOG_PREFIX Pruning old snapshots..."
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune

echo "$LOG_PREFIX $(date '+%Y-%m-%d %H:%M:%S') Backup complete"
```

### Pre-hook: PostgreSQL Dump

The `pg_dumpall` command runs before restic starts, ensuring a consistent SQL dump is included in the backup. This is critical because backing up PostgreSQL data files directly (without stopping the server) can produce a corrupted backup.

```bash
# Dump all databases (roles + data)
docker exec postgres pg_dumpall -U postgres > /data/massimiliano/backups/pg_dump_all.sql

# Alternative: dump individual databases
docker exec postgres pg_dump -U gitea -d gitea > /data/massimiliano/backups/gitea.sql
docker exec postgres pg_dump -U keycloak -d keycloak > /data/massimiliano/backups/keycloak.sql
```

## Retention Policy

| Period  | Keep | Purpose                            |
|---------|------|------------------------------------|
| Daily   | 7    | Last week of daily snapshots       |
| Weekly  | 4    | Last month of weekly snapshots     |
| Monthly | 6    | Last 6 months of monthly snapshots |

The `restic forget --prune` command removes snapshots outside the retention window and reclaims disk space by removing unreferenced data blobs.

## Common Operations

### Listing and browsing snapshots

```bash
# List all snapshots
restic -r /path/to/repo snapshots

# List snapshots with a specific tag
restic -r /path/to/repo snapshots --tag nightly

# Browse the latest snapshot (file listing)
restic -r /path/to/repo ls latest

# Browse a specific snapshot by ID
restic -r /path/to/repo ls abc123

# Search for a file across all snapshots
restic -r /path/to/repo find "nginx.conf"

# Search for a file modified after a date
restic -r /path/to/repo find "*.sql" --newer-than "2026-02-01"
```

### Repository health and stats

```bash
# Check repository integrity (fast, metadata only)
restic -r /path/to/repo check

# Thorough check (reads and verifies all data blobs)
restic -r /path/to/repo check --read-data

# Show repository size and deduplication stats
restic -r /path/to/repo stats

# Show stats in raw-data mode (actual storage used)
restic -r /path/to/repo stats --mode raw-data
```

### Manual backup

```bash
# Run the full backup script manually
sudo /usr/local/bin/backup-sol.sh

# View the last backup log entries
tail -50 /var/log/backup-sol.log

# Quick manual backup with a custom tag
restic backup /data/massimiliano --tag manual --tag pre-upgrade
```

## Restore Procedures

### Restore a specific file

```bash
# Restore a single file from the latest snapshot
restic restore latest \
  --target /tmp/restore \
  --include "/data/massimiliano/proxy/nginx.conf"

# Copy it back
cp /tmp/restore/data/massimiliano/proxy/nginx.conf /data/massimiliano/proxy/nginx.conf
```

### Restore PostgreSQL

```bash
# 1. Extract the dump file from backup
restic restore latest --target /tmp/restore --include "backups/pg_dump_all.sql"

# 2. Stop services that use the database
cd /data/massimiliano/gitea && docker compose down
cd /data/massimiliano/keycloak && docker compose down

# 3. Restore into PostgreSQL
cat /tmp/restore/data/massimiliano/backups/pg_dump_all.sql | \
  docker exec -i postgres psql -U postgres

# 4. Restart services
cd /data/massimiliano/keycloak && docker compose up -d
cd /data/massimiliano/gitea && docker compose up -d
```

### Restore a Docker service (e.g., Gitea)

```bash
# 1. Stop the service
cd /data/massimiliano/gitea && docker compose down

# 2. Restore the data directory from backup
restic restore latest --target /tmp/restore --include "gitea/"

# 3. Replace the current data with restored data
rm -rf /data/massimiliano/gitea/gitea-data/
cp -r /tmp/restore/data/massimiliano/gitea/gitea-data/ /data/massimiliano/gitea/gitea-data/

# 4. Restart the service
docker compose up -d
```

### Restore Claude shared storage

```bash
restic restore latest --target /tmp/restore --include "claude-shared/"
cp -r /tmp/restore/data/massimiliano/claude-shared/* /data/massimiliano/claude-shared/
```

### Restore from a specific snapshot (not latest)

```bash
# List snapshots to find the desired one
restic snapshots

# Restore from a specific snapshot ID
restic restore abc12345 --target /tmp/restore --include "proxy/"
```

## Restic Repository Initialization

First-time setup for different backends:

```bash
# Local filesystem repository
restic init -r /path/to/backup/repo

# S3-compatible storage (AWS, MinIO, Backblaze B2)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
restic init -r s3:s3.amazonaws.com/bucket-name/restic

# SFTP repository (remote server via SSH)
restic init -r sftp:user@host:/path/to/repo

# Create password file (store securely, back up separately)
echo "strong-random-password" > /path/to/.restic-password
chmod 600 /path/to/.restic-password
```

## Adding a New Service to the Backup

When a new Docker service is added to SOL:

1. Its data directory under `/data/massimiliano/<service>/` is automatically included
2. If it uses PostgreSQL, add a `pg_dump` line to the pre-hook section of `backup-sol.sh`
3. Add any large reproducible directories to the exclude list (e.g., `--exclude='*/<service>/cache'`)
4. Run a manual backup to verify: `sudo /usr/local/bin/backup-sol.sh`
5. Check the snapshot: `restic ls latest | grep <service>`

## Best Practices

1. **Always dump databases before backup** — PostgreSQL data files are not safe to back up while the server is running. Use `pg_dumpall` or `pg_dump` in a pre-hook.
2. **Exclude reproducible artifacts** — `node_modules`, `target/`, `.git/` can be regenerated and waste backup space.
3. **Keep the password file secure** — Store it outside the backup repository and back it up separately (e.g., password manager).
4. **Test restores periodically** — An untested backup is not a backup. Schedule quarterly restore drills.
5. **Use tags** — `--tag nightly` for automated runs, `--tag manual` or `--tag pre-upgrade` for one-offs.
6. **Monitor backup logs** — Check `/var/log/backup-sol.log` regularly or set up alerting on failures.
7. **Run `restic check` periodically** — At least monthly, to verify repository integrity before you need it.
8. **Include the backup script itself** — The script at `/usr/local/bin/backup-sol.sh` should be in the backup path or version-controlled.
9. **Clean up restore artifacts** — Always remove `/tmp/restore/` after completing a restore operation.

## Troubleshooting

| Problem | Diagnosis | Solution |
|---------|-----------|----------|
| Backup takes too long | `restic stats --mode raw-data` to find large blobs | Add excludes for large reproducible dirs |
| Lock file exists | Another backup running, or previous run crashed | Wait or use `restic unlock` (only if no backup is running) |
| Repository corrupted | `restic check --read-data` for thorough verification | Restore from a secondary backup or rebuild |
| PostgreSQL dump fails | Container not running or user lacks permissions | `docker ps` to check, verify `-U postgres` user |
| Disk space full | Old snapshots consuming space | `restic forget --prune` with retention flags |
| Backup log empty | Cron not running or path incorrect | `crontab -l` to verify, check cron daemon status |
| Permission denied | Script not executable or wrong user | `chmod +x /usr/local/bin/backup-sol.sh`, run as root |
| Snapshot missing expected files | Exclude patterns too broad | Review `--exclude` flags, test with `restic ls latest` |
