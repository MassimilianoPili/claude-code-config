# Piano: Download Decompiled ROMs + AGE Code Graph Embedding via MCP

## Context

In Chat `19a6ff10` hai creato `PIANO_RETRO_GAME.md` — un progetto per creare **"Crypt of Echoes"**, un roguelike Game Boy. L'idea: l'intero programma sta nella context window di un LLM.

Ora vuoi:
1. **Scaricare TUTTI i ROM decompilati** disponibili come reference architetturale
2. **Embeddarli in AGE `code_graph`** come struttura codice (funzioni, label, relazioni CALLS/BELONGS_TO)
3. Usare **MCP tools** per query e navigazione del grafo codice

---

## Fase 1 — Clone tutti i repo

**Directory separata**: `/data/massimiliano/retro-decomps/` (fuori da `retro-game-gb/`)

### Game Boy (DMG/GBC)

```bash
mkdir -p /data/massimiliano/retro-decomps/gb
cd /data/massimiliano/retro-decomps/gb
git clone https://github.com/osnr/tetris.git                        # Tetris (32KB, complete)
git clone https://github.com/pret/pokered.git                       # Pokemon Red/Blue (complete, 4.6K stars)
git clone https://github.com/pret/pokecrystal.git                   # Pokemon Crystal (complete, 2.4K stars)
git clone https://github.com/pret/pokeyellow.git                    # Pokemon Yellow (complete)
git clone https://github.com/pret/pokegold.git                      # Pokemon Gold (complete)
git clone https://github.com/pret/poketcg.git                       # Pokemon TCG (complete)
git clone https://github.com/zladx/LADX-Disassembly.git             # Zelda Link's Awakening DX (complete, 880 stars)
git clone https://github.com/CelestialAmber/DKGBDisasm.git          # Donkey Kong '94 (WIP)
git clone https://github.com/pret/pokepinball.git                   # Pokemon Pinball (WIP)
```

### NES

```bash
mkdir -p /data/massimiliano/retro-decomps/nes
cd /data/massimiliano/retro-decomps/nes
git clone https://github.com/cyneprepou4uk/NES-Games-Disassembly.git  # 20+ giochi completi (226 stars)
git clone https://github.com/vermiceli/nes-contra-us.git              # Contra (complete)
git clone https://github.com/vermiceli/nes-super-c.git                # Super C (complete)
git clone https://github.com/LuigiBlood/balloonfight_dis.git          # Balloon Fight (complete)
git clone https://github.com/RussianManSMWC/Donkey-Kong-NES-Disassembly.git  # DK (complete)
git clone https://github.com/Nostaljipi/dr-mario-disassembly.git      # Dr. Mario (complete)
```

### SNES

```bash
mkdir -p /data/massimiliano/retro-decomps/snes
cd /data/massimiliano/retro-decomps/snes
git clone https://github.com/snesrev/zelda3.git                     # Zelda ALTTP (C, complete, 4.5K stars) — LIVE!
git clone https://github.com/snesrev/smw.git                        # Super Mario World (C, complete)
git clone https://github.com/snesrev/sm.git                         # Super Metroid (C, complete)
git clone https://github.com/brunovalads/yoshisisland-disassembly.git  # Yoshi's Island (ASM, complete, 151 stars)
git clone https://github.com/Herringway/ebsrc.git                   # Earthbound (WIP, 200 stars)
git clone https://github.com/p4plus2/DKC2-disassembly.git           # DKC2 (WIP)
git clone https://github.com/Yoshifanatic1/Donkey-Kong-Country-1-Disassembly.git  # DKC1 (WIP)
```

### GBA

