# QMD in this dev environment

QMD ([`@tobilu/qmd`](https://github.com/tobi/qmd), Query Markup Documents) is an
on-device search engine — BM25 keyword search + vector semantic search + LLM
reranking — that lets Claude Code search a codebase instead of reading every
file. In this repo it is **pre-installed in the base image** and **wired up
per-project at deploy time**; there is nothing to install manually.

For the full rationale and design history, see
[QMD_IMPLEMENTATION_GUIDE.md](QMD_IMPLEMENTATION_GUIDE.md) (superseded in
places — see the note at its top) and the QMD section of
[deploy_dev_env/README.md](deploy_dev_env/README.md#35-qmd---ai-optimized-code-indexing).
This file is a short reference for how it actually works today.

## Where it comes from

- **Binary**: installed globally in the base image via
  `npm install -g @tobilu/qmd` (see
  [build_base_dev_image/Dockerfile.base_rust_dev](build_base_dev_image/Dockerfile.base_rust_dev)).
  Node 22 is required by QMD's engine constraint. Bun is also present, but the
  npm package ships a pre-built `dist/`, so the QMD wrapper runs under node.
- **Per-project setup**: [deploy_dev_env/init_qmd.sh](deploy_dev_env/init_qmd.sh),
  copied fresh into the container on every deploy and run automatically by
  `deploy-dev.ps1`, and again on first interactive shell login via the
  `qmd-auto-init` bashrc function.

## Per-repo index model

Every git repo found under `~/` or `/workspace` gets its **own** isolated
index — there is no single global collection:

| Artifact | Location |
| --- | --- |
| Index DB | `{repo}/.qmd/index.sqlite` (auto-added to the repo's `.gitignore`) |
| Discovery symlink | `~/.cache/qmd/{name}.sqlite` |
| Named config | `~/.config/qmd/{name}.yml` |
| Claude Code MCP override | `{repo}/.mcp.json` → `qmd --index {name} mcp` |
| Shell alias | `qmd-{name}` = `qmd --index {name}` |
| Shared GGUF models | `~/.cache/qmd/models/` (~2GB, downloaded once, reused by all projects) |

Indexed file mask: `**/*.{rs,md,toml,json,yaml,yml,sh,py,js,ts,jsx,tsx,go,c,cpp,h,hpp}`.

Because each repo carries its own `.mcp.json`, Claude Code automatically
scopes QMD search to whichever project is open — no manual MCP config editing.

## Setup

Nothing to install. After deployment:

```bash
# Inside the container, after cloning a project
~/init_qmd.sh
```

`init_qmd.sh` is fully idempotent — safe to re-run after cloning a new repo or
pulling changes. It:

1. Creates `.qmd/`, the cache symlink, and the named config for each repo
2. Creates or updates the index (`qmd --index {name} collection add|update`)
3. Writes/refreshes `{repo}/.mcp.json`
4. Adds a `qmd-{name}` alias to `~/.bashrc`
5. Generates vector embeddings (`qmd --index {name} embed`) — downloads the
   GGUF models on first run only

## Daily usage

```bash
qmd-status                 # health of every per-repo index (from Dockerfile bashrc helper)
qmd-{name} status          # health of one project's index
qmd-{name} update          # re-index after code changes
qmd-{name} embed           # regenerate semantic embeddings
qmd-{name} query "..."     # hybrid search (BM25 + rerank) — best quality
qmd-{name} search "..."    # fast BM25 keyword search
qmd-{name} vsearch "..."   # semantic vector search
qmd-{name} get <file>      # retrieve a specific document
qmd-reindex                 # alias for ~/init_qmd.sh — rescans for new repos
```

`qmd-auto-init` runs on every interactive shell login: it triggers
`~/init_qmd.sh` if no per-repo index exists yet, and warns if the newest index
is more than 24h old.

## Claude Code integration

The MCP server is registered per-repo in `{repo}/.mcp.json`
(`qmd --index {name} mcp`), plus an eternal fallback in the bind-mounted
`~/.claude.json` (`qmd mcp`, no `--index`) so QMD is available even outside an
indexed repo. The rule telling Claude Code to prefer QMD over
Read/Glob/Grep lives in the global template at
[deploy_dev_env/CLAUDE.md.template](deploy_dev_env/CLAUDE.md.template), copied
to `~/.claude/CLAUDE.md`. Available MCP tools: `search`, `query`, `vsearch`,
`get`, `multi_get`.
