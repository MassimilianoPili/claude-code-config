# Piano: SocialMCP — Social Network Federato su MCP

## Context

**Problema**: I social network attuali (Instagram, Twitter, Reddit) sono centralizzati. Il tuo profilo è dichiarativo, i contenuti sono manuali, l'algoritmo è opaco e di proprietà della piattaforma. L'identità digitale è frammentata su N piattaforme.

**Visione**: Un social network a due livelli dove:
- **Superficie**: post, profili, feed — quello che le persone vedono (come Instagram)
- **Substrato**: una rete di MCP server che si parlano, negoziano edge (relazioni), e generano contenuti autonomamente

Ogni persona ha un **nodo MCP** che:
1. **Assorbe** da tutti i tuoi interessi (bridge a Instagram, Reddit, Tumblr, Twitter, arXiv, Kindle...) → alimenta KORE
2. **Genera** contenuti basati su chi sei — profilo e post sono **emergenti** dal knowledge graph, non dichiarati
3. **Filtra** ciò che ti mostra — feed algoritmico locale, come Instagram ma decentralizzato
4. **Negozia** relazioni con altri nodi — gli edge sono **contrattati bilateralmente** (modello BGP), non unilaterali
5. **Pubblica** sui social legacy — bridge bidirezionali con consenso configurabile (o bypass)

**Cosa NON è**: Non è ActivityPub/Mastodon (unilateral follow, JSON-LD). Non è Nostr (semplice relay). Non è Solid (solo storage). È un protocollo dove MCP server autonomi negoziano relazioni e generano contenuti.

**Fonti del design**: BGP peering (bilateral edge negotiation), Tumblr (cell architecture, reblog trail), Reddit/Lemmy (community-as-relay, Wilson score), Instagram (algorithmic feed, multi-surface ranking), Bluesky AT Protocol (modular feed generation), A2A (Agent Card discovery), MCP (tool-based interaction), Automated Trust Negotiation (credential exchange).

**Ricerca completa**:
- `bubbly-twirling-aurora-agent-afdf43ddcd4716170.md` — protocolli (REST, ActivityPub, A2A, MCP, WebFinger)
- `bubbly-twirling-aurora-agent-a92b7d6aa6843f1a4.md` — architetture (Tumblr, Reddit/Lemmy, OpenSocial, edge negotiation, Solid)
- `bubbly-twirling-aurora-agent-a50cdb0b6d8dd477a.md` — Instagram feed algorithm, content generation, bridge patterns

---

## Architettura a Due Livelli

```
                    ┌─────────────────────────────────────────┐
                    │           SUPERFICIE (Social 2.0)        │
                    │  Post generati · Feed filtrato · Profilo │
                    │  emergente · Interazioni · Discovery     │
                    └────────────────────┬────────────────────┘
                                         │
┌──────────────┐    ┌────────────────────┴────────────────────┐    ┌──────────────┐
│ Social 1.0   │◄──►│            SUBSTRATO (MCP Network)       │◄──►│ Social 1.0   │
│ Instagram    │    │                                          │    │ Reddit       │
│ Twitter/X    │    │  ┌─────┐    negotiate    ┌─────┐        │    │ Tumblr       │
│ Facebook     │    │  │Nodo │◄──── edge ─────►│Nodo │        │    │ arXiv        │
│ Threads      │    │  │  A  │    bilaterale   │  B  │        │    │ Kindle       │
│              │    │  └──┬──┘                 └──┬──┘        │    │ HN           │
│   bridge     │    │     │         ┌─────┐       │           │    │   bridge     │
│   ingest +   │    │     └────────►│Comm │◄──────┘           │    │   ingest +   │
│   post       │    │               │ MCP │ (relay)           │    │   post       │
└──────────────┘    │               └─────┘                   │    └──────────────┘
                    └─────────────────────────────────────────┘
                                         │
                    ┌────────────────────┴────────────────────┐
                    │              KORE (cervello)             │
                    │  AGE knowledge graph · pgvector embeddings│
                    │  Assorbimento multi-fonte · Identità     │
                    └─────────────────────────────────────────┘
```

