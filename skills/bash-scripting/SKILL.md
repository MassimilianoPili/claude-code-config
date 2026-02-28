---
name: bash-scripting
description: Bash scripting patterns for service orchestration, Docker management, Git multi-repo operations, colored output, associative arrays, argument parsing, and shell toolkit development on self-hosted Linux servers.
allowed-tools: Read, Write, Bash, Edit
category: devops
tags: [bash, shell, scripting, linux, automation, cli]
version: 1.0.0
---

# Bash Scripting — SOL Server Patterns

Shell scripts toolkit for SOL server automation. All scripts live in
`/data/massimiliano/shell-scripts/bin/` and are in PATH via `~/.bashrc`.

Main tools:
- **sol** — Docker service orchestrator (status, restart, logs)
- **deploy-mcp** — Maven multi-project deploy to Maven Central
- **gitall** — Git operations across multiple repositories
- **ssh-ensure** — SSH agent diagnostics and key loading
- **xlib** — Shared library sourced by x-tools (colors, conflict handlers)
- **x-tools** — Git helpers: xcp, xmerge, xpush, xbranch, xcommit, xstash, xalign, xalign-multi, xtree

## When to Use

- Writing a new shell script for the SOL server
- Understanding or extending the `sol` orchestrator
- Adding a new service to the Docker management toolkit
- Following the SOL server scripting conventions
- Creating Git automation scripts that integrate with xlib
- Debugging script issues (unbound variables, pipe failures, color output)

## Key Pattern 1: Script Boilerplate

All SOL scripts follow this header and strict-mode pattern:

```bash
#!/bin/bash
# =============================================================================
# script-name - One-line description
# =============================================================================
# Detailed description of what the script does.
# Usage notes, dependencies, etc.
# =============================================================================

set -uo pipefail  # Exit on unset vars, catch pipe failures
# Note: no `set -e` — we handle errors explicitly with exit codes
```

No `set -e` — errors are handled explicitly with `$?` checks and `if` blocks.
Exception: `ssh-ensure` uses `set -euo pipefail` (simple linear script).

## Key Pattern 2: Color Output

```bash
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m'       # No Color
BOLD='\033[1m'
```

Status indicators use a fixed-width bracket prefix for aligned output:

```bash
echo -e "${GREEN}[ OK ]${NC} Service started"
echo -e "${RED}[FAIL]${NC} Service failed"
echo -e "${YELLOW}[WARN]${NC} Directory not found"
echo -e "${CYAN}[INFO]${NC} Restarting nginx..."
echo -e "${BLUE}[....]${NC} Starting..."       # In-progress placeholder
echo -e "${BLUE}[STEP]${NC} Fetching remotes..."
```

Headers use bold + blue:

```bash
echo -e "\n${BOLD}${BLUE}Header Text${NC}\n"
```

## Key Pattern 3: Shared Library (xlib)

Sourced (not executed) by x-tools for shared colors, output helpers, and
interactive conflict handlers. Source pattern with fallback:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/xlib" ]; then
  source "$SCRIPT_DIR/xlib"
else
  echo "[ERROR] xlib non trovato in $SCRIPT_DIR" >&2
  exit 1
fi
```

Functions provided by xlib:

```bash
print_success "msg"   # [OK] green
print_warning "msg"   # [WARN] yellow
print_error "msg"     # [ERROR] red
print_info "msg"      # [INFO] cyan
print_step "msg"      # [STEP] blue

has_local_changes_error "$output"   # detect "local changes would be overwritten"
has_unresolved_merge_error "$output"  # detect unresolved merge state
has_conflicts                       # check git ls-files -u

