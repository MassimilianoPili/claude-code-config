# Fix Wiki Rotte: Header Doppi, Link Duplicati, Artefatti

## Context

Le pagine WikiJS esportate via git sync presentano 3 problemi sistematici:
1. **105 paper** con H1 duplicato (titolo appare 2 volte)
2. **home.md** con ogni link duplicato (24 link x2 = 48)
3. **Directory `docs/docs/`** con file duplicati e frontmatter doppio (artefatto git sync)
4. **`papers/.md`** — file vuoto con nome invalido

### Root Cause Analysis

**Header doppi nei paper** (`/data/massimiliano/docs/papers/*.md`):
- `paper_archive.py` (riga 449) genera contenuto che inizia con `# {title}`
- WikiJS git sync, quando esporta, prepende automaticamente `# {title}` dal campo `title` della pagina
- Risultato: `# TITOLO\n\n# TITOLO\n\n| Campo | Valore |...`
- **Fix**: rimuovere `# {title}\n\n` dal template in `paper_archive.py`, perche' WikiJS lo aggiunge gia'

**Link duplicati in home.md**:
- `import-docs.js` → `scanDocsDirectory()` scansiona `/data/massimiliano/docs/` ricorsivamente
- La directory `docs/docs/` (artefatto git sync) contiene duplicati dei file root
- Lo scanner genera 2 entry con stesso path per ogni file (root + subdirectory)
- `generateHomePage()` li elenca entrambi → link duplicati
- **Fix**: eliminare `docs/docs/` (artefatto) + aggiungere filtro in scanner per ignorare `docs/` subdirectory

**Directory `docs/docs/` con frontmatter doppio**:
- WikiJS git sync esporta le pagine con path `docs/backup` come `docs/backup.md` dentro il repo
- Poiche' il repo root E' `/data/massimiliano/docs/`, il risultato e' `docs/docs/backup.md`
- Il frontmatter doppio e' probabilmente un conflitto merge mai risolto
- **Fix**: eliminare tutta la directory `docs/docs/`, gia' tracciata come `STANDALONE_FILES` in `docs-sync`

**Mermaid**: 4 file in `agent-framework/` con blocchi mermaid. WikiJS v2 li renderizza nativamente — non e' un bug.

---

## Piano di Intervento

### Step 1: Fix `paper_archive.py` — Rimuovere H1 dal template

File: `/data/massimiliano/kindle/paper_archive.py` (riga 449)

```python
# PRIMA (riga 449):
content = f"""# {title}

| Campo | Valore |
# DOPO:
content = f"""| Campo | Valore |
```

Il titolo e' gia' nel campo `title` della pagina WikiJS. Il git sync lo aggiungera' come H1 nell'export.

### Step 2: Fix header doppi nei 105 file paper esistenti

Script one-shot per rimuovere la prima riga `# TITOLO` duplicata da tutti i file in `docs/papers/`:
```bash
for f in /data/massimiliano/docs/papers/*.md; do
  # Se le righe 1 e 3 sono identiche e iniziano con #, rimuovi riga 1+2
  line1=$(sed -n '1p' "$f")
  line3=$(sed -n '3p' "$f")
  if [[ "$line1" == "$line3" ]] && [[ "$line1" == \#* ]]; then
    sed -i '1,2d' "$f"
  fi
done
```

### Step 3: Fix `import-docs.js` — Filtrare directory `docs/`

File: `/data/massimiliano/wikijs/import-docs.js` (riga 42, dentro `walk()`)

Aggiungere filtro per ignorare la subdirectory `docs` (artefatto git sync):
```javascript
if (item.isDirectory()) {
  // Skip docs/ subdirectory (WikiJS git sync artifact)
  if (item.name === 'docs' && !prefix) continue;
  walk(fullPath, prefix ? `${prefix}/${item.name}` : item.name);
```

### Step 4: Eliminare artefatti

```bash
# Rimuovere directory duplicata
rm -rf /data/massimiliano/docs/docs/

# Rimuovere file paper vuoto
rm /data/massimiliano/docs/papers/.md

# Git add removals
git -C /data/massimiliano/docs add -A docs/ papers/.md
```

### Step 5: Rigenerare home.md e aggiornare WikiJS

```bash
# Rigenerare home page (senza duplicati) e aggiornare wiki
cd /data/massimiliano/wikijs && node import-docs.js --update
```

### Step 6: Aggiornare pagine paper in WikiJS (rimuovere H1 dal DB)

Script per aggiornare il contenuto delle 105 pagine paper nel DB WikiJS, rimuovendo l'H1 iniziale:
```bash
docker exec postgres psql -U wikijs -d wikijs -c "
  UPDATE pages SET content = regexp_replace(content, E'^# [^\n]+\n\n', '')
  WHERE path LIKE 'papers/%' AND content ~ E'^# ';"
```

### Step 7: Commit e sync

```bash
git -C /data/massimiliano/docs add -A && git -C /data/massimiliano/docs commit -m "fix: rimuovi header doppi paper, link duplicati home, artefatti docs/"
docs-sync
```

---

## File da Modificare

| File | Modifica |
|------|----------|
| `/data/massimiliano/kindle/paper_archive.py:449` | Rimuovere `# {title}\n\n` dal template |
| `/data/massimiliano/wikijs/import-docs.js:42-46` | Filtrare directory `docs/` nello scanner |
| `/data/massimiliano/docs/papers/*.md` (105 file) | Script: rimuovere H1 duplicato |
| `/data/massimiliano/docs/docs/` (15 file) | Eliminare directory |
| `/data/massimiliano/docs/papers/.md` | Eliminare file vuoto |
| WikiJS DB `pages` (105 righe) | SQL: rimuovere H1 iniziale dal contenuto |

## Verifica

1. Controllare un paper a campione su WikiJS (`wiki.massimilianopili.com/en/papers/edwards-1975`) — deve avere un solo H1
2. Controllare home page — ogni link deve apparire una sola volta
3. `ls /data/massimiliano/docs/docs/` — non deve esistere
4. `node import-docs.js --scan` — nessun duplicato
5. Runnare `paper-archive --dry-run` — verificare che il template non includa piu' `# {title}`
