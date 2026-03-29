# Piano: Home WikiJS gerarchica — indice per cartelle

## Context

La home page WikiJS (`home.md`) è auto-generata da `generateHomePage()` in `import-docs.js`. Attualmente lista **tutte le singole pagine** in 6 sezioni flat, ignorando 6 directory (`research`, `papers`, `teoria`, `guides`, `design-validation`, `prompts`) e appiattendo le sotto-cartelle (`giardino-giapponese`, `adr`, `architecture`, ecc.).

L'utente vuole che la home sia un **indice di navigazione per cartelle** con mini-descrizione, che rispecchi esattamente la struttura directory. Le singole pagine non vanno listate — si trovano navigando nelle cartelle.

## Output atteso

```markdown
# Server SOL — Wiki

Documentazione completa dell'infrastruttura self-hosted Server SOL.

---

### Documentazione Operativa
Panoramica infrastruttura, rete, sicurezza, backup, monitoraggio, shell scripts.
*20 pagine*

---

### Servizi
Documentazione dei servizi Docker e host: proxy, code-server, monitoring, VPN, AI proxy.
*8 pagine*

---

### Librerie MCP
12 librerie Spring AI MCP Server pubblicate su Maven Central.
*13 pagine*

---

### Agent Framework
Framework multi-agent orchestration: architettura, fasi, research domains.
*16 pagine*

  - **ADR** — Architecture Decision Records *(4)*
  - **Architettura** — Diagrammi e design *(5)*
  - **Documentazione Fasi** — Storico implementazioni per fase *(9)*
  - **Manuale** — Guida utente *(1)*
  - **Branching** — Strategia branching *(1)*

---

### Progetti Futuri
Piani di implementazione per servizi e integrazioni.
*37 pagine*

  - **Giardino Giapponese** — Ricerca completa per giardino in Sardegna *(20)*
  - **Archivio** — Progetti archiviati *(1)*

---
... (research, papers, teoria, guide, varie, etc.)
```

## Struttura directory reale (da rispecchiare)

```
root/              (20 md) → "Documentazione Operativa"
servizi/           (8 md)  → "Servizi"
mcp/               (13 md) → "Librerie MCP"
agent-framework/   (16 md) → "Agent Framework"
  adr/             (4 md)
  architecture/    (5 md)
  documentazione/  (9 md)
  manual/          (1 md)
  branching/       (1 md)
progetti/          (37 md) → "Progetti Futuri"
  giardino-giapponese/ (20 md)
  archive/         (1 md)
research/          (122 md) → "Ricerca"
papers/            (110 md) → "Paper Accademici"
  kore-gc/         (1 md)
teoria/            (3 md)  → "Teoria"
guides/            (1 md)  → "Guide"
design-validation/ (1 md)  → "Design Validation"
prompts/           (1 md)  → "Prompt"
misc/              (4 md)  → "Varie"
kore-health/       (0 md)  → skip
```

## File da modificare

**Unico file**: `/data/massimiliano/wikijs/import-docs.js`

### 1. Aggiornare `TAG_MAP` (riga 26-34)

Aggiungere le directory mancanti:
```js
'research': ['ricerca', 'paper'],
'papers': ['paper', 'ricerca', 'bibliografia'],
'teoria': ['teoria', 'matematica'],
'guides': ['guida'],
'design-validation': ['validazione', 'design'],
'prompts': ['prompt', 'template'],
```

### 2. Riscrivere `generateHomePage()` (riga 346-378)

Nuova logica:

1. **Definire sezioni con meta-info** — oggetto ordinato con: chiave directory, nome display, descrizione breve
2. **Definire sotto-cartelle con nomi** — mappa `subDir → label` per quelle note (es. `adr` → `ADR`, `giardino-giapponese` → `Giardino Giapponese`)
3. **Contare pagine per directory** — dal `FILE_MAP`, contare `.md` per ogni prefix
4. **Generare markdown** — per ogni sezione:
   - `### Nome Sezione`
   - Descrizione (1 riga)
   - `*N pagine*` (count root files)
   - Per ogni sotto-cartella: `  - **Nome** — descrizione breve *(N)*`
5. **Separatore `---`** tra sezioni

Struttura dati:
```js
const SECTIONS = [
  { dir: 'docs',              name: 'Documentazione Operativa', desc: 'Panoramica infrastruttura, rete, sicurezza, backup, monitoraggio, shell scripts.' },
  { dir: 'servizi',           name: 'Servizi',                  desc: 'Documentazione dei servizi Docker e host.' },
  { dir: 'mcp',               name: 'Librerie MCP',             desc: 'Librerie Spring AI MCP Server per Maven Central.' },
  { dir: 'agent-framework',   name: 'Agent Framework',          desc: 'Framework multi-agent: architettura, fasi, research domains.' },
  { dir: 'progetti',          name: 'Progetti Futuri',          desc: 'Piani di implementazione per servizi e integrazioni.' },
  { dir: 'research',          name: 'Ricerca',                  desc: 'Note di ricerca su AI, graph DB, economia, matematica, fisica.' },
  { dir: 'papers',            name: 'Paper Accademici',         desc: 'Archivio paper importati con citazioni e metadati.' },
  { dir: 'teoria',            name: 'Teoria',                   desc: 'Fondamenti teorici: algebre di processo, PAC-Bayes, reti di Petri.' },
  { dir: 'guides',            name: 'Guide',                    desc: 'Guide pratiche e how-to.' },
  { dir: 'design-validation', name: 'Design Validation',        desc: 'Report di validazione design.' },
  { dir: 'prompts',           name: 'Prompt',                   desc: 'Template prompt per MCP e automazioni.' },
  { dir: 'misc',              name: 'Varie',                    desc: 'Documentazione varia: configurazione Claude Code, storage condiviso.' },
];

const SUBFOLDER_NAMES = {
  'adr': 'ADR',
  'architecture': 'Architettura',
  'documentazione': 'Documentazione Fasi',
  'manual': 'Manuale',
  'branching': 'Branching',
  'giardino-giapponese': 'Giardino Giapponese',
  'archive': 'Archivio',
  'kore-gc': 'KORE-GC Paper',
};
```

### 3. Logica conteggio pagine

Per ogni sezione `dir`:
- **Root pages**: entries in FILE_MAP dove `path.split('/')[0] === dir` (o `'docs'` per root) e non hanno ulteriori sotto-directory
- **Sub-folder pages**: entries dove il path ha 3+ segmenti (es. `agent-framework/adr/adr-001`)
- **Auto-discover sub-folders**: non hardcodare — raccogliere i segmenti intermedi dal FILE_MAP

### 4. Link alle cartelle

Ogni sezione top-level linka alla prima pagina indice della cartella (se esiste `index.md` o `indice.md` o `overview.md`), altrimenti solo testo.

Ogni sotto-cartella NON linka (non c'è una pagina indice per ogni sub-dir) — è solo testo + count.

## Verifica

1. `node /data/massimiliano/wikijs/import-docs.js --scan` — tutte le directory trovate
2. Aggiungere flag `--preview-home` che stampa solo il markdown della home senza importare
3. `node /data/massimiliano/wikijs/import-docs.js --update` — aggiornare in WikiJS
4. Verificare su `https://wiki.massimilianopili.com/en/home`