### Flusso dati

```
INGEST (bridge Social 1.0)          GENERATE (dal KORE)           DISTRIBUTE (MCP network)
─────────────────────────           ──────────────────            ────────────────────────
Reddit saved posts      ─┐                                       ┌─► Nodi MCP connessi
Instagram saved/liked    ├─► KORE ─► LLM genera contenuto ──────►├─► Feed filtrato locale
Tumblr followed blogs    │  (AGE +   basato su chi sei           ├─► Bridge → Instagram
arXiv papers             │  pgvec)   (profilo emergente)         └─► Bridge → Twitter
Kindle highlights        │                                            (con consenso o bypass)
Twitter/X bookmarks     ─┘
```

---

## Design Principles

1. **KORE-first** — il knowledge graph è la fonte di verità dell'identità. Tutto il resto è derivato
2. **Bilateral edges** — ogni relazione è negoziata (modello BGP). Nessun follow unilaterale
3. **Emergent identity** — il profilo non è dichiarato, è computato dal KORE
4. **Local filtering** — l'algoritmo del feed gira sul tuo nodo, non su un server centrale
5. **AI-generated content** — i nodi producono contenuti autonomamente dal knowledge graph
6. **Bidirectional bridges** — ingest da Social 1.0 per arricchire KORE + post verso Social 1.0
7. **Consent by default, bypass by config** — cross-posting chiede prima, ma c'è un modo automatico
8. **Hourglass protocol** — core tiny (whoami + ask + follow_request), estensioni illimitate sopra
9. **No JSON-LD** — JSON puro (lezione da ActivityPub)
10. **Additive-only versioning** — date-based, mai breaking changes

---

## Fasi di Implementazione

### Fase 0: Persona Endpoint (MVP) — `mcp-persona-tools` v0.1.0

**Obiettivo**: il tuo MCP risponde a "chi sei?" e "parlami di X" usando KORE + Ollama.
**Task accodato**: #238 (`persona-mcp-protocol`, priorità 3)

#### Componenti

```
/data/massimiliano/Vari/mcp-persona-tools/
├── pom.xml
└── src/main/java/io/github/massimilianopili/mcp/persona/
    ├── PersonaProperties.java          # @ConfigurationProperties(prefix = "mcp.persona")
    ├── PersonaAutoConfiguration.java   # @AutoConfiguration + @Import
    ├── PersonaConfig.java              # WebClient Ollama + Redis DB 8
    ├── PersonaLlmClient.java           # Ollama /api/chat (multi-turn)
    ├── PersonaKoreClient.java          # AGE query per context enrichment
    ├── PersonaService.java             # Core: prompt + sessions + KORE + LLM
    ├── PersonaController.java          # REST: /.well-known/persona.json + /api/persona/*
    ├── PersonaTools.java               # @ReactiveTool: persona_whoami, persona_ask, extensions
    └── PersonaCapabilityPatcher.java   # BeanPostProcessor: experimental.persona
```

#### MCP Tools

| Tool | Descrizione |
|------|-------------|
| `persona_whoami()` | Identità emergente (query KORE per Topic, interests) |
| `persona_ask(message, sessionId?, language?)` | Conversazione: KORE context + Ollama + Redis sessions |
| `persona_topics()` | Extension: topic dal KORE con depth level |
| `persona_research(query, depth?)` | Extension: ricerca papers/books dal KORE |
| `persona_links()` | Extension: contatti e social links |

#### HTTP Endpoints

