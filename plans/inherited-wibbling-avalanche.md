# Aumentare CLAUDE_CODE_MAX_OUTPUT_TOKENS a 128000

## Contesto
Il valore di default (~16K per Opus) limita la lunghezza delle risposte. L'utente vuole portarlo a 128000 per avere output più lunghi.

## Piano

1. **Aggiungere export in `~/.bashrc`** — prima del guard non-interattivo (come `SSH_AUTH_SOCK`), così è disponibile anche per Claude Code e code-server:
   ```bash
   export CLAUDE_CODE_MAX_OUTPUT_TOKENS=128000
   ```

2. **File da modificare**: `/home/massimiliano/.bashrc`
   - Posizione: subito dopo l'export di `SSH_AUTH_SOCK`, prima del blocco `# If not running interactively...`

## Verifica
- Riavviare la sessione Claude Code (o `source ~/.bashrc` + nuova sessione)
- Il nuovo valore sarà attivo dalla prossima sessione
