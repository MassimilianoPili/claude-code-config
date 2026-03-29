# Agent Framework — SETUP.md

## Context

La documentazione del framework è completa (9 README modulari, manuale utente, 3 ADR),
ma manca un file **SETUP.md** dedicato all'installazione e configurazione iniziale.
Il README root contiene una sezione "Local Development" minimale (~20 righe), ma non
copre prerequisiti dettagliati, variabili d'ambiente, provider messaging alternativi,
infrastruttura Azure, IDE setup, e troubleshooting di setup.

**Obiettivo**: creare `SETUP.md` nella root del progetto che guidi passo-passo
dall'installazione dei prerequisiti al primo plan eseguito con successo.

---

## Deliverable

**File**: `SETUP.md` (root del progetto, ~200 righe)

### Struttura

```
# Setup Guide

## Prerequisiti
## 1. Clone e Build
## 2. Ambiente Locale (Docker)
## 3. Variabili d'Ambiente
## 4. Avvio Orchestrator
## 5. Avvio Worker (opzionale)
## 6. Primo Plan — End-to-End
## 7. Provider Messaging Alternativi
## 8. Deploy Azure
## 9. IDE Setup
## 10. Troubleshooting
```

### Contenuto per sezione

**Prerequisiti** (~15 righe)
- Java 17 (Eclipse Temurin consigliato)
- Maven 3.9+
- Docker + Docker Compose
- `ANTHROPIC_API_KEY` (chiave API Anthropic per Claude)
- Verifica versioni: `java -version`, `mvn -version`, `docker compose version`

**1. Clone e Build** (~20 righe)
- `git clone` + `cd agent-framework`
- `mvn clean install` (build completo 16 moduli)
- Output atteso: BUILD SUCCESS, 16 moduli
- Nota: il primo build scarica ~500 MB di dipendenze

**2. Ambiente Locale (Docker)** (~25 righe)
- `docker compose -f docker/docker-compose.dev.yml up -d`
- Servizi avviati: PostgreSQL 16 (porta 5432) + Artemis (porta 61616 + console 8161)
- Credenziali di default (user/pass da docker-compose.dev.yml):
  - PostgreSQL: `agentframework/agentframework`, database: `agentframework`
  - Artemis: `admin/admin`, console: `http://localhost:8161`
- Verifica: `docker compose -f docker/docker-compose.dev.yml ps`
- Flyway crea automaticamente le tabelle al primo avvio dell'orchestrator

**3. Variabili d'Ambiente** (~30 righe)
- Tabella completa con variabili, default, e descrizione:

| Variabile | Default | Obbligatoria | Descrizione |
|-----------|---------|-------------|-------------|
| `ANTHROPIC_API_KEY` | — | Si | API key Anthropic (Claude) |
| `DB_HOST` | `localhost` | No | Host PostgreSQL |
| `DB_USER` | `agentframework` | No | Utente PostgreSQL |
| `DB_PASSWORD` | (vuoto) | No* | Password PostgreSQL |
| `ARTEMIS_HOST` | `localhost` | No | Host broker Artemis |
| `ARTEMIS_USER` | `admin` | No | Utente Artemis |
| `ARTEMIS_PASSWORD` | `admin` | No | Password Artemis |

- Nota: `DB_PASSWORD` è vuoto di default perché il docker-compose locale
  non imposta una password obbligatoria. In produzione, impostare sempre.
- Esempio export: `export ANTHROPIC_API_KEY=sk-ant-...`

**4. Avvio Orchestrator** (~15 righe)
- `mvn spring-boot:run -pl control-plane/orchestrator -Dspring-boot.run.profiles=dev`
- Verifica: `curl http://localhost:8080/management/health`
- Output atteso: `{"status":"UP"}`
- Flyway migra automaticamente il DB (V1-V6)
- Log di startup mostra `WorkerProfileRegistry validated: 5 profiles, 2 defaults`