| Endpoint | Auth | Descrizione |
|----------|------|-------------|
| `GET /.well-known/persona.json` | Pubblico | Social Card (discovery, cacheable 1h) |
| `GET /api/persona/whoami` | Pubblico | Identità |
| `POST /api/persona/ask` | `X-Persona-Key` | Conversazione |
| `GET /api/persona/topics` | Pubblico | Topic expertise |
| `POST /api/persona/research` | `X-Persona-Key` | Ricerca |
| `GET /api/persona/links` | Pubblico | Contatti |

#### Pattern da riusare

| Pattern | File sorgente |
|---------|---------------|
| `@ReactiveTool` + error handling | `mcp-ai-tools/.../AiTextTools.java` |
| Ollama WebClient + `/api/chat` | `mcp-ollama-tools/.../OllamaTools.java` |
| `@ConfigurationProperties` | `mcp-ollama-tools/.../OllamaProperties.java` |
| `@RestController` in libreria | `mcp-channel-tools/.../WebhookController.java` |
| MCP capability patching | `mcp-channel-tools/.../McpChannelCapabilityPatcher.java` |
| `@AutoConfiguration` + `@Import` | `mcp-channel-tools/.../ChannelAutoConfiguration.java` |

#### Modifiche a file esistenti

1. **`/data/massimiliano/Vari/mcp/pom.xml`** — aggiungere dependency `mcp-persona-tools:0.1.0`
2. **`/data/massimiliano/Vari/mcp/.env`** — aggiungere config `MCP_PERSONA_*`
3. **`/data/massimiliano/proxy/nginx.conf`** — rate limit `persona_limit:5r/m` + location `/.well-known/persona.json` e `/api/persona/`

#### Build & Deploy

```bash
cd /data/massimiliano/Vari/mcp-persona-tools && mvn clean install -Dgpg.skip=true
cd /data/massimiliano/Vari/mcp && mvn clean install -Dgpg.skip=true
sol deploy mcp
docker compose up -d nginx --force-recreate  # (in /data/massimiliano/proxy/)
```

#### Verifica Fase 0

```bash
curl https://sol.massimilianopili.com/.well-known/persona.json           # → Social Card
curl https://sol.massimilianopili.com/api/persona/whoami                  # → identità
curl -X POST .../api/persona/ask -H "X-Persona-Key: <key>" -d '{"message":"Who are you?"}'  # → risposta
# Verifica: experimental.persona nel MCP handshake
# Verifica: persona_whoami() e persona_ask() funzionano via Claude session
```

---

### Fase 1: Bridge Ingest — Alimentare KORE dai Social 1.0

**Obiettivo**: assorbire contenuti dai tuoi interessi su social legacy → arricchire KORE automaticamente.

#### Bridge da implementare

| Piattaforma | Cosa ingerire | API/Metodo | KORE node type |
|-------------|---------------|------------|----------------|
| **Reddit** | Saved posts, subreddit feeds | Reddit API (OAuth2, read-only) | Concept, Source |
| **Instagram** | Saved/liked posts, seguiti | Instagram Basic Display API | Concept, Source |
| **Tumblr** | Blog seguiti, reblog | Tumblr API v2 (OAuth1) | Concept, Source |
| **Twitter/X** | Bookmarks, liste | Twitter API v2 (se disponibile) | Concept, Source |
| **arXiv** | Paper dai feed (già esistente: `paper_archive.py`) | arXiv API | Paper, Author, Venue |
| **Kindle** | Highlights (già esistente: `import_kindle.py`) | File parser | Book, Sequence |
| **Hacker News** | Favoriti, top stories | HN API (nessuna auth) | Concept, Source |

#### Architettura bridge — Generic First

**Principio**: prima il bridge generico (scraper + LLM embedder), poi le specializzazioni per piattaforma.

