# Rust Development Environment Builder

Fully containerized, AI-augmented Rust development environment with MongoDB, deployed via a single PowerShell command on Windows.

---

## What This Repo Delivers

This repository produces **two deliverables**:

1. **A shared base Docker image** ([`tsouche/base_rust_dev`](https://hub.docker.com/r/tsouche/base_rust_dev)) — published to DockerHub. Contains all tooling: Rust stable, Node.js 20, Bun, Playwright/Chromium, QMD, SSH server, MongoDB shell, GitHub CLI, Docker CLI.

2. **A deployment kit** — PowerShell scripts + Docker Compose that build a project-specific image on top of the base, spin up 3 containers (dev, MongoDB, Mongo Express), and configure everything end-to-end including SSH access, Claude Code, gstack skills, and QMD indexing.

---

## Architecture

```doc
┌─────────────────────────────────────────────────────────────────┐
│  DockerHub: tsouche/base_rust_dev (shared base image, ~1.5 GB)  │
│  Ubuntu 22.04 · Rust · Node.js · Bun · Playwright · QMD · SSH   │
└──────────────────────────┬──────────────────────────────────────┘
                           │ FROM
┌──────────────────────────▼──────────────────────────────────────┐
│  Dockerfile.rust-dev (project-specific deploy image)            │
│  + SSH keys · Git config · Claude Code CLI · init scripts       │
└──────────────────────────┬──────────────────────────────────────┘
                           │ docker-compose
    ┌──────────────────────▼───────────────────────┐
    │           dev-container (SSH 2222)           │
    │  /workspace ← project code                   │
    │  ~/.claude  ← eternal volume (Win bind-mount)│
    ├──────────────────────────────────────────────┤
    │  MongoDB 7.0         │  Mongo Express (8080) │
    │  (27017)             │  Web admin UI         │
    └──────────────────────┴───────────────────────┘
```

**Persistence model:**

- `~/.claude/` — bind-mounted from Windows (`C:/rustdev/claude_config`). Survives all redeployments. Holds Claude history, gstack skills, MCP config.
- QMD GGUF models (~2 GB) — shared across projects, never re-downloaded.
- Per-project named volumes — home directory and QMD index isolated per project.

---

## Key Features

**Core Development**

- Rust stable toolchain (native glibc builds for Ubuntu deployments)
- Node.js 20 + Bun runtime
- Docker CLI with socket pass-through
- SSH server with key-based auth (connect via VS Code Remote-SSH)
- Shell aliases, git aliases, cargo shortcuts

**AI-Assisted Development**

- **Claude Code CLI** — latest version, installed globally
- **gstack Skills Framework** — 28 slash-command skills for Claude Code
  - Virtual engineering team: CEO review, design review, QA, release engineer
  - Key skills: `/office-hours`, `/review`, `/qa`, `/browse`, `/ship`, `/investigate`
  - Global install in persistent volume — works across all projects
- **QMD (Query Markup Documents)** — AI-optimized code indexing
  - 60-80% reduction in Claude token usage via semantic search (BM25 + vectors)
  - Persistent knowledge base across sessions
  - Smart auto-detection of projects in `~/` and `/workspace`
- **MCP Integration** — automatic configuration for Claude Code

**Infrastructure**

- Playwright + Chromium pre-installed (headless browsing for `/browse`, `/qa`, `/benchmark`)
- MongoDB 7.0 + Mongo Express web UI
- 3-container architecture orchestrated by Docker Compose
- Idempotent deployment — run `deploy-dev.ps1` as many times as needed

---

## Quick Start

### Prerequisites

- Docker Desktop installed and running
- PowerShell (Windows)
- Git
- SSH key generated (`ssh-keygen -t ed25519`)

### Deploy

```powershell
cd C:\rustdev\dev_env_builder\deploy_dev_env
.\deploy-dev.ps1
```

### Connect with VS Code

1. Press `Ctrl+Shift+P` → **Remote-SSH: Connect to Host** → **rust-dev**
2. Open folder: `/workspace`
3. Clone your project and start coding:

   ```bash
   git clone https://github.com/your-username/your-project.git
   cd your-project
   cargo build
   ```

---

## Repository Structure

```
build_base_dev_image/     # Base image builder → pushes to DockerHub
  Dockerfile.base_rust_dev
  build_and_push.ps1

deploy_dev_env/           # Deployment kit → local dev environment
  Dockerfile.rust-dev
  docker-compose-dev.yml
  deploy-dev.ps1          # Main entry point
  cleanup.ps1
  init_qmd.sh
  init_gstack.sh
  CLAUDE.md.template
```

---

## Documentation

- **Deployment guide**: [deploy_dev_env/README.md](deploy_dev_env/README.md)
- **Base image builder**: [build_base_dev_image/README.md](build_base_dev_image/README.md)
- **Changelogs**: [Root](CHANGELOG.md) · [Base image](build_base_dev_image/CHANGELOG.md) · [Deploy](deploy_dev_env/CHANGELOG.md)

---

## License

See [LICENSE](LICENSE) file.

## Acknowledgments

This project was built with the assistance of **Claude** by Anthropic.

---

**Current Version:** v0.7.0 · **Last Updated:** March 24, 2026