handle_local_changes "operation" "target"  # interactive: stash/discard/abort
handle_unresolved_merge                    # interactive: reset/abort
handle_conflicts "source" ["target"]       # interactive: mergetool/theirs/ours/continue/abort
apply_stash_if_needed                      # pop stash if XLIB_STASH_CREATED=true
```

## Key Pattern 4: Associative Arrays (Service Maps)

```bash
# Service -> directory mapping
declare -A SERVICE_DIR=(
  [postgres]="/data/massimiliano/postgres"
  [redis]="/data/massimiliano/redis"
  [keycloak]="/data/massimiliano/keycloak"
  [proxy]="/data/massimiliano/proxy"
  [filemanager]="/data/massimiliano/Vari/go-filemanager"
  # ...
)

# Service aliases for convenient names
declare -A SERVICE_ALIAS=(
  [nginx]="proxy"
  [db]="postgres"
  [pg]="postgres"
  [kc]="keycloak"
  [tunnel]="cloudflared"
  [files]="filemanager"
  [fm]="filemanager"
  [claude]="claude-proxy"
  [api]="server-api"
)

# Resolve alias to canonical name
resolve_service() {
  local name=$1
  if [ -n "${SERVICE_ALIAS[$name]+_}" ]; then
    echo "${SERVICE_ALIAS[$name]}"
  else
    echo "$name"
  fi
}
```

The `${ARRAY[$key]+_}` syntax checks key existence without triggering `set -u`
errors. Without it, accessing a non-existent key aborts the script.

## Key Pattern 5: Boot Order with Dependencies

Services have a defined startup order respecting dependencies. Nginx is last
because it needs all upstream containers on the Docker network.

```bash
BOOT_ORDER=(postgres redis keycloak gitea pgadmin portainer filemanager claude-proxy server-api kp-manager cloudflared proxy)

# Services that are nginx upstreams (need nginx restart after recreate)
NGINX_DEPS=(keycloak gitea pgadmin portainer filemanager claude-proxy server-api kp-manager)

is_nginx_dep() {
  local svc=$1
  for dep in "${NGINX_DEPS[@]}"; do
    [[ "$dep" == "$svc" ]] && return 0
  done
  return 1
}

# Auto-restart nginx when an upstream is recreated (DNS caching issue)
cmd_restart() {
  local target=$(resolve_service "$1")
  restart_service "$target"
  if is_nginx_dep "$target" && [ "$target" != "proxy" ]; then
    echo -e "${CYAN}[INFO]${NC} $target e' upstream di nginx — riavvio nginx..."
    restart_service "proxy"
  fi
}
```

## Key Pattern 6: Progress Indicator (Overwrite Line)

Print `[....]` without newline, run command, then `\r` overwrites with result:

```bash
restart_service() {
  local svc=$1
  local dir="${SERVICE_DIR[$svc]}"
  [ ! -d "$dir" ] && { echo -e "${YELLOW}[WARN]${NC} $svc: dir non trovata"; return; }

  echo -ne "${BLUE}[....]${NC} $svc "
  local output
  output=$(cd "$dir" && docker compose up -d --force-recreate 2>&1)
  if [ $? -eq 0 ]; then
    echo -e "\r${GREEN}[ OK ]${NC} $svc"
  else
    echo -e "\r${RED}[FAIL]${NC} $svc"
    echo "$output" | head -5
  fi
}
```

## Key Pattern 7: Argument Parsing (while + case)

```bash
DRY_RUN=false
SKIP_TESTS=true
TARGETS=()

while [ $# -gt 0 ]; do
  case $1 in
    --dry-run) DRY_RUN=true; shift ;;
    --with-tests) SKIP_TESTS=false; shift ;;
    --list|-l) list_projects; exit 0 ;;
    -h|--help) show_help; exit 0 ;;
    -*) echo -e "${RED}[ERROR]${NC} Unknown option: $1"; exit 1 ;;
    *) TARGETS+=("$1"); shift ;;
  esac
done

