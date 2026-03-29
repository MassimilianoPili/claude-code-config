# Fix home button position — align with content grid

## Context
The home button is currently `position:fixed` top-left corner. User wants it aligned with the left edge of the card grid, in the same row as "Sol Services" — like a breadcrumb/back navigation.

## File
- `/data/massimiliano/proxy/home/index.html`

## Changes

### 1. CSS: change `.home-btn` from fixed to flow layout
Remove `position:fixed;top:16px;left:16px;z-index:200`. Make it a normal flex item.

### 2. CSS: add `.header-row` wrapper
```css
.header-row{display:flex;align-items:center;width:100%;max-width:1400px;gap:12px;margin-bottom:0}
```
This matches `.main-layout`'s max-width so the home button aligns with the card grid edge.

### 3. HTML: wrap home-btn + h1 in `.header-row`
Move the `<a class="home-btn">` and `<h1>` inside a `<div class="header-row">`. The subtitle `<p>` stays outside (centered as before).

Result: casetta flush-left with cards, title next to it, subtitle centered below.

## Verification
- `docker compose up -d nginx --force-recreate`
- Home button left-aligned with card grid, same vertical line as "EXTERNAL" section label
