# Piano: Tre Piani Futuri + Implementazione mcp-jira-tools

## Contesto

L'utente ha 9 librerie MCP tool per Spring AI, tra cui `mcp-devops-tools` (Azure DevOps) e `mcp-ocp-tools` (OpenShift). Vuole:
1. Salvare 3 piani-progetto futuri in `/data/massimiliano/progetti_futuri/`
2. **Implementare ora** `mcp-jira-tools` — nuova libreria MCP per Jira Cloud REST API v3

La libreria segue esattamente il pattern di `mcp-devops-tools`: package `io.github.massimilianopili.mcp.jira`, attivazione condizionale via `mcp.jira.api-token`, `@ReactiveTool` con WebClient, publish su Maven Central.

---

## Task 1: Salvare 3 piani in `/data/massimiliano/progetti_futuri/`

Creare i file (contenuto già pronto dalla ricerca precedente):
- `PIANO_OCP4_SANDBOX.md` — OCP4 Developer Sandbox (30gg gratis, 14GB RAM)
- `PIANO_AZURE_CLOUD.md` — Azure DevOps Boards + Azure Portal ($200 crediti)
- `PIANO_JIRA_CLOUD.md` — Jira Cloud free tier (10 utenti, JQL, Scrum/Kanban)

---

## Task 2: Implementare mcp-jira-tools

### Directory
`/data/massimiliano/Vari/mcp-jira-tools/`

### Struttura file (ricalca mcp-devops-tools)

```
mcp-jira-tools/
├── pom.xml
├── CLAUDE.md
├── .gitea/workflows/release.yml    (copia da release-template)
└── src/main/
    ├── java/io/github/massimilianopili/mcp/jira/
    │   ├── JiraProperties.java
    │   ├── JiraConfig.java
    │   ├── JiraToolsAutoConfiguration.java
    │   ├── JiraIssueTools.java
    │   ├── JiraProjectTools.java
    │   ├── JiraBoardTools.java
    │   ├── JiraSprintTools.java
    │   ├── JiraCommentTools.java
    │   └── JiraUserTools.java
    └── resources/META-INF/spring/
        └── org.springframework.boot.autoconfigure.AutoConfiguration.imports
```

### File da replicare (pattern source)
- `pom.xml` → da `/data/massimiliano/Vari/mcp-devops-tools/pom.xml` (cambiare artifactId, name, description, url, scm)
- `JiraProperties.java` → da `DevOpsProperties.java` (cambiare prefix, campi)
- `JiraConfig.java` → da `DevOpsConfig.java` (cambiare bean name, auth pattern)
- `JiraToolsAutoConfiguration.java` → da `DevOpsToolsAutoConfiguration.java`
- Tool classes → da `DevOpsWorkItemTools.java` / `DevOpsBoardTools.java` come template

### Dettaglio implementazione

#### pom.xml
```xml
<groupId>io.github.massimilianopili</groupId>
<artifactId>mcp-jira-tools</artifactId>
<version>0.0.1</version>
<!-- Stesse dipendenze di mcp-devops-tools:
     spring-ai-model (provided), spring-boot-autoconfigure (optional),
     spring-boot-starter-webflux (provided), spring-ai-reactive-tools (provided),
     slf4j-api (compile). Stessi plugin build. -->
```

#### JiraProperties.java
```java
@ConfigurationProperties(prefix = "mcp.jira")
public class JiraProperties {
    private String baseUrl;      // es: https://myorg.atlassian.net
    private String email;        // email account Atlassian
    private String apiToken;     // API token (trigger attivazione)
    private String apiVersion = "3";

    // Helper: https://myorg.atlassian.net/rest/api/3
    public String getRestUrl() {
        return baseUrl + "/rest/api/" + apiVersion;
    }
    // Helper: https://myorg.atlassian.net/rest/agile/1.0
    public String getAgileUrl() {
        return baseUrl + "/rest/agile/1.0";
    }
}
```

