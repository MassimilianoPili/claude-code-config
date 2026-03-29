# Research: Autopoietic Knowledge Networks

## Research Summary: Autopoietic Knowledge Networks -- A Decentralized Social Network Where Topology Co-Evolves With Knowledge Distribution

### Executive Summary

The concept of an "autopoietic knowledge network" -- where each node maintains a personal knowledge graph, nodes discover each other via embedding similarity, and knowledge exchange alters the discovery topology itself -- is a genuinely novel synthesis that has **no direct prior art as a complete system**. However, each of its components draws on deep, well-established research traditions. The closest existing work is Roth's (2005) model of "epistemic networks" where social and semantic layers co-evolve, but no one has combined this with embedding-based discovery, decentralized anti-entropy protocols, and autopoietic self-maintenance in a single architecture.

**Epistemic status:** Novel synthesis of established components. No existing system implements this full design. Individual components range from settled science to active research frontiers.
**Confidence:** Medium-High -- the component technologies are well-validated, but the emergent behavior of their composition is theoretically predicted but empirically untested.

---

## A. Autopoiesis in Network Theory

### Core Theory

Autopoiesis ("self-creation") was introduced by Maturana & Varela (1980) to describe biological systems that recursively produce their own components while maintaining their organizational boundary. The canonical example is a living cell: its membrane is produced by the metabolic network it contains, and that membrane defines what enters the metabolic network. (T1 -- *De Maquinas y Seres Vivos*, 1972; English translation 1980)

**Luhmann's extension to social systems** is the critical bridge. Niklas Luhmann (1984, 1997) argued that social systems are autopoietic systems whose fundamental operation is *communication*, not people. A social system produces communications from communications -- each communication enables further communications, and the system's boundary is defined by what counts as a communication within it. (T1 -- Luhmann, "The Autopoiesis of Social Systems", *Journal of Sociocybernetics*, 2008 reprint)

This is directly relevant to the proposed design: **if the "communications" in an autopoietic social network are knowledge deltas exchanged between nodes, then the network literally produces its own structure through the act of learning.** Each knowledge exchange changes the node's embedding vector, which changes who it discovers, which changes what knowledge it receives next -- a perfect self-referential loop.

### Key Papers

1. **Mingers (2002), "Can Social Systems Be Autopoietic? Assessing Luhmann's Social Theory"** (T1 -- *The Sociological Review*). Critical assessment of whether Luhmann's extension is valid. Concludes that the extension works but requires careful distinction between "structural coupling" (nodes interacting with environment) and "autopoiesis proper" (the system maintaining its organizational closure). Important for the design: the knowledge network as a whole is autopoietic, but individual nodes are structurally coupled to it.

2. **Farini (2025), "Web-based groups as autopoietic social systems: A cybernetic perspective"** (T1 -- *Communication and the Public*). Very recent paper applying Luhmannian autopoiesis to Facebook groups. Finds that web-based groups demonstrate self-referential autopoiesis through communication processes. Directly validates applying autopoiesis to digital networks.

3. **Watson (2023), "Technology as an autopoietic system"** (T5 -- preprint/working paper). Argues that technology platforms, including social media, exhibit autopoietic properties: they produce their own components (content, connections, algorithms) through self-referential processes.

4. **Sukharevska (2021), "Heuristic Potential of Luhmann's Theory of Autopoiesis in Social Networks"** (T3 -- *Scientific Journal of Polonia University*). Argues social networks function as information databases, communication systems, and search engines simultaneously, making them both self-referential and autopoietic.

### Critical Insight for the Design

The autopoietic framing is not merely metaphorical -- it has precise operational consequences:
- **Organizational closure**: The network's topology is entirely determined by its own knowledge distribution. No external authority decides connections.
- **Structural coupling**: Individual nodes are coupled to the network through their embedding vectors, but the network maintains its own organizational identity.
- **Self-maintenance**: The system continuously regenerates its own connection patterns through the act of knowledge exchange.
- **Boundary**: The system's boundary is defined by the shared embedding space. Nodes outside this space cannot participate.

---

## B. Knowledge Graph Federation and Exchange

### Federated Knowledge Graphs

The problem of merging and aligning separate knowledge graphs is well-studied, though primarily in centralized/enterprise contexts rather than decentralized peer-to-peer settings.

