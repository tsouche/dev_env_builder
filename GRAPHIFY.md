# Graphify in this dev environment

Graphify ([`graphifyy`](https://pypi.org/project/graphifyy/) on PyPI,
[Graphify-Labs/graphify](https://github.com/Graphify-Labs/graphify) upstream) is a
code knowledge graph builder — tree-sitter AST extraction + call-graph traversal +
community detection — that answers *structural* questions about a codebase: what
calls X, the path between two symbols, what implements an interface. It complements
[QMD](QMD.md) rather than replacing it: QMD answers content/semantic questions via
chunk retrieval, Graphify answers structural questions via graph traversal. Both are
**pre-installed in the base image** and **wired up per-project at deploy time**; there
is nothing to install manually.

For the design decisions and how it was verified during the v0.8.0 build, see
[V0.8.0_PROGRESS.md](V0.8.0_PROGRESS.md). This file is a short reference for how it
actually works today.

## Where it comes from

- **Binary**: installed globally in the base image via
  `uv tool install "graphifyy[mcp]" --with tomli`, into `/usr/local` (see
  [build_base_dev_image/Dockerfile.base_rust_dev](build_base_dev_image/Dockerfile.base_rust_dev)).
  `uv` itself is installed the same way, also into `/usr/local`. Both are
  installed system-wide rather than under `~/.local` deliberately: `/home/rustdev`
  is a persistent named volume, and anything added under it in a *later* base-image
  build is invisible on redeploys against an already-existing volume — `/usr/local`
  avoids that class of bug entirely (same reasoning as Bun's install).
  `tomli` is required for `--cargo` (Cargo workspace introspection) on Python 3.10
  (Ubuntu 22.04's stock Python; 3.11+ ships this built in as `tomllib`).
- **Per-project setup**: [deploy_dev_env/init_graphify.sh](deploy_dev_env/init_graphify.sh),
  copied fresh into the container on every deploy and run automatically by
  `deploy-dev.ps1`, right after QMD's initialization.

## Per-repo model

Unlike QMD's `--index {name}` flag, Graphify's scoping is **path-based**: it operates
on `./graphify-out/` relative to the current directory, so there's no per-project
alias to remember — just `cd` into a repo and run `graphify query "..."`.

| Artifact | Location | Committed to git? |
| --- | --- | --- |
| Graph | `{repo}/graphify-out/graph.json` | Yes |
| Architecture report | `{repo}/graphify-out/GRAPH_REPORT.md` | Yes |
| Interactive viewer | `{repo}/graphify-out/graph.html` | Yes |
| Run metadata | `{repo}/graphify-out/cost.json` | No (git-ignored) |
| Claude Code skill | `{repo}/.claude/skills/graphify/SKILL.md` | Yes |
| Claude Code hook | `{repo}/.claude/settings.json` (PreToolUse) | Yes |
| Project guidance | `{repo}/.claude/CLAUDE.md`, `{repo}/CLAUDE.md` (graphify section) | Yes |
| Git hooks | `{repo}/.git/hooks/post-commit`, `post-checkout` | N/A (not tracked) |

Committing `graph.json`/`GRAPH_REPORT.md`/`graph.html` is upstream's own recommended
team workflow (JSON diffs reasonably, and `graphify hook install` registers a git merge
driver so parallel commits don't leave conflict markers) — the deliberate opposite of
QMD's fully git-ignored binary SQLite index.

## Setup

Nothing to install. After deployment:

```bash
# Inside the container, after cloning a project
~/init_graphify.sh
```

`init_graphify.sh` is fully idempotent — safe to re-run after cloning a new repo or
pulling changes. Per repo, it:

1. Extracts the graph: `graphify extract . --code-only [--cargo]` — zero LLM cost,
   pure AST + graph traversal, no API key or GGUF models needed
2. Generates the report: `graphify cluster-only .` — also fully offline; without an
   LLM backend configured it falls back to generic "Community N" labels instead of
   descriptive ones, but the report is still complete
3. Adds `graphify-out/cost.json` to `.gitignore`
4. Installs Claude Code project integration: `graphify claude install --project`
   (not `--strict`, so it coexists with QMD's soft CLAUDE.md rule instead of
   blocking the first `Read`)
5. Installs the git commit hooks: `graphify hook install`
6. Self-heals the `graphify-status`/`graphify-reindex` bashrc helpers on every run
   (same home-volume-shadowing reasoning as above — belt and suspenders on top of
   the base-image bake)

## Daily usage

```bash
graphify-status                  # graph status for every repo with a graphify-out/
graphify-reindex                 # alias for ~/init_graphify.sh — rescans for new repos

# From inside a project directory (no --index flag needed):
graphify query "what connects auth to the database?"
graphify path "UserService" "DatabasePool"
graphify explain "RateLimiter"
graphify extract . --code-only [--cargo]   # manual re-extract (the git post-commit
                                            # hook does this automatically)
```

## Claude Code integration

Each repo gets its own project-scoped Claude Code skill and `PreToolUse` hook via
`graphify claude install --project` (already run by `~/init_graphify.sh`) — detailed,
repo-specific usage guidance lives in that project's own generated
`.claude/skills/graphify/SKILL.md` and `CLAUDE.md`. The global routing rule that tells
Claude Code when to reach for Graphify vs QMD lives in
[deploy_dev_env/CLAUDE.md.template](deploy_dev_env/CLAUDE.md.template), copied to
`~/.claude/CLAUDE.md`: QMD for content/semantic questions, Graphify for structural
questions, `GRAPH_REPORT.md` for architecture orientation on an unfamiliar repo.