# Default to all targets when none specified
if [ ${#TARGETS[@]} -eq 0 ]; then
  TARGETS=("${ALL_PROJECTS[@]}")
fi
```

For options with values, use `shift 2`:

```bash
case $1 in
  -s|--start)
    START_BRANCH="$2"
    shift 2
    ;;
esac
```

## Key Pattern 8: Subcommand Dispatch

```bash
# === MAIN ===
if [ $# -eq 0 ]; then
  cmd_help
  exit 0
fi

case $1 in
  status|s)    cmd_status ;;
  restart|r)   [ $# -lt 2 ] && { echo "Usage: sol restart <service>"; exit 1; }
               cmd_restart "$2" ;;
  logs|l)      shift; cmd_logs "$@" ;;
  list|ls)     cmd_list ;;
  help|h|-h|--help) cmd_help ;;
  *)           echo -e "${RED}[ERROR]${NC} Comando sconosciuto: $1"
               cmd_help; exit 1 ;;
esac
```

Each subcommand has a full name and a short alias. Unknown commands show help.

## Key Pattern 9: Summary Report (Success/Failure Counters)

```bash
SUCCESSES=()
FAILURES=()

for project in "${TARGETS[@]}"; do
  # ... do work ...
  if [ $exit_code -eq 0 ]; then
    SUCCESSES+=("$project")
  else
    FAILURES+=("$project")
  fi
done

