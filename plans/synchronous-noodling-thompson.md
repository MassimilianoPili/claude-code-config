# Risultato: Embargo gia' compatibile con accesso autenticato

## Contesto

L'utente chiede che le pagine in embargo siano nascoste al pubblico ma **visibili agli utenti autenticati** (login SAML/Keycloak).

## Analisi del codice WikiJS

In `/wiki/server/controllers/common.js` (righe 467-479), la logica di rendering e':

```javascript
if (!pageIsPublished && !effectivePermissions.pages.write) {
  return res.status(403).render('unauthorized', { action: 'view' })
}
```

**Comportamento di `isPublished = false`:**

| Chi accede | Permesso `pages.write` | Risultato |
|------------|----------------------|-----------|
| Guest (anonimo) | No | **403 Forbidden** |
| Authenticated (Administrators) | Si | **Pagina visibile** |

## Conclusione: NESSUNA MODIFICA NECESSARIA

Il sistema di embargo esistente (`wiki-embargo` + systemd timer) **gia' implementa** il comportamento richiesto:

- Pagine in embargo (`isPublished = false`) → nascoste ai visitatori anonimi, **visibili** agli admin autenticati
- Pagine post-embargo (`isPublished = true`) → visibili a tutti

L'unica condizione e' che gli utenti autenticati siano nel gruppo **Administrators** (che ha `manage:system`, incluso `pages.write`). L'utente `sol_root` (login SAML) e' gia' in questo gruppo.

## Nessun file da modificare
