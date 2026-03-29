# Piano: #44 Execution Sandbox — Completamento

## Context

Il codice Java per l'execution sandbox è **~90% implementato** (6 file sorgente, 494 righe + 14 test, 311 righe). L'architettura dual-layer funziona: framework in Docker Compose + container effimeri via `docker run` (ProcessBuilder, no docker-java). I test unitari verificano la costruzione dei comandi Docker e il comportamento dell'interceptor.

**Gap identificati**:
1. **Dockerfiles**: la directory `sandbox/` non esiste — le 8 immagini del design doc non sono state create
2. **Profili mancanti**: `be-cobol`, `be-cpp`, `be-dotnet` presenti nel design doc ma assenti da `SandboxProperties`
3. **Metriche**: nessun counter/timer Prometheus per le esecuzioni sandbox in worker-sdk

**Item parziali (5)**: #7, #8, #9, #33, #36, #40 — tutti gap UI/dashboard/dipendenze esterne, nessun codice Java da scrivere.

## 1. Creare `sandbox/` con 8 Dockerfiles

Dir: `sandbox/` (root del progetto)

| Dockerfile | Base image | Toolchain | Note |
|------------|-----------|-----------|------|
| `Dockerfile.java` | `eclipse-temurin:21-jdk-alpine` | Maven 3.9.9, Gradle 8.x | User 1000, WORKDIR /code |
| `Dockerfile.cobol` | `alpine:3.21` | GnuCOBOL 3.2, gcc | `apk add gnucobol gcc musl-dev` |
| `Dockerfile.go` | `golang:1.22-alpine` | go, golangci-lint | GOPATH=/tmp/go |
| `Dockerfile.python` | `python:3.12-slim` | pip, pytest, ruff | `pip install pytest ruff` |
| `Dockerfile.node` | `node:22-alpine` | npm, pnpm, vitest | `npm i -g pnpm vitest` |
| `Dockerfile.rust` | `rust:1-alpine` | cargo, clippy | `rustup component add clippy` |
| `Dockerfile.cpp` | `gcc:14` | gcc, cmake, make, valgrind | Multi-tool C++ |
| `Dockerfile.dotnet` | `mcr.microsoft.com/dotnet/sdk:8.0-alpine` | dotnet CLI | `DOTNET_CLI_TELEMETRY_OPTOUT=1` |

**Pattern comune** per ogni Dockerfile:
```dockerfile
FROM <base>
RUN <install-tools> && rm -rf /var/cache/apk/* /tmp/*
RUN adduser -D -u 1000 sandbox || true
USER 1000
WORKDIR /code
ENTRYPOINT ["sh", "-c"]
```

### File: `sandbox/build-images.sh`
Script helper per build locale:
```bash
#!/bin/bash
for f in sandbox/Dockerfile.*; do
  tag="agent-sandbox-${f##*.}:latest"
  docker build -f "$f" -t "$tag" sandbox/
done
```

## 2. Aggiungere 3 profili mancanti a SandboxProperties

**File**: `execution-plane/worker-sdk/src/main/java/com/agentframework/worker/sandbox/SandboxProperties.java`

Aggiungere a `imagesByProfile` (riga 33-41):
- `"be-cobol"` → `"agent-sandbox-cobol:latest"`
- `"be-cpp"` → `"agent-sandbox-cpp:latest"`
- `"be-dotnet"` → `"agent-sandbox-dotnet:latest"`

Aggiungere a `buildCommands` (riga 47-55):
- `"be-cobol"` → `"cobc -x -o /out/program *.cob"`
- `"be-cpp"` → `"cmake -B /tmp/build . && cmake --build /tmp/build"`
- `"be-dotnet"` → `"dotnet build --nologo -v q"`

**Nota**: `Map.of()` supporta max 10 entry — con 10 profili totali serve `Map.ofEntries()`.

## 3. SandboxMetrics (Prometheus counters/timers)

**File da creare**: `execution-plane/worker-sdk/src/main/java/com/agentframework/worker/sandbox/SandboxMetrics.java`