1. **Huang et al. (2022), "FedCKE: Cross-Domain Knowledge Graph Embedding in Federated Learning"** (T1 -- *IEEE Transactions on Big Data*). Proposes federated learning for KG embeddings with inter-domain encrypted entity/relation alignment. Key insight: you can align entities across different knowledge graphs without revealing the full graph structure -- essential for privacy in a decentralized knowledge network.

2. **GraphMatcher (2024), "A Graph Representation Learning Approach for Ontology Matching"** (T2 -- arXiv). Uses graph neural networks to match ontologies across different knowledge graphs. Achieves state-of-the-art performance on the OAEI benchmark. Relevant because nodes in the proposed system need to determine which concepts in their KG correspond to concepts in a peer's KG.

3. **Zghal & Kachroudi (2026), "The Co-evolution of Ontologies and Extensive Knowledge Graphs on a Web Scale"** (T1 -- *The Journal of Supercomputing*). Very recent work on how ontologies and large knowledge graphs co-evolve. Directly relevant: as nodes exchange knowledge, their local ontologies will diverge and need reconciliation.

### Anti-Entropy and Merkle-Based Reconciliation

The distributed systems literature provides the exact protocols needed for efficient knowledge delta exchange:

4. **Sanjuan et al. (2020), "Merkle-CRDTs: Merkle-DAGs meet CRDTs"** (T2 -- arXiv:2004.00107). **This is the key paper for the exchange protocol.** Shows how Merkle-DAGs can serve as logical clocks for CRDTs, enabling efficient state reconciliation in peer-to-peer networks. The anti-entropy algorithm they describe -- comparing Merkle roots to identify differing subtrees -- is exactly what's needed for knowledge delta exchange. Two nodes compare their Merkle roots; if they differ, they recursively descend to find the specific concepts/triples that differ, exchanging only the deltas.

5. **Auvolat & Taiani (2019), "Merkle Search Trees: Efficient State-Based CRDTs in Open Networks"** (T1 -- *38th Symposium on Reliable Distributed Systems, IEEE*). Proposes a Merkle tree structure specifically designed for anti-entropy in open (permissionless) networks. The key contribution: a deterministic tree structure that ensures all replicas converge to the same shape, enabling efficient comparison without coordination.

6. **Kleppmann (2022), "Making CRDTs Byzantine Fault Tolerant"** (T1 -- *Proceedings of the 9th Workshop on Principles and Practice of Consistency for Distributed Data, ACM*). Extends CRDTs to handle malicious participants. Essential for any decentralized knowledge network where nodes might inject false knowledge.

7. **Khan, Habiba & Khan (2025), "A Gossip-Enhanced Communication Substrate for Agentic AI"** (T2 -- arXiv:2512.03285). Very recent paper that revisits gossip protocols for multi-agent systems, arguing for anti-entropy reconciliation as enabling "soft forms of coordination." Directly applicable to the decentralized discovery mechanism.

### Novel Application: Knowledge CRDTs

**No existing work applies Merkle-CRDT reconciliation to knowledge graph triples specifically.** This is a gap and an opportunity. A "Knowledge CRDT" would:
- Represent each triple (subject, predicate, object) as an element in a grow-only set (G-Set CRDT)
- Use Merkle trees over the sorted set of triples for efficient delta computation
- Handle conflicting triples (where two nodes assert contradictory facts) via a conflict resolution policy (e.g., latest-writer-wins, or keeping both with provenance metadata)

---

## C. Homophily-Driven Network Formation

### The Foundational Work

1. **McPherson, Smith-Lovin & Cook (2001), "Birds of a Feather: Homophily in Social Networks"** (T1 -- *Annual Review of Sociology*, 27:415-444). The seminal survey on homophily, with an estimated ~13,000+ citations. Establishes that similarity breeds connection across virtually every dimension studied: age, race, education, occupation, gender, attitudes, abilities, aspirations. Crucially distinguishes between:
   - **Choice homophily** (baseline): people actively choose similar others
   - **Induced homophily**: structural features of the environment (geography, organizations) create similarity among contacts

   This distinction matters for the design: embedding-based discovery creates *induced* homophily (the algorithm surfaces similar nodes), but users exercise *choice* homophily in deciding which knowledge to absorb.

### Adaptive/Co-Evolutionary Networks

