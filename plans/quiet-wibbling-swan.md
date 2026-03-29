# Fix: Embedding Column Exposure + SQL Injection in mcp-sql-tools

## Context
Task #185 audit found two vulnerabilities in `DatabaseTools.java`:
1. **`db_query`** — arbitrary SELECT can extract raw pgvector embeddings (Zero2Text makes embeddings ≈ plaintext)
2. **`db_count`** — WHERE clause is string-concatenated → SQL injection

Both are mitigated by HMAC auth, but defense-in-depth requires fixing them.

## File to modify
`/data/massimiliano/Vari/mcp-sql-tools/src/main/java/io/github/massimilianopili/mcp/sql/DatabaseTools.java`

## Progress
- [x] Code fix in `DatabaseTools.java` (all 3 validation methods + constants)
- [x] Compiled and locally installed (`mvn install`)
- [x] Committed: `fafff5d` — "security: block embedding column extraction and SQL injection in WHERE clause"
- [x] Pushed to Gitea with tags `v0.1.2` + `g0.1.2`
- [ ] **Pipeline #636** (`release.yml` → Maven Central) — still in progress
- [ ] Bump `mcp/pom.xml` dependency `mcp-sql-tools` from `0.1.1` → `0.1.2`
- [ ] `sol deploy mcp` — rebuild MCP server with new jar
- [ ] Verify security checks via MCP tools

## Remaining steps (TDT: publish first, then update consumer)

1. **Wait** for pipeline #636 (`release.yml` → Maven Central) to complete
   - Also check if `deploy-gitea.yml` ran for `g0.1.2` (Gitea registry)
   - Verify `0.1.2` available: check Gitea packages or Maven Central
2. **Only after 0.1.2 is published**: edit `/data/massimiliano/Vari/mcp/pom.xml` line 82: `0.1.1` → `0.1.2`
3. `sol deploy mcp` — Docker build resolves from Gitea registry (first) / Maven Central (fallback)
4. Test:
   - `db_query("SELECT embedding FROM some_table")` → should throw SecurityException
   - `db_query("SELECT * FROM vector_store")` → should throw SecurityException
   - `db_query("SELECT id, content FROM vector_store LIMIT 1")` → should work
   - `db_count("vector_store", "1=1; DROP TABLE x")` → should throw SecurityException