```
                    ┌───────────────────────────────────┐
                    │       GenericBridge (base)          │
                    │                                     │
                    │  URL/feed → fetch → extract text    │
                    │  → ai_extract_entities (Ollama)     │
                    │  → generate embedding (qwen3-emb)   │
                    │  → graph_write (AGE) + upsert_emb   │
                    └──────────────┬────────────────────┘
                                   │ extends
              ┌────────────────────┼────────────────────┐
              │                    │                     │
    ┌─────────┴──────┐  ┌─────────┴──────┐  ┌──────────┴─────┐
    │ RedditBridge   │  │ TumblrBridge   │  │ InstagramBridge │
    │ OAuth2 API     │  │ OAuth1 API     │  │ Graph API       │
    │ saved, subs    │  │ followed blogs │  │ saved/liked     │
    │ markdown text  │  │ reblog chains  │  │ image + caption │
    └────────────────┘  └────────────────┘  └────────────────┘
                                   │
                        ┌──────────┴──────────┐
                        │ HackerNewsBridge    │
                        │ Nessuna auth        │
                        │ Top stories, favs   │
                        └─────────────────────┘
```

**GenericBridge** (la base):
1. Input: URL o feed (RSS, API response, scraped page)
2. `web_fetch` → estrai testo (o `ai_extract_entities` per contenuto non strutturato)
3. `ai_keywords` → estrai topic
4. Genera embedding (`qwen3-embedding:8b` via Ollama)
5. Scrivi in KORE: `graph_write` (nodo Concept/Source + relazioni) + `upsert_embedding`
6. Dedup: hash del contenuto → skip se già ingerito

**Specializzazioni**: le piattaforme aggiungono solo auth + API-specific fetch + parsing specifico (es. Instagram: image analysis via minicpm-v, Reddit: markdown, Tumblr: reblog trail).

Timer: inesorabilità (batch limitato, convergenza graduale). Pattern: identico a `paper_archive.py`.

---

### Fase 2: Content Generation — Il nodo produce contenuti

**Obiettivo**: il tuo MCP genera post/pensieri basati su cosa c'è nel KORE. Il profilo è emergente.

#### Come funziona

1. **Profilo emergente**: query KORE per Topic nodes con più connessioni → ranked per centralità → genera bio dinamica
2. **Content generation**:
   - Timer periodico (o trigger su nuovi nodi KORE)
   - Query KORE per contenuti recenti/interessanti
   - LLM sintetizza un "post" in prima persona
   - Post salvato in Redis/AGE con metadata (topic, confidence, source nodes)
3. **Modalità**:
   - `auto`: genera e pubblica automaticamente
   - `draft`: genera bozze, l'utente approva
   - `silent`: genera ma non pubblica (solo KORE enrichment)

#### MCP Tools aggiuntivi (Fase 2)

| Tool | Descrizione |
|------|-------------|
| `persona_feed(limit?, cursor?)` | Feed dei post generati dal nodo |
| `persona_generate(topic?)` | Trigger manuale: genera un post su un topic |
| `persona_profile()` | Profilo emergente computato dal KORE |
| `persona_drafts()` | Lista bozze in attesa di approvazione |

---

### Fase 3: Edge Negotiation — MCP si parlano tra loro

**Obiettivo**: due nodi MCP possono negoziare una relazione (follow, peer, community member).

#### Protocollo di negoziazione (modello BGP + ATN)

```
Nodo A                                          Nodo B
  │                                                │
  ├─► GET /.well-known/persona.json ──────────────►│  (discovery)
  │◄── Social Card + capabilities ─────────────────┤
  │                                                │
  ├─► social_follow_request(social_card_A, terms)─►│  (proposta)
  │                                                │
  │   B valuta: policy, trust score, mutual edges  │
  │                                                │
  │◄── social_follow_accept(capability_token) ─────┤  (accettazione + token)
  │    oppure                                      │
  │◄── social_follow_reject(reason) ───────────────┤  (rifiuto)
  │    oppure                                      │
  │◄── social_follow_negotiate(need_credential) ───┤  (richiesta ulteriore)
  │                                                │
  ├─► social_credential(proof) ───────────────────►│  (scambio credenziali ATN)
  │◄── social_follow_accept(capability_token) ─────┤
  │                                                │
  │  === EDGE STABILITO (bilaterale) ===           │
  │                                                │
  ├─► social_post(content, audience) ─────────────►│  (push contenuto)
  │◄── social_post(content, audience) ─────────────┤  (push contenuto)
```

