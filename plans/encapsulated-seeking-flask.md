# Piano: Installazione tutti i 43 Plugin Claude Code

## Contesto

Nessun plugin attualmente installato (`claude plugin list` vuoto). Il marketplace contiene 29 plugin interni + 13 esterni = 42 disponibili. `code-review` e' nella blocklist (`blocklist.json`) — va sbloccato prima dell'installazione.

## File da modificare

- `/home/massimiliano/.claude/plugins/blocklist.json` — rimuovere entry `code-review@claude-plugins-official`

## Comandi di installazione

### Passo 1: Sbloccare code-review
Editare `blocklist.json` per rimuovere la entry `code-review` (mantenere solo `fizz@testmkt-marketplace`).

### Passo 2: Installare tutti i 42 plugin
```bash
# Interni (29)
claude plugin install commit-commands@claude-plugins-official
claude plugin install claude-md-management@claude-plugins-official
claude plugin install feature-dev@claude-plugins-official
claude plugin install hookify@claude-plugins-official
claude plugin install code-review@claude-plugins-official
claude plugin install code-simplifier@claude-plugins-official
claude plugin install pr-review-toolkit@claude-plugins-official
claude plugin install security-guidance@claude-plugins-official
claude plugin install skill-creator@claude-plugins-official
claude plugin install agent-sdk-dev@claude-plugins-official
claude plugin install plugin-dev@claude-plugins-official
claude plugin install claude-code-setup@claude-plugins-official
claude plugin install playground@claude-plugins-official
claude plugin install frontend-design@claude-plugins-official
claude plugin install explanatory-output-style@claude-plugins-official
claude plugin install learning-output-style@claude-plugins-official
claude plugin install ralph-loop@claude-plugins-official
claude plugin install gopls-lsp@claude-plugins-official
claude plugin install jdtls-lsp@claude-plugins-official
claude plugin install typescript-lsp@claude-plugins-official
claude plugin install pyright-lsp@claude-plugins-official
claude plugin install clangd-lsp@claude-plugins-official
claude plugin install csharp-lsp@claude-plugins-official
claude plugin install kotlin-lsp@claude-plugins-official
claude plugin install lua-lsp@claude-plugins-official
claude plugin install php-lsp@claude-plugins-official
claude plugin install rust-analyzer-lsp@claude-plugins-official
claude plugin install swift-lsp@claude-plugins-official
claude plugin install example-plugin@claude-plugins-official

# Esterni (13)
claude plugin install github@claude-plugins-official
claude plugin install gitlab@claude-plugins-official
claude plugin install playwright@claude-plugins-official
claude plugin install context7@claude-plugins-official
claude plugin install greptile@claude-plugins-official
claude plugin install serena@claude-plugins-official
claude plugin install asana@claude-plugins-official
claude plugin install linear@claude-plugins-official
claude plugin install slack@claude-plugins-official
claude plugin install firebase@claude-plugins-official
claude plugin install supabase@claude-plugins-official
claude plugin install stripe@claude-plugins-official
claude plugin install laravel-boost@claude-plugins-official
```

I comandi verranno eseguiti in parallelo (batch da ~10) per velocizzare l'installazione.

## Verifica

1. `claude plugin list` — deve mostrare 42 plugin installati
2. Verificare che `code-review` non sia piu' nella blocklist
