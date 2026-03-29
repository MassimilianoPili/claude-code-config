# Piano: Documentare Concept Extraction da Kindle Highlights

## Contesto

La Fase 1 (import `My Clippings.txt` → Neo4j) e' completata: lo script `import_kindle.py` crea nodi
`(:Author)`, `(:Book)`, `(:Highlight)` con relazioni `[:WRITTEN_BY]` e `[:FROM]`.

L'utente vuole documentare la **Fase 2**: usare Claude per analizzare gli highlight importati,
estrarre concetti/topic, e creare nodi `(:Concept)` con relazioni `[:MENTIONS]` e `[:RELATED_TO]`
nel grafo Neo4j. Questo abilita query strutturali cross-book ("quali autori parlano dello stesso concetto?").

---

## Cosa creare

### 1. File `progetti_futuri/PIANO_KINDLE_GRAPH_ENRICHMENT.md`

Piano dettagliato per l'arricchimento del grafo Kindle con concept extraction:

- **Obiettivo**: estrarre concetti/topic dagli highlight e creare un knowledge graph navigabile
- **Modello grafo esteso**: `(:Highlight)-[:MENTIONS]->(:Concept)-[:RELATED_TO]->(:Concept)`
- **Approccio**: batch processing — leggere highlight dal grafo via `graph_query`, passarli a Claude per estrarre concetti, scrivere i risultati via `graph_write`
- **Prompt engineering**: prompt per estrarre 1-5 concetti per highlight con categoria (tema, persona, framework, metafora, etc.)
- **Deduplicazione concetti**: MERGE su nome normalizzato (lowercase, trim)
- **Relazioni RELATED_TO**: Claude identifica connessioni tra concetti di libri diversi
- **Query patterns abilitati**: "concetti in comune tra libro A e B", "tutti gli highlight su [concetto]", "mappa concettuale di [autore]"
- **Formato**: seguire lo stile degli altri piani (Fasi numerate, comandi, confronti)

### 2. Aggiornamento `docs/vector-db-strategy.md`

Aggiungere una sezione "Kindle Knowledge Graph" dopo la sezione "Neo4j" (riga ~34), che documenta:

- Lo stato attuale (Fase 1 completata: Book/Author/Highlight)
- Il piano Fase 2 (Concept extraction)
- Il modello grafo completo (ASCII)
- Come si integra con vector search (hybrid retrieval: vector per discovery semantico, graph per navigazione strutturale)

---

## File coinvolti

| File | Azione |
|------|--------|
| `progetti_futuri/PIANO_KINDLE_GRAPH_ENRICHMENT.md` | **Nuovo** — piano concept extraction |
| `docs/vector-db-strategy.md` | **Modifica** — sezione Kindle Knowledge Graph |
