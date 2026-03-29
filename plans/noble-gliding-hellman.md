# Task Completion Chart — Task DAG UI

## Context

The Task UI (`/tasks/`) shows a DAG of tasks with status, priority, and dependencies. The `completed_at` timestamp already exists in the DB and is populated on task completion. The user wants a **completion chart** to visualize task throughput over time. This adds observability to the task system — answering "how fast are we closing tasks?" at a glance.

## Approach

**Combined chart**: daily completion bars + cumulative line, toggled via a 4th topbar mode button ("Chart"), powered by a new backend endpoint.

## Changes

### 1. Backend — New endpoint `GET /api/stats/completion`

**File**: `task-ui/tasks.go`

Add `CompletionStats` handler (~40 lines) after the existing `Stats` handler (line 540):

```
GET /api/stats/completion?days=30
```

SQL query:
```sql
-- Daily completions (last N days)
SELECT completed_at::date AS day, COUNT(*)
FROM ag_catalog.claude_tasks
WHERE completed_at IS NOT NULL
  AND completed_at >= NOW() - INTERVAL '1 day' * $1
GROUP BY day ORDER BY day;

-- Daily creations (same range, for the cumulative gap)
SELECT created_at::date AS day, COUNT(*)
FROM ag_catalog.claude_tasks
WHERE created_at >= NOW() - INTERVAL '1 day' * $1
GROUP BY day ORDER BY day;
```

Response JSON:
```json
{
  "days": 30,
  "completed": [{"date": "2026-03-15", "count": 3}, ...],
  "created":   [{"date": "2026-03-15", "count": 2}, ...],
  "total_completed": 45,
  "total_created": 67
}
```

### 2. Backend — Register route

**File**: `task-ui/main.go` (after line 100)

```go
mux.HandleFunc("GET /api/stats/completion", authHandler.RequireAuth(taskHandler.CompletionStats))
```

### 3. Frontend — Mode button

**File**: `task-ui/static/index.html`

Add 4th button in the `.mode-group` div (after line 178):
```html
<button class="mode-btn" data-mode="chart">Chart</button>
```

Update `setupEvents()` mode handling to show/hide the chart vs DAG.

### 4. Frontend — Chart rendering with D3

**File**: `task-ui/static/index.html`

Add `renderChart()` function (~80 lines) using D3.js (already loaded):

- **Bars**: daily completed count, colored `var(--completed)` (#51cf66)
- **Line**: cumulative completed, colored `var(--accent)` (#6c8cff)
- **Secondary line** (subtle): cumulative created, colored `var(--muted)` — shows the gap
- **Axes**: x = dates, y-left = daily count, y-right = cumulative
- **Tooltip**: on hover show date + count
- **Period selector**: 7d / 30d / 90d (small button group in the chart area)
- Renders inside the existing `.canvas` SVG area (replaces DAG when in chart mode)
- Respects dark theme via CSS variables

### 5. Frontend — Mode switching logic

When mode = "chart":
- Hide DAG nodes/edges from `gRoot`
- Fetch `/api/stats/completion?days=30` and call `renderChart()`
- Show period selector buttons

When switching back to pointer/urgency/connect:
- Clear chart, restore DAG via `renderAll()`

## Files to modify
- `task-ui/tasks.go` — add `CompletionStats` handler
- `task-ui/main.go` — register route
- `task-ui/static/index.html` — mode button + chart JS/CSS

## Verification
1. `curl http://localhost:8101/api/stats/completion?days=30` — verify JSON response
2. Open `https://sol.massimilianopili.com/tasks/` → click "Chart" button → verify chart renders
3. Toggle between Chart and Pointer mode — verify DAG restores correctly
4. Test with different periods (7d, 30d, 90d)
