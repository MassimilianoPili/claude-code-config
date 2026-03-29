# Piano: Stop container inutilizzati + MongoDB + libSQL + Artemis

## Contesto

Il server ha 7.6 GB di RAM, 5.4 GB usati + 4.6 GB in swap.
Il consumo principale è dei processi host (20 Claude Code + 5 MCP Server = ~4.75 GB).
Diversi container Docker sono rotti o inutilizzati. L'utente vuole spegnere MongoDB, libSQL e Artemis.

## Azioni

### 1. Stop crash-loop — `/data/massimiliano/monitoring/docker-compose.yml`
```bash
cd /data/massimiliano/monitoring && docker compose stop cadvisor
```
> cadvisor: exit code 2, flag CLI errato — restart infinito

### 2. Stop vector + goaccess — `/data/massimiliano/proxy/docker-compose.yml`
```bash
cd /data/massimiliano/proxy && docker compose stop vector goaccess
```
> vector: Docker socket mancante, 78 restart. goaccess: 0 richieste analizzate.

### 3. Stop loki — `/data/massimiliano/monitoring/docker-compose.yml`
```bash
cd /data/massimiliano/monitoring && docker compose stop loki
```
> Senza vector non riceve log — errori `empty ring` continui (~60 MB)

### 4. Stop MongoDB + mongo-express — `/data/massimiliano/mongodb/docker-compose.yml`
```bash
cd /data/massimiliano/mongodb && docker compose stop
```
> ~157 MB liberati. Dati persistenti in `/data/massimiliano/mongodb/data/`

### 5. Stop libSQL — `/data/massimiliano/libsql/docker-compose.yml`
```bash
cd /data/massimiliano/libsql && docker compose stop
```
> ~15 MB. Zero tabelle, nessun client connesso.

### 6. Stop Artemis — `/data/massimiliano/artemis/docker-compose.yml`
```bash
cd /data/massimiliano/artemis && docker compose stop
```
> ~144 MB. Broker JMS idle, nessun producer/consumer.

### 7. Rimuovi container già fermi (pgadmin, portainer)
Non li tocchiamo — sono già exited e non consumano RAM. Si riavviano con `docker compose up -d` quando servono.

## RAM stimata liberata dai container
| Container | RAM |
|-----------|-----|
| cadvisor + vector | ~0 MB (già crash) |
| loki | ~60 MB |
| goaccess | ~2 MB |
| mongodb + mongo-express | ~157 MB |
| libsql | ~15 MB |
| artemis | ~144 MB |
| **Totale** | **~378 MB** |

## Nota: il vero collo di bottiglia
I container liberano ~378 MB, ma il grosso della pressione RAM viene da:
- **20 processi Claude Code** (~3.2 GB)
- **5 MCP Server Java** (~850 MB)

Dopo gli stop, suggerisco `claude-cleanup` per terminare sessioni stale.

## Container che restano attivi
nginx, keycloak, postgres, redis, gitea, act-runner, cloudflared, oauth2-proxy (x2), jwt-gateway, code-server-massimiliano, go-filemanager, server-api, kp-manager, prometheus, grafana, node-exporter

## Verifica
```bash
docker ps --format "table {{.Names}}\t{{.Status}}" | sort
free -m
```