```java
@Component
@ConditionalOnBean(SandboxExecutor.class)
public class SandboxMetrics {
    private final Counter executions;
    private final Counter failures;
    private final Counter timeouts;
    private final Timer duration;

    public SandboxMetrics(MeterRegistry registry) {
        executions = Counter.builder("sandbox.executions.total").register(registry);
        failures = Counter.builder("sandbox.executions.failed").register(registry);
        timeouts = Counter.builder("sandbox.executions.timed_out").register(registry);
        duration = Timer.builder("sandbox.execution.duration").register(registry);
    }
}
```

**Dipendenza**: `micrometer-core` deve essere nel `pom.xml` di worker-sdk (verificare se già presente come transitive da spring-boot-starter-actuator).

**Integrazione**: `SandboxBuildInterceptor` chiama `sandboxMetrics.record(result)` dopo ogni esecuzione.

### File: `execution-plane/worker-sdk/pom.xml`
Verificare dipendenza micrometer. Se assente:
```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-core</artifactId>
</dependency>
```

## 4. Test aggiuntivi

### SandboxExecutorTest — 2 nuovi test
- `buildDockerCommand_customResourceLimits`: verifica memory 256m e cpus 0.5
- `buildDockerCommand_workingDirectoryIsCode`: verifica `-w /code`

### SandboxBuildInterceptorTest — 2 nuovi test
- `afterExecute_cobolProfile_executesCorrectImage`: verifica che be-cobol mappa a cobol image
- `afterExecute_timedOutBuild_enrichesWithTimeout`: verifica build_timed_out = true

### SandboxMetricsTest — 3 test
- `recordSuccess_incrementsExecutions`: counter +1
- `recordFailure_incrementsBothCounters`: executions +1, failures +1
- `recordTimeout_incrementsTimeoutCounter`: timeouts +1

## 5. Aggiornare PIANO.md

Spostare #44 da "Non implementati" a completati. Aggiornare descrizione con stato implementazione.

## Verifica

```bash
# Build
mvn clean install -pl agent-common,execution-plane/worker-sdk -DskipTests --no-transfer-progress

# Test
mvn test -pl execution-plane/worker-sdk --no-transfer-progress

# Build Docker images (manuale, richiede Docker)
cd sandbox && bash build-images.sh
```

Target: test esistenti + 7 nuovi, 0 failure.

## Ordine esecuzione

1. Creare `sandbox/` con 8 Dockerfiles + `build-images.sh`
2. Aggiornare `SandboxProperties` (3 profili + `Map.ofEntries`)
3. Creare `SandboxMetrics` + verificare dipendenza micrometer
4. Integrare metriche in `SandboxBuildInterceptor`
5. Scrivere test aggiuntivi
6. `mvn test` su worker-sdk
7. Aggiornare PIANO.md
8. Commit e push

## File coinvolti (riepilogo)

| File | Azione |
|------|--------|
| `sandbox/Dockerfile.java` | CREA |
| `sandbox/Dockerfile.cobol` | CREA |
| `sandbox/Dockerfile.go` | CREA |
| `sandbox/Dockerfile.python` | CREA |
| `sandbox/Dockerfile.node` | CREA |
| `sandbox/Dockerfile.rust` | CREA |
| `sandbox/Dockerfile.cpp` | CREA |
| `sandbox/Dockerfile.dotnet` | CREA |
| `sandbox/build-images.sh` | CREA |
| `execution-plane/worker-sdk/.../SandboxProperties.java` | MODIFICA |
| `execution-plane/worker-sdk/.../SandboxMetrics.java` | CREA |
| `execution-plane/worker-sdk/.../SandboxBuildInterceptor.java` | MODIFICA |
| `execution-plane/worker-sdk/pom.xml` | VERIFICA/MODIFICA |
| `execution-plane/worker-sdk/.../SandboxExecutorTest.java` | MODIFICA |
| `execution-plane/worker-sdk/.../SandboxBuildInterceptorTest.java` | MODIFICA |
| `execution-plane/worker-sdk/.../SandboxMetricsTest.java` | CREA |
| `PIANO.md` | MODIFICA |