```bash
mkdir -p /data/massimiliano/retro-decomps/gba
cd /data/massimiliano/retro-decomps/gba
git clone https://github.com/pret/pokeemerald.git                   # Pokemon Emerald (C, complete, 3K stars)
git clone https://github.com/pret/pokefirered.git                   # Pokemon FireRed (C, complete, 1.2K stars)
git clone https://github.com/pret/pokeruby.git                      # Pokemon Ruby (C, complete)
git clone https://github.com/pret/pokepinballrs.git                 # Pokemon Pinball RS (WIP)
git clone https://github.com/pret/pmd-red.git                       # PMD Red Rescue Team (WIP)
git clone https://github.com/zeldaret/tmc.git                       # Zelda Minish Cap (C, complete, 600 stars)
git clone https://github.com/FireEmblemUniverse/fireemblem8u.git     # FE Sacred Stones (WIP, 300 stars)
git clone https://github.com/metroidret/mzm.git                     # Metroid Zero Mission (WIP)
git clone https://github.com/metroidret/mf.git                      # Metroid Fusion (WIP)
git clone https://github.com/jiangzhengwenjz/katam.git              # Kirby Amazing Mirror (WIP)
git clone https://github.com/testyourmine/cvaos.git                 # Castlevania AoS (WIP)
git clone https://github.com/lilDavid/warioland4.git                # Wario Land 4 (WIP)
git clone https://github.com/SAT-R/sa2.git                          # Sonic Advance 2 (WIP)
git clone https://github.com/jellees/mksc.git                       # Mario Kart Super Circuit (WIP)
git clone https://github.com/Eebit/aw2bhr.git                       # Advance Wars 2 (WIP)
```

### Genesis

```bash
mkdir -p /data/massimiliano/retro-decomps/genesis
cd /data/massimiliano/retro-decomps/genesis
git clone https://github.com/sonicretro/s1disasm.git                # Sonic 1 (complete, 200 stars)
git clone https://github.com/sonicretro/s2disasm.git                # Sonic 2 (complete)
git clone https://github.com/sonicretro/skdisasm.git                # Sonic 3&K (complete)
```

### N64 (--depth 1 per risparmiare spazio)

```bash
mkdir -p /data/massimiliano/retro-decomps/n64
cd /data/massimiliano/retro-decomps/n64
git clone --depth 1 https://github.com/n64decomp/sm64.git           # Super Mario 64 (C, complete, 8.5K stars)
git clone --depth 1 https://github.com/zeldaret/oot.git              # Zelda OoT (C, complete, 5.3K stars)
git clone --depth 1 https://github.com/pmret/papermario.git          # Paper Mario (C, complete, 2K stars)
git clone --depth 1 https://github.com/n64decomp/mk64.git           # Mario Kart 64 (WIP)
git clone --depth 1 https://github.com/AngheloAlf/drmario64.git     # Dr. Mario 64 (WIP, puzzle)
git clone --depth 1 https://github.com/AngheloAlf/puzzleleague64.git  # Pokemon Puzzle League (WIP, puzzle)
git clone --depth 1 https://github.com/sonicdcer/sf64.git           # Star Fox 64 (WIP)
git clone --depth 1 https://github.com/n64decomp/banjo-kazooie.git  # Banjo-Kazooie (WIP ~70%)
```

### Totale: ~50 repo, stima ~4-6 GB

---

## Fase 2 — `mcp-code-graph-tools` (Java Spring Boot MCP library)

**Dir**: `/data/massimiliano/Vari/mcp-code-graph-tools/`
**Pattern**: segue `mcp-graph-tools` (AGE via JdbcTemplate) + `mcp-vector-tools` (pgvector search)

### Stato attuale (5 file creati)

| File | Stato | Contenuto |
|------|-------|-----------|
| `pom.xml` | OK | Java 21, tree-sitter-jni 1.12.0, spring-ai 1.1.1, spring-boot 3.5.11 |
| `CodeGraphProperties.java` | OK | Config: decompsDir, graphName, batchSize, bodyPreviewMaxChars |
| `CodeGraphAutoConfiguration.java` | OK | Wiring beans (references 3 missing classes) |
| `parser/CodeElement.java` | OK | Record: FUNCTION, LABEL, STRUCT, ENUM, TYPEDEF, INCLUDE, MACRO |
| `parser/CallReference.java` | OK | Record: callerName, targetName, filePath, line |
| `parser/ParseResult.java` | OK | Container: elements + calls per file |

### File da creare (7 file, ~800 righe)

#### 2a. `parser/CodeParser.java` — Interface

```java
public interface CodeParser {
    boolean supports(String extension);
    ParseResult parse(Path file, int bodyPreviewMaxChars);
}
```

#### 2b. `parser/CParser.java` — tree-sitter JNI per C/H

Usa `ch.usi.si.seart:java-tree-sitter:1.12.0` (già in `.m2`).
- Parsa `function_definition` → CodeElement.FUNCTION (name, signature, body preview)
- Parsa `struct_specifier` → CodeElement.STRUCT
- Parsa `call_expression` → CallReference (caller → callee)
- Parsa `preproc_include` → CodeElement.INCLUDE
- Supporta: `.c`, `.h`

