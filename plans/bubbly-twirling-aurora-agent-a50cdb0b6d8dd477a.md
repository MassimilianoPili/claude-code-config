# Research: Instagram Architecture, Algorithmic Feeds, and Decentralized Social Network Design

## Research Summary

### Executive Summary

Instagram's recommendation system is a multi-stage ML pipeline that ranks content across four distinct surfaces (Feed, Stories, Explore, Reels), each with its own ranking model but sharing common signal categories: relationship strength, user interest, content popularity, and recency. The transition from chronological to algorithmic feed (2016) was driven by the observation that users missed ~70% of posts. For a decentralized social network where each node filters locally, the most relevant architectural parallels come from **Bluesky's AT Protocol** (where feed generators are modular, independently operated components consuming a firehose stream) and **Mastodon's federated curation** (where users navigate trade-offs between ML-based and rule-based filtering).

**Epistemic status:** Mixed -- Instagram's internal architecture is partially disclosed via engineering blogs and Adam Mosseri's transparency posts (T7 quality, corporate self-disclosure); academic validation comes from the Edelson/Haugen comparative survey (T1 -- ACM TORS 2025) and several peer-reviewed studies on Bluesky/Mastodon. AI content generation and cross-posting tools are commercially documented but academically understudied.

**Confidence:** Medium -- Instagram's own disclosures are deliberately vague about model internals; Bluesky/Mastodon research is peer-reviewed but recent.

---

## 1. Instagram's Feed Algorithm

### 1.1 The Chronological-to-Algorithmic Transition (2016)

In March 2016, Instagram announced the shift from reverse-chronological to algorithmic feed ordering. The stated rationale was that users were missing an average of 70% of posts in their feed, including roughly half of posts from close connections (T7 -- Instagram blog, "See the Moments You Care About First," March 2016). The transition was gradual: Instagram ran A/B tests throughout 2016 before fully rolling out the algorithmic feed.

**Key context:** At the time of the switch, Instagram had ~400M monthly active users and the volume of content had grown to the point where chronological ordering was no longer surfacing the most relevant content. This mirrors the same problem Facebook faced with News Feed in 2009-2011.

### 1.2 How Instagram Ranks Content Today (per Mosseri 2021-2024 disclosures)

Adam Mosseri, Head of Instagram, has published multiple transparency posts explaining the algorithm. According to these disclosures (T7 -- Instagram blog):

**Instagram does NOT have one algorithm.** It uses distinct ranking systems for each surface:

| Surface | Primary signals | Ranking approach |
|---------|----------------|-----------------|
| **Feed** | Relationship strength, interest, recency, popularity | Multi-objective ranking model |
| **Stories** | Relationship (heavily weighted), viewing history, closeness | Relationship-first ranking |
| **Explore** | Content popularity, user interest history, author info | Discovery-optimized (content from non-followed accounts) |
| **Reels** | Entertainment value, relevance, recency, author activity | Engagement-prediction model (completion rate, likes, shares) |

### 1.3 Signal Categories (Five Key Signal Groups)

From Mosseri's disclosures and the Edelson/Haugen 2025 comparative survey:

1. **Information about the post** -- when it was posted, how many likes, content type (photo/video/carousel), duration (for video), location tags, hashtags

2. **Information about the author** -- how often the user has interacted with this author recently (likes, comments, DMs, profile visits), relationship closeness indicators

3. **User activity** -- what content the user has liked, saved, commented on, shared; how long they spend on different content types; what they search for

4. **User-author interaction history** -- whether they comment on each other's posts, whether they are tagged together, DM frequency, story reply history

5. **Predicted actions** -- the model predicts the probability that the user will perform several actions on each candidate post:
   - P(spend time) -- will the user pause on this post?
   - P(like) -- will the user like it?
   - P(comment) -- will the user comment?
   - P(save) -- will the user save it?
   - P(share) -- will the user share it?
   - P(tap profile) -- will the user visit the author's profile?