Env vars: `MCP_JIRA_BASE_URL`, `MCP_JIRA_EMAIL`, `MCP_JIRA_API_TOKEN`

#### JiraConfig.java
```java
@Configuration
@ConditionalOnProperty(name = "mcp.jira.api-token")
public class JiraConfig {
    @Bean(name = "jiraWebClient")
    public WebClient jiraWebClient(JiraProperties props) {
        // Jira Cloud: Basic Auth = base64(email:apiToken)
        String credentials = Base64.getEncoder()
            .encodeToString((props.getEmail() + ":" + props.getApiToken()).getBytes());
        return WebClient.builder()
            .defaultHeader("Authorization", "Basic " + credentials)
            .defaultHeader("Accept", "application/json")
            .exchangeStrategies(/* 5MB buffer */)
            .build();
    }
}
```

**Differenza da DevOps**: Jira usa `email:token` (non `:pat`)

#### JiraToolsAutoConfiguration.java
```java
@AutoConfiguration
@ConditionalOnProperty(name = "mcp.jira.api-token")
@EnableConfigurationProperties(JiraProperties.class)
@Import({JiraConfig.class,
         JiraIssueTools.class, JiraProjectTools.class,
         JiraBoardTools.class, JiraSprintTools.class,
         JiraCommentTools.class, JiraUserTools.class})
public class JiraToolsAutoConfiguration { }
```

#### Tool Classes — Endpoint Mapping

**JiraIssueTools.java** (~7 tool)
| Tool | Metodo HTTP | Endpoint Jira | Descrizione |
|------|-------------|---------------|-------------|
| `jira_search_issues` | POST | `/rest/api/3/search` | Cerca issue con JQL |
| `jira_get_issue` | GET | `/rest/api/3/issue/{key}` | Dettaglio issue per chiave (es. MCP-123) |
| `jira_create_issue` | POST | `/rest/api/3/issue` | Crea issue (project, type, summary, description) |
| `jira_update_issue` | PUT | `/rest/api/3/issue/{key}` | Aggiorna campi issue |
| `jira_transition_issue` | POST | `/rest/api/3/issue/{key}/transitions` | Cambia stato (To Do → In Progress → Done) |
| `jira_get_transitions` | GET | `/rest/api/3/issue/{key}/transitions` | Lista transizioni disponibili |
| `jira_delete_issue` | DELETE | `/rest/api/3/issue/{key}` | Elimina issue |

**JiraProjectTools.java** (~5 tool)
| Tool | Metodo | Endpoint | Descrizione |
|------|--------|----------|-------------|
| `jira_list_projects` | GET | `/rest/api/3/project` | Lista progetti |
| `jira_get_project` | GET | `/rest/api/3/project/{key}` | Dettaglio progetto |
| `jira_list_issue_types` | GET | `/rest/api/3/issuetype` | Tipi issue disponibili |
| `jira_list_priorities` | GET | `/rest/api/3/priority` | Priorità disponibili |
| `jira_list_statuses` | GET | `/rest/api/3/status` | Stati disponibili |

**JiraBoardTools.java** (~3 tool)
| Tool | Metodo | Endpoint | Descrizione |
|------|--------|----------|-------------|
| `jira_list_boards` | GET | `/rest/agile/1.0/board` | Lista board (Scrum/Kanban) |
| `jira_get_board` | GET | `/rest/agile/1.0/board/{id}` | Dettaglio board |
| `jira_get_board_configuration` | GET | `/rest/agile/1.0/board/{id}/configuration` | Colonne, filtro, estimation |