#### Edge types

| Tipo | Simmetria | Descrizione |
|------|-----------|-------------|
| `follow` | Asimmetrico | A riceve i post di B (ma B decide cosa condividere) |
| `peer` | Simmetrico | Scambio bidirezionale di contenuti |
| `community` | N:1 | A è membro di un Community MCP server (relay Lemmy-style) |

#### Capability token

Quando B accetta la relazione, emette un token che specifica:
```json
{
  "edge_id": "uuid",
  "granted_to": "https://server-a.example",
  "permissions": ["read_public", "read_topics"],
  "issued_at": "2026-03-23T...",
  "expires_at": "2027-03-23T...",
  "revocable": true
}
```

---

### Fase 4: Feed Filtering — Algoritmo locale

**Obiettivo**: il tuo nodo filtra i post in arrivo dagli altri nodi. Come Instagram ma decentralizzato.

#### Architettura del filtro (ispirata a Bluesky AT Protocol)

```
Post in arrivo (da nodi connessi)
         │
         ▼
    ┌────────────┐
    │ Candidate   │  Tutti i post ricevuti (Redis sorted set per timestamp)
    │ Pool        │
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │ Embedding   │  Cosine similarity tra embedding post e embedding interessi utente
    │ Scorer      │  (pgvector: post embedding vs user interest embedding)
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │ Social      │  Boost da: edge strength, interaction history, trust score
    │ Scorer      │
    └─────┬──────┘
          │
          ▼
    ┌────────────┐
    │ Diversity   │  Evita echo chamber: penalizza topic ripetuti, boost topic nuovi
    │ Filter      │
    └─────┬──────┘
          │
          ▼
    Feed ordinato (top-N)
```

Segnali di ranking (da Instagram): P(like), P(save), P(share), P(spend_time). Ma calcolati **localmente** dal tuo nodo, non da un server centrale.

---

### Fase 5: Bridge Outbound — Pubblicare su Social 1.0

**Obiettivo**: i contenuti generati dal tuo nodo vengono cross-postati sui social legacy.

#### Modalità di consenso

| Modalità | Comportamento | Config |
|----------|---------------|--------|
| `consent` (default) | Genera bozza, chiede approvazione prima di postare | `mcp.social.bridge.mode=consent` |
| `auto` | Posta automaticamente senza chiedere | `mcp.social.bridge.mode=auto` |
| `silent` | Non posta mai sui legacy (solo MCP network) | `mcp.social.bridge.mode=silent` |

Per piattaforma: `mcp.social.bridge.instagram.mode=auto`, `mcp.social.bridge.twitter.mode=consent`, etc.

#### Bridge outbound per piattaforma

| Piattaforma | API | Rate limit | Note |
|-------------|-----|------------|------|
| Instagram | Graph API (Business/Creator) | 25 post/giorno | Richiede Facebook Page collegata |
| Twitter/X | Twitter API v2 | 50 tweet/giorno (tier base) | API a pagamento dal 2023 |
| Reddit | Reddit API | 60 req/min | Post su subreddit specifici |
| Tumblr | Tumblr API v2 | Nessun limite esplicito | Post su blog |
| Threads | Threads API (via Meta) | 25 post/giorno | Stessa infra di Instagram |
| Mastodon | ActivityPub / API | Dipende dall'istanza | Nativo fediverse |

---

### Fase 5b: Personal Recommender — Il nodo suggerisce contenuti dal mondo

**Obiettivo**: il nodo MCP funziona come **recommendation engine personale** — cerca nel mondo e ti propone ciò che matcha il tuo KORE. Indipendente dal social network, funziona standalone.

