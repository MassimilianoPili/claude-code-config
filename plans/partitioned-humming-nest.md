# Piano: Fix click handler sui nodi del diagramma architetturale

## Contesto

Alcuni nodi del diagramma Mermaid sono cliccabili ma puntano a servizi senza UI web (API pure che restituiscono JSON). Altri nodi con UI web mancano del click handler. Inoltre il CSS `.mermaid .node { cursor: pointer }` mostra il cursore puntatore su tutti i nodi, anche quelli non navigabili (database, infrastruttura).

## File: `proxy/home/architecture.html`

### 1. Rimuovere click da nodi senza UI

```diff
-    click ClaudeProxy "/claude/health"
-    click ServerAPI "/server/ui/"
```

Claude Proxy e Server API sono API Go pure — nessuna pagina web da visitare.

### 2. Aggiungere click a nodi con UI mancanti

```diff
+    click KPMgr "/kp/"
+    click LibSQLCon "/libsql/"
+    click ArtemisCon "/mq/"
```

Tutti e tre hanno console web accessibili via OAuth2 Proxy.

### 3. Fix CSS cursor: solo nodi cliccabili

```diff
-.mermaid .node { cursor: pointer; }
+.mermaid .node.clickable { cursor: pointer; }
```

Mermaid v11 aggiunge la classe `.clickable` ai nodi con `click` handler. I nodi senza handler (PostgreSQL, Redis, Monitoring, ecc.) manterranno il cursor default.

### Verifica

- Hover su Gitea/pgAdmin/Grafana → cursore puntatore, click naviga al servizio
- Hover su PostgreSQL/Redis/Prometheus → cursore default, nessun click
- Riavvio: `cd /data/massimiliano/proxy && docker compose up -d nginx --force-recreate`

### Sicurezza (verificata)

I click handler usano path relativi (`/ide/`, `/pgadmin/`, ecc.) che passano per nginx con `auth_request` → OAuth2 Proxy → Keycloak. Nessun bypass: verificato in incognito, il login viene richiesto correttamente. La sessione OAuth2 cookie-based condivisa spiega l'accesso senza re-login quando già autenticati.
