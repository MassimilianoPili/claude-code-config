# Dashboard UI Polish — Terminal, Mobile, Architettura

## Context

La dashboard funziona ma ha 3 punti da migliorare:
1. Il terminale e' visivamente piatto (solo un box nero)
2. Su mobile la colonna di sinistra (card) viene prima della colonna destra (chat/terminal/tokens) — l'utente vuole il contrario
3. Il link all'architettura e' una icona SVG 20px quasi invisibile

## File: `proxy/home/index.html`

### 1. Terminal piu' carino

Attuale: `#terminal-container` e' 280px con 4px padding, nessun bordo, nessun header. Solo un `panel-divider` "Terminal" come separatore drag.

Modifiche CSS:
- Aggiungere header bar al terminale con titolo + indicatore di stato (pallino verde/rosso)
- Bordo superiore `border-top: 1px solid var(--border)` con leggero glow accent
- Sfondo leggermente diverso dal chat (`--bg` piu' scuro, tipo `#0a0c12`)
- Aggiungere padding interno piu' generoso (8px)
- Scrollbar custom sottile (`::-webkit-scrollbar`)

### 2. Mobile: right column prima

Attuale `@media(max-width:900px)`:
```css
.main-layout{flex-direction:column}
```
Il flex-direction column mantiene l'ordine DOM: grid-section (cards) prima, right-column dopo.

Fix: aggiungere `flex-direction: column-reverse` oppure usare `order`:
```css
@media(max-width:900px){
  .main-layout{flex-direction:column}
  .right-column{order:-1}
}
```
`order:-1` porta la right-column sopra senza invertire l'ordine degli elementi interni.

### 3. Architettura piu' visibile

Attuale: icona SVG 20x20 accanto al titolo "Sol Services", colore muted, quasi invisibile.

Opzione: trasformarlo in una mini-card/badge cliccabile sotto il sottotitolo, con icona + testo "Architettura". Stile coerente con le badge esistenti (`.badge-docs`).

## Verifica

1. `docker compose up -d nginx --force-recreate`
2. Desktop: verificare terminal styling, architecture badge
3. Mobile (DevTools responsive): verificare che right-column appaia prima dei card
