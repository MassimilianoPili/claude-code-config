# Dashboard: Terminal + Note stacked — COMPLETATO

## Contesto

Terminale e note erano in un sistema a tab che non funzionava (xterm.js in `display:none`).
Ristrutturato in layout stacked sotto la chat, con note accessibili anche da URL pubblica.

## Lavoro completato

### Fase 1: Layout stacked (tab → stacked)
- Rimossi CSS/HTML/JS dei tab, layout a 3 sezioni stacked visibili
- File: `/data/massimiliano/proxy/home/index.html`

### Fase 2: Bug fix
- xterm.js script tags spostati prima dell'inline script (race condition)
- `isPublic` detection per URL pubblica

### Fase 3: Note pubbliche + hint terminal
- `location = /api/notes` aggiunto a nginx porta 8888 (exact match, solo note)
- Terminal nascosto su pubblica, hint cliccabile "solo Tailscale"
- Note funzionanti su entrambi gli URL
- File: `/data/massimiliano/proxy/nginx.conf`, `index.html`

### Fase 4: Documentazione
- CLAUDE.md aggiornato (routing, server blocks, sicurezza, subpath)
- MEMORY.md aggiornato (Dashboard Home)

## Stato: TUTTO DEPLOYATO E VERIFICATO
