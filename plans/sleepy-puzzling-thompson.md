# Piano: Aggiornamento architecture.html con Gaia e stato attuale

## Context

Il diagramma architetturale a `/data/massimiliano/proxy/home/architecture.html` è obsoleto: mostra ~18 servizi su una architettura single-server, ma l'infrastruttura reale comprende ~42 container Docker, 2 server fisici (SOL + Gaia), e diversi servizi aggiunti negli ultimi mesi. L'utente vuole aggiornare il diagramma per riflettere lo stato attuale, con focus su Gaia come GPU coprocessor.

## File da modificare

1. **`/data/massimiliano/proxy/home/static/icons/simple-icons.json`** — aggiungere 5 nuove icone (ollama, searxng, spring, nvidia, anki). SVG già scaricati da Simple Icons GitHub.
2. **`/data/massimiliano/proxy/home/architecture.html`** — sezione `<pre class="mermaid">` (righe 241-398) + legenda (righe 211-232)

## Step 1: Aggiungere icone a simple-icons.json

Aggiungere questi 5 entry all'oggetto `icons`:

| Chiave | Sorgente |
|--------|----------|
| `ollama` | `raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/ollama.svg` |
| `searxng` | idem `/searxng.svg` |
| `spring` | idem `/spring.svg` |
| `nvidia` | idem `/nvidia.svg` |
| `anki` | idem `/anki.svg` |

Formato: estrarre solo il contenuto `<path d="..."/>` dal SVG, wrapparlo come `"body": "<path fill=\"currentColor\" d=\"...\"/>"`.

## Step 2: Aggiornare il diagramma Mermaid

### 2a. Aggiungere Server Gaia (subgraph separato in basso)
```mermaid
subgraph gaia ["Server Gaia — GPU Coprocessor"]
    direction LR
    GaiaOllama@{ icon: "simple-icons:ollama", form: "square", label: "Ollama (RTX 3090)" }
end
```
- Connesso da `OllamaSocat` su SOL via freccia `-->|"Tailscale TCP"|`
- Style: nuovo `gaiaStyle` (fill distinto, es. #1a2a1a, stroke #4aff8c — verde scuro per hardware GPU)

### 2b. Fix PostgreSQL e rimuovere Neo4j
- `PG` label: `"PostgreSQL 16"` → `"PostgreSQL 18 + AGE"`
- Rimuovere: `Neo4j_DB`, `Neo4jUI` (nodi + edges + click + class assignments)
- `KGraph` edge: `KGraph -->|Bolt| Neo4j_DB` → `KGraph -->|AGE Cypher| PG`

### 2c. Aggiungere subgraph MCP (nuovo, tra infra e data)
```mermaid
subgraph mcp ["MCP Ecosystem"]
    direction LR
    MCPProxy@{ icon: "fa6-solid:shield-halved", form: "square", label: "mcp-proxy" }
    SimogeMCP@{ icon: "simple-icons:spring", form: "square", label: "simoge-mcp (234 tools)" }
    SearXNG@{ icon: "simple-icons:searxng", form: "square", label: "SearXNG" }
    OllamaSocat@{ icon: "simple-icons:ollama", form: "square", label: "Ollama (socat)" }
end
```
Edges:
- `MCPProxy --> SimogeMCP`
- `SimogeMCP --> PG`
- `SimogeMCP --> Redis_DB`
- `SimogeMCP --> SearXNG`
- `SimogeMCP --> OllamaSocat`
- `OllamaSocat -->|"Tailscale TCP"| GaiaOllama`

### 2d. Aggiungere servizi mancanti nel subgraph web
- `EmbedViz@{ icon: "fa6-solid:diagram-project", form: "square", label: "/embeddings/ Viz" }` — JWT
- `AnkiAPI@{ icon: "simple-icons:anki", form: "square", label: "/anki/ Anki" }` — JWT

### 2e. Aggiornare nodi esistenti
- `ClaudeProxy` label: `"/claude/ Anthropic API"` → `"/claude/ AI Proxy (multi)"` (riflette multi-provider)
- `Docs` label: `"/docs/ Swagger"` → `"/docs/ MkDocs + Swagger"`

### 2f. Aggiornare Cloudflare Tunnel
- `Tunnel` label aggiornata con i 4 hostname
- Edge label: `-->|":8888 :8889 :8891 :8095"|`

### 2g. Aggiornare classDef e class assignments
- Nuovo `gaiaStyle fill:#1a2a1a,stroke:#4aff8c,color:#e1e4ed,stroke-width:2px`
- `class GaiaOllama gaiaStyle`
- `class EmbedViz,AnkiAPI jwt`
- `class SimogeMCP,MCPProxy,SearXNG,OllamaSocat infraStyle`
- Rimuovere `Neo4jUI` da class oauth, `Neo4j_DB` da class infraStyle

### 2h. Click links
- Aggiungere: `click EmbedViz "/embeddings/"`, `click AnkiAPI "/anki/api/"`
- Rimuovere: `click Neo4jUI "/neo4j/"`

## Step 3: Aggiornare legenda HTML

Aggiungere nella sezione `.legend`:
```html
<div class="legend-line">
    <div class="legend-item"><div class="legend-dot" style="background:#1a2a1a;border-color:#4aff8c;"></div>Gaia GPU</div>
</div>
```

## Vincoli

- Mantenere tutta la struttura HTML/CSS/JS invariata (pan-zoom, loading, etc.)
- Solo contenuto Mermaid, legenda, e icon pack JSON cambiano
- I nodi devono restare clickable dove possibile
- Il diagramma deve restare leggibile — non sovraccaricare

## Verifica

1. Aprire `https://sol.massimilianopili.com/architecture.html` nel browser (Playwright o manuale)
2. Verificare che il diagramma renderizza senza errori Mermaid v11
3. Verificare che Gaia appare come server separato connesso via Tailscale
4. Verificare nuove icone (ollama, searxng, spring, nvidia, anki) renderizzano
5. Click sui nodi → navigazione corretta
6. Zoom/pan funziona come prima
