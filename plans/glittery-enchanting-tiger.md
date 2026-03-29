# Piano: Popolare Grafana con dashboard provisionati

## Contesto

Grafana è deployato con OIDC Keycloak funzionante, 3 datasource provisionati (Prometheus, Loki, PostgreSQL),
ma **nessuna dashboard**. La directory di provisioning `grafana/provisioning/dashboards/json/` esiste
ma è vuota. Il provider è già configurato (`dashboards.yml`) per caricare JSON da quella directory
ogni 5 minuti, nella cartella "Server SOL".

L'obiettivo è popolare Grafana con dashboard utili per il monitoraggio del server, scaricando
i JSON da grafana.com e adattandoli ai datasource locali.

---

## Dashboard da provisionare

| # | Dashboard | Grafana ID | Datasource | Scopo |
|---|-----------|:----------:|------------|-------|
| 1 | Node Exporter Full | 1860 | Prometheus | Metriche host: CPU, RAM, disco, rete, filesystem |
| 2 | Docker Container & Host Metrics | 14282 | Prometheus | Metriche per-container: CPU, RAM, rete (cAdvisor) |
| 3 | Loki & Promtail | 13639 | Loki | Visualizzazione log centralizzati (query LogQL) |

---

## Passo 1 — Scaricare i JSON

Scaricare i dashboard da `grafana.com/api/dashboards/{id}/revisions/latest/download`
e salvarli in `/data/massimiliano/monitoring/grafana/provisioning/dashboards/json/`.

Wrappare ogni JSON in un envelope di provisioning:
```json
{
  "dashboard": { ... contenuto originale ... },
  "overwrite": true
}
```

**NOTA**: i JSON di grafana.com usano variabili template (`$datasource`, `$DS_PROMETHEUS`).
Per il provisioning, bisogna impostare il datasource name corretto nella sezione `__inputs`
oppure sostituire i riferimenti con il nome del datasource provisionato.

Approccio: salvare i JSON raw e configurare il datasource UID come variabile nei file,
usando `"uid": "prometheus"` / `"uid": "loki"` che corrispondano ai datasource provisionati.

---

## Passo 2 — Adattare il datasource UID

Verificare gli UID dei datasource provisionati:
```bash
docker exec grafana grafana-cli admin data-sources list 2>/dev/null
# oppure via API:
curl -s -u admin:$GF_ADMIN_PASSWORD http://grafana:3000/grafana/api/datasources
```

Nei JSON, sostituire i riferimenti al datasource template con l'UID reale.
Oppure aggiungere `uid` ai datasource in `datasources.yml` per avere UID prevedibili.

---

## Passo 3 — Recreate Grafana

```bash
cd /data/massimiliano/monitoring && docker compose up -d grafana --force-recreate
```

Grafana caricherà i JSON all'avvio. I dashboard appariranno nella cartella "Server SOL".

---

## File coinvolti

| File | Azione |
|------|--------|
| `monitoring/grafana/provisioning/dashboards/json/node-exporter.json` | Nuovo |
| `monitoring/grafana/provisioning/dashboards/json/cadvisor.json` | Nuovo |
| `monitoring/grafana/provisioning/dashboards/json/loki.json` | Nuovo |
| `monitoring/grafana/provisioning/datasources/datasources.yml` | Aggiungere `uid` fissi ai datasource |

---

## Verifica

1. Aprire `/grafana/` → login
2. Sidebar → Dashboards → cartella "Server SOL" → 3 dashboard presenti
3. **Node Exporter Full**: verificare che i pannelli mostrino dati (CPU%, RAM, disco)
4. **cAdvisor**: verificare metriche container (almeno grafana, prometheus, nginx visibili)
5. **Loki**: verificare che la query `{container=~".+"}` restituisca log recenti
