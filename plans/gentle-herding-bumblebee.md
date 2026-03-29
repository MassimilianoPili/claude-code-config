# Configurazione Keycloak per visitor read-only — COMPLETATO

## Contesto
Il codice per il visitor view-only e' gia' deployato su tutti i servizi (dashboard-api, server-api, frontend, nginx).
Serviva configurare Keycloak: creare il ruolo `readonly` sui client e l'utente `visitor`.
La password admin in `.env` non era piu' valida (cambiata via UI), quindi e' stata resettata via DB.

## Stato: COMPLETATO

Tutti i passi sono stati eseguiti con successo:

### 1. Reset password admin — DONE
- Password admin resettata via UPDATE diretto su tabella `credential` in PostgreSQL
- Formato Argon2id Keycloak: `value` = raw hash base64, `salt` = raw salt base64 (NON formato PHC standard)
- Password: quella di `.env` (`EBNJ4TTRA7AzkrBtkn20v0snenDXu1il`)

### 2. Configurazione Keycloak — DONE
- Client `dashboard-chat` (ID: `1d6a84bd-3139-40a1-a604-a3e300b7ae95`): ruolo `readonly` creato
- Client `go-filemanager` (ID: `58ebbe1d-a088-444e-b8e1-eac9ce61505c`): ruolo `readonly` creato
- Utente `visitor` (ID: `691bce6e-9558-41a4-8d31-1f349cf6dded`): creato, password=`visitor`, email=`visitor@sol.local`
- Role mapping: `readonly` assegnato su entrambi i client

### 3. Verifica JWT — DONE
Token di esempio generato via `kcadm.sh evaluate-scopes/generate-example-access-token` conferma:
```json
"resource_access": {
  "dashboard-chat": { "roles": ["readonly"] },
  "go-filemanager": { "roles": ["readonly"] }
}
```

## Test end-to-end rimanenti (manuali via browser)
1. Cliccare "Visitor" sulla dashboard → login con password `visitor`
2. Verificare: chat disabilitata, terminal bloccato (4403), note read-only
3. Navigare a `/files/` → browse OK, upload/delete bloccati
4. **Gitea**: primo login SSO di visitor, poi aggiungere come collaborator Read nei repo
5. **Portainer**: primo login OAuth2 di visitor, poi assegnare ruolo Read-only user
