# Task #138: Gaia KV cache q8

## Approach
Use bash ssh from host (MCP SSH tool stays broken for encrypted keys — future fix).
Delete the unused unencrypted key `id_mcp`.

### Steps
1. Delete `/home/massimiliano/.ssh/id_mcp` and `id_mcp.pub`
2. Revert Dockerfile APR additions (libapr1, libtcnative-1)
3. SSH to Gaia via bash: read Ollama docker-compose, add `OLLAMA_KV_CACHE_TYPE=q8_0`, restart
4. Verify env var is set

### Cleanup
- Remove agent socket mount from MCP docker-compose (not useful without working agent)
- Keep .ssh mount (useful for known_hosts) and SSH_AUTH_SOCK env (future-proofing)