# Summary
echo ""
if [ ${#SUCCESSES[@]} -gt 0 ]; then
  echo -e "${GREEN}Successi (${#SUCCESSES[@]}):${NC} ${SUCCESSES[*]}"
fi
if [ ${#FAILURES[@]} -gt 0 ]; then
  echo -e "${RED}Falliti (${#FAILURES[@]}):${NC} ${FAILURES[*]}"
  exit 1
fi
```

## Key Pattern 10: Tabular Status Output

Use `printf` with fixed-width format strings for aligned columns. Parse
multi-line `docker compose ps` output with `while IFS=$'\t' read -r`:

```bash
cmd_status() {
  printf "%-16s %-20s %s\n" "SERVIZIO" "CONTAINER" "STATO"
  printf "%-16s %-20s %s\n" "--------" "---------" "-----"

  for svc in "${BOOT_ORDER[@]}"; do
    local output
    output=$(cd "${SERVICE_DIR[$svc]}" && docker compose ps --format '{{.Name}}\t{{.Status}}' 2>/dev/null)
    if [ -z "$output" ]; then
      printf "%-16s %-20s ${RED}%s${NC}\n" "$svc" "-" "non avviato"
    else
      while IFS=$'\t' read -r name status; do
        local color=$GREEN
        [[ "$status" == *"Exit"* ]] && color=$RED
        [[ "$status" == *"starting"* ]] && color=$YELLOW
        printf "%-16s %-20s ${color}%s${NC}\n" "$svc" "$name" "$status"
      done <<< "$output"
    fi
  done
}
```

## Key Pattern 11: Trap and Cleanup

For scripts that create temporary files or change state, use `trap` for cleanup:

```bash
TEMP_FILE=$(mktemp)
ORIGINAL_BRANCH=""

cleanup() {
  [ -n "$TEMP_FILE" ] && [ -f "$TEMP_FILE" ] && rm -f "$TEMP_FILE"
  if [ -n "$ORIGINAL_BRANCH" ]; then
    git checkout "$ORIGINAL_BRANCH" 2>/dev/null || true
  fi
}

trap cleanup EXIT
trap 'echo ""; cleanup; exit 130' INT TERM
```

## Key Pattern 12: Multi-Repo Operations

The `gitall` pattern iterates over repos, running commands in subshells with
indented output via `sed 's/^/  /'` and repo name headers in brackets:

```bash
ALL_REPOS=(mcp-mongo-tools mcp-sql-tools mcp-devops-tools spring-ai-reactive-tools)

run_on_repos() {
  local cmd=$1
  for repo in "${ALL_REPOS[@]}"; do
    local dir="$BASE_DIR/$repo"
    if [ -d "$dir" ] && (cd "$dir" && git rev-parse --git-dir &>/dev/null); then
      echo -e "${BOLD}${CYAN}[$repo]${NC}"
      (cd "$dir" && eval "$cmd" 2>&1) | sed 's/^/  /'
    fi
  done
}
```

## Shell Scripts Toolkit Reference

| Script | Purpose | Key Usage |
|--------|---------|-----------|
| `sol` | Docker service orchestrator | `sol status`, `sol restart keycloak`, `sol logs -f proxy` |
| `deploy-mcp` | Maven Central deploy | `deploy-mcp`, `deploy-mcp mongo sql`, `deploy-mcp --dry-run` |
| `gitall` | Multi-repo Git ops | `gitall status`, `gitall pull`, `gitall push --only mcp-mongo-tools` |
| `ssh-ensure` | SSH agent diagnostics | `ssh-ensure`, `ssh-ensure --quiet` |
| `xlib` | Shared library (sourced) | `source "$SCRIPT_DIR/xlib"` |
| `xcp` | Smart checkout + pull | `xcp develop` (handles local changes, auto-pulls if behind) |
| `xmerge` | Merge with conflict UI | `xmerge feature/xyz` (interactive conflict resolution) |
| `xpush` | Push current branch | `xpush` (auto-sets upstream) |
| `xbranch` | Create + checkout branch | `xbranch feature/new` |
| `xcommit` | Quick commit | `xcommit` (git commit --no-edit) |
| `xstash` | Stash all | `xstash` (git stash --all) |
| `xalign` | Cascade branch alignment | `xalign -s master-collaudo -e release/test --dry-run` |
| `xalign-multi` | Multi-repo alignment | `xalign-multi` |
| `xtree` | Git worktree add | `xtree feature/xyz` |

## Best Practices

1. **`set -uo pipefail` always, `set -e` never** (unless trivially linear script) — handle errors explicitly
2. **Associative arrays** for service/project maps with `${ARRAY[$key]+_}` existence check
3. **Color output** with fixed-width status indicators: `[ OK ]`, `[FAIL]`, `[WARN]`, `[INFO]`, `[....]`
4. **`\r` overwrite** for progress lines — print `[....]` first, then overwrite with result
5. **`--dry-run`** support for all destructive or batch operations
6. **Default to all** targets when none specified (deploy-mcp, sol restart all)
7. **`--help` and `help` subcommand** on every script, both `-h` and `--help` flags
8. **`local`** for all function variables (prevent pollution of global scope)
9. **Capture output** in variables for clean progress display (`output=$(command 2>&1)`)
10. **Summary report** after batch operations with success/failure counters
11. **Boot order array** to encode service dependencies
12. **Auto-restart nginx** when an upstream container is recreated (DNS caching)

## Docker Compose Conventions

All services restart with `--force-recreate` (never `docker compose restart`):

```bash
cd /data/massimiliano/<service> && docker compose up -d --force-recreate
```

Never use `docker exec nginx nginx -s reload` with bind-mounted config files.
Docker mounts by inode — editors that create new files break the bind mount.

## Troubleshooting

- **Command not found**: Verify PATH includes `/data/massimiliano/shell-scripts/bin/` (check `~/.bashrc`)
- **Unbound variable**: Use `${VAR:-default}` for optional values, `${ARRAY[$key]+_}` for associative array key checks
- **Pipe failure not caught**: Ensure `set -o pipefail` is set; use `${PIPESTATUS[0]}` to get exit code before the pipe
- **Colors not showing**: Verify terminal supports ANSI, always use `echo -e` (not plain `echo`)
- **Progress line not overwriting**: Check that the first `echo -ne` has no trailing newline and the second uses `\r`
- **Nginx 502 after restart**: The `sol` orchestrator handles this automatically; if running manually, restart nginx after recreating any upstream service
