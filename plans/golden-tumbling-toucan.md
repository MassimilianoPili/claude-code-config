# Sessione S15 — Worker Abstraction (worker-parent + @WorkerMetadata + LlmWorker)

## Context

Il framework ha ~47 worker (45 generati dal `agent-compiler-maven-plugin` + 2 hand-written: AdvisoryWorker, RagManagerWorker). L'analisi mostra **~49% di boilerplate** (~3200 LOC) duplicato in ogni worker: 7 dipendenze POM identiche, 5 method override che ritornano costanti, e un pattern `execute()` identico per tutti i worker LLM.

**Obiettivo**: estrarre il common in 3 livelli — POM parent, annotazione metadata, classe intermedia LLM — riducendo ~6700 LOC e semplificando drasticamente i template Mustache del generatore.

---

## Fase 1: `worker-parent` POM (dipendenze comuni)

### Razionale
Tutti i 45 worker generati dichiarano le stesse 7 dipendenze + 1 plugin. Un POM parent intermedio le centralizza. Advisory-worker resta parented da `agent-framework` (intenzionalmente lightweight: omette `messaging-redis` e `spring-ai-reactive-tools`).

### 1a. Nuovo modulo `execution-plane/worker-parent/pom.xml`
```xml
<parent>
    <groupId>com.agentframework</groupId>
    <artifactId>agent-framework</artifactId>
    <version>1.1.0-SNAPSHOT</version>
    <relativePath>../../pom.xml</relativePath>
</parent>

<artifactId>worker-parent</artifactId>
<packaging>pom</packaging>
<name>Agent Framework :: Execution Plane :: Worker Parent</name>

<dependencies>
    <!-- 5 compile-scope universali -->
    <dependency><groupId>com.agentframework</groupId><artifactId>worker-sdk</artifactId></dependency>
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-web</artifactId></dependency>
    <dependency><groupId>org.springframework.ai</groupId><artifactId>spring-ai-starter-model-anthropic</artifactId></dependency>
    <dependency><groupId>com.agentframework</groupId><artifactId>messaging-redis</artifactId></dependency>
    <dependency><groupId>io.github.massimilianopili</groupId><artifactId>spring-ai-reactive-tools</artifactId></dependency>
    <!-- 1 test -->
    <dependency><groupId>org.springframework.boot</groupId><artifactId>spring-boot-starter-test</artifactId><scope>test</scope></dependency>
</dependencies>

<build><plugins>
    <plugin>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-maven-plugin</artifactId>
        <configuration><classifier>exec</classifier></configuration>
    </plugin>
</plugins></build>
```

### 1b. Root `pom.xml`
- Aggiungere `<module>execution-plane/worker-parent</module>` PRIMA dei worker modules

### 1c. `pom.xml.mustache` — cambiare parent
```xml
<parent>
    <groupId>com.agentframework</groupId>
    <artifactId>worker-parent</artifactId>
    <version>{{parentVersion}}</version>
    <relativePath>../worker-parent/pom.xml</relativePath>
</parent>
```
Rimuovere le 7 dipendenze universali. Restano solo i blocchi `{{#toolDependencies}}` e `{{#hasMcpServers}}`.

### 1d. `WorkerGenerator.java`
- Aggiornare `relativePath` generato per i POM: `../worker-parent/pom.xml` (era `../../../pom.xml`)

### Advisory-worker
**NON cambia parent** — resta su `agent-framework`. Il suo POM hand-written (5 dipendenze, senza `messaging-redis`/`reactive-tools`) resta intatto.

### Rag-manager-worker
**Cambia parent** automaticamente: il suo POM è generato dal template, quindi adotta `worker-parent`.

---

## Fase 2: `@WorkerMetadata` annotation (elimina 5 method override)

### 2a. Nuova annotazione in worker-sdk
**File**: `execution-plane/worker-sdk/src/main/java/com/agentframework/worker/WorkerMetadata.java`
```java
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface WorkerMetadata {
    String workerType();
    String workerProfile() default "";
    String systemPromptFile();
    String[] toolAllowlist() default {};
    String[] skillPaths() default {};
}
```

### 2b. Modifica `AbstractWorker.java`
- `workerType()`: da `abstract` → concreto con fallback annotation:
  ```java
  public String workerType() {
      WorkerMetadata m = getClass().getAnnotation(WorkerMetadata.class);
      if (m != null) return m.workerType();
      throw new IllegalStateException("@WorkerMetadata or workerType() override required on " + getClass().getName());
  }
  ```