These predicted probabilities are combined using a weighted sum (the weights reflect Instagram's value judgment about which engagement types matter most). Mosseri has stated that **saves and shares are weighted more heavily than likes** in the ranking formula.

### 1.4 Negative Signals and Demotion

Instagram also applies demotion signals:
- Content that violates Recommendation Guidelines (but doesn't violate Community Guidelines)
- Posts reported as "not interested"
- Content from accounts the user has muted
- Borderline content (near-nudity, violence, misinformation)
- Content flagged by third-party fact-checkers
- Posts with engagement patterns suggesting manipulation (bot likes, comment pods)

### 1.5 Relevance to Decentralized Architecture

**Key insight for your project:** Instagram's approach is fundamentally a **multi-objective optimization problem** where the ranking function combines predicted engagement probabilities using platform-chosen weights. In a decentralized network, the critical design decision is: **who controls these weights?**

Options for decentralized feed ranking:
- **User-controlled weights** (Bluesky's approach -- see Section 3)
- **Community-chosen weights** (federated instances set shared policies)
- **Algorithmic defaults with user overrides** (hybrid approach)

---

## 2. Instagram's Ranking Model: ML Architecture

### 2.1 Known Technical Details

Meta has not published a single paper titled "Instagram's ranking system," but the architecture can be reconstructed from several sources:

**Multi-stage retrieval-and-ranking pipeline** (standard across Meta products):

```
Stage 1: CANDIDATE GENERATION (retrieval)
  - For Feed: all posts from followed accounts (last N days)
  - For Explore: embedding-based retrieval from ~billions of posts
  - Two-tower neural network for initial retrieval
  - Output: ~1000 candidate posts

Stage 2: FIRST-PASS RANKING (lightweight model)
  - Fast neural network (fewer features)
  - Scores all ~1000 candidates
  - Output: top ~500

Stage 3: FINAL RANKING (heavy model)
  - Deep neural network with full feature set
  - Multi-task learning: predicts P(like), P(comment), P(save), P(share), etc.
  - Combines predictions via weighted objective function
  - Output: ordered list

Stage 4: POST-RANKING RULES
  - Diversity injection (avoid showing 5 posts from same author consecutively)
  - Content-type mixing (photos, videos, carousels, ads)
  - Demotion rules (borderline content, reported content)
  - Business rules (ad insertion, suggested posts quota)
```

### 2.2 Evidence from Meta Engineering Publications

**Que2Search** (Liu et al., KDD 2021) -- describes Meta's two-tower architecture for Facebook Marketplace's embedding-based retrieval, using Gradient Blending across towers. This is the same architectural pattern used across Meta products including Instagram. (T1 -- KDD 2021, ~N cit S2)

**Multi-stage recommender tradeoffs** (Evnine et al., KDD 2024) -- "Achieving a better tradeoff in multi-stage recommender systems through personalization" -- describes the retrieval -> early-stage ranking -> late-stage ranking pipeline used at Meta, with two-tower networks for retrieval and personalized stage selection. (T1 -- KDD 2024)

**Fairness in compositional recommender systems** (Hsu et al., ICML 2025 workshop) -- from Meta, describes how fairness issues manifest differently across retrieval, ranking, and serving layers in compositional recommender systems (the kind Instagram uses). Notes that embedding quality disparities in the retrieval stage can be a significant driver of utility gaps. (T1 -- ICML 2025)

### 2.3 Feature Extraction

**Image analysis:** Meta uses internal computer vision models (descendants of ResNet/ViT trained on billions of Instagram images) to extract:
- Visual embeddings (content similarity)
- Object detection (what's in the image)
- Scene classification (indoor, outdoor, food, travel, etc.)
- Aesthetic quality scores
- OCR on text in images

**NLP on captions:** Transformer-based models extract:
- Topic embeddings
- Sentiment
- Entity recognition (people, places, brands)
- Hashtag semantics (not just string matching -- semantic similarity between hashtags)

**Social graph signals:**
- Graph neural networks on the social graph
- Community detection (implicit groups)
- Influence propagation patterns
- Mutual connections strength

### 2.4 Edelson/Haugen Comparative Survey (2025)

The most important academic reference on this topic is:

**"A Comparative Survey of Algorithmic Feed Recommendation System Designs"** by Laura Edelson, Frances Haugen, and Damon McCoy (2025), published in ACM Transactions on Recommender Systems. (T1 -- ACM TORS 2025)

Key findings relevant to your project:
- Instagram lists its **five highest-weighted ranking signals** in public documentation (the ones in Section 1.3 above)
- The paper compares feed algorithms across platforms and notes that **Instagram is relatively more transparent than most** about its ranking factors, while still being opaque about model weights and architecture
- Machine learning powers Facebook's News Feed ranking with a comparable multi-stage pipeline
- The authors note a fundamental tension: platforms optimize for engagement metrics that may not align with user wellbeing or societal values

### 2.5 Value Alignment of Feed Algorithms

Highly relevant to your decentralized design:

**"Value Alignment of Social Media Ranking Algorithms"** by Jahanbakhsh et al. (arXiv:2509.14434, 2025, ~5 cit S2) -- Implements an approach where users can express weights on Schwartz's Basic Human Values, combining these weights with value expressions detected in posts to produce a value-aligned feed. Controlled experiments (N=141, N=250) demonstrate that users can effectively use these controls to shape feeds reflecting their desired values, and these value-ranked feeds diverge substantially from engagement-driven feeds. (T2 -- arXiv 2025)

**Direct relevance:** This is exactly the kind of user-controlled ranking that makes sense in a decentralized architecture where each node controls its own feed algorithm.

---

## 3. Instagram's Explore Page and Content Discovery

### 3.1 How Explore Works

The Explore page is Instagram's primary content discovery surface for content from accounts you **don't** follow. Its architecture differs fundamentally from the main Feed:

**Candidate generation for Explore:**
1. **Seed accounts**: Instagram identifies accounts similar to ones you already engage with
2. **Seed posts**: Recent posts from those seed accounts that have high engagement
3. **Embedding-based retrieval**: A two-tower model maps users and posts into a shared embedding space; nearest-neighbor search retrieves candidates
4. **Topic clustering**: Posts are clustered by topic; if you engage with fitness content, Explore retrieves from fitness clusters

**Ranking for Explore** uses similar signals to Feed but with different weights:
- Content popularity (more weight than in Feed -- since you don't follow the author, social proof matters more)
- Visual quality and appeal (higher weight for discovery)
- Content freshness
- Topical relevance to user's inferred interests
- Author credibility (follower count, engagement rates, account age)

### 3.2 The Explore Graph

Meta has described (in engineering blog posts) a system called the **"IG Explore Graph"** -- a heterogeneous graph connecting users, posts, hashtags, locations, and topics. Random walk-based algorithms on this graph generate candidate sets for exploration.

The graph structure:
```
User --follows--> User
User --likes--> Post
User --saves--> Post
Post --tagged--> Hashtag
Post --located--> Location
Post --about--> Topic (inferred)
User --interests--> Topic (inferred)
Hashtag --related--> Hashtag
```

### 3.3 Relevance for Decentralized Content Discovery

This is the hardest problem for your decentralized network. In a centralized system, Explore works because Instagram has:
1. A **global index** of all content
2. **Global engagement data** (what's trending, what similar users like)
3. **Massive compute** for embedding similarity search

In a decentralized network, you need alternatives:

| Centralized approach | Decentralized equivalent |
|---------------------|------------------------|
| Global content index | Federated content crawling / DHT-based content addressing |
| Global engagement data | Aggregated engagement signals from connected nodes |
| Two-tower embedding retrieval | Local embedding model on each node, with periodic model sync |
| Topic clustering | Shared topic ontology + local clustering |
| Random walks on social graph | Random walks on local subgraph + relay through connected nodes |

**Bluesky's approach** (see next section) solves this by having the "firehose" -- a real-time stream of all public posts that any feed generator can subscribe to. This is a pragmatic middle ground between fully centralized and fully decentralized.

---

## 4. Bluesky and the AT Protocol: The Most Relevant Architectural Reference

### 4.1 Architecture Overview

**"Bluesky and the AT Protocol: Usable Decentralized Social Media"** by Kleppmann et al. (arXiv:2402.03239, 2024, ~48 cit S2, published at ACM CCS/SOSP-adjacent venue). (T2 -- arXiv 2024, high impact)

The AT Protocol separates concerns into four layers:

```
1. IDENTITY (DIDs -- Decentralized Identifiers)
   - Users own their identity via cryptographic keys
   - Portable across providers

2. DATA (Personal Data Servers -- PDS)
   - Each user's data stored in their own repo
   - Repos are Merkle trees (content-addressable)
   - Can self-host or use a provider

3. AGGREGATION (Relay / "Big Graph Services")
   - Crawls all PDSs, produces the "firehose"
   - Currently centralized (Bluesky's relay)
   - But protocol allows multiple relays

4. APPLICATION (App Views + Feed Generators + Labelers)
   - App Views: serve the main app experience
   - Feed Generators: independently operated services that consume
     the firehose and produce ranked feeds
   - Labelers: independently operated moderation services
```

### 4.2 Feed Generators -- The Key Innovation for Your Project

**Feed generators are modular, independently operated components** that:
1. Subscribe to the firehose (real-time stream of all events)
2. Apply custom filtering and ranking logic
3. Return an ordered list of post URIs when queried by a client

This means **any developer can create a feed algorithm.** Users choose which feeds to subscribe to. Examples:
- A "Quiet Posters" feed that surfaces posts from low-follower accounts
- A "Science" feed that filters by topic
- A "Mutual Aid" feed for community support
- A "No Quote Tweets" feed

**Technical details:**
- Feed generators expose a `getFeedSkeleton` endpoint
- They return a list of `{post: at://did:plc:xyz/app.bsky.feed.post/abc}` URIs
- The client app (Bluesky) then hydrates these URIs with full post data
- The feed generator does NOT need to store post content -- only post references

### 4.3 Knowledge Graph-Enhanced Feed Generation

**"Leveraging Knowledge Graphs for Semantic-Aware Feed Generation in Bluesky Social Network"** by Zhao & Fujita (2025, ~0 cit S2). (T2 -- preprint 2025)

This paper proposes two enhancements to Bluesky's feed generation:
1. **Entity extraction using knowledge graphs**: Uses DBpedia Spotlight for named entity recognition, stores semantic relationships in Neo4j-backed RDF graph
2. **Personalized recommendation based on user profiles**: Infers user interests from interaction history and matches against semantic content representations

**Direct relevance to your project:** This is almost exactly the architecture you'd want -- a local knowledge graph (you already have AGE/Neo4j) powering semantic feed filtering on each node.

### 4.4 Network Topology Analysis

**"Bluesky: Network topology, polarization, and algorithmic curation"** by Quelle & Bovet (2024, PLOS ONE, ~28 cit S2). (T1 -- PLOS ONE 2024)

Key findings:
- Bluesky's network exhibits heavy-tailed degree distributions, high clustering, and short path lengths -- **same as centralized social networks**
- A large number of custom feeds have been created, but **user uptake is limited** -- most users stick to the default chronological + algorithmic feed
- This is an important lesson: **offering feed choice is necessary but not sufficient; the default must be good**

### 4.5 Mastodon Feed Curation Research

**"Understanding Decentralized Social Feed Curation on Mastodon"** by Liu et al. (2025, ~5 cit S2). (T2 -- 2025)

A two-part study with 21 Mastodon users found:
- **Seamful design** (making the system's seams visible to users) increases trust in algorithmic curation
- Users navigate trade-offs between **ML-based filtering** (more effective but less transparent) and **rule-based filtering** (more transparent but less effective)
- Users want **granular control**: filter by language, content type, topic, author behavior patterns
- The "local timeline" (all posts from your instance) serves as a lightweight discovery mechanism

### 4.6 Cross-Platform Federation (Threads <-> Mastodon)

**"Fediverse Sharing: Cross-Platform Interaction Dynamics Between Threads and Mastodon Users"** by Jeong et al. (2025, ~0 cit S2). (T2 -- 2025)

Studies interactions between 20K+ Threads users and 20K+ Mastodon users over ten months. Lays foundation for understanding cross-platform dynamics in federated networks. Key finding: **federation-driven platform integration creates asymmetric interaction patterns** -- Threads users receive more engagement from Mastodon users than vice versa.

---

## 5. AI Content Generation for Social Media

### 5.1 Autonomous AI Posting Systems

**"Social Media Manager Agent: An AI-Powered System for Caption, Hashtag, and Image Generation with Automated Instagram Publishing"** by Thota et al. (2026, ~0 cit S2). (T2 -- preprint 2026)

A reference architecture for end-to-end AI-driven social media posting:
- **Caption generation**: Perplexity AI for on-brief, concise captions
- **Hashtag curation**: Platform-aware hashtag selection
- **Image synthesis**: Stability AI diffusion models (1024x1024)
- **Publishing**: Meta Graph API for Instagram posting
- **Technical pipeline**: Flask backend, React frontend, media compression to 1080x1080 JPEG
- **Posting flow**: Uses `creation_id`-based media containers for reliable posting via the Meta Graph API

### 5.2 AI Virtual Influencers / Digital Twins

**"SoMeMax - A Novel AI-driven Approach to Generate Artificial Social Media Content That Maximises User Engagement"** by Stave et al. (2023, ~1 cit S2). (T2 -- 2023)

Proposes an autonomous framework for generating social media content optimized for engagement:
- Deep learning models for realistic image generation
- Hashtag generation models
- Evolutionary algorithm for engagement optimization
- Trained on real social media datasets
- User evaluation confirmed generated content matches preferences

### 5.3 Social Simulacra -- AI Communities

**"Social Simulacra in the Wild: AI Agent Communities on Moltbook"** by Goyal et al. (2026, ~0 cit S2). (T2 -- preprint 2026)

First large-scale empirical comparison of AI-agent vs human online communities:
- Analyzed 73,899 Moltbook posts (AI agents) vs 189,838 Reddit posts (humans)
- Compared across five matched communities
- Relevant to understanding what happens when AI agents autonomously participate in social networks

### 5.4 Emergent Profiles -- Identity from Behavior

The concept of "emergent profiles" -- where identity is computed from behavior rather than declared -- is not a well-established academic term, but the underlying idea has significant research support:

**Behavioral profiling in recommendation systems:**
- Every modern recommendation system implicitly constructs an "emergent profile" from user behavior (clicks, dwell time, saves, shares)
- Instagram's interest model is essentially an emergent profile: it infers your interests from your behavior, not from what you declare in your bio

**Academic framing:**
- In privacy research, this is called "inferred data" or "derived data" (as opposed to "provided data")
- In ML, it maps to **user embedding** -- a learned vector representation of the user
- In identity studies, relates to **performative identity** (Judith Butler) and **digital identity construction**

**For your decentralized network:**
- Each node could maintain a local "emergent profile" vector computed from the user's interaction history
- This vector never needs to leave the node -- it's used locally for content filtering
- Privacy advantage: the profile is computed and stored locally, never shared with a central server
- Technical approach: local embedding model (e.g., via Ollama) that processes interaction history into a user interest vector

### 5.5 Commercial AI Posting Tools (as of 2025-2026)

| Tool | AI Features | Posting Capability |
|------|------------|-------------------|
| **Buffer AI Assistant** | Caption generation, hashtag suggestions, optimal time prediction | Multi-platform: Instagram, Facebook, Twitter/X, LinkedIn, TikTok |
| **Hootsuite OwlyWriter AI** | Full post generation from prompts, caption rephrasing, hashtag generation | Multi-platform, bulk scheduling |
| **Later AI** | Caption writing, hashtag suggestions, best-time-to-post prediction | Instagram-focused, visual planning |
| **Jasper AI** | Long-form content generation, brand voice training | API-based, integrates with social tools |
| **Canva Magic Write** | Post text generation, image generation (Magic Media) | Direct publishing to social platforms |
| **Meta AI (native)** | Caption suggestions, ad copy generation, audience targeting | Native to Facebook/Instagram |
| **Publer AI Assist** | Text generation, image generation, auto-hashtags | Multi-platform publishing |

**Key trend:** These tools are moving from "assist" to "autonomous" mode -- from suggesting captions to generating and scheduling entire content calendars. The "Social Media Manager Agent" paper (Section 5.1) represents the fully autonomous end of this spectrum.

---

## 6. Social Media Bridge / Cross-Posting

### 6.1 Existing Cross-Posting Tools and Patterns

**IFTTT / Zapier / Make (Integromat):**
- Trigger-action pattern: "When I post on Instagram, post to Twitter"
- Limitations: API restrictions (Instagram's API is read-heavy, limited write access)
- Rate limits and authentication complexity
- No content adaptation (a post optimized for Instagram may not work on Twitter)

**Buffer / Hootsuite multi-platform posting:**
- Single interface for multiple platforms
- Content adaptation per platform (different text lengths, hashtag strategies, image formats)
- Scheduling and analytics
- NOT true bridging -- requires user to actively post through the tool

**Mastodon-Twitter bridges (historical):**

| Bridge | Status | Pattern |
|--------|--------|---------|
| **Moa Bridge** (moa.party) | Defunct (Twitter API changes 2023) | Bi-directional sync, OAuth on both sides |
| **Crossposter** (crossposter.masto.donte.com.br) | Defunct | Mastodon -> Twitter |
| **Bridgy Fed** (fed.brid.gy) | Active | Bridges Fediverse <-> Bluesky, IndieWeb |
| **Threads federation** | Active (partial) | Threads -> Fediverse (opt-in by Threads users) |

### 6.2 Instagram Graph API for Posting

The Meta Graph API supports **Content Publishing** for Instagram:

**Requirements:**
- Instagram Business or Creator account
- Facebook Page connected to the Instagram account
- App with `instagram_basic`, `instagram_content_publish`, `pages_read_engagement` permissions
- App Review by Meta

**Posting flow (two-step):**
```
Step 1: Create media container
POST /{ig-user-id}/media
  ?image_url={url}
  &caption={text}
  &access_token={token}
Response: { "id": "{creation_id}" }

Step 2: Publish the container
POST /{ig-user-id}/media_publish
  ?creation_id={creation_id}
  &access_token={token}
Response: { "id": "{media_id}" }
```

**Limitations:**
- Only Business/Creator accounts (not personal)
- Rate limited (25 posts per 24 hours)
- Images must be hosted at a public URL
- No Stories publishing via API (as of 2025)
- Carousel posts require sequential container creation
- Reels have specific video format requirements

### 6.3 Facebook Graph API for Posting

```
POST /{page-id}/feed
  ?message={text}
  &link={url}
  &access_token={page_token}
```

More permissive than Instagram's API. Supports text, link, photo, video, and scheduled posts.

### 6.4 Consent-Based vs Automatic Cross-Posting

**Automatic cross-posting** (traditional):
- User configures once, all posts are mirrored
- Problems: context collapse, inappropriate content for target platform, no adaptation
- User may forget it's active, leading to unintended sharing

**Consent-based cross-posting** (emerging pattern):
- Per-post or per-category consent
- User explicitly marks which posts should be cross-posted
- Content adaptation happens before cross-posting
- Examples: Threads' opt-in federation (users must explicitly enable Fediverse sharing)

**For your decentralized network, the recommended pattern:**
1. **Explicit opt-in per platform bridge** (user enables "bridge to Instagram")
2. **Per-post control** (toggle per post, or default-on with per-post override)
3. **Content adaptation layer** (transform post format/length for target platform)
4. **Bidirectional with asymmetry** (easy to cross-post out, import from external requires explicit action to avoid spam)

---

## 7. Serendipitous Connections

### 7.1 Knowledge Graph for Feed Generation <-> KORE

The Zhao & Fujita paper on Bluesky feed generation using Neo4j + DBpedia Spotlight is remarkably close to what you already have with KORE (AGE knowledge graph + pgvector). Your existing infrastructure could serve as the foundation for a decentralized feed generator:

- **AGE knowledge graph**: semantic relationships between concepts, authors, topics
- **pgvector**: embedding similarity search for content matching
- **Ollama embeddings**: local embedding generation (no external API dependency)
- **Paper archive**: already imports academic content with metadata

### 7.2 Bradley-Terry Model <-> Feed Ranking

Your Ranking Todo project (Bradley-Terry model, preference learning) directly connects to the value alignment work by Jahanbakhsh et al. -- **a value-aligned feed is essentially a preference learning problem** where the user expresses preferences over values and the system learns to rank content accordingly.

### 7.3 Agent Framework <-> Social Media Manager Agent

The Social Media Manager Agent architecture (Flask + Perplexity + Stability AI + Meta Graph API) maps naturally onto your Agent Framework's multi-agent orchestration. An agent for "publish to Instagram" would be a concrete use case.

---

## 8. Open Questions

### For your decentralized social network design:

1. **Cold start for discovery**: How does a new node discover interesting content before it has built up an interaction history? Bluesky solves this with curated default feeds. What's your approach?

2. **Gossip protocol for engagement signals**: If each node filters locally, how do you aggregate "what's popular" without a central authority? Options: epidemic/gossip protocols, DHT-based aggregation, federated averaging.

3. **Model synchronization**: If each node runs a local ranking model, do they share model updates? Federated learning is the obvious approach but introduces privacy and convergence challenges.

4. **Spam in a decentralized discovery system**: Without a central authority to block spam, how do you prevent Explore-like discovery from being overwhelmed by spam nodes? Web of trust / reputation systems are the standard approach.

5. **AI content authenticity**: As AI-generated content becomes indistinguishable from human content (Section 5), how does your network handle provenance and authenticity? C2PA / Content Credentials is one approach.

---

## 9. What to Read Next

1. **Kleppmann et al. "Bluesky and the AT Protocol" (arXiv:2402.03239)** -- The most directly relevant architectural reference for your project. Read the feed generator section carefully.

2. **Edelson, Haugen & McCoy "A Comparative Survey of Algorithmic Feed Recommendation System Designs" (ACM TORS 2025)** -- The authoritative comparative analysis of how major platforms (including Instagram) design their feed algorithms.

3. **Jahanbakhsh et al. "Value Alignment of Social Media Ranking Algorithms" (arXiv:2509.14434)** -- Directly applicable to user-controlled feed ranking in a decentralized setting.

4. **Liu et al. "Understanding Decentralized Social Feed Curation on Mastodon" (2025)** -- Empirical evidence on how real users interact with decentralized feed curation.

5. **Zhao & Fujita "Leveraging Knowledge Graphs for Semantic-Aware Feed Generation in Bluesky" (2025)** -- The closest existing work to what you'd build with KORE as a feed engine.

---

## 10. Sources

### T1 -- Peer-reviewed
- Edelson, Haugen & McCoy (2025). "A Comparative Survey of Algorithmic Feed Recommendation System Designs." ACM Transactions on Recommender Systems. DOI: 10.1145/3757327
- Quelle & Bovet (2024). "Bluesky: Network topology, polarization, and algorithmic curation." PLOS ONE. ~28 cit S2
- Liu et al. (KDD 2021). "Que2Search: fast and accurate query and document understanding for search at facebook." KDD 2021
- Evnine et al. (KDD 2024). "Achieving a better tradeoff in multi-stage recommender systems through personalization." KDD 2024
- Hsu et al. (ICML 2025). "From Models to Systems: A Comprehensive Fairness Framework for Compositional Recommender Systems." ICML 2025

### T2 -- arXiv / preprints
- Kleppmann et al. (2024). "Bluesky and the AT Protocol: Usable Decentralized Social Media." arXiv:2402.03239. ~48 cit S2
- Jahanbakhsh et al. (2025). "Value Alignment of Social Media Ranking Algorithms." arXiv:2509.14434. ~5 cit S2
- Zhao & Fujita (2025). "Leveraging Knowledge Graphs for Semantic-Aware Feed Generation in Bluesky Social Network." ~0 cit S2
- Liu et al. (2025). "Understanding Decentralized Social Feed Curation on Mastodon." ~5 cit S2
- Jeong et al. (2025). "Fediverse Sharing: Cross-Platform Interaction Dynamics Between Threads and Mastodon Users." ~0 cit S2
- Thota et al. (2026). "Social Media Manager Agent." ~0 cit S2
- Stave et al. (2023). "SoMeMax - A Novel AI-driven Approach to Generate Artificial Social Media Content." ~1 cit S2
- Goyal et al. (2026). "Social Simulacra in the Wild: AI Agent Communities on Moltbook." ~0 cit S2

### T7 -- Corporate disclosures / blogs
- Adam Mosseri / Instagram blog: "Shedding More Light on How Instagram Works" (2021, updated 2023, 2024)
- Instagram blog: "See the Moments You Care About First" (March 2016)
- Meta Engineering blog: various posts on recommendation systems architecture

### Not found / could not verify
- No peer-reviewed paper exists that details Instagram's exact model architecture (weights, layer counts, training procedure). This is proprietary.
- The exact URL for Mosseri's ranking explanation post was unreachable during this research session (about.instagram.com returned 400 errors), but the content has been widely cited and summarized in academic literature.

---

## Personal Project Connection

This research directly connects to:
- **Ranking Todo**: Bradley-Terry preference learning for user-controlled feed weights
- **Kindle Graph Enrichment / KORE**: Knowledge graph as feed generation engine (per Zhao & Fujita 2025)
- **Agent Framework**: Multi-agent architecture for social media posting agents
- **MCP Server**: Content discovery could use the existing pgvector + AGE infrastructure
