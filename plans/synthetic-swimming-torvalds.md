# Piano: mcp-redis-tools

## Contesto

Il `simoge-mcp` è ora un container SSE singleton condiviso da tutte le sessioni Claude Code.
Redis è già attivo sulla rete Docker (`redis:6379`, DB 0/1/2 Gitea, DB 4 Preference Sort).
Non esiste ancora una libreria MCP per Redis — `mcp-redis-tools` va creata da zero.

**Obiettivo:** esporre Redis come tool MCP con due categorie:
1. **KV generico** — GET/SET/DEL/KEYS su chiavi arbitrarie
2. **Inter-Claude messaging** — inbox per sessione + broadcast (DB 5 dedicato, isolato)

## Pattern da replicare

Da `mcp-mongo-tools` e `mcp-sql-tools` (analizzati):
- `@AutoConfiguration` + `@ConditionalOnClass` + `@ConditionalOnProperty(matchIfMissing=false)`
- `@Import({Config.class, Tools.class})` + `@Bean ToolCallbackProvider`
- `spring-ai-model`: `provided` / `spring-boot-autoconfigure`: `optional` / driver: `compile`
- File `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`

---

## File da creare

### `/data/massimiliano/Vari/mcp-redis-tools/pom.xml`
```xml
<groupId>io.github.massimilianopili</groupId>
<artifactId>mcp-redis-tools</artifactId>
<version>0.1.0</version>
Java 21, Spring Boot 3.4.1, Spring AI 1.0.0
Dipendenze:
  - spring-ai-model: provided
  - spring-boot-autoconfigure: optional
  - spring-boot-starter-data-redis: compile  (porta Lettuce + RedisTemplate)
```

### `RedisToolsAutoConfiguration.java`
```java
@AutoConfiguration
@ConditionalOnClass(StringRedisTemplate.class)
@ConditionalOnProperty(name = "mcp.redis.enabled", havingValue = "true", matchIfMissing = false)
@Import({RedisConfig.class, RedisTools.class})
public class RedisToolsAutoConfiguration {
    @Bean @ConditionalOnMissingBean(name = "redisToolCallbackProvider")
    public ToolCallbackProvider redisToolCallbackProvider(RedisTools t) {
        return MethodToolCallbackProvider.builder().toolObjects(t).build();
    }
}
```

### `RedisConfig.java`
Due `StringRedisTemplate` distinti:
- `redisTemplate` → DB configurabile via `MCP_REDIS_DB` (default: 0) — KV generico
- `redisMessagingTemplate` → DB 5 fisso — inter-Claude messaging

Connessione via `MCP_REDIS_URL` (default: `redis://redis:6379`).

### `RedisTools.java` — Tool esposti

**KV generico:**

| Tool | Operazione |
|------|-----------|
| `redis_get(key)` | GET |
| `redis_set(key, value, ttlSeconds?)` | SET [EX ttl] |
| `redis_del(pattern)` | DEL tutte le chiavi matching glob (max 100) |
| `redis_keys(pattern)` | KEYS pattern (max 100 risultati) |
| `redis_ttl(key)` | TTL restante in secondi (-1 = nessuno, -2 = non esiste) |
| `redis_incr(key)` | INCR atomico (utile per contatori condivisi) |

**Inter-Claude messaging (DB 5):**

| Tool | Operazione |
|------|-----------|
| `claude_send(to, content)` | LPUSH `claude:inbox:<to>` + EXPIRE 86400 (24h) |
| `claude_read(my_label, count?)` | LRANGE `claude:inbox:<my_label>` 0 count (default 10), poi DEL |
| `claude_broadcast(content)` | LPUSH `claude:inbox:__broadcast__` + EXPIRE 3600 (1h) |
| `claude_list_inboxes()` | KEYS `claude:inbox:*` — chi ha messaggi in attesa |
| `claude_clear(my_label)` | DEL `claude:inbox:<my_label>` |

Nota: `claude_read` è **destructive** (legge e rimuove) per evitare rilettura. Pattern pull-based (nessun push).

### `AutoConfiguration.imports`
```
io.github.massimilianopili.mcp.redis.RedisToolsAutoConfiguration
```

---

## File da modificare

### `/data/massimiliano/Vari/mcp/pom.xml`
Aggiungere nella sezione tool starters:
```xml
<dependency>
    <groupId>io.github.massimilianopili</groupId>
    <artifactId>mcp-redis-tools</artifactId>
    <version>0.1.0</version>
</dependency>
```

### `/data/massimiliano/Vari/mcp/docker-compose.yml`
Aggiungere alle environment:
```yaml
MCP_REDIS_ENABLED: "true"
MCP_REDIS_URL: redis://redis:6379
```

---

## Sequenza build e deploy

```bash
# 1. Build e install libreria in local Maven repo
cd /data/massimiliano/Vari/mcp-redis-tools
mvn install -DskipTests -q

# 2. Rebuild mcp-server con la nuova lib
cd /data/massimiliano/Vari/mcp
mvn package -DskipTests -q
docker compose up -d --build

# 3. Aggiornare ~/.claude.json (ancora su stdio → va fatto separatamente)
# "simoge-mcp": { "type": "sse", "url": "http://localhost:8099/sse" }
```

---

## Verifica

```bash
# Tool registrato nel server MCP
docker exec simoge-mcp cat /app/logs/mcp-server.log | grep -i "redis\|tool"

# Test messaging: istanza A invia, istanza B legge
docker exec redis redis-cli -n 5 KEYS "claude:inbox:*"

# Nessuna interferenza con DB esistenti
docker exec redis redis-cli info keyspace
# Deve mostrare db0, db3, db4 invariati + db5 solo se ci sono messaggi
```

---

## Note architetturali

- `matchIfMissing = false`: la lib è opt-in — non si attiva se `MCP_REDIS_ENABLED` è assente
- DB 5 isolato: zero interferenza con Gitea (0/1/2), sessions (1), queue (2), preference-sort (4)
- `claude_read` è distruttivo (LRANGE + DEL atomico con pipeline) per evitare rilettura accidentale
- 24h TTL automatico sui messaggi: nessun accumulo silenzioso in Redis
- Le sessioni Claude non hanno event loop → comunicazione è sempre pull-based (nessuna notifica push)
