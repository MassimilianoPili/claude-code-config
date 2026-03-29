# Research: Federated Social Network on MCP — Architecture Patterns

**Epistemic status:** Synthesis of established architectures (Tumblr, Reddit) + emerging protocols (ActivityPub/Lemmy, A2A, MCP). The "MCP as social substrate" idea is novel — no prior art found.
**Confidence:** High for historical architectures (T5/T7 sources), Medium for federation protocols (official docs), Low/Speculative for MCP social networking (no existing literature).

---

## 1. Tumblr Architecture

### Sources Fetched
- High Scalability, "Tumblr Architecture — 15 Billion Page Views a Month" (2012) (T5)
- Tumblr Engineering, "How Reblogs Work" (2019) (primary source)
- Tumblr Engineering, "How Post Content is Stored on Tumblr" (2021) (primary source)
- Tumblr API v2 documentation (primary source)

### Data Model

**Posts** are the atomic unit. Each post has:
- A globally unique post ID (custom ID generator, not auto-increment — they built a dedicated C service for this)
- A blog owner (the "tumblelog")
- Post type (text, photo, quote, link, chat, audio, video)
- Content stored in **Neue Post Format (NPF)** — a JSON-based block format replacing legacy HTML

**Reblog model** — what makes Tumblr unique:
- A reblog is NOT a reference/pointer. It is a **new post** that contains a **copy** of the content plus a **reblog trail** (the chain of reblogs back to the original).
- Pre-2019: the entire reblog trail was stored as nested HTML within each post — massive data duplication but zero runtime JOINs needed.
- Post-2019 (NPF): the trail is stored as an array of `{blog, content_blocks}` objects. Each reblog still stores a **materialized copy** of the trail, not references.
- Key insight: **denormalization over normalization**. Every post is self-contained. You never need to "resolve" a chain at read time. This is the opposite of a relational approach where you'd store post_id references and JOIN.

**Follow model:**
- Asymmetric (unilateral). User A follows User B. No approval needed. No mutual requirement.
- Following creates a subscription: all of B's posts (and reblogs) appear in A's Dashboard.
- The follower graph is enormous: average user follows hundreds of blogs, and average post fans out to hundreds of followers.

**Dashboard (the feed):**
- 70% of all Tumblr traffic is Dashboard reads.
- Originally scatter-gather: when you load your Dashboard, Tumblr queries all blogs you follow and merges results. This does NOT scale.
- **Cell-based architecture** (the key innovation):
  - Users are hashed into **cells**. A cell is a self-contained unit with its own HBase cluster, Redis cache, and service nodes.
  - **All posts are replicated to all cells** via a Kafka firehose.
  - Each cell stores two HBase tables: (1) a copy of every post, (2) a per-user inbox of post IDs mapping which posts belong in that user's Dashboard.
  - When User A publishes, the post goes to Kafka, all cells consume it, each cell checks if any of its users follow A, and if so writes the post ID into those users' inboxes.
  - Result: Dashboard reads are a single cell query — no cross-cell communication. Spec: 1M writes/sec, 50K reads/sec.
  - Cells are the unit of parallelization, failure isolation, and rolling upgrades.

**Scale numbers (2012):**
- 500M page views/day, ~40K req/sec peak
- Posts: ~50GB/day. Follower list updates: **2.7TB/day**
- Dashboard: 1M writes/sec, 50K reads/sec
- 1000+ servers, 200 DB servers (47 pools, 30 shards)

### Tumblr + ActivityPub

Tumblr announced ActivityPub support in late 2022. As of March 2026, it remains extremely limited:
- Individual blogs can opt-in to be discoverable from the fediverse
- Follows from Mastodon work in one direction
- The implementation is incomplete — no reblog federation, no federated replies that work well
- Recent (March 2026) controversy: Tumblr tried changing reblog chains to be more Twitter-like (each reblog gets its own note count) — reversed within 24 hours after user backlash. This shows how central the reblog chain model is to Tumblr's identity.

### What's Relevant for MCP Social