- `systemPromptFile()`: da `abstract` → concreto con stesso pattern
- `workerProfile()`: aggiungere annotation fallback (se `m.workerProfile()` non vuoto → ritorna, altrimenti `null`)
- `toolAllowlist()`: aggiungere annotation fallback (se `m.toolAllowlist().length > 0` → `Explicit`, altrimenti `ALL`)
- `skillPaths()`: aggiungere annotation fallback

**Compatibilità**: i metodi restano overridable. Hand-written workers possono usare annotation O override (o entrambi per `resolveSystemPromptFile()` che override `systemPromptFile()` a runtime). I test che istanziano anonymous subclass con override continuano a funzionare — l'override ha priorità su annotation.

---

## Fase 3: `LlmWorker` classe intermedia (elimina `execute()` duplicato)

### 3a. Nuovo file in worker-sdk
**File**: `execution-plane/worker-sdk/src/main/java/com/agentframework/worker/LlmWorker.java`

```java
public abstract class LlmWorker extends AbstractWorker {

    protected LlmWorker(AgentContextBuilder contextBuilder,
                        WorkerChatClientFactory chatClientFactory,
                        WorkerResultProducer resultProducer,
                        List<WorkerInterceptor> interceptors) {
        super(contextBuilder, chatClientFactory, resultProducer, interceptors);
    }

    /** Worker-specific instructions (injected into user prompt). */
    protected abstract String instructions();

    /** Expected JSON result schema (appended to instructions). */
    protected abstract String resultSchema();

    @Override
    protected String execute(AgentContext context, ChatClient chatClient)
            throws WorkerExecutionException {
        String userPrompt = buildStandardUserPrompt(context,
            instructions() + "\n\nReturn your result as JSON with the following structure:\n```json\n"
            + resultSchema() + "\n```");

        log.info("[{}] Executing task '{}' with {} dependency results",
                 workerType(), context.taskKey(), context.dependencyResults().size());
        try {
            ChatResponse chatResponse = chatClient.prompt()
                .system(context.systemPrompt())
                .user(userPrompt)
                .call()
                .chatResponse();

            String response = chatResponse.getResult().getOutput().getText();
            if (chatResponse.getMetadata() != null && chatResponse.getMetadata().getUsage() != null) {
                recordTokenUsage(chatResponse.getMetadata().getUsage());
            }
            log.info("[{}] Task '{}' completed, response length: {} chars",
                     workerType(), context.taskKey(), response != null ? response.length() : 0);
            return response;
        } catch (Exception e) {
            throw new WorkerExecutionException(
                workerType() + " worker execution failed for task " + context.taskKey(), e);
        }
    }
}
```

### Gerarchia risultante

```
AbstractWorker (template method: process(), buildStandardUserPrompt())
├── LlmWorker (default execute() con instructions/resultSchema)
│   ├── 45 generated workers (@WorkerMetadata + instructions() + resultSchema())
│   └── AdvisoryWorker (override resolveSystemPromptFile() per profile routing)
└── RagManagerWorker (programmatic, override execute() diretto)
```

---

## Fase 4: Template Mustache aggiornati

### 4a. `Worker.java.mustache` — da 117 → ~30 righe
```java
// Generated by agent-compiler-maven-plugin from {{manifestFile}}. DO NOT EDIT.
package com.agentframework.workers.generated.{{packageName}};

import com.agentframework.worker.LlmWorker;
import com.agentframework.worker.WorkerMetadata;
import com.agentframework.worker.claude.WorkerChatClientFactory;
import com.agentframework.worker.context.AgentContextBuilder;
import com.agentframework.worker.interceptor.WorkerInterceptor;
import com.agentframework.worker.messaging.WorkerResultProducer;
import org.springframework.stereotype.Component;

import javax.annotation.processing.Generated;
import java.util.List;

