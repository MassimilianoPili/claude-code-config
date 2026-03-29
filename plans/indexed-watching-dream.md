# Preference Ranking + Vector DB: Teoria e Architettura

## Context

Discussione teorica sull'integrazione tra il Preference Sort API (Bradley-Terry pairwise ranking) e il Vector DB (pgvector, embeddings all-MiniLM-L6-v2). L'intuizione chiave: se gli item rankati hanno anche embedding ad alta dimensionalità, il ranking opera su **cluster** dello spazio, non su item individuali — rivelando correlazioni cross-dominio nascoste.

## Azione richiesta

Salvare l'intera discussione come documentazione persistente in:
- `/data/massimiliano/docs/preference-vector-theory.md` (documento operativo)
- `/home/massimiliano/.claude/projects/-data-massimiliano/memory/preference-vector-theory.md` (memoria Claude)
- Aggiornare MEMORY.md con riferimento

## Contenuto da salvare

### Concetti chiave

1. **Spazio semantico vs spazio preferenze**: embedding cattura "cosa le cose sono", ranking cattura "cosa significano per te". Il gap tra i due rivela pattern nascosti.

2. **Gaussian Process per preferenze**: f(embedding) → predicted_score + uncertainty. Generalizza il ranking a item mai confrontati. Kernel RBF con PCA a 30 dim.

3. **Serendipità**: tre metriche (pairwise surprise, neighborhood discordance, GP residual). Item semanticamente lontani ma preferenzialmente vicini → gusti latenti.

4. **Taste Embedding**: rappresentare l'utente come costellazione di cluster nello spazio embedding, pesati per BT score.

5. **Active Learning GP-aware**: acquisition functions (UCB, EI) che esplorano lo spazio embedding, non solo il grafo degli item.

6. **Implementazione**: Python microservice (FastAPI + sklearn GP), 256m RAM, API /discover/.

### Architettura proposta

```
/rank/     → preference-sort:8093  (Go, BT ranking esistente)
/discover/ → preference-gp:8096   (Python, GP + serendipità analysis)
                ↓
           PostgreSQL 16 (preference_sort + embeddings)
```

### Riferimenti teorici

- Bradley-Terry model (1952) — pairwise comparison ranking
- Gaussian Process Preference Learning (Chu & Ghahramani, 2005)
- Reward Modeling / RLHF (Christiano et al., 2017)
- Bayesian Optimization (Snoek et al., 2012)
- Collaborative Filtering (Netflix Prize, 2009)

## Verifica

Nessuna implementazione — solo documentazione da salvare.