2. **Gross & Blasius (2008), "Adaptive Coevolutionary Networks: A Review"** (T1 -- *Journal of the Royal Society Interface*, 5:259-271). **This is the most important theoretical paper for the proposed system.** Reviews networks where topology and node states co-evolve. Key findings:
   - Co-evolutionary dynamics can produce emergent phenomena not present in either static networks or non-networked dynamics alone
   - Common emergent behaviors include: self-organization into homogeneous clusters, spontaneous formation of complex topologies, and critical transitions (phase transitions in network structure)
   - The feedback loop between node state changes and topology changes can lead to bistability and hysteresis

   **Direct implication**: the proposed knowledge network will likely exhibit phase transitions -- sudden reorganizations of the connection topology when knowledge distributions cross certain thresholds.

3. **Roth (2005), "Co-evolution in Epistemic Networks -- Reconstructing Social Complex Systems"** (T1 -- *Structure and Dynamics: eJournal of Anthropological and Related Sciences*). **The closest existing work to the proposed system.** Roth models an "epistemic network" with three layers:
   - A **social network** (who knows whom)
   - A **semantic network** (how concepts relate to each other)
   - A **socio-semantic network** (who knows what)

   He shows that the co-evolution of agents and concepts at the lower level produces emergent structure at the higher level. This is precisely the mechanism proposed: knowledge exchange (socio-semantic) changes the topology (social), which changes future knowledge exchange.

4. **Alaa, Ahuja & van der Schaar (2015), "A Micro-foundation of Social Capital in Evolving Social Networks"** (T2 -- arXiv:1511.02429). Models network evolution with homophily, structural opportunism, and gregariousness. Key finding: homophily creates asymmetries in popularity -- more gregarious types become more popular. In the proposed system, nodes with broader knowledge graphs will attract more connections, creating a "rich get richer" dynamic that must be managed.

### Echo Chamber Risk

The similarity-based discovery mechanism creates a fundamental tension:

5. **Ge et al. (2020), "Understanding Echo Chambers in E-commerce Recommender Systems"** (T1 -- *Proceedings of SIGIR 2020*, ACM). Finds that prolonged exposure to similarity-based recommendations substantially decreases content diversity. Echo chambers form in click behaviors but are mitigated in purchase behaviors (where users are more deliberate). Implication: passive knowledge absorption will create echo chambers; active knowledge selection may not.

6. **Noordeh et al. (2020), "Echo Chambers in Collaborative Filtering Based Recommendation Systems"** (T2 -- arXiv:2011.03890). Shows that once echo chambers form, individual users cannot break out by manipulating their own behavior alone. System-level interventions are required.

---

## D. Embedding-Based Node Discovery

### Graph and Knowledge Graph Embeddings

1. **Grover & Leskovec (2016), node2vec** (T1 -- KDD 2016, ~8000+ citations). Learns continuous feature representations for nodes by simulating biased random walks. Could be used to embed each node's knowledge graph into a vector space, enabling cosine similarity comparison.

2. **Bordes et al. (2013), TransE** (T1 -- NeurIPS 2013, ~10,000+ citations). Embeds knowledge graph entities and relations into a continuous vector space where h + r ~ t for each triple (h, r, t). The aggregated entity embeddings of a node's KG could serve as its "interest vector."

3. **Parnami et al. (2021), "Transformation of Node to Knowledge Graph Embeddings for Faster Link Prediction in Social Networks"** (T2 -- arXiv:2111.09308). Shows how to transform random-walk-based embeddings (node2vec) into knowledge graph embeddings (TransE-style) without retraining. This is directly applicable: a node could quickly compute its interest vector from its KG using a pre-trained transformation.

### Decentralized Similarity Search

4. **Haghani, Michel & Aberer (2009), "Distributed Similarity Search in High Dimensions Using Locality Sensitive Hashing"** (T1 -- *12th International Conference on Extending Database Technology, ACM*). The foundational paper for distributed LSH in P2P networks. Shows how to perform approximate nearest neighbor search in structured P2P overlays with bounded communication cost.

5. **Kraus et al. (2016), "NearBucket-LSH: Efficient Similarity Search in P2P Networks"** (T1 -- *International Conference on Similarity Search and Applications, Springer*). Designed specifically for decentralized social networks organized as P2P overlays. Uses LSH to limit search scope while maintaining discovery quality.

