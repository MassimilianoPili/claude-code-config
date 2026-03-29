# Fix Mermaid diagramma rotto nella wiki

## Context

La pagina wiki `agent-framework/overview` mostra **"Syntax error in graph"** al posto
del sequenceDiagram. Causa: WikiJS 2.5.312 include **Mermaid 8.8.2** (2020), che non
supporta la keyword `actor` nei sequenceDiagram (introdotta in 8.9.0).

Il diagramma usa:
```
actor User
actor Human as Human Reviewer
```
Mermaid 8.8.2 non riconosce `actor` e fallisce con syntax error.

## Fix

**File**: `/data/massimiliano/docs/agent-framework/overview.md` (righe 41-42)

Sostituire `actor` con `participant`:
```
- actor User
- actor Human as Human Reviewer
+ participant User
+ participant Human as Human Reviewer
```

La differenza visiva tra `actor` e `participant` è solo cosmetica (icona persona vs box).
Con `participant`, il diagramma renderizza correttamente su Mermaid 8.8.2+.

## Sync

Il file si sincronizza automaticamente via `docs-sync` → Gitea repo `sol-docs` → WikiJS GitSync.
Per avere effetto immediato sulla wiki, aspettare il prossimo ciclo (30 min) oppure
forzare: `docs-sync` manuale.

In alternativa, il file master è in `/data/massimiliano/docs/` — la modifica arriverà
in WikiJS al prossimo sync bidirezionale.

## Verifica

1. Dopo la modifica, navigare a `http://100.86.46.84:8889/en/agent-framework/overview`
2. Verificare che il sequenceDiagram renderizzi (attori, frecce, blocchi par/alt)
3. Controllare con JS nel browser: `document.querySelectorAll('.mermaid svg [class*="error"]').length === 0`
