# Hook git commit-msg: rimozione tracce Claude

## Contesto

Claude Code aggiunge automaticamente trailers e attributions nei commit message:
- `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` (e varianti con Sonnet, Haiku, etc.)
- `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

Serve un hook `commit-msg` **globale** che li rimuova automaticamente da TUTTI i repo git sul server (~20+ repo in `/data/massimiliano/`).

## Approccio: git global `core.hooksPath`

Nessun `core.hooksPath` configurato attualmente, nessun hook `commit-msg` locale in nessun repo. Sicuro da attivare.

### Struttura

```
~/.git-hooks/              # Directory hooks globali (nuova)
└── commit-msg             # Rimuove tracce Claude dal messaggio
```

### Pattern da rimuovere (sed in-place sul file messaggio)

1. **Co-Authored-By con Claude/Anthropic**: righe che contengono `Co-Authored-By:` e `Claude` o `anthropic` (case-insensitive)
2. **Footer "Generated with Claude Code"**: righe con `Generated with.*Claude`
3. **Righe vuote residue** in fondo al messaggio (cleanup dopo rimozione)

### Script `~/.git-hooks/commit-msg`

```bash
#!/bin/bash
# Rimuove tracce Claude dal commit message
MSG_FILE="$1"

# Rimuovi righe Co-Authored-By con Claude/Anthropic
sed -i '/[Cc]o-[Aa]uthored-[Bb]y:.*[Cc]laude/d' "$MSG_FILE"
sed -i '/[Cc]o-[Aa]uthored-[Bb]y:.*[Aa]nthropic/d' "$MSG_FILE"
sed -i '/[Cc]o-[Aa]uthored-[Bb]y:.*noreply@anthropic/d' "$MSG_FILE"

# Rimuovi footer "Generated with Claude Code"
sed -i '/Generated with.*[Cc]laude/d' "$MSG_FILE"

# Rimuovi righe vuote consecutive in fondo
sed -i -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$MSG_FILE"
```

### Attivazione globale

```bash
git config --global core.hooksPath ~/.git-hooks
```

## File da creare/modificare

| File | Azione |
|------|--------|
| `~/.git-hooks/commit-msg` | Creare (nuovo) |
| git config global | `core.hooksPath = ~/.git-hooks` |
| MEMORY.md | Aggiungere nota su git global hooks |

## Verifiche

1. Creare un commit di test in un repo con messaggio contenente `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` e verificare che la riga venga rimossa
2. Verificare che commit normali (senza tracce Claude) passino inalterati
3. Verificare che `git config --global core.hooksPath` sia impostato