**Insight**: è il tuo Google Discover/Instagram Explore personale, ma l'algoritmo è tuo, il modello di te è esplicito (KORE), e le fonti sono le tue.

#### Architettura

```
Timer (inesorabilità, es. ogni 6h)
    │
    ▼
RecommenderService
    │
    ├─► Estrai top-N topic dal KORE (centralità, recency)
    ├─► Per ogni topic: web_search + web_fetch (SearXNG)
    ├─► Filtra: embedding similarity vs KORE interests
    ├─► Novelty check: skip se già nel KORE o già suggerito
    ├─► Diversity: max 2 suggerimenti per topic
    ├─► Salva in inbox Redis (sorted set, score = relevance)
    └─► Opzionale: ingest in KORE i migliori (auto-enrichment)
```

#### Tre modalità d'uso

| Modalità | Descrizione |
|----------|-------------|
| **Proattivo** | Timer periodico cerca e riempie inbox di suggerimenti |
| **On-demand** | Tool MCP `persona_recommend(topic?, limit?)` cerca al momento |
| **Auto-ingest** | I suggerimenti con score > soglia vengono ingeriti in KORE automaticamente |

#### MCP Tools

| Tool | Descrizione |
|------|-------------|
| `persona_recommend(topic?, limit?, sources?)` | Cerca contenuti rilevanti dal web, filtrati per KORE |
| `persona_inbox(limit?, cursor?)` | Leggi suggerimenti proattivi accumulati |
| `persona_inbox_accept(id)` | Approva suggerimento → ingest in KORE |
| `persona_inbox_dismiss(id)` | Scarta suggerimento (feedback negativo per tuning) |

#### Config

```
mcp.persona.recommender.enabled=true
mcp.persona.recommender.interval-hours=6
mcp.persona.recommender.max-per-run=20
mcp.persona.recommender.auto-ingest-threshold=0.85
mcp.persona.recommender.sources=web,reddit,arxiv,hn
```

---

### Fase 6: OpenNode Protocol — Discovery automatica per similarità

**Obiettivo**: i nodi MCP si scoprono automaticamente in base alla similarità dei loro knowledge graph. Il social graph emerge dal KORE, non da follow manuali.

**Principio**: il social graph E il knowledge graph sono la stessa cosa. Connettersi con un nodo significa scoprire nuova conoscenza.

#### Come funziona

```
        ┌─ KORE ──┐          ┌─ KORE ──┐
        │ Topics  │          │ Topics  │
        │ Papers  │          │ Papers  │
        │ Concepts│          │ Concepts│
        └────┬────┘          └────┬────┘
             │                    │
             ▼                    ▼
      interest vector      interest vector
      (embedding aggregato  (embedding aggregato
       dei top-N Topic)      dei top-N Topic)
             │                    │
             └───► cosine sim ◄───┘
                   > 0.7?
                     │
                     ▼ sì
              auto follow_request
              (bilateral negotiation)
                     │
                     ▼
              EDGE STABILITO
                     │
              ┌──────┴──────┐
              │              │
              ▼              ▼
        Nodo A scopre   Nodo B scopre
        Topic/Concept   Topic/Concept
        di B che non    di A che non
        ha nel KORE     ha nel KORE
              │              │
              ▼              ▼
        KORE A si       KORE B si
        arricchisce     arricchisce
              │              │
              └──────┬──────┘
                     │
              interest vector
              cambia → nuovi
              match → nuovi nodi
              → ciclo autopoietico
```

#### Social Card estesa (OpenNode)

```json
{
  "name": "Massimiliano Pili",
  "interestVector": "base64-encoded-embedding-of-aggregated-topics",
  "topTopics": ["knowledge-graphs", "self-hosting", "economics", "MCP"],
  "koreStats": {"nodes": 50000, "domains": 5},
  "openNode": {
    "autoConnect": true,
    "similarityThreshold": 0.7,
    "maxEdges": 50,
    "exchangePolicy": "topics_only"
  }
}
```

