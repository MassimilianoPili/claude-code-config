# Push SAST fixes su Gitea — comando unico

## Context

Fix CRITICAL C1-C3 completati localmente. Serve push su Gitea di 4 repo:
- **solsec** (nuovo) — libreria validazione/sanificazione condivisa
- **kp-manager** (nuovo) — fix C1 argument injection
- **knowledge-graph** (nuovo) — fix C2 ReDoS
- **gitea-config** (esistente) — fix C3 Docker socket act-runner

I symlink `solsec/` esistono in kp-manager e knowledge-graph e vanno esclusi da git (`.gitignore`).

## Comando unico

```bash
# === 0. Token API temporaneo ===
TOKEN=$(docker exec -u git gitea gitea admin user generate-access-token --username sol_root --token-name sast-push --scopes repo 2>&1 | grep -oP '(?<=: ).*') && \
echo "Token: $TOKEN" && \
API="http://127.0.0.1/git/api/v1" && \
\
# === 1. Creare 3 repo vuoti su Gitea ===
curl -sf -X POST "$API/user/repos" -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"solsec","description":"Shared Go validation/sanitization library for Server SOL","private":false,"auto_init":false}' > /dev/null && \
curl -sf -X POST "$API/user/repos" -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"kp-manager","description":"KeePass password manager web UI","private":false,"auto_init":false}' > /dev/null && \
curl -sf -X POST "$API/user/repos" -H "Authorization: token $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"knowledge-graph","description":"D3.js graph viewer for Neo4j knowledge graph","private":false,"auto_init":false}' > /dev/null && \
echo "Repos created" && \
\
# === 2. SOLSEC — init + push + tag ===
cd /data/massimiliano/Vari/solsec && \
git init && git add -A && \
git commit -m "Initial commit: solsec validation/sanitization library

Shared Go module for input validation, regex escaping, path traversal
prevention. Used by kp-manager (C1 fix) and knowledge-graph (C2 fix).
Functions: ValidateCLIFields, EscapeRegex, SanitizeFileName, SafePath.
11 tests passing." && \
git remote add origin ssh://git@gitea-local:222/sol_root/solsec.git && \
git push -u origin main && \
git tag v0.1.0 && \
git push origin v0.1.0 && \
echo "solsec pushed + tagged" && \
\
# === 3. KP-MANAGER — .gitignore + init + push ===
cd /data/massimiliano/Vari/kp-manager && \
echo "solsec" >> .gitignore && \
git init && git add -A && \
git commit -m "Initial commit: kp-manager with solsec integration (C1 fix)

KeePass password manager web UI. Integrates solsec.ValidateCLIFields()
to prevent argument injection in keepassxc-cli commands.
Added -- sentinel before positional args in AddEntry/EditEntry." && \
git remote add origin ssh://git@gitea-local:222/sol_root/kp-manager.git && \
git push -u origin main && \
echo "kp-manager pushed" && \
\
# === 4. KNOWLEDGE-GRAPH — .gitignore + init + push ===
cd /data/massimiliano/knowledge-graph && \
printf "solsec\n" > .gitignore && \
git init && git add -A && \
git commit -m "Initial commit: knowledge-graph with solsec integration (C2 fix)

D3.js graph viewer for Neo4j. Integrates solsec.EscapeRegex() to prevent
ReDoS via unescaped user input in Neo4j regex patterns." && \
git remote add origin ssh://git@gitea-local:222/sol_root/knowledge-graph.git && \
git push -u origin main && \
echo "knowledge-graph pushed" && \
\
# === 5. GITEA-CONFIG — commit + push ===
cd /data/massimiliano/gitea && \
git add docker-compose.yml && \
git commit -m "Security: act-runner Docker socket :ro + no-new-privileges (C3 fix)

Changed Docker socket mount from RW to :ro and added
security_opt: no-new-privileges:true to act-runner container." && \
git push && \
echo "gitea-config pushed" && \
\
# === 6. Cleanup token ===
curl -sf -X DELETE "$API/user/tokens/sast-push" -H "Authorization: token $TOKEN" && \
echo "=== ALL DONE ==="
```

## Note

- Il token API viene creato e poi cancellato alla fine (scope `repo` — minimo necessario)
- `.gitignore` aggiunge `solsec` in kp-manager (append) e knowledge-graph (nuovo file) per escludere il symlink
- `git push -u origin main` — il branch si chiama `main` (default `git init` su Ubuntu 24.04)
- Se un repo esiste gia' su Gitea, il `curl -sf` fallisce e il `&&` interrompe la catena — modificare con `|| true` se necessario
- Il tag `v0.1.0` su solsec permette future references senza `replace` directive

## Verifica

Dopo il push, verificare:
```bash
git ls-remote ssh://git@gitea-local:222/sol_root/solsec.git
git ls-remote ssh://git@gitea-local:222/sol_root/kp-manager.git
git ls-remote ssh://git@gitea-local:222/sol_root/knowledge-graph.git
cd /data/massimiliano/gitea && git log --oneline -1
```