**5. Avvio Worker (opzionale)** (~15 righe)
- I worker sono necessari solo per eseguire task (non per creare piani)
- Esempio: `mvn spring-boot:run -pl execution-plane/workers/be-java-worker`
- Ogni worker richiede la propria `ANTHROPIC_API_KEY`
- Un terminale per worker (o usare profilo Spring per concurrency)
- Per lo sviluppo è sufficiente un solo worker (be-java di default)

**6. Primo Plan — End-to-End** (~30 righe)
- Crea plan:
  ```bash
  curl -X POST http://localhost:8080/api/v1/plans \
    -H "Content-Type: application/json" \
    -d '{"spec":"Build a REST API for user management"}'
  ```
- Verifica stato: `curl http://localhost:8080/api/v1/plans/{planId}`
- Flusso atteso: PENDING → planner decompone → PlanItems creati → RUNNING
- Se worker attivo: items dispatched → worker esegue → risultati
- Quality gate: `curl http://localhost:8080/api/v1/plans/{planId}/quality-gate`
- Retry falliti: `curl -X POST .../items/{itemId}/retry`

**7. Provider Messaging Alternativi** (~25 righe)
- JMS/Artemis è il default, ma si può switchare:
- **Redis Streams**:
  ```yaml
  messaging:
    provider: redis
    redis:
      host: localhost
      port: 6379
      database: 3
  ```
- **Azure Service Bus**:
  ```yaml
  messaging:
    provider: servicebus
  azure:
    servicebus:
      connection-string: "Endpoint=sb://..."
  ```
- Riferimento: `messaging/README.md`

**8. Deploy Azure** (~20 righe)
- Infrastruttura: `infra/azure/bicep/main.bicep`
- 4 ambienti parametrizzati: develop, test, collaudo, prod
- Deploy Bicep:
  ```bash
  az deployment group create \
    --resource-group rg-agent-framework-dev \
    --template-file infra/azure/bicep/main.bicep \
    --parameters infra/azure/bicep/env/develop.parameters.json
  ```
- Risorse create: Container Apps Environment, Service Bus, PostgreSQL, Key Vault, App Insights
- Worker Docker images: ogni worker ha Dockerfile generato
- Riferimento: `config/environments.yml`

**9. IDE Setup** (~10 righe)
- IntelliJ IDEA: Import come progetto Maven, JDK 17
- VS Code: Java Extension Pack + Spring Boot Extension Pack
- Rigenerare worker dopo modifica manifest:
  `mvn agent-compiler:generate-workers agent-compiler:generate-registry`
- Non editare file in `execution-plane/workers/` — sono generati

**10. Troubleshooting** (~20 righe)
- `BUILD FAILURE` al primo build: verificare Java 17 (`java -version`)
- Artemis non raggiungibile: `docker compose -f docker/docker-compose.dev.yml ps`
- `WorkerProfileRegistry validation failed`: controllare `config/worker-profiles.yml`
- Plan rimane PENDING: verificare `ANTHROPIC_API_KEY` impostata
- Worker non riceve task: verificare topic/subscription in `application.yml` del worker
- 409 su retry: l'item non è in stato FAILED

---

## Modifica aggiuntiva: link in README root

Aggiungere `SETUP.md` alla tabella Documentation nel README root:

```markdown
| [Setup Guide](SETUP.md) | Installazione, configurazione, primo avvio |
```

---

## File sorgente consultati

| File | Dato estratto |
|------|--------------|
| `docker/docker-compose.dev.yml` | Servizi, porte, credenziali default |
| `control-plane/orchestrator/src/main/resources/application.yml` | Env vars, defaults, profili |
| `infra/azure/bicep/main.bicep` | Comando deploy, risorse |
| `infra/azure/bicep/env/develop.parameters.json` | Parametri ambiente |
| `config/environments.yml` | 4 ambienti di deploy |
| `README.md` (root) | Sezione Local Development esistente |

---

## Verifica

```bash
# File creato
cat SETUP.md | head -5

# Link nel README root aggiornato
grep "SETUP.md" README.md

# Build non impattato (nessun file Java toccato)
mvn clean install
```