#### 2c. `parser/AsmParser.java` — Regex parser per assembly

Sottoclassi per ISA, strategy pattern per le istruzioni di call/jump:

| ISA | File | Extensions | Call patterns | Label patterns |
|-----|------|-----------|---------------|----------------|
| Z80/GBZ80 | `Z80AsmParser` | `.asm`, `.inc` (RGBDS) | `CALL`, `JP`, `JR`, `RST` | `name:` (col 0), `SECTION` |
| 6502 | `M6502AsmParser` | `.asm`, `.s` (ca65) | `JSR`, `JMP` | `.proc`/`.endproc`, labels |
| 65816 | `M65816AsmParser` | `.asm` | `JSR`, `JSL`, `JMP`, `JML` | labels, `SECTION` |
| 68000 | `M68kAsmParser` | `.asm` | `BSR`, `JSR`, `JMP` | labels |
| ARM | `ArmAsmParser` | `.s` | `BL`, `B` | labels, `.global` |

Pattern comune regex:
```java
// Label: riga che inizia con un identificatore seguito da ':'
Pattern LABEL = Pattern.compile("^([A-Za-z_][A-Za-z0-9_.]*):(?:\\s|$)");
// Call: istruzione di branch/call
Pattern CALL = Pattern.compile("(?i)\\b(CALL|JSR|BL)\\s+([A-Za-z_][A-Za-z0-9_.]*)");
```

Ogni parser identifica:
1. **Labels** (definizioni di funzione/data) → `CodeElement.LABEL`
2. **Call references** (istruzioni di branch) → `CallReference`
3. **Include directives** → `CodeElement.INCLUDE`

#### 2d. `parser/CodeParserRegistry.java` — Registry

```java
public class CodeParserRegistry {
    private final List<CodeParser> parsers;
    // Auto-registers: CParser, Z80AsmParser, M6502AsmParser, M65816AsmParser, M68kAsmParser, ArmAsmParser
    public Optional<CodeParser> parserFor(String extension) { ... }
    public Optional<CodeParser> parserFor(Path file) { ... }
}
```

Logica di selezione per piattaforma: il parser corretto viene scelto in base all'estensione del file E alla directory parent (gb/→Z80, nes/→6502, snes/→65816 o C, gba/→ARM o C, genesis/→68k, n64/→C).

#### 2e. `graph/AgeCodeGraphService.java` — AGE Cypher execution

Segue il pattern esatto di `AgeCypherExecutor` in `mcp-graph-tools`:

```java
public class AgeCodeGraphService {
    private final JdbcTemplate jdbc;
    private final String graphName;  // "code_graph"

    // Cypher execution via AGE SQL wrapper
    public List<Map<String, Object>> query(String cypher) {
        String sql = "SELECT * FROM cypher('" + graphName + "', $$ " + cypher + " $$) AS (result agtype)";
        // Parse agtype → JSON via cleanAgtype() + Jackson
    }

    // Write (MERGE/CREATE) — no result needed
    public void write(String cypher) {
        String sql = "SELECT * FROM cypher('" + graphName + "', $$ " + cypher + " $$) AS (result agtype)";
        jdbc.execute(sql);
    }

    // Init: LOAD 'age', SET search_path, create_graph if not exists
    public void initGraph() { ... }

    // Batch import: Project → File → Function/Label → CALLS
    public void importProject(String name, String platform, String language, Path dir, List<ParseResult> results) {
        // 1. MERGE Project node
        // 2. MERGE File nodes + CONTAINS relations
        // 3. MERGE Function/Label nodes + DEFINES relations
        // 4. MERGE CALLS relations
        // Batch: 20 statements per transaction (from props.batchSize)
    }

    // Escape string for Cypher (single-quote safe)
    private String esc(String s) {
        return s.replace("\\", "\\\\").replace("'", "\\'").replace("\n", " ");
    }
}
```

#### 2f. `tools/CodeGraphTools.java` — MCP tool entry points

