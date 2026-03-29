# Piano: Spostare pulsanti SOL Home / Tools Home nella Quick Nav

## Contesto

I pulsanti "SOL Home" e "Tools Home" sono stati aggiunti alla **landing page** (`index.html`, card "Static Home") ma l'utente li voleva nella pagina **Quick Nav** (`/home/index.html`). Due modifiche: rimuovere dalla landing page, aggiungere nella Quick Nav.

## Step 1 — Rimuovere pulsanti dalla landing page

**File**: `Vari/MassimilianoPili.github.io/index.html`

- Rimuovere il `<div class="card-links">` con i due `<span class="card-link">` dalla card "Static Home"
- Rimuovere il CSS `.card-links` e `.card-link` dal `<style>` (non più usati)
- La card torna ad avere solo titolo + descrizione, come le altre

## Step 2 — Aggiungere pulsanti nella Quick Nav

**File**: `Vari/MassimilianoPili.github.io/home/index.html`

Aggiungere una sezione con due pulsanti sotto la griglia (o nell'header), prima del bonsai widget:

```html
<section class="home-links">
    <a class="home-btn" href="https://sol.massimilianopili.com" target="_blank">SOL Home</a>
    <a class="home-btn" href="https://tools.massimilianopili.com" target="_blank">Tools Home</a>
</section>
```

CSS inline: ghost button style coerente con i `.btn` esistenti, centrati orizzontalmente.

## Step 3 — Commit e push

Un commit unico con entrambe le modifiche → push Gitea + GitHub.

## File critici

| File | Azione |
|------|--------|
| `Vari/MassimilianoPili.github.io/index.html` | Rimuovere `.card-links`/`.card-link` CSS + HTML |
| `Vari/MassimilianoPili.github.io/home/index.html` | Aggiungere sezione con pulsanti SOL Home / Tools Home |
