# Fix Task Queue — Sync 16 task manuali (redis:N → dual-write)

## Context
16 task (#85-#100) inseriti manualmente in PostgreSQL da `claude-review-sessioni` senza passare dal tool MCP `claude_task_enqueue`. Risultato: presenti in PG ma assenti da Redis (`redis:N`), quindi non dispatchabili.

## Piano

### Step 1 — Cancellare i 16 record da PostgreSQL
```sql
docker exec postgres psql -U postgres -d embeddings -c "DELETE FROM task_queue WHERE id BETWEEN 85 AND 100;"
```

### Step 2 — Re-inserire via MCP `claude_task_enqueue` (dual-write PG+Redis)

16 task da re-inserire con i dati originali. Raggruppati per priorità:

**Prio 2:**
| ref | taskType | payload (riassunto) |
|-----|----------|---------------------|
| wiki-file-links-broken | BUG | WikiJS link file rotti |
| dashboard-host-stats-temp | FEATURE | CPU/GPU temp + host stats in dashboard SSE |
| openalex-hdd-mount | OPS | Formattare /dev/sdc ext4, mount /mnt/hdd |
| agent-framework-fase21 | FEATURE | Fase 21 agent-framework (12 item) |
| mcp-media-tools-library | FEATURE | Lib Java mcp-media-tools (vision_ocr, audio_transcribe, html_extract) |

**Prio 3:**
| ref | taskType | payload (riassunto) |
|-----|----------|---------------------|
| openalex-s2-s3-pipeline | TODO | Step 2 enrichment + Step 4 embedding at scale |
| mcp-devops-pat-missing | OPS | Nuovo PAT Azure DevOps per 51 tool |
| agent-framework-fase-cc-13 | FEATURE | 13 pattern Claude Code nel worker SDK |
| llm-batch-qwen3-72b | OPS | Pull qwen3:72b + coder:30b, benchmark, test e2e |
| paddleocr-vl-deploy | FEATURE | PaddleOCR-VL 1.5 su Gaia via vLLM |
| code-embedding-ast-aware | FEATURE | Code embedding AST-aware con tree-sitter |
| anki-embed-venv-path | BUG | Fix ExecStart venv path in anki-embed.service |

**Prio 4:**
| ref | taskType | payload (riassunto) |
|-----|----------|---------------------|
| pref-sort-healthcheck-fix | BUG | Fix healthcheck preference-sort (wget non esiste) |
| audit-hash-chain-cross-sess | BUG | Design fix hash-chain audit cross-session |
| openalex-batch-embedding-opt | TODO | Batch embedding 10x (5.5/s → 25/s) |

**Prio 5:**
| ref | taskType | payload (riassunto) |
|-----|----------|---------------------|
| wikijs-mermaid-version-note | TODO | Documentare limitazione Mermaid 8.8.2 |

### Step 3 — Verifica
`claude_task_list(status="PENDING")` — tutti 16 devono avere `redis:Y`.

## File coinvolti
Nessun file da modificare. Operazione puramente sui dati (PG + Redis).
