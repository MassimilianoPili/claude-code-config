# Plan: Auto-restore Claude VS Code extension panels after SSH reconnect

## Context

The user runs Claude Code via the VS Code extension over Remote SSH. When SSH drops:
- VS Code reconnects to the same `vscode-server` process
- The old Claude processes keep running (orphaned, children of vscode-server)
- The extension's `deserializeWebviewPanel` recreates panels, but only restores `isFullEditor` — **not the session UUID** (`D.setupPanel(G, void 0, void 0, F)`)
- Panels appear empty/reset, previous conversations gone from UI

**Key discovery**: The `claude-vscode.editor.open` command accepts a session UUID as first argument:
```javascript
registerCommand("claude-vscode.editor.open", async(sessionId, initialPrompt, viewColumn) => {
    D.createPanel(sessionId, initialPrompt);
})
```

**Solution**: A lightweight companion VS Code extension that:
1. Detects orphaned Claude `--resume <uuid>` processes on activation
2. Auto-opens panels for each using `claude-vscode.editor.open(uuid)`
3. Zero config, works silently after SSH reconnect

## Part 1: Companion extension `claude-session-restore`

### New directory
- `/data/massimiliano/claude-session-restore/`

### Files

```
claude-session-restore/
├── package.json
├── tsconfig.json
└── src/
    └── extension.ts    # ~60 lines
```

### package.json

```json
{
  "name": "claude-session-restore",
  "displayName": "Claude Session Restore",
  "description": "Auto-restores Claude Code panels after VS Code Remote SSH reconnect",
  "version": "0.1.0",
  "publisher": "massimiliano",
  "engines": { "vscode": "^1.85.0" },
  "activationEvents": ["onStartupFinished"],
  "extensionDependencies": ["anthropic.claude-code"],
  "main": "./out/extension.js",
  "contributes": {
    "commands": [{
      "command": "claude-session-restore.restore",
      "title": "Claude: Restore Previous Sessions"
    }]
  }
}
```

### extension.ts

Uses `execFile` (not `exec`) to avoid shell injection. Spawns `ps` directly and parses output in JS.

```typescript
import * as vscode from 'vscode';
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

export function activate(context: vscode.ExtensionContext) {
    setTimeout(() => autoRestore(context), 5000);

    context.subscriptions.push(
        vscode.commands.registerCommand('claude-session-restore.restore',
            () => autoRestore(context))
    );
}

async function findOrphanedSessions(): Promise<string[]> {
    const { stdout } = await execFileAsync('ps', ['aux'], { timeout: 5000 });
    const uuidRegex = /--resume\s+([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/g;
    const sessionIds = new Set<string>();
    let match;
    while ((match = uuidRegex.exec(stdout)) !== null) {
        sessionIds.add(match[1]);
    }
    return [...sessionIds];
}

async function autoRestore(context: vscode.ExtensionContext) {
    try {
        const sessionIds = await findOrphanedSessions();
        if (sessionIds.length === 0) return;

        const restoredKey = 'lastRestoredSessions';
        const lastRestored = context.globalState.get<string[]>(restoredKey, []);
        const toRestore = sessionIds.filter(id => !lastRestored.includes(id));
        if (toRestore.length === 0) return;

        for (const sessionId of toRestore) {
            await vscode.commands.executeCommand(
                'claude-vscode.editor.open', sessionId
            );
            await new Promise(r => setTimeout(r, 1500));
        }

        await context.globalState.update(restoredKey, sessionIds);
        vscode.window.showInformationMessage(
            `Restored ${toRestore.length} Claude session(s)`
        );
    } catch {
        // Silently fail
    }
}

export function deactivate() {}
```

### How it works

1. Extension activates `onStartupFinished` (after Claude Code is ready)
2. After 5s delay, runs `ps aux` via `execFile` (no shell) to find `--resume <uuid>` processes
3. Parses output with regex to extract session UUIDs
4. Filters out sessions already restored in this window lifecycle (via `globalState`)
5. For each orphaned session: `claude-vscode.editor.open(sessionId)` → opens panel with conversation
6. Manual command `Claude: Restore Previous Sessions` also available in command palette

**Why this works**:
- Fresh VS Code start: no orphaned `--resume` processes → nothing happens
- SSH reconnect: orphaned processes exist → panels auto-restored
- `globalState` prevents double-restore within same window lifecycle

### Build & install

```bash
cd /data/massimiliano/claude-session-restore
npm init -y
npm install --save-dev @types/vscode typescript @vscode/vsce
npx tsc
npx @vscode/vsce package
# Install in vscode-server for Remote SSH:
code --install-extension claude-session-restore-0.1.0.vsix
```

## Part 2: `chat running` CLI command (fallback)

### File to modify
- `/data/massimiliano/shell-scripts/bin/chat`

### New command

```bash
running|ps)
    ps aux | grep -oP '(?<=--resume )[0-9a-f-]+' | sort -u | while read SID; do
        ROW=$($PSQL -c "
            SELECT chat_id || '|' || coalesce(left(title,50), '(in corso)')
            FROM chat_sessions WHERE session_id = '${SID}';
        ")
        [ -n "$ROW" ] && echo "#${ROW%%|*}  ${ROW#*|}  ($SID)"
    done
    ;;
```

Useful as manual fallback from VS Code terminal or raw SSH.

## Verification

### Extension auto-restore
1. Open 2-3 Claude panels in VS Code, start conversations (note Chat #N)
2. Simulate reconnect: Developer → Reload Window (or kill SSH + reconnect)
3. After 5s, restored panels should appear with conversations intact
4. Info message: "Restored N Claude session(s)"
5. Reloading again should NOT double-restore (globalState guard)

### Manual restore command
1. Open command palette → "Claude: Restore Previous Sessions"
2. Should find and restore any orphaned sessions

### `chat running` fallback
1. From terminal: `chat running` → lists active sessions with Chat #N and UUIDs