6. **Keizer et al. (2023), "Ditto: Towards Decentralized Similarity Search for Web3 Services"** (T1 -- *IEEE Conference on Decentralized Applications*). Very recent. Uses LSH to extract similarity signatures stored on a decentralized index (DHT). Directly applicable to the proposed system -- nodes could store their LSH signatures in a DHT, enabling other nodes to discover similar peers without a central index.

7. **Krasanakis et al. (2022), "p2pGNN: A Decentralized Graph Neural Network for Node Classification in Peer-to-Peer Networks"** (T1 -- *IEEE Access*). Proposes GNNs that operate in a fully decentralized manner where each device holds its own feature vectors. Shows that decentralized training can achieve comparable accuracy to centralized approaches.

### Practical Architecture for Discovery

The combination of these techniques suggests a concrete architecture:
1. Each node computes an aggregate embedding of its KG (using TransE or similar)
2. The embedding is hashed via LSH into multiple buckets
3. LSH bucket assignments are published to a DHT (like Kademlia)
4. Discovery = looking up your own LSH buckets in the DHT and finding other nodes there
5. After knowledge exchange, the node recomputes its embedding, potentially changing its LSH buckets
6. This triggers discovery of new, different peers -- the co-evolutionary loop

---

## E. Serendipity and Diversity in Recommendation

### The Echo Chamber Problem and Its Solutions

1. **Kaminskas & Bridge (2016), "Diversity, Serendipity, Novelty, and Coverage: A Survey and Empirical Analysis of Beyond-Accuracy Objectives in Recommender Systems"** (T1 -- *ACM Transactions on Interactive Intelligent Systems*). The definitive survey. Defines:
   - **Diversity**: how different recommended items are from each other
   - **Novelty**: how different recommendations are from what the user has seen before
   - **Serendipity**: recommendations that are both novel AND relevant -- the "pleasant surprise"
   - **Coverage**: what fraction of the item catalog is ever recommended

   For the proposed system, serendipity is the critical metric. A purely homophily-based system will score high on relevance but low on serendipity.

2. **Reviglio (2019), "Serendipity as an Emerging Design Principle of the Infosphere"** (T1 -- *Ethics and Information Technology*, Springer). Argues that deliberately architecturing for serendipity is an ethical imperative to counter echo chambers. Proposes a taxonomy of serendipity mechanisms.

3. **Duricic et al. (2023), "Beyond-Accuracy: A Review on Diversity, Serendipity and Fairness in Recommender Systems Based on Graph Neural Networks"** (T2 -- arXiv:2310.02294). Reviews how GNN-based recommender systems can be modified to promote diversity and serendipity while maintaining accuracy. Key technique: modifying the graph propagation layers to inject diversity.

### Information Foraging Theory

4. **Pirolli & Card (1995/1999), "Information Foraging in Information Access Environments"** (T1 -- *Proceedings of SIGCHI*, ACM; extended in *Psychological Review*, 1999). Introduces information foraging theory (IFT), applying optimal foraging theory from ecology to information seeking. Key concepts:
   - **Information scent**: cues that help a forager assess the value of a potential information source
   - **Information patches**: clusters of related information
   - **Marginal value theorem**: a forager should leave a patch when the rate of gain drops below the average rate achievable by moving to a new patch

   **Critical insight for the design**: in the proposed system, a node's current knowledge neighborhood is an "information patch." The marginal value theorem predicts that nodes should periodically seek radically different peers (leave the patch) when the knowledge gain from similar peers diminishes. This provides a theoretical foundation for built-in serendipity.

5. **Pirolli (2009), "An Elementary Social Information Foraging Model"** (T1 -- *Proceedings of SIGCHI*, ACM). Extends IFT to social settings where information is distributed across people. Models how participation rates and knowledge discovery rates depend on the social network structure. Directly applicable: the autopoietic knowledge network is a social information foraging environment.

### Explore-Exploit Tradeoff

6. **McInerney et al. (2018), "Explore, Exploit, and Explain: Personalizing Explainable Recommendations with Bandits"** (T1 -- *RecSys 2018*, ACM). Uses multi-armed bandits to balance exploration and exploitation in recommendations. The "explain" component is novel: recommendations include justifications, which increases user acceptance of exploratory suggestions.