| Pattern | Lesson |
|---------|--------|
| **Denormalized content** | Each node should store self-contained posts, not references. In MCP context: when you reblog/share, send the full content, not a pointer. |
| **Cell architecture** | Partition users into cells. Each MCP server could BE a cell — self-contained with all data for its users. |
| **Firehose replication** | All cells consume all posts. Analogous to MCP servers subscribing to each other's event streams. |
| **Inbox model** | Pre-compute "what should user X see" rather than scatter-gather at read time. Each MCP server maintains inboxes for its users. |
| **Asymmetric follow** | Simple, proven. But for MCP you might want bilateral negotiation (see section 4). |

---

## 2. Reddit Architecture

### Sources Fetched
- Amir Salihefendic, "How Reddit ranking algorithms work" (2015/2016, Medium) (T5)
- Lemmy federation documentation (official docs, primary source)
- Wikipedia: Reddit (T7 background)

### Data Model

**Subreddits** are the organizational unit (unlike Tumblr's blog-centric model):
- A subreddit is a topic-based community with its own rules, moderators, and subscriber list
- Users subscribe to subreddits (not to other users — though user profiles exist)
- Posts belong to exactly one subreddit
- Comments form a tree under each post

**Relationships:**
- User -> Subreddit: subscription (unilateral, no approval for public subreddits)
- User -> Post: author, upvote, downvote, save
- User -> Comment: author, upvote, downvote
- Post -> Subreddit: belongs_to (exactly one)
- Comment -> Post: belongs_to
- Comment -> Comment: reply_to (tree structure)

### Ranking Algorithms

Reddit uses two distinct algorithms:

**1. Story Ranking (Hot)** — Wilson-like time decay:
```
score = log10(max(|ups - downs|, 1)) + (sign(ups - downs) * seconds_since_epoch) / 45000
```
Key properties:
- Logarithmic: the first 10 upvotes matter as much as the next 100
- Time-weighted: newer posts get a boost via the epoch term
- The sign function means downvoted content gets actively buried
- Submission time is fixed — you can't "revive" an old post by upvoting it later

**2. Comment Ranking (Best)** — Wilson score confidence interval:
- Uses the lower bound of a Wilson score confidence interval for a Bernoulli parameter
- Given n ratings, p_hat = upvotes/total, the score is:
  `(p_hat + z^2/(2n) - z*sqrt((p_hat*(1-p_hat) + z^2/(4n))/n)) / (1 + z^2/n)`
- Where z = 1.96 (95% confidence)
- This correctly handles "1 upvote, 0 downvotes" vs "100 upvotes, 1 downvote" — the latter ranks higher because we have more confidence in its quality
- Xkcd's Randall Munroe wrote the blog post that convinced Reddit to adopt this

### Content Distribution

- **Push model** for subscriptions: when you load your home feed, Reddit aggregates posts from your subscribed subreddits, ranks them, and returns the top N
- **r/all** and **r/popular**: global aggregations with per-subreddit normalization to prevent a few large subreddits from dominating
- **No user-to-user follow** historically (added much later, never central to the model)

### Lemmy: Federated Reddit via ActivityPub

Lemmy is the most complete federated Reddit alternative. Its federation model is extremely well-documented and directly relevant.

**ActivityPub Mapping:**

| Lemmy Concept | ActivityPub Type | Role |
|---------------|-----------------|------|
| Community | `Group` | Automated actor that receives and distributes posts |
| User | `Person` | Creates content, follows communities |
| Post | `Page` | Belongs to exactly one community |
| Comment | `Note` | Reply to a post or another comment (tree via `inReplyTo`) |
| Instance | `Application` | Represents the entire server |

**The Community-as-Relay pattern (critical for MCP design):**
1. User on Instance A creates a post addressed `to` Community on Instance B
2. Community B receives the `Create/Page` activity
3. Community B wraps it in an `Announce` activity and sends it to ALL followers
4. Followers can be on Instance A, B, C, D... — they all receive the post
5. The Community actor is an **automated relay** — it doesn't create content, it amplifies/distributes

This is essentially **pub/sub with the Community as the topic/channel**.

**Federation Activities:**
- `Follow` / `Undo/Follow`: user subscribes to a community (auto-accepted with `Accept/Follow`)
- `Create/Page`, `Create/Note`: new post or comment
- `Like`, `Dislike`, `Undo/Like`: voting
- `Delete`, `Remove`: content moderation
- `Add` / `Remove` (to featured collection): pinning posts
- `Block`: instance-level or user-level blocking

**Key architectural decisions:**
- Each instance stores a LOCAL COPY of all federated content it has seen (similar to Tumblr's cell model!)
- Votes are federated — they propagate to the origin instance
- Community moderators can be on different instances than the community itself
- Private messages use `ChatMessage` type, user-to-user only
- Follower lists expose only the COUNT, not individual followers (privacy)

### What's Relevant for MCP Social

| Pattern | Lesson |
|---------|--------|
| **Community-as-Group actor** | An MCP server could act as a "community" — an automated relay that receives content and fans it out to subscribers |
| **Announce wrapping** | When distributing content, the community wraps the original activity. MCP servers could similarly wrap/endorse content they relay |
| **Local copies everywhere** | Each Lemmy instance stores everything it has seen. MCP servers should maintain local state, not depend on remote queries |
| **Wilson score for ranking** | Applicable for any voting/ranking in the MCP social network |
| **Federated moderation** | Moderators on different servers — possible via MCP tool calls for moderation actions |

---

## 3. OpenClaw

### Search Results

**"OpenClaw" does not exist** as a social protocol, federation framework, or networking standard. Exhaustive search across general web, Docker Hub, npm, and academic databases returned zero relevant results. The closest matches were:
- OpenClaw: an open-source reimplementation of the game "Captain Claw" (2D platformer) — completely unrelated
- No protocol, API, or social framework by this name

### OpenSocial (likely what was meant)

**OpenSocial** was Google's 2007 attempt at a common API for social networks. Key facts (T7 — Wikipedia):

- Launched 2007 by Google, joined by MySpace, Yahoo, LinkedIn, and others
- Defined a **common API** for social network gadgets/widgets: people, activities, persistence
- Three core APIs:
  1. **People API**: access user profiles and friend lists
  2. **Activities API**: read/write social activity streams
  3. **Persistence API**: key-value storage for app data
- Used REST/JSON-RPC over HTTP
- **Transferred to W3C** in 2014 as the "W3C Social Web Working Group" — which eventually produced **ActivityPub** (the W3C Recommendation that powers Mastodon, Lemmy, etc.)
- OpenSocial itself is **effectively dead** as a standard, but its DNA lives on in ActivityPub

**The lineage is important:** OpenSocial (2007) -> W3C Social Web WG (2014) -> ActivityPub (2018 W3C Rec). The core idea — a standard API for social interactions across platforms — succeeded, just not as OpenSocial.

### What's Relevant for MCP Social

| Pattern | Lesson |
|---------|--------|
| **Standard API for social ops** | OpenSocial tried to standardize people/activities/persistence across platforms. MCP already has a standard protocol — the opportunity is to define social-specific tools/resources |
| **Widget/gadget model failed** | The embed-a-widget approach was too limiting. Full federation (ActivityPub) worked better. MCP should go for full server-to-server communication, not embedded widgets |
| **OpenSocial -> ActivityPub lineage** | The W3C social standards evolution shows that simpler protocols win. MCP's JSON-RPC is already simpler than ActivityPub's JSON-LD |

---

## 4. Edge Negotiation in Social Graphs

### Sources Fetched
- Google Scholar: SybilGuard, DeSocial, trust negotiation papers (T1/T2)
- Solid Protocol specification (primary source)
- Solid Project "About" page (primary source)

### BGP Peering as Analogy

BGP (Border Gateway Protocol) is the most successful example of bilateral edge negotiation at scale:

- Two autonomous systems (AS) must **both agree** to peer before exchanging routes
- Peering involves explicit configuration on both sides (or Route Server mediation at IXPs)
- Three types of relationships: **customer-provider** (paid, asymmetric), **peer-peer** (mutual, free), **sibling** (same organization)
- Trust is established via: (1) contractual agreement, (2) IP prefix filtering, (3) RPKI/ROA for cryptographic route origin validation
- **BGP communities** allow tagging routes with metadata about their intended distribution

**Mapping to social graphs:**
- AS = MCP server (or user's personal server)
- Peering session = social connection (follow/friend)
- Route announcements = content distribution
- BGP communities = content tagging/scoping (who should see this)
- RPKI = cryptographic identity verification
- The **bilateral agreement** requirement is exactly what makes BGP different from Tumblr's unilateral follow

### Automated Trust Negotiation (ATN)

ATN is an academic protocol family for establishing trust between strangers by incrementally disclosing credentials:

- Core idea: instead of "I trust you or I don't," parties iteratively exchange **credentials** (signed assertions about attributes) until enough trust is established
- Each party has an **access control policy** that specifies which credentials are needed to access which resources, AND which credentials are needed before they'll disclose their own credentials
- This creates a **negotiation loop**: "I'll show you my university affiliation if you show me your security clearance"
- Key papers: Winsborough et al. (2000), Yu & Winslett (2003) — "Automated trust negotiation" (T1 — IEEE S&P, ACM TISSEC)
- **Privacy-preserving**: you only disclose what's needed, not your entire identity

**Mapping to social graphs:**
- Follow request = initiate trust negotiation
- Credentials = proof of membership, reputation score, mutual connections
- Policy = "I accept follows from accounts older than 30 days with at least N mutual connections"
- Negotiation = automated back-and-forth via MCP tool calls

### Capability-Based Security (OCAP)

Object-capability model — relevant for fine-grained access control in federated social networks:

- A **capability** is an unforgeable token that grants specific access rights
- Unlike ACLs (where the resource decides who gets in), capabilities are **held by the accessor** and presented on use
- **Delegation**: capabilities can be attenuated and passed on. If I have read+write, I can create a read-only capability and give it to you
- Used in: Solid (via WAC/ACP), E programming language, Cap'n Proto RPC

**Mapping to social graphs:**
- When MCP Server A follows Server B, B issues a capability token to A
- This token grants specific access: "read public posts," "read friends-only posts," "post to my community"
- A can delegate attenuated capabilities to its users
- Revocation: B can revoke the capability at any time

### Solid (Tim Berners-Lee)

Solid is the most developed decentralized social data project:

- Users store data in **Pods** (Personal Online Data stores) — they own their data
- Applications request access to specific Pod data via standard protocols
- Built on: HTTP, Linked Data (RDF), WebID (decentralized identity), WAC (Web Access Control)
- **Solid Protocol** (W3C specification):
  - Pods are HTTP servers implementing LDP (Linked Data Platform)
  - Resources are identified by URLs
  - Access control via ACL resources (who can read/write/append)
  - Authentication via Solid-OIDC (OpenID Connect profile)
  - Data format: RDF (Turtle, JSON-LD, etc.)

**Key Solid concepts for MCP social:**
- **Data sovereignty**: users control their data, not the platform
- **Interoperability**: any app can read/write data if authorized
- **Shape validation**: SHACL/ShEx shapes define expected data structures (like schemas)

### WebID / FOAF+SSL (Historical)

- **FOAF** (Friend of a Friend): RDF vocabulary for describing people and relationships
- **WebID**: a URL that identifies a person, resolvable to an RDF document
- **WebID-TLS**: authentication by presenting a TLS client certificate whose URI matches a WebID
- Largely superseded by Solid-OIDC, but the WebID concept persists in Solid

### What's Relevant for MCP Social

| Pattern | Lesson |
|---------|--------|
| **BGP bilateral peering** | The strongest analogy. MCP servers negotiate edges the way ASes negotiate peering. Both sides must agree. |
| **ATN credential exchange** | Follow requests become trust negotiations. MCP tool calls exchange credentials iteratively. |
| **Capability tokens** | When a connection is established, issue a capability token granting specific access levels. |
| **Solid's data sovereignty** | Each MCP server owns its data. Other servers get delegated access, not copies (contrast with Tumblr/Lemmy's full replication). |
| **WebID** | Each MCP server or user needs a resolvable identity URL — the MCP endpoint itself could serve this role. |

---

## 5. MCP as Social Substrate

### Sources Fetched
- MCP Specification 2025-03-26 (official, modelcontextprotocol.io)
- Google A2A Protocol README (github.com/google/A2A, primary source)
- Various searches for "MCP social", "MCP federation" — **no prior art found**

### Current MCP Architecture (2025-03-26 spec)

MCP is a client-server protocol:
- **Transport**: JSON-RPC 2.0 over stdio, HTTP+SSE, or Streamable HTTP
- **Primitives**: Tools (functions the server exposes), Resources (data the server exposes), Prompts (templates)
- **Session lifecycle**: initialize -> notifications/initialized -> normal operation -> shutdown
- **Authentication**: delegated to transport layer (no built-in auth)
- **One-way**: a client connects to a server. There is NO server-to-server communication in the spec.
- **Stateful sessions**: the connection maintains state (capabilities, subscriptions)

**What MCP has that's useful for social networking:**
1. **Tool calls** — a standardized way for one party to invoke operations on another
2. **Resources** — a standardized way to expose and subscribe to data
3. **Notifications** — server can push updates to connected clients
4. **Capability negotiation** — during initialization, client and server exchange supported capabilities
5. **JSON-RPC** — simple, well-understood transport

**What MCP lacks for social networking:**
1. **No server-to-server** — MCP is client->server only. Social networking requires peer-to-peer or server-to-server.
2. **No identity** — no built-in concept of "who is this server" or "who is this user"
3. **No content addressing** — no URIs for individual pieces of content
4. **No federation** — no mechanism for servers to discover, connect to, or relay content from other servers
5. **No persistence** — MCP sessions are ephemeral

### Google A2A (Agent-to-Agent) Protocol

A2A fills exactly the gap MCP leaves — agent-to-agent communication:

- **Transport**: JSON-RPC 2.0 over HTTP(S) — same as MCP
- **Agent Cards**: JSON documents at `/.well-known/agent.json` describing capabilities, supported content types, authentication requirements — **this is the discovery mechanism MCP lacks**
- **Key differences from MCP:**
  - A2A is **peer-to-peer** (any agent can talk to any agent)
  - A2A has **Tasks** as first-class objects (with lifecycle: submitted -> working -> completed/failed)
  - A2A supports **push notifications** via webhooks
  - A2A explicitly handles **opaque agents** — you don't need to know internal state
  - A2A has **Parts** (text, file, data) as structured content types

- **A2A + MCP relationship** (from Google's docs): "A2A complements MCP. MCP handles tool integration (agent-to-tool), A2A handles agent collaboration (agent-to-agent)."

**Agent Card example:**
```json
{
  "name": "Recipe Agent",
  "description": "Helps with recipes",
  "url": "https://recipe-agent.example.com",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true
  },
  "authentication": {
    "schemes": ["OAuth2"]
  },
  "skills": [
    {
      "id": "recipe-search",
      "name": "Search Recipes",
      "description": "Find recipes by ingredients"
    }
  ]
}
```

### Has Anyone Proposed MCP for Social Networking?

**No.** Exhaustive search found zero proposals, blog posts, academic papers, or forum discussions about using MCP (Anthropic's Model Context Protocol) as a social networking substrate. This appears to be a genuinely novel idea.

The closest concepts found:
1. **A2A** — agent networks, but focused on task collaboration, not social graph
2. **ActivityPub** — the established social federation protocol, but not MCP-based
3. **ActivityPods** (found on Docker Hub) — combines ActivityPub with Solid Pods, but not MCP
4. **MCP Reddit tool** (Docker Hub: `mcp-reddit`) — an MCP server that provides tools to interact with Reddit's API, not a federated social network

### Proposed Architecture: MCP Social Protocol

Based on this research, here is a synthesis of how a federated social network could work with MCP servers negotiating edges:

#### Layer 1: Identity & Discovery (from A2A)
- Each MCP server publishes a **Social Card** at `/.well-known/social.json`
- Contains: server name, description, public key, supported content types, follow policy, capabilities
- Discovery via DNS, well-known URIs, or a registry

#### Layer 2: Edge Negotiation (from BGP + ATN)
- Server A wants to follow Server B
- A calls B's `social/follow_request` tool with A's Social Card and any credentials
- B evaluates against its policy (automated trust negotiation)
- B responds with `Accept` (+ capability token) or `Reject` or `NeedCredential` (requesting more info)
- If accepted, both servers store the edge. This is **bilateral** — both sides have explicitly agreed
- Edge metadata: relationship type (follow, peer, community-member), permissions (read-public, read-friends, post, moderate)

#### Layer 3: Content Distribution (from Tumblr cells + Lemmy federation)
Two models possible:

**A. Inbox/Push model (Tumblr-like):**
- When Server A publishes content, it pushes to all connected servers' inboxes
- Each server stores a local copy (denormalized, self-contained)
- Reads are local — no cross-server queries
- Pro: fast reads, offline-resilient. Con: storage cost, consistency lag

**B. Subscription/Pull model:**
- Servers subscribe to each other's resource streams (MCP resource subscriptions)
- Content stays on the origin server
- Reads require cross-server queries
- Pro: data sovereignty, less storage. Con: latency, availability dependency

**C. Hybrid (recommended):**
- Public content: push to connected servers (Tumblr model)
- Private/restricted content: pull on demand with capability tokens (Solid model)
- Community content: relay through community MCP servers (Lemmy Group model)

#### Layer 4: Content Model (from Tumblr NPF + ActivityPub)
```json
{
  "id": "https://server-a.example/posts/12345",
  "type": "Post",
  "author": "https://server-a.example/.well-known/social.json",
  "content": [
    {"type": "text", "text": "Hello federated world"},
    {"type": "image", "url": "https://server-a.example/media/abc.jpg"}
  ],
  "published": "2026-03-23T10:00:00Z",
  "audience": "public",
  "reblog_of": null,
  "signature": "..."
}
```

#### Layer 5: Social Operations as MCP Tools

| Tool | Direction | Description |
|------|-----------|-------------|
| `social/follow_request` | A -> B | Initiate edge negotiation |
| `social/follow_accept` | B -> A | Accept with capability token |
| `social/follow_reject` | B -> A | Reject with reason |
| `social/unfollow` | A -> B | Tear down edge |
| `social/post` | A -> followers | Publish content to inbox |
| `social/reblog` | A -> origin + followers | Reblog with trail (Tumblr-style) |
| `social/react` | A -> origin | Like/vote (Lemmy-style) |
| `social/reply` | A -> origin + community | Threaded reply |
| `social/announce` | Community -> followers | Relay content (Lemmy Group pattern) |
| `social/moderate` | Mod -> Community | Remove/ban/pin |

#### Layer 6: Community Servers (from Lemmy)
- A Community MCP server is a specialized server that acts as a relay
- Users follow the community server
- When a user posts to the community, the community server wraps it in an `Announce` and pushes to all followers
- Community servers have their own moderation policies, ranking algorithms, and rules
- Multiple community servers can exist for the same topic — users choose which to subscribe to

---

## Serendipitous Connections

### MCP Social <-> Agent Framework (personal project)
The Agent Framework project already has multi-agent orchestration, task graphs, and inter-agent communication. A social network of MCP servers is essentially a **multi-agent system where the agents are social actors**. The task_graph in AGE could model social interactions. The agent-to-agent communication patterns being developed for the Agent Framework are directly applicable.

### BGP + Social Graphs <-> Network Economics (econ)
BGP peering decisions are fundamentally economic — who pays whom, what traffic ratios are acceptable. Social graph edge negotiation has the same structure: what value does each party get from the connection? This connects to **two-sided market theory** (Rochet & Tirole, 2003, T1 — JPE) and **network effects** (Katz & Shapiro, 1985, T1 — AER).

### Tumblr Cell Architecture <-> Consistent Hashing (CS)
Tumblr's cell-based architecture, where users are hashed to cells and all posts are replicated to all cells, is structurally similar to **consistent hashing with full replication** — a pattern used in distributed databases like DynamoDB. The tradeoff (replicate everything vs. query on demand) maps directly to the CAP theorem applied to social feeds.

### Wilson Score <-> Preference Sort (personal project)
Reddit's Wilson score confidence interval for comment ranking is mathematically related to the Bradley-Terry model used in the Preference Sort project. Both are trying to estimate a "true quality" from pairwise comparisons (upvote/downvote is a binary comparison). The Preference Sort could serve as a more sophisticated ranking mechanism for an MCP social network.

### Capability Tokens <-> DSS Wrapper (personal project)
The capability-based security model for edge permissions connects directly to the DSS Wrapper project's work on digital signatures and certificate validation. Capability tokens for social edges could be implemented as signed assertions (CAdES/JAdES format).

---

## Summary of Key Architectural Decisions

| Decision | Option A | Option B | Recommendation |
|----------|----------|----------|----------------|
| **Edge model** | Unilateral (Tumblr follow) | Bilateral (BGP peering) | **Bilateral** — both servers must agree. Novel, differentiating. |
| **Content distribution** | Push/inbox (Tumblr) | Pull/subscription | **Hybrid** — push public, pull private |
| **Content storage** | Full replication (Tumblr/Lemmy) | Origin-only (Solid) | **Full replication for public** — resilience + speed |
| **Identity** | Centralized registry | Self-sovereign (WebID/DID) | **Self-sovereign** — Social Card at well-known URL |
| **Community model** | Subreddit (single authority) | Lemmy Group (federated relay) | **Federated relay** — Community MCP server pattern |
| **Ranking** | Chronological (Tumblr) | Algorithmic (Reddit) | **Both** — let each server/community choose |
| **Protocol base** | ActivityPub | MCP + A2A concepts | **MCP** with A2A-inspired discovery. Simpler than ActivityPub's JSON-LD. |
| **Reblog model** | Pointer/reference | Materialized copy (Tumblr) | **Materialized copy** with cryptographic trail |

---

## Sources

| Source | Tier | Used For |
|--------|------|----------|
| High Scalability: Tumblr Architecture (2012) | T5 | Cell architecture, scale numbers |
| Tumblr Engineering: How Reblogs Work (2019) | Primary | Reblog data model, NPF format |
| Tumblr Engineering: Post Content Storage (2021) | Primary | Storage model evolution |
| Lemmy Federation Documentation | Primary | ActivityPub implementation details, JSON examples |
| Google A2A Protocol README | Primary | Agent discovery, Agent Cards, A2A vs MCP |
| Solid Protocol specification | Primary | Pod architecture, access control |
| Solid Project: About | Primary | Data sovereignty concepts |
| Amir Salihefendic: Reddit ranking (2015) | T5 | Hot ranking, Wilson score formulas |
| Wikipedia: OpenSocial | T7 | Historical context, OpenSocial->ActivityPub lineage |
| Wikipedia: Tumblr | T7 | Recent reblog controversy (March 2026) |
| Winsborough et al.: ATN (2000) | T1 (not directly fetched, from training data) | Trust negotiation protocol concepts |
| Katz & Shapiro: Network Effects (1985) | T1 (not directly fetched) | Two-sided market theory |

**Not found / No prior art:**
- "OpenClaw" as a protocol or framework — does not exist
- MCP used as social networking substrate — no prior proposals found
- MCP server-to-server federation — not in the spec, not proposed anywhere

---

## What to Read/Build Next

1. **A2A specification** (https://a2a-protocol.org) — the Agent Card discovery mechanism is the closest thing to what MCP Social needs for server discovery
2. **Lemmy's activitypub-federation Rust library** (https://github.com/LemmyNet/activitypub-federation-rust) — proven federation primitives that could inspire MCP federation
3. **FEP-1b12: Group Federation** (https://codeberg.org/fediverse/fep/src/branch/main/feps/fep-1b12.md) — the Fediverse Enhancement Proposal that defines how Group actors work across instances
4. **Prototype**: implement `social/follow_request` and `social/follow_accept` as MCP tools on simoge-mcp, with two MCP server instances negotiating an edge
