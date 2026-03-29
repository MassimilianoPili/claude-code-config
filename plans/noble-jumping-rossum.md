# Piano: Fix notes.massimilianopili.com + rpg-godot 403

## Context

Due problemi segnalati dall'utente:
1. **notes.massimilianopili.com** mostra pagina bianca — errore JS di sintassi nel frontend
2. **sol.massimilianopili.com/rpg-godot/** ritorna 403 — directory export/web vuota (file rimossi da git)

---

## Issue 1: Knowledge Graph — pagina bianca

### Root cause
Errore di parsing JS in `/data/massimiliano/knowledge-graph/static/index.html:279`.
La funzione `selectNode` ha una `}` extra che chiude la funzione prima del `catch`, causando `SyntaxError: Missing catch or finally after try`. L'intero blocco `<script>` non viene eseguito → `init()` non parte → entrambi i div (`app-login`, `app-main`) restano `display:none`.

### Fix
**File**: `/data/massimiliano/knowledge-graph/static/index.html`
**Linea 279**: cambiare `}}}` → `}}`

```
# PRIMA (linea 279):
connSec.appendChild(ul);content.appendChild(connSec)}}}

# DOPO:
connSec.appendChild(ul);content.appendChild(connSec)}}
```

Conteggio braces corretto:
- `}` chiude `if(conns.length>0)` (aperto linea 275)
- `}` chiude `try{` (aperto linea 267)
- Poi `catch(e){...}` segue il try (linea 280)
- `}` finale di linea 280 chiude `async function selectNode(node){` (linea 259)

### Deploy
```bash
cd /data/massimiliano/knowledge-graph
docker compose up -d --build
```

### Verifica
- `curl -s https://notes.massimilianopili.com/ | grep -c 'Knowledge Graph'` → 1
- Playwright: navigare a `https://notes.massimilianopili.com/`, verificare che la login screen appare (no console errors)

---

## Issue 2: RPG Godot — 403 Forbidden

### Root cause
Il commit `e46832b` ("chore: remove rpg-godot from repo") ha eliminato tutti i file del progetto Godot, incluso l'export web. La directory montata da nginx (`rpg-godot/export/web/`) è vuota.

I file originali esistono nel commit `802c2f4` nel repo `/data/massimiliano/Vari/MassimilianoPili.github.io/`.

### Fix
Recuperare i file dell'export web da git:
```bash
cd /data/massimiliano/Vari/MassimilianoPili.github.io
git checkout 802c2f4 -- rpg-godot/export/web/
```

Questo ripristina solo la directory `export/web/` senza toccare il resto.

### Deploy
Nessun rebuild necessario — il volume mount è read-only e nginx serve i file statici direttamente. Al massimo:
```bash
# Solo se nginx non vede i file subito (improbabile)
cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate
```

### Verifica
- `curl -sI https://sol.massimilianopili.com/rpg-godot/` → 200 OK
- Controllare che index.html + file .wasm/.pck esistano in `export/web/`

---

## Ordine di esecuzione

1. Fix JS in knowledge-graph/static/index.html (edit linea 279)
2. Rebuild container knowledge-graph
3. Verifica notes.massimilianopili.com con Playwright
4. Restore export/web da git
5. Verifica rpg-godot con curl