7. **Oudeyer (2018), "Computational Theories of Curiosity-Driven Learning"** (T2 -- arXiv:1802.10546). Reviews computational models of curiosity, arguing that curiosity-driven exploration enables organisms to solve complex problems with rare or deceptive rewards. Key concept: **learning progress** as an intrinsic motivation signal -- explore areas where your rate of learning is highest, not where your current knowledge is highest. This is the antidote to echo chambers: nodes should preferentially connect to peers from whom they learn the most new information, not peers who are most similar.

### Design Recommendation: The Curiosity Coefficient

Combining IFT and curiosity-driven learning, the discovery mechanism should incorporate a **curiosity coefficient** (epsilon):
- With probability (1 - epsilon): discover peers by embedding similarity (exploit)
- With probability epsilon: discover peers by **maximal knowledge delta** -- peers who share the fewest concepts with you but are within a minimum relevance threshold (explore)
- epsilon should be adaptive: increase it when the rate of new knowledge from similar peers drops below a threshold (the marginal value theorem trigger)

---

## F. Prior Art -- Has Anyone Built This?

### The Short Answer: No, Not As a Complete System

No existing system combines all five elements: (1) personal knowledge graphs, (2) embedding-based peer discovery, (3) decentralized knowledge delta exchange, (4) topology-knowledge co-evolution, and (5) autopoietic self-maintenance. However, several systems implement subsets:

### Closest Prior Art

1. **Roth's Epistemic Networks (2005)** -- see Section C above. Models the co-evolution of social and semantic networks but as a theoretical/simulation framework, not a deployed system.

2. **Bluesky / AT Protocol** (T7 -- Kleppmann et al., arXiv:2402.03239, also ACM CoNEXT-DiCE Workshop 2024). The AT Protocol is the most architecturally relevant decentralized social protocol. Key features:
   - Personal Data Servers (PDS) that hold user data (analogous to personal KGs)
   - Federated crawling and indexing
   - Algorithmic choice (users choose their feed algorithms)
   - Account portability

   However, AT Protocol has no concept of content-based peer discovery or knowledge co-evolution. Connections are still follower/following relationships, not knowledge-graph relationships.

3. **ActivityPub / Fediverse** (T7 -- W3C Recommendation, 2018). The most widely deployed federated social protocol (Mastodon, etc.). Federation is server-to-server, not peer-to-peer. No concept of knowledge graphs or embedding-based discovery. Connections are still social (follow/friend), not semantic.

4. **Obsidian / Roam Research / Logseq** -- Personal Knowledge Graphs (T7 -- various). These tools implement personal knowledge graphs (Zettelkasten-style linked notes) but are entirely single-user. No federation, no peer discovery, no knowledge exchange. The Zettelkasten MCP server (GitHub: entanglr/zettelkasten-mcp) adds AI interaction but not peer networking.

5. **Kazienko et al. (2011/2013), "Multidimensional Social Network in the Social Recommender System"** (T1 -- *IEEE Transactions on Systems, Man, and Cybernetics, Part A*). Builds a multi-layered social network where layers represent different relationship types (social, semantic, object-based). Uses this to generate personalized suggestions for new connections. Close to the proposed system in spirit but centralized and not knowledge-graph-based.

6. **Smirnov & Ponomarev (2014/2015), "A Hybrid Peer-to-Peer Recommendation System Based on Locality-Sensitive Hashing"** (T1 -- *FRUCT Conference* and *Springer*). Uses LSH of user preferences in a P2P network for decentralized recommendation. This is the closest existing system to the discovery mechanism proposed, but it operates on item preferences, not knowledge graphs.

### Collaborative Knowledge Building Systems (Beyond Wikipedia)

7. **Knowledge Building (Scardamalia & Bereiter)** (T1 -- educational research, 1990s-present). A pedagogical framework where students collaboratively build knowledge through discourse. Implemented in Knowledge Forum software. Has the knowledge co-evolution idea but is classroom-based, centralized, and not graph-structured.

8. **Semantic MediaWiki** (T7). Extends Wikipedia with structured data (RDF triples). Collaborative but centralized. No peer discovery, no personal graphs, no co-evolution.

### What's Missing From All Prior Art