**JiraSprintTools.java** (~4 tool)
| Tool | Metodo | Endpoint | Descrizione |
|------|--------|----------|-------------|
| `jira_list_sprints` | GET | `/rest/agile/1.0/board/{boardId}/sprint` | Sprint di una board |
| `jira_get_sprint` | GET | `/rest/agile/1.0/sprint/{sprintId}` | Dettaglio sprint |
| `jira_get_sprint_issues` | GET | `/rest/agile/1.0/sprint/{sprintId}/issue` | Issue nello sprint |
| `jira_get_backlog_issues` | GET | `/rest/agile/1.0/board/{boardId}/backlog` | Issue nel backlog |

**JiraCommentTools.java** (~3 tool)
| Tool | Metodo | Endpoint | Descrizione |
|------|--------|----------|-------------|
| `jira_list_comments` | GET | `/rest/api/3/issue/{key}/comment` | Commenti di una issue |
| `jira_add_comment` | POST | `/rest/api/3/issue/{key}/comment` | Aggiungi commento (ADF format) |
| `jira_get_changelog` | GET | `/rest/api/3/issue/{key}/changelog` | Storico modifiche |

**JiraUserTools.java** (~2 tool)
| Tool | Metodo | Endpoint | Descrizione |
|------|--------|----------|-------------|
| `jira_get_current_user` | GET | `/rest/api/3/myself` | Utente corrente |
| `jira_search_users` | GET | `/rest/api/3/user/search` | Cerca utenti per query |

**Totale: ~24 tool** (vs 47 di devops-tools — Jira ha un'API più semplice)

### Note su Jira REST API v3

1. **Autenticazione**: Basic Auth `email:api_token` (generato su https://id.atlassian.com/manage-profile/security/api-tokens)
2. **JQL** (Jira Query Language): equivalente di WIQL per Azure DevOps. Es: `project = MCP AND status = "In Progress" ORDER BY priority DESC`
3. **ADF** (Atlassian Document Format): i commenti e description in API v3 usano JSON strutturato, non plain text. Per semplicità, useremo il wrapper `text` → `{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"..."}]}]}`
4. **Agile API** è separata (`/rest/agile/1.0/`) dalla Platform API (`/rest/api/3/`): board e sprint usano l'Agile API
5. **Paginazione**: `startAt` + `maxResults` (default 50, max 100 per search)

### Integrazione nel MCP Server

Dopo la creazione della libreria, aggiungere in `/data/massimiliano/Vari/mcp/pom.xml`:
```xml
<dependency>
    <groupId>io.github.massimilianopili</groupId>
    <artifactId>mcp-jira-tools</artifactId>
    <version>0.0.1</version>
</dependency>
```

E in `application.properties`:
```properties
mcp.jira.base-url=${MCP_JIRA_BASE_URL:}
mcp.jira.email=${MCP_JIRA_EMAIL:}
mcp.jira.api-token=${MCP_JIRA_API_TOKEN:}
```

### Git setup
```bash
cd /data/massimiliano/Vari/mcp-jira-tools
git init
git remote add origin git@gitea-local:sol_root/mcp-jira-tools.git
git remote add github git@github.com:MassimilianoPili/mcp-jira-tools.git
```

Aggiungere il repo a `gitall` per multi-repo management.

---

## Ordine di esecuzione

1. Creare i 3 file piano in `/data/massimiliano/progetti_futuri/`
2. Creare directory `/data/massimiliano/Vari/mcp-jira-tools/`
3. Implementare tutti i file Java + pom.xml + auto-config
4. Build locale: `mvn clean package -DskipTests`
5. Aggiungere dipendenza nel server MCP
6. (Opzionale) Creare repo Gitea + push iniziale

## Verifica

1. `cd /data/massimiliano/Vari/mcp-jira-tools && /opt/maven/bin/mvn clean package -DskipTests` → BUILD SUCCESS
2. Aggiungere al server MCP → `cd /data/massimiliano/Vari/mcp && /opt/maven/bin/mvn clean package -DskipTests` → BUILD SUCCESS
3. Test con Jira Cloud (dopo setup account): configurare env vars → avviare server MCP → invocare `jira_list_projects`
