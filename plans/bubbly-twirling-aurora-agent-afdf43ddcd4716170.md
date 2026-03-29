# Research: Protocol Design Principles for the Persona MCP Protocol

## Research Summary

### Executive Summary

Successful communication protocols share a small set of recurring design principles: simplicity of the core, schema-first capability discovery, progressive complexity through layered extensions, and adoption-friendly ergonomics (good defaults, reference implementations, zero-config bootstrap). The most relevant precedents for a "Persona MCP Protocol" are **ActivityPub** (federated identity + interaction over HTTP), **Google A2A** (agent-to-agent interoperability with Agent Cards for discovery), **MCP itself** (capability negotiation via initialize handshake), and **WebFinger** (lightweight identity resolution via `.well-known`). The analysis below extracts actionable design recommendations from each.

**Epistemic status:** Strong consensus on core principles (drawn from established standards: RFCs, W3C Recommendations, Fielding's dissertation). The agent-to-agent space (A2A, MCP sampling) is still pre-stabilization -- patterns are emerging but not yet battle-tested at scale.

**Confidence:** High for protocol design principles (T1 -- RFCs, dissertations). Medium for agent communication patterns (T7 -- industry specs < 2 years old, no academic replication yet).

---

## 1. Protocol Design Patterns -- Comparative Analysis

### 1.1 REST (Fielding, 2000)

**Source:** Fielding's dissertation, Chapter 5 (T1 -- UC Irvine, 2000). URL: `https://ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm`

Six constraints that made REST the dominant web architecture:

| Constraint | Principle | Relevance to Persona MCP |
|------------|-----------|--------------------------|
| **Client-Server** | Separation of concerns | Persona endpoint is a server; callers are clients |
| **Stateless** | Each request contains all context | Critical -- persona interactions should be self-contained |
| **Cacheable** | Responses declare cacheability | `whoami` responses are highly cacheable; `ask` responses are not |
| **Uniform Interface** | 4 sub-constraints (see below) | THE key lesson -- small verb set, self-describing messages |
| **Layered System** | Intermediaries are invisible | Allows proxies, gateways, load balancers between caller and persona |
| **Code-on-Demand** (optional) | Server can extend client | Could allow persona to send executable instructions (risky) |

**The Uniform Interface** decomposes into:
1. **Identification of resources** -- every persona is a URI
2. **Manipulation through representations** -- JSON payloads describe the persona
3. **Self-descriptive messages** -- each message contains enough metadata to process it
4. **HATEOAS** -- hypermedia as the engine of application state; the response tells you what you can do next

**Key insight for Persona MCP:** HATEOAS is the most violated REST constraint in practice, yet it is the most powerful. If `whoami` returns not just identity data but also *links to available actions* (capabilities, conversation endpoints, scheduling), the protocol becomes self-navigating. This is directly analogous to A2A's Agent Card pattern (see below).

**Lesson:** "The state transfer in Representational State Transfer refers to navigating a state machine using hyperlinks between resources" (T5 -- Two-Bit History, 2020). The persona protocol should model interactions as state transitions, not just RPC calls.

### 1.2 GraphQL (Facebook, 2015)

**Source:** GraphQL specification (T7 -- graphql.org). Relevant principles only.

| Principle | How it works | Relevance |
|-----------|-------------|-----------|
| **Schema-first** | Schema is the contract; introspectable at runtime | Persona capabilities should be introspectable |
| **Client-driven queries** | Client asks for exactly what it needs | Caller should specify what persona info they want |
| **Single endpoint** | One URL, infinite queries | Aligns with MCP's single-endpoint model |
| **Type system** | Strong typing prevents malformed requests | Persona responses need a schema |

**Key insight:** GraphQL's introspection query (`__schema`) lets any client discover the full API at runtime. This is the equivalent of what `whoami` + capability negotiation should provide.

**Lesson:** Schema introspection is more powerful than static documentation. The protocol should allow callers to discover capabilities programmatically.

### 1.3 JSON-RPC 2.0

**Source:** JSON-RPC 2.0 Specification (T7 -- jsonrpc.org).

JSON-RPC is the wire protocol underneath both MCP and A2A. Its virtues:

- **Minimal:** `method`, `params`, `id` -- three fields
- **Transport-agnostic:** works over HTTP, WebSocket, stdio, SSE
- **Bidirectional:** both sides can send requests (crucial for MCP sampling)
- **Batch support:** multiple requests in one message
- **Error codes:** structured error responses with code + message + data

**Key insight:** JSON-RPC's success comes from being *so minimal* that it's almost impossible to get wrong. MCP chose it over REST precisely because it's simpler for tool invocation.

**Lesson for Persona MCP:** Build on JSON-RPC 2.0. Do not invent a new wire format. The protocol's value is in the *semantics* (verbs, capability model), not the *transport*.

### 1.4 MCP (Anthropic, 2024)

**Source:** MCP Specification 2025-11-25 (T7 -- modelcontextprotocol.io). Architecture overview (T7 -- modelcontextprotocol.io/docs/learn/architecture).

MCP's architecture:

```
Host Application
  |-- MCP Client A <--> MCP Server A (tools, resources, prompts)
  |-- MCP Client B <--> MCP Server B
  |-- MCP Client C <--> MCP Server C
```

**Key design decisions:**

| Decision | Rationale | Relevance |
|----------|-----------|-----------|
| **Host-Client-Server** triad | Host manages security; client handles protocol; server exposes capabilities | Persona protocol needs a security boundary |
| **Capability negotiation** | `initialize` handshake declares `capabilities` object | DIRECTLY applicable -- persona handshake should declare supported verbs |
| **Three primitives** | Tools (actions), Resources (read-only context), Prompts (templates) | Persona verbs map to tools; identity maps to resources |
| **JSON-RPC 2.0** | Minimal wire protocol | Inherit this |
| **Sampling** | Server can request LLM completions from client | Enables *persona requesting things from caller* -- powerful |
| **Transport flexibility** | stdio, HTTP+SSE, Streamable HTTP | Persona protocol should be transport-agnostic |

**MCP Capability Negotiation in detail:**

```json
// Client -> Server
{
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "sampling": {},
      "roots": { "listChanged": true }
    },
    "clientInfo": { "name": "Claude", "version": "1.0" }
  }
}

// Server -> Client
{
  "result": {
    "protocolVersion": "2025-11-25",
    "capabilities": {
      "tools": { "listChanged": true },
      "resources": { "subscribe": true },
      "prompts": { "listChanged": true }
    },
    "serverInfo": { "name": "my-server", "version": "1.0" }
  }
}
```

**Key insight:** MCP's capability negotiation is *bilateral* -- both client and server declare what they support. This is superior to one-sided discovery (like OpenAPI, where only the server describes itself).

**Lesson:** The Persona MCP handshake should follow this pattern exactly. Each persona declares what verbs it supports, what topics it can discuss, what availability constraints apply.

### 1.5 ActivityPub (W3C, 2018)

**Source:** W3C Recommendation (T1 -- w3.org/TR/activitypub/). Published 2018-01-23.

ActivityPub is the **closest architectural analog** to what we are building. It defines:

1. **Actors** -- entities with identity (persons, organizations, services)
2. **Inbox** -- where you receive messages (POST to someone's inbox)
3. **Outbox** -- where your messages appear (GET to read history)
4. **Activities** -- typed actions (Create, Follow, Like, Announce, etc.)
5. **Collections** -- ordered/unordered sets of objects

**Actor model:**
```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "type": "Person",
  "id": "https://example.com/users/alice",
  "inbox": "https://example.com/users/alice/inbox",
  "outbox": "https://example.com/users/alice/outbox",
  "preferredUsername": "alice",
  "name": "Alice",
  "summary": "Software engineer interested in distributed systems",
  "publicKey": { ... }
}
```

**Key design decisions:**

| Decision | Rationale | Application to Persona MCP |
|----------|-----------|---------------------------|
| **Actor = URI** | Every person has a canonical URL | Every persona has a canonical MCP endpoint |
| **Inbox/Outbox** | Asymmetric message delivery | `ask` is posting to someone's inbox |
| **Typed activities** | Verbs are first-class (Create, Follow, etc.) | Persona verbs (whoami, ask, schedule, etc.) are first-class |
| **JSON-LD** | Extensible, linked data | Overkill for us -- JSON is sufficient |
| **HTTP Signatures** | Server-to-server auth | Need an auth story for persona-to-persona |
| **WebFinger discovery** | Find actor by handle (`@alice@example.com`) | Discovery mechanism for personas |

**What ActivityPub got right:**
- The actor model is intuitive and maps perfectly to "a person's AI representative"
- Inbox/outbox separation is clean
- Federation works because the protocol is simple enough to implement

**What ActivityPub got wrong (or hard):**
- JSON-LD complexity alienates implementers
- No built-in capability negotiation -- every server must support all activity types
- Authentication is underspecified (HTTP Signatures were never fully standardized)
- No built-in content negotiation or preference signaling

**Key insight:** ActivityPub proves that the actor + inbox model works at scale (Mastodon, ~15M users). But it also shows that underspecifying auth and capability negotiation leads to fragmentation.

### 1.6 Google A2A Protocol (2025)

**Source:** A2A Specification v1.0.0 (T7 -- a2a-protocol.org/latest/specification/). Google Developers Blog announcement (T7 -- April 2025). Donated to Linux Foundation June 2025. IBM's Agent Communication Protocol merged into A2A.

A2A is the **most directly relevant** protocol to Persona MCP. Key concepts:

**Agent Card** (discovery document at `/.well-known/agent.json`):
```json
{
  "name": "Recipe Agent",
  "description": "Helps find and plan recipes",
  "url": "https://example.com/a2a",
  "version": "1.0.0",
  "capabilities": {
    "streaming": true,
    "pushNotifications": true,
    "stateTransitionHistory": true
  },
  "authentication": {
    "schemes": ["Bearer"],
    "credentials": "..."
  },
  "defaultInputModes": ["text", "audio"],
  "defaultOutputModes": ["text", "image"],
  "skills": [
    {
      "id": "recipe-search",
      "name": "Recipe Search",
      "description": "Search for recipes by ingredients",
      "tags": ["cooking", "search"],
      "examples": ["Find me a recipe with chicken and rice"]
    }
  ]
}
```

**Core concepts:**

| Concept | Description | Persona MCP analog |
|---------|-------------|-------------------|
| **Agent Card** | JSON discovery doc at `.well-known/agent.json` | `whoami` response + capability declaration |
| **Task** | Unit of work with lifecycle (submitted -> working -> completed/failed) | Conversation session |
| **Message** | Communication within a task (user or agent role) | Messages within `ask` |
| **Part** | Content within a message (text, file, data, form) | Response format |
| **Artifact** | Output produced by agent during task | Conversation artifacts |
| **Streaming** | SSE for long-running tasks | Streaming `ask` responses |
| **Push Notifications** | Webhook callbacks for async tasks | Async conversation completion |

**A2A Design Principles (stated explicitly in the spec):**

1. **Agentic by design** -- agents are opaque; no shared memory/tools requirement
2. **Built on existing standards** -- HTTP, JSON-RPC, SSE
3. **Security first** -- enterprise-grade auth from day one
4. **Long-running tasks** -- first-class support for async operations
5. **Modality agnostic** -- text, audio, video, forms, iframes

**Key insight:** A2A's Agent Card is essentially our `whoami` response plus capability negotiation rolled into one discoverable document. The `.well-known` convention makes it work without any prior configuration.

**Key insight 2:** A2A v0.3 (July 2025) added gRPC support and signed security cards. The protocol is evolving rapidly, showing that starting with HTTP + JSON and adding complexity later is the right approach.

**Lesson:** The Persona MCP Protocol should adopt the Agent Card pattern. A persona's identity + capabilities + supported interaction modes should all be discoverable at a well-known URL, independent of the MCP handshake.

---

## 2. Capability Negotiation -- Cross-Protocol Analysis

| Protocol | Mechanism | When | Bilateral? | Extensible? |
|----------|-----------|------|-----------|------------|
| **HTTP** | `Accept` / `Content-Type` headers | Per-request | Yes (client proposes, server decides) | Yes (custom media types) |
| **TLS** | ClientHello / ServerHello | Connection setup | Yes | Yes (cipher suites) |
| **MCP** | `initialize` handshake | Session start | Yes (both declare capabilities) | Yes (custom capability keys) |
| **A2A** | Agent Card at `.well-known/agent.json` | Pre-connection discovery | No (server-only declaration) | Yes (skills array) |
| **OAuth2/OIDC** | `.well-known/openid-configuration` | Pre-auth discovery | No (server-only) | Yes (scopes, grant types) |
| **WebFinger** | `/.well-known/webfinger?resource=acct:...` | Pre-connection discovery | No (server-only) | Yes (links with rel types) |
| **XMPP** | XEP-0030 Service Discovery (`disco#info`) | Post-connection query | No (query/response) | Yes (features, identities) |
| **HTTP/2** | SETTINGS frame | Connection setup | Yes (both send SETTINGS) | Yes (custom settings) |

**Synthesis -- The Two-Phase Discovery Pattern:**

The most robust protocols use TWO phases of capability discovery:

1. **Phase 1: Pre-connection discovery** (static, cacheable)
   - A2A: Agent Card at `.well-known/agent.json`
   - OIDC: `.well-known/openid-configuration`
   - WebFinger: `/.well-known/webfinger?resource=...`

2. **Phase 2: Session negotiation** (dynamic, bilateral)
   - MCP: `initialize` handshake
   - TLS: ClientHello/ServerHello
   - HTTP/2: SETTINGS exchange

**Recommendation for Persona MCP:**

Adopt BOTH phases:
- **Phase 1:** A WebFinger-compatible or `.well-known/persona.json` discovery document (static, cacheable, human-readable). This is the equivalent of A2A's Agent Card.
- **Phase 2:** An MCP `initialize`-style handshake that negotiates session-specific capabilities (supported verbs, language preferences, privacy level, response format).

---

## 3. Versioning Strategies

| Protocol | Strategy | Compatibility Guarantee |
|----------|----------|------------------------|
| **HTTP** | Major version in protocol (`HTTP/1.1`, `HTTP/2`) | New major versions are separate protocols |
| **MCP** | Date-based version string (`2025-11-25`) in initialize | Server selects mutually supported version |
| **A2A** | Semantic versioning (`1.0.0`) in Agent Card | Agent card declares version |
| **TLS** | Version negotiation in handshake | Client proposes highest; server selects |
| **GraphQL** | No versioning -- additive changes only | Fields are never removed (deprecated) |
| **Stripe API** | Date-based (`2024-12-18`) + rolling window | Old versions supported for years |

**Key insight:** The most developer-friendly versioning strategy is **additive-only** (GraphQL style) combined with **date-based version strings** (MCP/Stripe style). Never remove fields; deprecate them. Include the version in the handshake, not the URL.

**Recommendation:** Use date-based version strings in the handshake (like MCP). Design the schema to be additive-only. Require backward compatibility for at least one prior version.

---

## 4. Identity Protocols -- Comparison

| Standard | Format | Discovery | Decentralized? | Maturity | Relevance |
|----------|--------|-----------|---------------|----------|-----------|
| **WebFinger (RFC 7033)** | JSON (JRD) | `/.well-known/webfinger?resource=acct:user@host` | Federated (domain-based) | Mature (2013) | HIGH -- simple, proven |
| **vCard/jCard (RFC 6350/7095)** | Text/JSON | Embedded or linked | N/A | Mature | Medium -- data format only |
| **Schema.org Person** | JSON-LD | Embedded in HTML | N/A | Mature | Medium -- SEO-oriented |
| **DID (W3C)** | DID Document (JSON) | DID resolution (method-specific) | Yes (crypto-based) | Emerging (v1.1 in progress) | Low-Medium -- overkill for our use case |
| **ActivityPub Actor** | JSON-LD | WebFinger -> Actor URL | Federated | Mature (2018) | HIGH -- actor model |
| **hCard** | HTML microformat | Embedded in HTML | N/A | Legacy | Low |
| **FOAF** | RDF/XML | Linked data | Partial | Legacy | Low |

**WebFinger (RFC 7033)** is the clear winner for Phase 1 discovery:

```
GET /.well-known/webfinger?resource=acct:alice@example.com HTTP/1.1
Host: example.com

{
  "subject": "acct:alice@example.com",
  "links": [
    {
      "rel": "self",
      "type": "application/activity+json",
      "href": "https://example.com/users/alice"
    },
    {
      "rel": "http://persona-mcp.org/ns/endpoint",
      "type": "application/json",
      "href": "https://example.com/mcp/alice"
    }
  ]
}
```

**Recommendation:** Use WebFinger for initial discovery ("given `alice@example.com`, where is her persona endpoint?") and a custom identity document (inspired by A2A Agent Card + ActivityPub Actor) for the full persona profile.

---

## 5. What Makes Protocols Succeed vs Fail

Based on the research across all protocols studied, here is a synthesis of success/failure factors:

### Success Factors

| Factor | Evidence | Priority for Persona MCP |
|--------|----------|------------------------|
| **Simplicity of core** | HTTP beat SOAP; JSON-RPC beat XML-RPC; REST beat CORBA | CRITICAL -- keep the core tiny (3-5 verbs) |
| **Extensibility without breaking** | HTTP headers, MCP custom capabilities, GraphQL additive schema | CRITICAL -- extension points from day one |
| **Good defaults** | HTTP content types, MCP's default capabilities | HIGH -- `whoami` and `ask` should work with zero config |
| **Reference implementation** | Mastodon for ActivityPub; Claude Desktop for MCP; Google ADK for A2A | HIGH -- ship a reference implementation |
| **Developer experience** | GraphQL Playground, Swagger UI, MCP Inspector | HIGH -- provide tooling |
| **Incremental adoption** | HTTP/2 upgrade mechanism; MCP stdio transport | HIGH -- start with simplest transport |
| **Network effects** | Email, HTTP, ActivityPub/Mastodon | MEDIUM -- initially small network, but design for federation |
| **Standards body backing** | W3C for ActivityPub; Linux Foundation for A2A; IETF for HTTP | MEDIUM -- not needed initially, but plan for it |

### Failure Factors

| Factor | Casualties | Lesson |
|--------|-----------|--------|
| **Overengineering the spec** | SOAP, CORBA, XMPP (partially), JSON-LD in ActivityPub | Do not mandate complex serialization |
| **Underspecifying auth** | ActivityPub (HTTP Signatures mess), early WebSocket | Specify auth from day one |
| **No extensibility path** | FTP, Gopher | Build extension mechanisms into v1 |
| **Vendor lock-in perception** | Google Wave, Facebook Platform API | Open specification + multiple implementations |
| **No backward compatibility** | Python 2->3, HTTP/2 (partially) | Additive changes only |
| **Too many options** | XMPP (380+ XEPs) | Mandate a small core, make everything else optional |

### The "Waist of the Hourglass" Principle

The most successful protocols follow an hourglass architecture (T7 -- well-established CS architecture principle):

```
     Many applications
          |
    [Narrow waist: small, universal protocol]
          |
     Many transports/implementations
```

- IP is the waist of the Internet
- HTTP is the waist of the web
- JSON-RPC could be the waist of agent communication

**Recommendation:** The Persona MCP Protocol should be the "waist" between diverse AI agents above and diverse transport mechanisms below. Keep the waist thin: just `whoami`, `ask`, and capability negotiation.

---

## 6. Agent-to-Agent Communication -- Emerging Patterns

### 6.1 Google A2A (covered in detail above)

The dominant emerging standard. Key takeaway: Agent Card + Task lifecycle + streaming.

### 6.2 MCP Sampling

MCP's sampling capability allows a server to *request LLM completions from the client*. This inverts the typical flow:

```
Normal: Client -> Server: "call this tool"
Sampling: Server -> Client: "generate a completion for this prompt"
```

This is relevant for Persona MCP because it enables *the persona to ask the caller for clarification or information* -- not just respond to queries.

### 6.3 Agent Network Protocol (ANP)

**Source:** agent-network-protocol.com (T7). Uses `did:wba` (Web-based DID) for agent identity. Interesting approach: combines W3C DIDs with web-based resolution. Worth monitoring but not mature enough to adopt.

### 6.4 Academic Literature

From the search results (T2 -- arXiv 2025): "From LLM Reasoning to Autonomous AI Agents: A Comprehensive Review" surveys ~60 benchmarks and multiple agent frameworks (2023-2025). The paper notes the landscape is "fragmented and lacks a unified taxonomy." This validates the need for standardization but also cautions that the space is moving too fast for premature standardization.

**Key academic insight:** Multi-agent communication protocols are converging on three patterns:
1. **Shared workspace** (AutoGen, CrewAI) -- agents share memory/context
2. **Message passing** (A2A, MCP) -- agents send structured messages
3. **Orchestrator-mediated** (LangGraph, agent-framework) -- a central agent routes work

The Persona MCP Protocol falls squarely in category 2 (message passing), which is the most decentralized and federation-friendly.

---

## 7. Serendipitous Connections

### Economics -- Mechanism Design
The capability negotiation problem in protocols is structurally identical to **mechanism design** in economics (T1 -- Myerson, 1981). Each party has private information about their capabilities and preferences. The protocol must elicit truthful revelation of these capabilities. In Persona MCP: a persona that claims capabilities it does not actually support degrades the ecosystem, analogous to adverse selection in insurance markets.

### Graph Theory -- Network Effects
Protocol adoption follows the **Metcalfe's Law** pattern: value proportional to n^2 connections. But the more nuanced model is the **S-curve of adoption** from innovation economics: slow start, rapid growth after critical mass, saturation. For Persona MCP: focus on the first 10 adopters and make the protocol trivially implementable. Network effects will handle the rest IF the core is right.

### Personal Project -- Agent Framework
The `agent-framework` project (multi-agent orchestration, HTN planning) is directly relevant. Persona MCP endpoints could be registered as external agents in the orchestration framework, enabling cross-framework agent collaboration.

---

## 8. Practical Recommendations for Persona MCP Protocol

### 8.1 Architecture

```
Discovery Layer:    WebFinger (.well-known/webfinger)
                         |
                         v
Identity Layer:     Persona Card (.well-known/persona.json)
                    [name, bio, capabilities, endpoint, auth]
                         |
                         v
Session Layer:      MCP initialize handshake
                    [version negotiation, capability refinement]
                         |
                         v
Interaction Layer:  MCP tools (whoami, ask, ...)
                    [JSON-RPC 2.0 over HTTP/SSE/stdio]
```

### 8.2 Core Verbs (keep it minimal)

| Verb | Type | Description | Cacheable? |
|------|------|-------------|-----------|
| `whoami` | Tool | Returns identity + capabilities | Yes (TTL-based) |
| `ask` | Tool | Conversational interaction | No |
| `capabilities` | Resource | Detailed capability manifest | Yes |
| `availability` | Resource | Scheduling/availability info | Yes (short TTL) |

Extension verbs (optional, declared in capability negotiation):
- `schedule` -- book a meeting/interaction
- `delegate` -- forward request to another persona
- `subscribe` -- receive updates
- `verify` -- cryptographic identity verification

### 8.3 Discovery -- Recommended Pattern

Following the two-phase model:

**Phase 1: WebFinger**
```
GET /.well-known/webfinger?resource=acct:alice@example.com
-> Returns link to Persona Card
```

**Phase 2: Persona Card** (inspired by A2A Agent Card)
```json
{
  "name": "Alice's AI Representative",
  "description": "Software engineer, interested in distributed systems",
  "endpoint": "https://example.com/mcp/alice",
  "version": "2026-03-23",
  "capabilities": {
    "verbs": ["whoami", "ask"],
    "streaming": true,
    "languages": ["en", "it"],
    "topics": ["tech", "research", "general"],
    "availability": true
  },
  "authentication": {
    "schemes": ["Bearer", "HMAC"]
  },
  "owner": {
    "name": "Alice Smith",
    "url": "https://alice.example.com"
  }
}
```

### 8.4 Design Principles to Adopt

1. **Build on MCP + JSON-RPC 2.0** -- do not invent a new wire protocol
2. **Bilateral capability negotiation** -- both caller and persona declare capabilities
3. **Additive-only versioning** -- never remove fields, use date-based versions
4. **WebFinger for discovery** -- leverage existing federation infrastructure
5. **Agent Card for identity** -- single discoverable document (like A2A)
6. **Small core, rich extensions** -- 2-3 mandatory verbs, everything else optional
7. **Auth from day one** -- specify Bearer + HMAC at minimum
8. **Transport agnostic** -- HTTP+SSE primary, but stdio/WebSocket possible
9. **Streaming-first for conversations** -- `ask` should support SSE streaming
10. **Opaque agents** -- do not require sharing internal state or prompts

### 8.5 Anti-Patterns to Avoid

1. **No JSON-LD** -- ActivityPub's biggest adoption friction
2. **No mandatory crypto** -- DID/blockchain requirements kill adoption
3. **No global registry** -- federated, not centralized
4. **No kitchen-sink v1** -- resist adding verbs until there are real implementations
5. **No custom serialization** -- JSON only, no protobuf/msgpack in the core

---

## 9. Sources

### Fetched and Read

| Tier | Source | URL | Used for |
|------|--------|-----|----------|
| T1 | Fielding's REST dissertation (2000) | `ics.uci.edu/~fielding/pubs/dissertation/rest_arch_style.htm` | REST constraints, uniform interface |
| T1 | W3C ActivityPub Recommendation (2018) | `w3.org/TR/activitypub/` | Actor model, inbox/outbox, federation |
| T1 | RFC 7033 WebFinger (2013) | `rfc-editor.org/rfc/rfc7033.html` | Discovery protocol |
| T1 | W3C DID v1.0/v1.1 | `w3.org/TR/did-core/` | Decentralized identity |
| T7 | MCP Specification 2025-11-25 | `modelcontextprotocol.io/specification/2025-11-25` | Capability negotiation, architecture |
| T7 | A2A Protocol v1.0.0 Specification | `a2a-protocol.org/latest/specification/` | Agent Card, Task lifecycle |
| T7 | Google A2A announcement blog (2025-04) | `developers.googleblog.com` | Design principles |
| T7 | IBM A2A overview (2025-11) | `ibm.com/think/topics/agent2agent-protocol` | Industry adoption context |
| T7 | A2A Linux Foundation press release (2025-06) | `linuxfoundation.org/press/...` | Governance model |
| T7 | A2A v0.3 upgrade blog (2025-07) | `cloud.google.com/blog/...` | gRPC support, evolution |
| T5 | Two-Bit History: Fielding's REST (2020) | `twobithistory.org/2020/06/28/rest.html` | REST misappropriation analysis |
| T5 | htmx: REST Explained | `htmx.org/essays/rest-explained/` | REST constraint breakdown |
| T7 | Semgrep A2A Security Guide (2025-12) | `semgrep.dev/blog/2025/...` | Security analysis |
| T7 | ActivityPub and WebFinger W3C report (2024) | `w3.org/community/reports/socialcg/CG-FINAL-apwf-20240608/` | WebFinger + ActivityPub integration |
| T7 | Mastodon WebFinger docs | `docs.joinmastodon.org/spec/webfinger/` | Practical WebFinger implementation |
| T7 | MCP GitHub issue #1960 (.well-known/mcp) | `github.com/modelcontextprotocol/.../issues/1960` | MCP discovery proposal |

### Not Found / Not Fetched

- No peer-reviewed academic papers specifically on "AI persona protocol design" were found. The field is too new for T1/T2 sources on this specific topic.
- XMPP XEP-0030 details were not successfully fetched due to search engine rate limiting, but the core concept (query-based feature discovery with `disco#info` IQ stanzas) is well-established.
- FOAF ontology was not fetched -- it is largely deprecated in favor of Schema.org and ActivityPub actors.

---

## Quality Checklist

- [x] At least 2 primary sources (T1) fetched and read (Fielding, ActivityPub W3C Rec, RFC 7033)
- [x] Epistemic status and confidence label included
- [x] Source tier labeled for every key claim
- [x] Open questions addressed (agent-to-agent space is pre-stabilization)
- [x] Serendipitous connections section included (mechanism design, Metcalfe's law, agent-framework project)
- [x] No fabricated citations
- [x] Personal project connection noted (agent-framework)
- [x] Template A structure followed