```java
@Service
@ConditionalOnProperty(name = "mcp.codegraph.enabled", havingValue = "true")
public class CodeGraphTools {

    @Tool(name = "code_import",
          description = "Import a decompiled project into the code_graph. Parses source files, "
                      + "extracts functions/labels/calls, creates AGE nodes and relationships.")
    public Map<String, Object> codeImport(
        @ToolParam(description = "Project directory path") String projectDir,
        @ToolParam(description = "Platform: gb, nes, snes, gba, genesis, n64") String platform,
        @ToolParam(description = "Project name (default: directory name)", required = false) String name)

    @Tool(name = "code_import_all",
          description = "Import all projects from the retro-decomps directory into code_graph.")
    public Map<String, Object> codeImportAll()

    @Tool(name = "code_search",
          description = "Search functions and labels in the code graph by name pattern.")
    public List<Map<String, Object>> codeSearch(
        @ToolParam(description = "Function/label name pattern (regex)") String pattern,
        @ToolParam(description = "Filter by platform", required = false) String platform,
        @ToolParam(description = "Filter by project", required = false) String project)

    @Tool(name = "code_callers",
          description = "Find all callers of a function/label in the code graph.")
    public List<Map<String, Object>> codeCallers(
        @ToolParam(description = "Target function/label name") String name,
        @ToolParam(description = "Filter by project", required = false) String project)

    @Tool(name = "code_callees",
          description = "Find all functions/labels called by a given function.")
    public List<Map<String, Object>> codeCallees(
        @ToolParam(description = "Caller function name") String name,
        @ToolParam(description = "Filter by project", required = false) String project)

    @Tool(name = "code_file_tree",
          description = "Get the file tree of a project in the code graph.")
    public List<Map<String, Object>> codeFileTree(
        @ToolParam(description = "Project name") String project)

    @Tool(name = "code_stats",
          description = "Get statistics about the code graph: projects, files, functions, labels, calls.")
    public Map<String, Object> codeStats(
        @ToolParam(description = "Filter by project", required = false) String project)
}
```

#### 2g. `META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`

```
io.github.massimilianopili.mcp.codegraph.CodeGraphAutoConfiguration
```

### Schema AGE `code_graph`

```
Nodi:
  - Project {name, platform, language, status, genre}
  - File {path, name, extension, project, size_bytes}
  - Function {name, file_path, project, line_start, line_end, language, signature, body_preview}
  - Label {name, file_path, project, line, type}
  - DataStructure {name, file_path, project, type}

Relazioni:
  - (Project)-[:CONTAINS]->(File)
  - (File)-[:DEFINES]->(Function)
  - (File)-[:DEFINES]->(Label)
  - (File)-[:DEFINES]->(DataStructure)
  - (Function)-[:CALLS]->(Function)
  - (Function)-[:CALLS]->(Label)
  - (Function)-[:REFERENCES]->(DataStructure)
  - (File)-[:INCLUDES]->(File)
```

### Pattern chiave: AGE SQL wrapper (da `mcp-graph-tools/AgeCypherExecutor.java`)

```java
// Execute
String sql = "SELECT * FROM cypher('" + graphName + "', $$ " + cypher + " $$) AS (result agtype)";
// Parse result
String agtype = rs.getString("result");
String cleaned = agtype.replaceAll("::vertex|::edge|::path|::numeric|::integer|::float|::boolean|::string", "");
Object parsed = mapper.readValue(cleaned, Object.class);
// Init
"LOAD 'age'; SET search_path = ag_catalog, \"$user\", public"
```

### File chiave da riusare

| Pattern | File sorgente | Cosa riusare |
|---------|---------------|--------------|
| AGE SQL wrapper | `Vari/mcp-graph-tools/.../AgeCypherExecutor.java` | `cypher()` template, `cleanAgtype()`, `initGraph()` |
| Auto-configuration | `Vari/mcp-graph-tools/.../GraphConfig.java` | `connectionInitSql`, HikariDataSource config |
| MCP tool annotations | `Vari/mcp-vector-tools/.../VectorTools.java` | `@Tool`, `@ToolParam`, error handling pattern |
| Cypher escaping | `kindle/paper_archive.py` → `esc()` | Single-quote + newline escaping |

---

## Fase 3 — Integrazione in `simoge-mcp`

Aggiungere dipendenza al pom.xml di simoge-mcp e configurare in `.env`:

```xml
<!-- Vari/mcp/pom.xml -->
<dependency>
    <groupId>io.github.massimilianopili</groupId>
    <artifactId>mcp-code-graph-tools</artifactId>
    <version>0.1.0</version>
</dependency>
```

```env
# Vari/mcp/.env
MCP_CODEGRAPH_ENABLED=true
MCP_CODEGRAPH_DECOMPS_DIR=/data/massimiliano/retro-decomps
MCP_CODEGRAPH_GRAPH_NAME=code_graph
MCP_CODEGRAPH_PG_DATABASE=embeddings
```