@Component
@Generated("agent-compiler-maven-plugin")
@WorkerMetadata(
    workerType = "{{workerType}}",
    {{#workerProfile}}workerProfile = "{{workerProfile}}",{{/workerProfile}}
    systemPromptFile = "{{systemPromptFile}}",
    toolAllowlist = { {{#allowlistEntries}}"{{name}}"{{#hasNext}}, {{/hasNext}}{{/allowlistEntries}} },
    skillPaths = { {{#skillEntries}}"{{path}}"{{#hasNext}}, {{/hasNext}}{{/skillEntries}} }
)
public class {{className}} extends LlmWorker {

    private static final String INSTRUCTIONS = """
            {{{instructions}}}""";

    private static final String RESULT_SCHEMA = """
            {{{resultSchema}}}""";

    public {{className}}(AgentContextBuilder contextBuilder,
            {{constructorPad}}WorkerChatClientFactory chatClientFactory,
            {{constructorPad}}WorkerResultProducer resultProducer,
            {{constructorPad}}List<WorkerInterceptor> interceptors) {
        super(contextBuilder, chatClientFactory, resultProducer, interceptors);
    }

    @Override protected String instructions() { return INSTRUCTIONS; }
    @Override protected String resultSchema() { return RESULT_SCHEMA; }
}
```

Eliminati: 5 method override (workerType, workerProfile, systemPromptFile, toolAllowlist, skillPaths), execute(), TOOL_ALLOWLIST/SKILL_PATHS constants, Logger, 6 import.

### 4b. `pom.xml.mustache`
Come descritto in Fase 1c — parent → `worker-parent`, solo toolDependencies + hasMcpServers.

---

## Fase 5: Migrazione AdvisoryWorker

**File**: `execution-plane/workers/advisory-worker/src/main/java/com/agentframework/workers/advisory/AdvisoryWorker.java`

- Cambiare `extends AbstractWorker` → `extends LlmWorker`
- Aggiungere `@WorkerMetadata(workerType = "MANAGER", systemPromptFile = "prompts/council/managers/be-manager.agent.md", toolAllowlist = {"Glob", "Grep", "Read"})`
- Rimuovere `workerType()`, `systemPromptFile()`, `toolAllowlist()` override (ora via annotation)
- Rimuovere `execute()` override (identico a `LlmWorker.execute()`)
- **MANTENERE** `resolveSystemPromptFile(AgentTask)` override (unica logica custom: profile routing)
- Aggiungere `instructions()` e `resultSchema()` override (spostando INSTRUCTIONS da campo statico a metodo)
- **POM invariato** — resta parent `agent-framework`, niente `messaging-redis`/`reactive-tools`

---

## Ordine di build (dipendenze)

```
Fase 1 (worker-parent POM) — nessuna dipendenza
    ↓
Fase 2 (@WorkerMetadata + AbstractWorker) ─── dipende dal nuovo annotation in worker-sdk
    ↓
Fase 3 (LlmWorker) ─── dipende da AbstractWorker refactored
    ↓
Fase 4 (template Mustache) ─── dipende da LlmWorker + @WorkerMetadata
    ↓
Fase 5 (AdvisoryWorker migration) ─── dipende da LlmWorker
```

---

## Riepilogo file

### Nuovi file (3)
| # | File | Modulo |
|---|------|--------|
| 1 | `worker-parent/pom.xml` | execution-plane |
| 2 | `WorkerMetadata.java` | worker-sdk |
| 3 | `LlmWorker.java` | worker-sdk |

### File modificati (6)
| # | File | Cambiamento |
|---|------|-------------|
| 1 | `pom.xml` (root) | +module worker-parent |
| 2 | `AbstractWorker.java` | workerType/systemPromptFile non-abstract con annotation fallback |
| 3 | `Worker.java.mustache` | extends LlmWorker, @WorkerMetadata, elimina 5 override + execute() |
| 4 | `pom.xml.mustache` | parent → worker-parent, elimina 7 dep universali |
| 5 | `WorkerGenerator.java` | relativePath aggiornato |
| 6 | `AdvisoryWorker.java` | extends LlmWorker, @WorkerMetadata, rimuove execute() |

### Impatto LOC stimato
| Componente | Prima | Dopo | Risparmio |
|-----------|-------|------|-----------|
| Worker.java.mustache | 117 | ~35 | -82 |
| Generated Worker.java (×45) | ~117 each | ~35 each | ~3690 totali |
| Generated pom.xml (×45) | ~85 each | ~25 each | ~2700 totali |
| AdvisoryWorker.java | 169 | ~55 | -114 |
| Nuovi file | 0 | ~125 | +125 |
| **Netto** | | | **~6400 LOC rimossi** |

---

## Verifica end-to-end

1. **Build**: `mvn clean install -T1` — compilazione completa con test (2102+)
2. **Template regen**: verificare che i 45 worker rigenerati estendano `LlmWorker` e abbiano `@WorkerMetadata`
3. **Advisory test**: verificare che AdvisoryWorker compili e i test passino con la nuova gerarchia
4. **Rag-manager**: verificare che RagManagerWorker resti su `AbstractWorker` e compili
5. **Worker-parent transitività**: `mvn dependency:tree -pl execution-plane/workers/be-java-worker` → le 7 dep devono apparire come transitive da `worker-parent`
6. **Nessuna regressione funzionale**: il comportamento runtime è identico — stessa execute(), stessi metodi, stessa risoluzione prompt
