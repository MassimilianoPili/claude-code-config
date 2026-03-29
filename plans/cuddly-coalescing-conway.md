# WikiJS SAML: fix doppio giro di login

## Contesto

WikiJS (`wiki.massimilianopili.com`) richiede di completare il flusso SAML **due volte** prima di autenticare l'utente. Il primo tentativo va a buon fine lato Keycloak (l'utente si autentica), ma al ritorno su WikiJS la sessione non viene preservata e l'utente viene rimandato al login.

**Causa root**: Keycloak ha `saml.force.post.binding: true` sul client `wiki`. Questo forza l'invio della SAML Response tramite HTTP-POST (form auto-submit da `sol.massimilianopili.com` verso `wiki.massimilianopili.com`). I browser moderni applicano `SameSite=Lax` di default ai cookie — e `Lax` **blocca i cookie sulle richieste POST cross-site**. Al primo tentativo, il cookie di sessione WikiJS non viene salvato; al secondo tentativo funziona perche' il browser ha gia' il contesto del dominio wiki.

## Soluzione

Disabilitare `saml.force.post.binding` sul client Keycloak `wiki`. Keycloak usera' HTTP-Redirect per la SAML Response (query parameter nella URL, niente POST cross-site). Questo elimina il problema SameSite perche' il browser fa un GET (non un POST) verso wiki, e `SameSite=Lax` permette i cookie sui GET top-level.

### 1. Aggiornare attributo Keycloak (via DB)

```sql
docker exec postgres psql -U keycloak -d keycloak -c "
UPDATE client_attributes
SET value = 'false'
WHERE name = 'saml.force.post.binding'
  AND client_id = (
    SELECT c.id FROM client c
    WHERE c.client_id = 'wiki'
      AND c.realm_id = (SELECT id FROM realm WHERE name = 'sol')
  );"
```

### 2. Restart Keycloak (per ricaricare la config dal DB)

```bash
docker restart keycloak
```

### 3. Aggiornare WikiJS SAML — wantAssertionsSigned

Con HTTP-Redirect, la SAML Response viaggia come query parameter e non puo' contenere assertions firmate inline (limite dimensionale URL). Se WikiJS richiede `wantAssertionsSigned: true`, potrebbe rifiutare la risposta. Verificare e, se necessario, impostare a `false` (il documento SAML intero resta firmato tramite `saml.server.signature`):

```sql
docker exec postgres psql -U wikijs -d wikijs -c "
UPDATE authentication
SET config = jsonb_set(config, '{wantAssertionsSigned}', 'false')
WHERE strategykey = 'saml'
  AND config->>'wantAssertionsSigned' = 'true';"
```

(Nessun restart necessario per WikiJS — legge la config dal DB a ogni richiesta.)

## File modificati

| Risorsa | Modifica |
|---------|----------|
| Keycloak DB (`client_attributes`) | `saml.force.post.binding` → `false` |
| Keycloak container | Restart per ricaricare |
| WikiJS DB (`authentication`) | `wantAssertionsSigned` → `false` (se necessario) |

## Verifica

1. Aprire una finestra browser in incognito
2. Navigare a `https://wiki.massimilianopili.com/`
3. Click su "Login with SAML"
4. Autenticarsi su Keycloak
5. **Verificare**: dopo il callback, l'utente deve essere loggato al primo tentativo (niente secondo giro)
6. Verificare che la sessione persista navigando le pagine wiki
7. Verificare anche da Tailscale: `http://100.86.46.84:8889/`
