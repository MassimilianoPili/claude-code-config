# Allinea README e push librerie MCP

## Contesto

Dopo la migrazione Java 21 e le sessioni di sviluppo, due librerie MCP hanno modifiche locali da committare e pushare.

**Stato attuale:**

| Libreria | Modifiche | Dettaglio |
|----------|-----------|-----------|
| `mcp-filesystem-tools` | Staged: `FileSystemTools.java` (+93/-8) | `fs_read` con paginazione (offset/limit, line numbering), nuovo `fs_grep`, nuovo `fs_write` |
| `mcp-sql-tools` | Manca `.gitignore`, `target/` tracciato in git | Build artifacts committati per errore |
| 3 repos | `CLAUDE.md` non tracciato | Auto-generato da sessioni Claude Code, da ignorare |

Tutte le librerie sono a `ahead=0` sia vs `origin` (Gitea) che vs `github` (mirror).

## Piano

### Step 1: Aggiornare README di `mcp-filesystem-tools`

**File**: `/data/massimiliano/Vari/mcp-filesystem-tools/README.md`

Aggiornare la tabella Tools per riflettere i nuovi tool e le modifiche a `fs_read`:

```markdown
| Tool | Description |
|------|-------------|
| `fs_list` | List files and directories at a given path |
| `fs_read` | Read file contents with line numbering and pagination (offset/limit, default 50 lines) |
| `fs_grep` | Search for text/regex patterns in files within a directory (max 50 matches) |
| `fs_write` | Write (create/overwrite) text files with auto-directory creation (max 500KB) |
| `fs_search` | Search files by name pattern (max 10 levels, 100 results) |
```

### Step 2: Fix `mcp-sql-tools` — aggiungere `.gitignore` e rimuovere `target/` dal tracking

**Creare**: `/data/massimiliano/Vari/mcp-sql-tools/.gitignore` (copiato da `spring-ai-reactive-tools/.gitignore`)

```
target/
.idea/
*.iml
*.class
*.jar
*.log
.DS_Store
.settings/
.project
.classpath
```

**Poi**: `git rm -r --cached target/` per rimuovere gli artifacts dall'indice senza cancellarli dal disco.

### Step 3: Aggiungere `CLAUDE.md` ai `.gitignore`

Appendere `CLAUDE.md` ai `.gitignore` di tutti i 13 repo MCP, per prevenire commit accidentali in futuro.

### Step 4: Commit e push

**mcp-filesystem-tools** (2 commit):
1. Commit staged: "Add fs_grep and fs_write tools, add pagination to fs_read"
2. Commit README + .gitignore update: "Update README with new tools, add CLAUDE.md to gitignore"
3. Push a `origin` + `github`

**mcp-sql-tools**:
1. Commit: "Add .gitignore, remove tracked build artifacts"
2. Push a `origin` + `github`

**Altri repo** (solo .gitignore update, se CLAUDE.md aggiunto):
1. Commit: "Add CLAUDE.md to gitignore"
2. Push a `origin` + `github`

## Verifica

- `git status` pulito in tutti i repo dopo push
- `git log --oneline -1` mostra i nuovi commit
- README di `mcp-filesystem-tools` elenca tutti e 5 i tool
- `target/` non piu' tracciato in `mcp-sql-tools`
