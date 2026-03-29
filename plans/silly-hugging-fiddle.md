# Piano: Fix badge "API Docs" nelle card dashboard

## Contesto

Le spec OpenAPI e Swagger UI sono gia' deployati e funzionanti (`/docs/`).
Due problemi aperti:

1. **Badge "API Docs" non cliccabile**: il click sul badge `<span>` dentro `<a class="card">` naviga
   sempre all'href della card (`/claude/health`) invece di `/docs/`. Il capture-phase listener non
   riesce a prevenire l'activation behavior nativo dell'`<a>` in tutti i browser.

2. **401 su `/rank/`**: atteso — gli endpoint richiedono JWT. Non e' un bug.

## Causa root del problema badge

Un `<span>` dentro un `<a>` non puo' prevenire in modo affidabile la navigazione dell'ancora parent.
`preventDefault()` e `stopPropagation()` in capture phase funzionano in teoria, ma il comportamento
varia tra browser e il click target potrebbe non essere sempre l'elemento atteso (es. text node,
padding area). L'unica soluzione affidabile: **eliminare l'`<a>` parent** dalle card API.

## Fix: convertire card API da `<a>` a `<div>`

### File: `/data/massimiliano/proxy/home/index.html`

**1. HTML** — righe 459-475: cambiare `<a>` → `<div>` per le due card API

Da:
```html
<a class="card" id="link-claude">
  <div class="card-icon">&#129302;</div>
  <div class="card-body">
    <div class="card-title">Claude Proxy <span class="badge badge-docs" data-href="/docs/?urls.primaryName=Claude+Proxy+API">API Docs</span></div>
    ...
  </div>
</a>

<a class="card" id="link-rank">
  ...
</a>
```

A:
```html
<div class="card" id="link-claude" style="cursor:pointer">
  <div class="card-icon">&#129302;</div>
  <div class="card-body">
    <div class="card-title">Claude Proxy <span class="badge badge-docs" data-href="/docs/?urls.primaryName=Claude+Proxy+API">API Docs</span></div>
    ...
  </div>
</div>

<div class="card" id="link-rank" style="cursor:pointer">
  ...
</div>
```

**2. JS — link setter** (riga 670-683): il loop `Object.keys(links)` fa `el.href = url`.
Un `<div>` non ha `.href`. Salvare l'URL in `dataset.href` e aggiungere un click handler:

Sostituire:
```js
if (url) {
  el.href = url;
}
```

Con:
```js
if (url) {
  if (el.tagName === 'A') {
    el.href = url;
  } else {
    el.dataset.cardHref = url;
    el.addEventListener('click', function(e) {
      if (!e.target.closest('.badge-docs')) {
        location.href = this.dataset.cardHref;
      }
    });
  }
}
```

Questo gestisce: click sulla card → naviga alla destinazione principale; click sul badge → il check `closest('.badge-docs')` salta la navigazione, e il capture-phase listener esistente fa `location.href = badge.dataset.href`.

**3. Rimuovere il listener capture-phase** (righe 626-636): non piu' necessario. Il `<div>` non ha
activation behavior nativo, quindi il badge handler nella sezione 2 e' sufficiente.
Rimuovere:
```js
// ── Badge docs: capture-phase click per prevenire navigazione <a> parent ──
document.addEventListener('click', function(e) {
  ...
}, true);
```

E usare un singolo listener delegato (piu' semplice):
```js
// ── Badge docs: click navigazione ──
document.addEventListener('click', function(e) {
  var badge = e.target.closest('.badge-docs');
  if (badge && badge.dataset.href) {
    location.href = badge.dataset.href;
  }
});
```

## Ordine di esecuzione

1. Modificare HTML: `<a>` → `<div>` per `#link-claude` e `#link-rank`
2. Modificare JS link setter: check `el.tagName`, usare `dataset.cardHref` + click handler per `<div>`
3. Semplificare listener badge: rimuovere capture-phase, usare listener delegato semplice
4. Restart nginx: `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate`

## Verifica

1. Hard refresh dashboard (Ctrl+Shift+R)
2. Click su area card Claude Proxy (non badge) → naviga a `/claude/health`
3. Click su badge "API Docs" di Claude Proxy → naviga a `/docs/?urls.primaryName=Claude+Proxy+API`
4. Click su area card Preference Sort (non badge) → naviga a `/rank/`
5. Click su badge "API Docs" di Preference Sort → naviga a `/docs/?urls.primaryName=Preference+Sort+API`
6. Verificare che il 401 su "Try it out" in Swagger UI si risolve con il bottone "Authorize" + JWT token
