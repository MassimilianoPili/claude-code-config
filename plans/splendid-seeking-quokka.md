# Migrazione claude-shared → claude-code-config [COMPLETATA]

## Riepilogo
Migrazione completata. `claude-shared` è stato decommissionato e rinominato a `.bak`.

### Fatto:
1. 6 symlink `~/.claude/{plugins,agents,plans,skills,history.jsonl,.bak}` → `claude-code-config`
2. `~/.claude/projects` → `/mnt/hdd/claude-projects`
3. 32 hook paths in `settings.json` normalizzati (path diretto, no indirezione)
4. `.gitignore` aggiornato (projects, plugins/cache, plugins/data)
5. `restic-backup` aggiornato
6. Projects mergiati (claude-shared.bak → HDD)
7. `history.jsonl` ricostruito: 411 sessioni da scan completo
8. Tutto committato (3 commit su `claude-code-config`)

### Rimane:
- `rm -rf /data/massimiliano/claude-shared.bak` (sicuro da eliminare)
- Aggiornare CLAUDE.md (riferimenti a claude-shared)
