---
name: gitea-actions-ci
description: Gitea Actions CI/CD patterns for self-hosted runners, tag-triggered releases, Maven Central publishing, Docker image builds, workflow templates, and act_runner configuration in self-hosted Gitea instances.
allowed-tools: Read, Write, Bash, Edit
category: devops
tags: [gitea, ci-cd, actions, runner, maven, docker, automation]
version: 1.0.0
---

# Gitea Actions CI/CD — SOL Server

## Overview

Gitea Actions (GitHub Actions compatible) on SOL with a self-hosted `act_runner`.
Primary use case: automated Maven Central publishing triggered by version tag push.
The runner executes jobs inside Docker containers on the same `shared` network.
Gitea: `https://sol.massimilianopili.com/git/` (public) or `http://100.86.46.84/git/` (Tailscale).

## When to Use This Skill

- Creating or modifying CI/CD workflows for Gitea repositories
- Debugging act_runner issues (offline, failed jobs, container errors)
- Setting up tag-triggered release pipelines (Maven Central, Docker registry)
- Configuring secrets for automated builds
- Understanding differences between GitHub Actions and Gitea Actions

## Runner Configuration

The act_runner runs alongside Gitea in `/data/massimiliano/gitea/docker-compose.yml`:

```yaml
services:
  act-runner:
    image: gitea/act_runner:latest
    container_name: act-runner
    restart: unless-stopped
    depends_on:
      - gitea
    environment:
      GITEA_INSTANCE_URL: http://gitea:3000
      GITEA_RUNNER_REGISTRATION_TOKEN: ${RUNNER_TOKEN}
      GITEA_RUNNER_NAME: sol-runner
      GITEA_RUNNER_LABELS: "ubuntu-latest:docker://catthehacker/ubuntu:act-latest,ubuntu-22.04:docker://catthehacker/ubuntu:act-22.04"
      CONFIG_FILE: /data/config.yaml
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./runner-data:/data
    networks:
      - shared
```

| Property | Value |
|----------|-------|
| **Name** | `sol-runner` |
| **Container** | `act-runner` |
| **Gitea URL** | `http://gitea:3000` (internal Docker DNS) |
| **Docker socket** | Mounted — runner creates sibling job containers |
| **Runner data** | `/data/massimiliano/gitea/runner-data/` |
| **Admin page** | `https://sol.massimilianopili.com/git/-/admin/runners` |

Labels map `runs-on` values to Docker images (`catthehacker/ubuntu:act-*`).
These are community images from the `nektos/act` project — not identical to GitHub-hosted runners
but compatible for most workflows.

Generate a new runner token:
```bash
docker exec -u git gitea gitea actions generate-runner-token
```

Actions must be enabled in Gitea (`GITEA__actions__ENABLED=true` in the gitea service environment).

## Workflow File Location

Place workflow files in `.gitea/workflows/` (preferred) or `.github/workflows/` (compatible):
```text
repo/
├── .gitea/workflows/
│   ├── ci.yml          # Build + test on push/PR
│   └── release.yml     # Publish on tag push
```

## Primary Workflow: Maven Central Release

Template: `/data/massimiliano/gitea/config/release-template.yml`

```yaml
name: Release to Maven Central
on:
  push:
    tags: ['v*']

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
          server-id: central
          server-username: MAVEN_USERNAME
          server-password: MAVEN_PASSWORD
          gpg-private-key: ${{ secrets.GPG_PRIVATE_KEY }}
          gpg-passphrase: GPG_PASSPHRASE

      - name: Publish to Maven Central
        run: mvn deploy -P release -DskipTests
        env:
          MAVEN_USERNAME: ${{ secrets.OSSRH_USERNAME }}
          MAVEN_PASSWORD: ${{ secrets.OSSRH_TOKEN }}
          GPG_PASSPHRASE: ${{ secrets.GPG_PASSPHRASE }}
```

### Trigger

```bash
git tag v1.2.3
git push origin v1.2.3
```

### Required Secrets

Configure at repo or organization level (Settings -> Actions -> Secrets):

| Secret | Description |
|--------|-------------|
| `OSSRH_USERNAME` | Sonatype OSSRH username |
| `OSSRH_TOKEN` | Sonatype OSSRH token |
| `GPG_PRIVATE_KEY` | Armored GPG key (`gpg --export-secret-keys --armor <KEY_ID>`) |
| `GPG_PASSPHRASE` | GPG key passphrase |

### How setup-java Works

`actions/setup-java@v4` with `server-id: central` generates `~/.m2/settings.xml` with credentials
and imports the GPG key. The `server-id` MUST match `<distributionManagement><repository><id>` in `pom.xml`.

## Additional Workflow Templates

### Java Build + Test (CI)

```yaml
name: Java CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          java-version: '21'
          distribution: 'temurin'
      - run: mvn clean verify
```

### Docker Image Build + Push to Gitea Registry

```yaml
name: Build Docker Image
on:
  push:
    tags: ['v*']

jobs:
  docker:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: |
          docker build -t gitea:3000/${{ github.repository }}:${{ github.ref_name }} .
          docker build -t gitea:3000/${{ github.repository }}:latest .
      - name: Login to Gitea registry
        run: echo "${{ secrets.REGISTRY_TOKEN }}" | docker login gitea:3000 -u ${{ github.actor }} --password-stdin
      - name: Push image
        run: |
          docker push gitea:3000/${{ github.repository }}:${{ github.ref_name }}
          docker push gitea:3000/${{ github.repository }}:latest
```

