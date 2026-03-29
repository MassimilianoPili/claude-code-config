# Plan: Add task dependencies via junction table

## Context
The `claude_tasks` table supports inter-session Claude task coordination but tasks are independent. Adding a `claude_task_deps` junction table enables multi-dependency DAGs with proper FK integrity.

## Design: Junction table `claude_task_deps`

```sql
CREATE TABLE claude_task_deps (
    task_id       BIGINT NOT NULL REFERENCES claude_tasks(task_id) ON DELETE CASCADE,
    depends_on_id BIGINT NOT NULL REFERENCES claude_tasks(task_id) ON DELETE CASCADE,
    PRIMARY KEY (task_id, depends_on_id),
    CHECK (task_id <> depends_on_id)
);
CREATE INDEX idx_task_deps_dep ON claude_task_deps(depends_on_id);
```

- Two FK constraints → referential integrity enforced by DB
- CASCADE DELETE → removing a task cleans up edges
- Composite PK → no duplicate deps
- Self-reference CHECK → no circular self-dep
- Reverse index → efficient "what depends on #X" lookup

## Changes

### 1. DB Schema
Run `CREATE TABLE` + index on PostgreSQL `embeddings` DB.

### 2. Java — `ClaudeTaskQueueTools.java`

**`claude_task_enqueue`**: add optional `dependsOn` param (`String`, comma-separated IDs e.g. `"3,5,12"`). After INSERT, batch-insert into `claude_task_deps`. Warn if any referenced ID doesn't exist (FK will reject).

**`claude_task_list`**: LEFT JOIN with `array_agg(depends_on_id)` grouped. Format output: `dep:#3,#5` or `dep:-`. For PENDING tasks, check if all deps are COMPLETED — show `[BLOCKED]` if not.

**`claude_task_claim`**: query unmet deps via:
```sql
SELECT d.depends_on_id, t.status
FROM claude_task_deps d JOIN claude_tasks t ON t.task_id = d.depends_on_id
WHERE d.task_id = ? AND t.status <> 'COMPLETED'
```
Block claim if any rows returned. Error lists unmet deps with their statuses.

### 3. Files to modify
- `/data/massimiliano/Vari/mcp/src/main/java/com/example/mcp/tools/ClaudeTaskQueueTools.java`
- Direct DDL on PostgreSQL

### 4. Verification
- DDL on live DB
- Build: `cd /data/massimiliano/Vari/mcp && /opt/maven/bin/mvn clean compile`
- Deploy: `sol deploy mcp`
- Test: enqueue with deps, list shows dep column + BLOCKED, claim blocked on unmet deps, delete cascades