#### Discovery modes

| Modalità | Descrizione |
|----------|-------------|
| **Registry** | Un server centrale (o federato) indicizza le Social Card e suggerisce match |
| **Gossip** | Ogni nodo chiede ai suoi connessi "conosci nodi simili a me?" — DHT-style |
| **Broadcast** | Pubblica la Social Card in community MCP servers → chi matcha propone handshake |

#### Knowledge exchange dopo handshake

Quando due nodi si connettono, scambiano **delta knowledge**:
- A invia a B: "i miei top Topic che tu probabilmente non hai" (anti-entropy, come Merkle tree)
- B valuta: embedding similarity di ogni Topic offerto vs proprio KORE
- B accetta/rifiuta singoli Topic (o auto-accept sopra soglia)
- Il KORE di B si arricchisce → il suo interest vector cambia → nuovi discovery

Questo è il pattern **anti-entropy gossip** delle DHT (Dynamo, Cassandra), applicato alla conoscenza personale.

#### Fondamenti teorici (dalla ricerca)

**Knowledge CRDT** — Applicare Merkle-CRDT (Sanjuan et al. 2020) allo scambio di triple del knowledge graph:
- Ogni tripla (soggetto, predicato, oggetto) è un elemento in un G-Set CRDT
- Merkle tree sulle triple ordinate per delta computation efficiente
- Conflitti: latest-writer-wins o keep-both con provenance metadata

**Curiosity Coefficient** — Parametro adattivo explore/exploit (analogia con temperatura nel modello di Ising):
- Con probabilità (1 - ε): discover per embedding similarity (exploit)
- Con probabilità ε: discover per **massimo delta knowledge** — nodi con meno overlap ma sopra soglia minima (explore)
- ε adattivo: aumenta quando il rate di nuova conoscenza da nodi simili scende sotto soglia (marginal value theorem, Pirolli & Card 1999)
- Sotto ε critico → echo chamber (fase ordinata). Sopra → rumore (fase disordinata). Al punto critico → diversità ottimale

**Echo chamber prevention**: Gross & Blasius (2008) confermano che reti coevolutive adattive esibiscono transizioni di fase. Il Curiosity Coefficient è il meccanismo per navigare al "edge of chaos".

**Nessun prior art completo**: nessun sistema esistente combina KG personali + embedding discovery + anti-entropy exchange + co-evoluzione topologia-conoscenza + autopoiesi. Più vicino: Roth (2005) epistemic networks, Bluesky AT Protocol.

**Ricerca completa**: `/data/massimiliano/docs/research/autopoietic-knowledge-networks.md`
**KORE**: 8 Concept nodes ingeriti (Autopoiesis, Adaptive Coevolutionary Networks, Epistemic Networks, Merkle-CRDT, Information Foraging Theory, Curiosity Coefficient, Homophily, Locality-Sensitive Hashing)

#### MCP Tools (Fase 6)

| Tool | Descrizione |
|------|-------------|
| `opennode_discover(limit?)` | Cerca nodi simili (via registry o gossip) |
| `opennode_similarity(nodeUrl)` | Calcola cosine similarity con un nodo specifico |
| `opennode_exchange(nodeUrl)` | Scambia delta knowledge con un nodo connesso |
| `opennode_auto_connect(enabled, threshold?)` | Abilita/disabilita auto-discovery |

---

### Fase 7: Community MCP Servers (futuro)

**Obiettivo**: MCP server specializzati che fanno da relay/community (pattern Lemmy Group).

Un Community MCP server:
- Non rappresenta una persona, rappresenta un **topic/comunità**
- Riceve post dai membri, li wrappa in un `Announce`, li distribuisce a tutti i follower
- Ha le proprie regole di moderazione e ranking (Wilson score o Preference Sort)
- Chiunque può crearne uno — è un MCP server con le tool `social/announce`, `social/moderate`

---

## Note Architetturali

### KORE come Hub Centrale

