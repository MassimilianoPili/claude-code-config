# Piano: Installare tool di sviluppo aggiuntivi

## Contesto
Completare il toolset dell'host con linter, formatter e utility che Claude Code usa attivamente.
Python e Go sono già installati. gofmt già presente con Go.

## Step 1 — Tool APT (ShellCheck, tree, Lua)
```bash
sudo apt install -y shellcheck tree lua5.4
```

## Step 2 — yq (binary da GitHub, non APT)
```bash
sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

## Step 3 — ruff (Python linter/formatter, user install)
```bash
pip3 install --user ruff
```
Il binary va in `~/.local/bin/` (già nel PATH su Ubuntu 24.04).

## Step 4 — Verifica
```bash
shellcheck --version
tree --version
lua5.4 -v
yq --version
ruff --version
```

## Step 5 — Aggiornare MEMORY.md
Aggiungere i nuovi tool alla tabella "Linguaggi e Runtime sull'Host".