None of these systems have:
- **The feedback loop**: where knowledge exchange changes the discovery topology, which changes future knowledge exchange
- **Embedding-based discovery**: where connections emerge from content similarity rather than explicit social action
- **The identity between social graph and knowledge graph**: where "connecting with someone" literally means "learning from them"

---

## Serendipitous Connections

### 1. Ising Model Analogy (Physics <-> Network Theory)
The proposed system has a deep structural analogy to the **Ising model with adaptive coupling**. Each node's knowledge state is like a spin configuration; the embedding similarity acts as the coupling constant; and the topology co-evolution is analogous to adaptive coupling where coupling strengths depend on spin alignment. This predicts:
- **Phase transitions**: at some critical temperature (analogous to the curiosity coefficient), the system will transition between an ordered phase (echo chambers, highly clustered) and a disordered phase (diverse but unfocused connections)
- **Critical point**: there exists an optimal curiosity coefficient where the system is at the boundary between order and disorder -- maximizing both coherence and diversity. This is analogous to the "edge of chaos" in complex systems theory.

### 2. Marginal Value Theorem (Ecology <-> Information Science)
Pirolli & Card's information foraging theory provides an exact quantitative criterion for when a node should "leave its current knowledge patch" (stop connecting to similar peers and seek diverse ones). The marginal value theorem from optimal foraging theory says: leave the patch when your instantaneous rate of knowledge gain drops below the average rate achievable across all patches. This gives a principled, non-arbitrary way to set the curiosity coefficient adaptively.

### 3. Gossip Protocols as Epistemic Protocols (CS <-> Epistemology)
Van Ditmarsch et al. (2019) study "dynamic gossip" where agents share secrets, and the act of sharing changes who can call whom. This is a formal logic framework for exactly the proposed system: the "secrets" are knowledge, the "calling" is connecting, and the protocol determines how knowledge propagation and topology evolution interact. Their key finding -- that there is **no strengthening of the Learn New Secrets protocol that always terminates successfully** -- has a profound implication: a purely greedy knowledge-seeking strategy cannot guarantee full knowledge dissemination. Some form of structured exploration is mathematically necessary.

### 4. Bradley-Terry and Knowledge Exchange (Statistics <-> Design)
The preference learning framework (Bradley-Terry model) used in your Ranking Todo project has a connection here: when a node must decide which of several potential peers to exchange knowledge with, it faces a ranking problem. The information gain from each potential peer is uncertain, and the node must learn which peers are most valuable through sequential interactions -- exactly the multi-armed bandit setting. Your existing preference-sort infrastructure could be adapted for peer ranking.

### 5. Agent Framework Connection (CS/AI <-> Design)
The multi-agent orchestration framework you're building (agent-framework) has direct applicability: each node in the autopoietic network could be modeled as an agent with:
- A knowledge state (KG)
- A discovery policy (embedding + curiosity coefficient)
- An exchange protocol (Merkle-CRDT anti-entropy)
- A learning objective (maximize knowledge gain while maintaining coherence)

The HTN planning approach in your agent framework could orchestrate the explore/exploit decisions.

---

## Open Questions

1. **Convergence**: Does the system converge to a stable state, or does it oscillate? Gross & Blasius (2008) suggest co-evolutionary networks can exhibit both stable equilibria and limit cycles. Simulation is needed.

2. **Scalability of Embedding Recomputation**: After each knowledge exchange, the node must recompute its embedding. For large KGs, this could be expensive. Incremental embedding updates (e.g., using online TransE variants) would be needed.

3. **Trust and Adversarial Knowledge**: How to handle nodes that inject false triples? Kleppmann's BFT-CRDTs (2022) provide a starting point, but knowledge quality assessment is harder than data integrity.

4. **Privacy**: Embedding vectors leak information about a node's knowledge. Differential privacy on embeddings, or secure multi-party computation for similarity comparison (cf. Bickson et al., 2008), would be needed for sensitive domains.

5. **Incentive Compatibility**: Why would a node share its knowledge? If knowledge is competitive, nodes may free-ride. Game-theoretic analysis (mechanism design) is needed.

6. **Ontology Drift**: As nodes independently evolve their local ontologies through learning, will the shared embedding space remain meaningful? Periodic re-alignment may be needed.

---

## What to Read Next

1. **Gross & Blasius (2008), "Adaptive Coevolutionary Networks: A Review"** -- the theoretical foundation for topology-state co-evolution. Start here.

