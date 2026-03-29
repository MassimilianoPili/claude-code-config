# Plan: Reorganize Memory System

## Context
MEMORY.md is 286 lines (limit: 200). The bottom ~86 lines are **truncated and never loaded** into future conversations. Critical memories (conventions, git safety, testing policy, Maven deploy rules, Claude Code setup) are invisible. The root cause is that MEMORY.md contains extensive inline content instead of being a pure index.

## Strategy: Slim MEMORY.md to a Pure Index

### Phase 1: Extract inline content into topic files

Each MEMORY.md section that has inline content needs its content moved into its own file. Only a 1-line description + link should remain in MEMORY.md.

**Sections to extract (new files to create):**

1. **Knowledge Graph section** (lines 7-26, ~20 lines inline) → `reference_kore_graph.md`
   - Move: domain stats, import scripts, sync info, MCP graph tools list, AGE query syntax
   - Keep in MEMORY.md: 1-line link + "FONTE PRIMARIA" directive

2. **Core Infrastructure** (lines 28-37) → already has `architecture.md`, just trim inline
   - Move: A2A Gateway details, SearXNG, zero-downtime details → topic files already exist
   - Keep: 1-line summary + links to existing files

3. **MCP Libraries** (lines 94-136, ~40 lines!) → `project_mcp_ecosystem.md`
   - Move: all tool counts, library details, HMAC auth, config patterns, redis/gitea tools
   - Keep: 1-line + link

4. **Services & Databases** (lines 63-70) → `reference_services.md`
   - Move: WikiJS details, FerretDB, embedding model, Anki pipeline
   - Keep: 1-line + link

5. **Paper Archive** (lines 72-86) → already has detail, but MEMORY.md duplicates it
   - Merge inline content into existing `reference_research.md` or new `project_paper_archive.md`
   - Keep: 1-line + link

6. **Conventions** (lines 241-253) → `feedback_conventions.md`
   - Move: all convention bullet points
   - Keep: 1-line + link

7. **Claude Code Setup** (lines 255-276) → `reference_claude_code_setup.md`
   - Move: hooks list, plugins count, chat tracker, agent-framework hooks
   - Keep: 1-line + link

8. **Small Web + Web Tools** (lines 115-136) → content already in `project_smallweb_crawler.md` and `project_web_tools.md`
   - Just trim to 1-line links

### Phase 2: Deduplicate

Several topic files contain content that's also duplicated in MEMORY.md. After Phase 1, verify no duplication remains.

### Phase 3: Rewrite MEMORY.md as pure index

Target format — each entry should be MAX 2 lines:
```
## Section Name
[filename.md](filename.md) — one-line description
```

**Target: MEMORY.md under 120 lines** (well within 200-line limit, with room to grow).

### Phase 4: Optional — Subdirectories

Organize 43+ files into subdirectories:
```
memory/
├── MEMORY.md
├── user/          # user_*.md (2 files)
├── feedback/      # feedback_*.md (12 files)
├── project/       # project_*.md (20 files)
├── reference/     # reference_*.md (5 files)
└── other/         # architecture.md, shell-scripts.md
```

**Risk**: All existing MEMORY.md links use flat paths (`[file.md](file.md)`). Moving to subdirs requires updating all links. Also, the memory system docs say to write files directly to the memory dir — subdirs might confuse future auto-saves.

**Decision**: Keep flat. User confirmed. The real win is slimming MEMORY.md.

## Files to modify
- `/home/massimiliano/.claude/projects/-data-massimiliano/memory/MEMORY.md` — rewrite as pure index
- ~7 new topic files to create (extracting inline content)
- ~5 existing topic files to update (merging duplicated content)

## Verification
1. `wc -l MEMORY.md` → should be < 150 lines
2. All 43+ memory files still accessible via links
3. No content lost — every inline paragraph moved to a topic file
4. Critical memories (conventions, git safety, testing policy) now in their own files with proper links in the top 150 lines of MEMORY.md
