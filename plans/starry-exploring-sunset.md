# Piano: Documentazione NotebookLM

## Contesto
Conversazione esplorativa su Google NotebookLM. L'utente chiede di documentare i risultati della ricerca, con focus su graph e vector (confronto con stack SOL).

## Azione
Creare un file markdown `/data/massimiliano/docs/notebooklm.md` con:

1. Cos'è NotebookLM (breve)
2. Funzionalità principali (elenco)
3. Supporto YouTube
4. API (ufficiale Enterprise + client non ufficiali)
5. **Confronto architetturale con stack SOL**: NotebookLM come RAG consumer vs pgvector + AGE knowledge graph + MCP vector tools come equivalente self-hosted
6. **Vantaggi stack SOL**: controllo completo, nessuna dipendenza API instabili, graph database (AGE + Neo4j) per relazioni strutturate che NotebookLM non ha, embeddings custom via Ollama

## Verifica
- Il file è leggibile e completo
- Verrà sincronizzato su WikiJS via docs-sync