```
              ┌──────────────────────────┐
              │          KORE            │
              │   AGE knowledge_graph    │
              │   pgvector embeddings    │
              ├──────────────────────────┤
     INGEST   │                          │  GENERATE
  ────────────►  50K+ nodi               ├──────────►
  Reddit       │  Paper, Author, Book,   │  Profilo emergente
  Instagram    │  Concept, Topic, Venue, │  Post generati
  Tumblr       │  Source, Tag            │  Risposte persona
  arXiv        │                          │  Feed filtrato
  Kindle       │  + SocialPost (nuovo)   │
  HN           │  + SocialEdge (nuovo)   │
              └──────────────────────────┘
```

### Redis DB allocation

| DB | Uso attuale | Uso SocialMCP |
|----|-------------|---------------|
| 5 | Claude messaging | invariato |
| 6 | Web fetch chunks | invariato |
| 8 | (libero) | Persona sessions (1h TTL) |
| 9 | (libero) | Social feed cache + edge state |

### Nuovi nodi AGE (domain="social")

| Label | Proprietà | Relazioni |
|-------|-----------|-----------|
| `SocialPost` | id, content, generated_at, topic, confidence, source_nodes | AUTHORED_BY Person, ABOUT Topic, DERIVED_FROM Concept/Paper/Book |
| `SocialEdge` | id, type (follow/peer/community), established_at, capability_token | CONNECTS Person↔Person, MEMBER_OF Community |
| `SocialProfile` | id, computed_at, bio, interests[], expertise[] | REPRESENTS Person, DERIVED_FROM Topic[] |
| `Bridge` | id, platform, direction (ingest/outbound), mode, last_sync | FEEDS_INTO KORE (ingest), PUBLISHES_FROM SocialPost (outbound) |

---

## Priorità e Sequenza

| Fase | Cosa | Dipende da | Stima |
|------|------|------------|-------|
| **0** | Persona endpoint (whoami + ask + KORE) | — | Prima implementazione |
| **1** | Bridge ingest (Reddit, HN, arXiv esteso) | Fase 0 | Dopo Fase 0 |
| **2** | Content generation + profilo emergente | Fase 0 + 1 | Dopo Fase 1 |
| **3** | Edge negotiation (follow_request/accept) | Fase 0 | Indipendente da 1-2 |
| **4** | Feed filtering (ranking locale) | Fase 3 | Dopo Fase 3 |
| **5a** | Bridge outbound (cross-post a legacy) | Fase 2 | Dopo Fase 2 |
| **5b** | Personal recommender (standalone) | Fase 1 | Indipendente da 3-5a |
| **6** | OpenNode Protocol (auto-discovery per similarità) | Fase 3 + 5b | Dopo network + recommender |
| **7** | Community servers (relay Lemmy-style) | Fase 3 + 4 | Futuro |

### Task Queue

| Task | Ref | Fase | Priorità | Dipende da |
|------|-----|------|----------|------------|
| #238 | `persona-mcp-protocol` | 0 | 3 | — |
| #239 | `socialmcp-bridge-generic` | 1 base | 4 | #238 |
| #240 | `socialmcp-bridge-reddit-hn` | 1 spec | 5 | #239 |
| #241 | `socialmcp-bridge-tumblr-instagram` | 1 spec | 5 | #239 |
| #242 | `socialmcp-content-generation` | 2 | 5 | #238, #239 |
| #243 | `socialmcp-edge-negotiation` | 3 | 5 | #238 |
| #244 | `socialmcp-feed-filtering` | 4 | 6 | #243 |
| #245 | `socialmcp-bridge-outbound` | 5a | 6 | #242 |
| #246 | `socialmcp-recommender` | 5b | 5 | #239 |

Due rami paralleli: **ingestione** (#239→#240/#241→#242→#245) e **network** (#243→#244).
Recommender (#246) è indipendente dal network — serve solo bridge ingest + KORE.