La libreria riusa la stessa DataSource AGE configurata in `mcp-graph-tools` (stesso DB `embeddings`, stessa connessione).
Alternativa: `@Qualifier("ageDataSource")` se il bean esiste, altrimenti crea il proprio.

---

## Struttura directory finale

```
/data/massimiliano/
├── retro-decomps/              # DONE: 48 repo clonati, 3.3 GB, 148K files
│   ├── gb/     (9 repo)
│   ├── nes/    (6 repo, uno contiene 20+ giochi)
│   ├── snes/   (7 repo, inclusi snesrev C)
│   ├── gba/    (15 repo)
│   ├── genesis/ (3 repo)
│   └── n64/    (8 repo, depth 1)
└── Vari/mcp-code-graph-tools/  # NUOVO: MCP library
    ├── pom.xml                 # DONE
    └── src/main/java/.../codegraph/
        ├── CodeGraphProperties.java         # DONE
        ├── CodeGraphAutoConfiguration.java  # DONE
        ├── parser/
        │   ├── CodeElement.java             # DONE
        │   ├── CallReference.java           # DONE
        │   ├── ParseResult.java             # DONE
        │   ├── CodeParser.java              # TODO: interface
        │   ├── CParser.java                 # TODO: tree-sitter JNI
        │   ├── CodeParserRegistry.java      # TODO: registry
        │   ├── Z80AsmParser.java            # TODO: GB parser
        │   ├── M6502AsmParser.java          # TODO: NES parser
        │   ├── M65816AsmParser.java         # TODO: SNES parser
        │   ├── M68kAsmParser.java           # TODO: Genesis parser
        │   └── ArmAsmParser.java            # TODO: GBA parser
        ├── graph/
        │   └── AgeCodeGraphService.java     # TODO: AGE queries
        └── tools/
            └── CodeGraphTools.java          # TODO: 7 MCP tools
```

## Ordine di esecuzione

1. ~~Clone repos~~ DONE — 48 repo, 3.3 GB
2. **Scrivere parser interface + registry** (`CodeParser.java`, `CodeParserRegistry.java`)
3. **Scrivere ASM parsers** (Z80, 6502, 65816, 68k, ARM — tutti regex-based, ~80 righe ciascuno)
4. **Scrivere C parser** (`CParser.java` — tree-sitter JNI, ~120 righe)
5. **Scrivere AgeCodeGraphService** (AGE queries + batch import, ~200 righe)
6. **Scrivere CodeGraphTools** (7 MCP tools, ~250 righe)
7. **Aggiungere Spring Boot auto-config imports** file
8. **Build** (`mvn clean install`)
9. **Integrare in simoge-mcp** (pom.xml + .env)
10. **Deploy + test** (`code_import` su Tetris GB, poi `code_import_all`)

## Verifica

- [ ] `mvn clean install` su mcp-code-graph-tools senza errori
- [ ] `code_import` su Tetris GB crea nodi in AGE `code_graph`
- [ ] `graph_query("MATCH (p:Project) RETURN {name: p.name}", backend="age")` mostra "tetris"
- [ ] `code_search("main")` trova le funzioni main dei vari progetti
- [ ] `code_callers("VBlankHandler")` in Tetris mostra chi chiama il VBlank handler
- [ ] `code_stats()` mostra conteggi corretti
- [ ] `code_import_all` completa su tutti i 48 progetti
- [ ] snesrev repos (zelda3, smw, sm) parsificati con CParser (C source)
- [ ] Deploy simoge-mcp aggiornato funzionante

## Risorse

- **Catalogo completo 250+ progetti**: `/home/massimiliano/.claude/plans/snug-inventing-barto-agent-aebe2b7e800e900e6.md`
- **Ricerca tool parsing**: `/home/massimiliano/.claude/plans/snug-inventing-barto-agent-ab28a6ab26b608e96.md`
- **Piano Crypt of Echoes**: `/data/massimiliano/progetti_futuri/PIANO_RETRO_GAME.md`
- **AGE executor pattern**: `Vari/mcp-graph-tools/.../AgeCypherExecutor.java`
- **AGE config pattern**: `Vari/mcp-graph-tools/.../GraphConfig.java`
- **MCP tool pattern**: `Vari/mcp-vector-tools/.../VectorTools.java`
- **tree-sitter JNI**: `~/.m2/repository/ch/usi/si/seart/java-tree-sitter/1.12.0/` (available)
