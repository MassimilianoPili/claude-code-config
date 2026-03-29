# Piano: Push Custom Hooks e Skills su Gitea (Single Source of Truth)

## Context

13 hook + 102 skill Claude Code. Repo Git = unica sorgente, Claude Code li legge via symlink.

## Stato attuale (gia' fatto)

- [x] Creata directory `/data/massimiliano/claude-code-config/`
- [x] **Spostati** (mv) 13 hooks da `/data/massimiliano/.claude/hooks/` → `repo/hooks/`
- [x] **Spostate** (mv) 102 skills da `/data/massimiliano/claude-shared/skills/` → `repo/skills/`
- **ATTENZIONE**: symlink rotti — hooks e skills non raggiungibili da Claude Code fino al passo 1

## Passi rimanenti

### Passo 1 (URGENTE): Creare symlink

I path in `settings.json` usano `/data/massimiliano/.claude/hooks/xxx.sh`.
Il symlink `~/.claude/skills` punta a `/data/massimiliano/claude-shared/skills` (che non esiste piu').

```bash
# Hooks: settings.json riferisce /data/massimiliano/.claude/hooks/xxx.sh
ln -s /data/massimiliano/claude-code-config/hooks /data/massimiliano/.claude/hooks

# Skills: ~/.claude/skills → claude-shared/skills → repo/skills
ln -s /data/massimiliano/claude-code-config/skills /data/massimiliano/claude-shared/skills
```

Verifica: `ls -la /data/massimiliano/.claude/hooks/block-dangerous-commands.sh` deve funzionare.
Verifica: `ls -la /home/massimiliano/.claude/skills/` deve listare 102 directory.

### Passo 2: Generare settings-hooks.json

Estrarre solo `"hooks": {...}` da `/home/massimiliano/.claude/settings.json` (righe 99-202).
File: `/data/massimiliano/claude-code-config/settings-hooks.json`

### Passo 3: Generare README.md

File: `/data/massimiliano/claude-code-config/README.md`
Contenuto:
- Descrizione repo (single source of truth per Claude Code config)
- Tabella 13 hook (nome, evento, matcher, descrizione breve)
- Elenco 102 skill raggruppate per categoria (tabella)
- Istruzioni installazione (symlink + merge settings-hooks.json)

### Passo 4: Generare .gitignore

File: `/data/massimiliano/claude-code-config/.gitignore`
```
*.log
audit/
.env
*.key
*.pem
```

### Passo 5: Git init + creare repo Gitea + push

```bash
cd /data/massimiliano/claude-code-config
git init -b main
git add -A
git commit -m "Initial commit: 13 hooks + 102 skills (single source of truth)"

# Creare repo su Gitea via API
curl -s -X POST "http://gitea:3000/api/v1/user/repos" \
  -H "Authorization: token <TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"name":"claude-code-config","description":"Claude Code hooks + skills","private":false}'

# Oppure via SSH
git remote add origin git@gitea-local:sol_root/claude-code-config.git
git push -u origin main
```

## Struttura finale

```
/data/massimiliano/claude-code-config/    ← REPO GIT (source of truth)
├── hooks/                                 # 13 hook .sh (file reali)
├── skills/                                # 102 dir/SKILL.md (file reali)
├── settings-hooks.json                    # Reference config hooks
├── .gitignore
└── README.md

Symlink chain:
  /data/massimiliano/.claude/hooks → .../claude-code-config/hooks
  /data/massimiliano/claude-shared/skills → .../claude-code-config/skills
  ~/.claude/skills → .../claude-shared/skills  (symlink preesistente, ora funziona via catena)
```

## Verifica

1. `ls /data/massimiliano/.claude/hooks/*.sh | wc -l` → 13 (symlink OK)
2. `ls ~/.claude/skills/ | wc -l` → 102 (catena symlink OK)
3. `cd /data/massimiliano/claude-code-config && git log --oneline` → commit
4. Gitea: `https://sol.massimilianopili.com/git/sol_root/claude-code-config`