2. **Roth (2005), "Co-evolution in Epistemic Networks"** -- the closest existing model to the proposed system.

3. **Sanjuan et al. (2020), "Merkle-CRDTs"** -- the exchange protocol you'd actually implement.

4. **Oudeyer (2018), "Computational Theories of Curiosity-Driven Learning"** -- the antidote to echo chambers.

5. **Kleppmann et al. (2024), "Bluesky and the AT Protocol"** -- the most relevant existing decentralized social architecture to learn from and differentiate against.

6. **Kaminskas & Bridge (2016), "Diversity, Serendipity, Novelty, and Coverage"** -- the metrics you'd use to evaluate the system.

---

## Knowledge Graph Candidates

- "Autopoiesis" -- Type: framework. Links: Maturana, Varela, Luhmann, self-organization, systems theory
- "Adaptive Coevolutionary Networks" -- Type: framework. Links: Gross & Blasius, phase transitions, network topology, complex systems
- "Epistemic Networks" -- Type: framework. Links: Roth, co-evolution, social network, semantic network
- "Merkle-CRDT" -- Type: technique. Links: CRDT, Merkle tree, anti-entropy, distributed systems, Kleppmann
- "Information Foraging Theory" -- Type: framework. Links: Pirolli, Card, optimal foraging, information scent, explore-exploit
- "Homophily" -- Type: principle. Links: McPherson, social networks, echo chambers, birds of a feather
- "Serendipity in Recommendation" -- Type: theme. Links: diversity, novelty, filter bubbles, echo chambers
- "Locality-Sensitive Hashing" -- Type: technique. Links: ANN, distributed search, P2P, embedding similarity

---

## Sources (Tier-Labeled)

### T1 -- Peer-Reviewed
- McPherson, Smith-Lovin & Cook (2001). *Annual Review of Sociology*
- Gross & Blasius (2008). *J. Royal Society Interface*
- Luhmann (2008 reprint). *Journal of Sociocybernetics*
- Mingers (2002). *The Sociological Review*
- Auvolat & Taiani (2019). *IEEE SRDS*
- Kleppmann (2022). *ACM PaPoC Workshop*
- Haghani et al. (2009). *EDBT, ACM*
- Kaminskas & Bridge (2016). *ACM TiiS*
- Pirolli & Card (1995). *ACM SIGCHI*
- Roth (2005). *Structure and Dynamics*
- Kazienko et al. (2011). *IEEE Trans. SMC-A*
- McInerney et al. (2018). *ACM RecSys*
- Ge et al. (2020). *ACM SIGIR*
- Reviglio (2019). *Ethics and Information Technology*
- Huang et al. (2022). *IEEE Trans. Big Data*
- Farini (2025). *Communication and the Public*
- Kleppmann et al. (2024). *ACM CoNEXT-DiCE*

### T2 -- arXiv/Preprints (Strong)
- Sanjuan et al. (2020). arXiv:2004.00107
- Oudeyer (2018). arXiv:1802.10546
- Parnami et al. (2021). arXiv:2111.09308
- Duricic et al. (2023). arXiv:2310.02294
- Khan et al. (2025). arXiv:2512.03285
- Krasanakis et al. (2022). *IEEE Access*
- Kraus et al. (2016). *SISAP, Springer*
- Noordeh et al. (2020). arXiv:2011.03890
- Alaa et al. (2015). arXiv:1511.02429
- Keizer et al. (2023). *IEEE DAPPS*

### T3 -- Working Papers / Lower-Tier Journals
- Sukharevska (2021). *Scientific Journal of Polonia University*
- Watson (2023). Working paper/preprint

### T7 -- Wikipedia / Background
- AT Protocol, ActivityPub, Zettelkasten -- Wikipedia entries
- Various blog posts on PKM tools

---

## Personal Project Connections

| Project | Connection |
|---------|-----------|
| **Ranking Todo** | Bradley-Terry model for peer ranking; information gain as comparison criterion |
| **Kindle Graph Enrichment** | Your KORE system IS a personal knowledge graph -- the first node of this network already exists |
| **Agent Framework** | Multi-agent orchestration for node behavior; HTN planning for explore/exploit |
| **Fantacalcio** | Network effects in player valuation; information asymmetry between managers |