Note: `gitea:3000` is the internal Docker DNS name.

### Go Build + Test

```yaml
name: Go CI
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - run: go build ./...
      - run: go test -v ./...
```

## Gitea vs GitHub Actions Differences

| Feature | GitHub Actions | Gitea Actions |
|---------|---------------|---------------|
| Runner images | GitHub-hosted (full toolchain) | `catthehacker/ubuntu:act-*` (community) |
| Secrets UI | Settings -> Secrets and variables | Settings -> Actions -> Secrets |
| Container registry | `ghcr.io` | `gitea:3000` (internal DNS) |
| Marketplace | Large ecosystem | Compatible subset |
| Env variables | `GITHUB_*` | Both `GITHUB_*` and `GITEA_*` |
| Concurrency | `concurrency:` key | Not yet supported |
| Reusable workflows | Full support | Partial support |
| Caching | Native GitHub storage | Local runner storage |
| OIDC tokens | `id-token: write` | Not supported |

Most `actions/*` official actions work (checkout, setup-java, setup-go, setup-node, setup-python).
Third-party actions work if they don't rely on GitHub-specific APIs. Composite and Docker container
actions are supported. Service containers (`services:` key) work.

## Common Operations

```bash
# View runner logs
docker logs act-runner --tail 50
docker logs act-runner -f

# Restart runner
cd /data/massimiliano/gitea && docker compose restart act-runner

# Full recreate (after docker-compose.yml changes)
cd /data/massimiliano/gitea && docker compose up -d act-runner --force-recreate

# Regenerate runner token
docker exec -u git gitea gitea actions generate-runner-token

# Check job containers created by runner
docker ps --filter "label=gitea"

# UI: runner admin page
# https://sol.massimilianopili.com/git/-/admin/runners

# UI: workflow runs
# https://sol.massimilianopili.com/git/<owner>/<repo>/actions
```

## Best Practices

1. **Tag-triggered releases**: `on: push: tags: ['v*']` for CD. Separate CI (push/PR) from CD (tag).
2. **Action versions**: Pin to major versions (`@v4`), not `@latest` or `@main`.
3. **Skip tests in deploy**: Tests go in CI; release workflow uses `-DskipTests`.
4. **Organization-level secrets**: Shared secrets (OSSRH, GPG) at org level to avoid duplication.
5. **Workflow directory**: Prefer `.gitea/workflows/` over `.github/workflows/`.
6. **Internal DNS**: Use `gitea:3000` for registry operations inside workflows, not the public URL.
7. **Idempotent deploys**: Tag-triggered workflows are naturally idempotent.

## Troubleshooting

### Runner Offline

```bash
docker logs act-runner --tail 30
docker exec act-runner wget -qO- http://gitea:3000/api/v1/version
# If token expired, regenerate and recreate:
docker exec -u git gitea gitea actions generate-runner-token
cd /data/massimiliano/gitea && docker compose up -d act-runner --force-recreate
```

### Workflow Not Triggered
- File must be in `.gitea/workflows/` or `.github/workflows/`
- Check trigger conditions (branch name, tag pattern)
- Actions must be enabled globally (`GITEA__actions__ENABLED=true`) AND per-repo (Settings -> Actions)

### Java/Maven Build Fails
- `server-id: central` must match `<distributionManagement>` in `pom.xml`
- GPG_PRIVATE_KEY must include full armored output (with BEGIN/END headers)
- Verify secrets in Gitea: repo Settings -> Actions -> Secrets

### Docker Build Fails in Workflow
- Docker socket must be mounted in `act-runner` (`/var/run/docker.sock`)
- Job containers are siblings (not nested) — they share the host Docker daemon
- Use `gitea:3000` (internal DNS) for registry, not public URL

### Slow Job Startup
- First run pulls `catthehacker/ubuntu:act-*` (several GB). Pre-pull: `docker pull catthehacker/ubuntu:act-latest`

## SOL-Specific Context

### MCP Libraries Release Flow

The 8 MCP libraries (`io.github.massimilianopili`) in `/data/massimiliano/Vari/` use this workflow:
1. Push code to `main` on Gitea
2. Tag: `git tag v1.2.3 && git push origin v1.2.3`
3. act_runner runs `mvn deploy -P release -DskipTests`
4. Signed artifacts uploaded to Maven Central via OSSRH
5. Optional: `git push github main --tags` mirrors to GitHub

### Remotes Convention

- `origin` — Gitea (`ssh://git@100.86.46.84:222/<owner>/<repo>.git`)
- `github` — GitHub mirror (`git@github.com:<owner>/<repo>.git`)

Tags must be pushed to `origin` (Gitea) to trigger workflows.

### Related Tools

- `deploy-mcp` — Maven multi-project deployment orchestrator
- `gitall` — Git operations across multiple repositories
- `xcp/xpush/xtree` — Git helpers in `/data/massimiliano/shell-scripts/bin/`
