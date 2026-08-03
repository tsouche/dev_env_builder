# Rust Development Environment - Deployment Guide

**Complete containerized Rust development environment with MongoDB**

**Current Version:** v0.8.1
**Base Image:** `tsouche/base_rust_dev:v0.8.0`  
**Last Updated:** August 3, 2026

*For version history and changelog, see [CHANGELOG.md](CHANGELOG.md)*

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start](#quick-start)
4. [SSH Configuration](#ssh-configuration)
5. [VS Code Remote Development](#vs-code-remote-development)
6. [Deployment Scripts](#deployment-scripts)
7. [Services & Access](#services--access)
8. [Development Workflow](#development-workflow)
9. [Troubleshooting](#troubleshooting)
10. [File Structure](#file-structure)

---

## Overview

- **Platform**: Windows with Docker Desktop
- **Container**: Rust development environment with SSH access
- **Base Image**: `tsouche/base_rust_dev:v0.8.0` (see [build_base_dev_image/README.md](../build_base_dev_image/README.md) for what it includes)
- **Services**: Dev container + MongoDB + Mongo Express
- **Access**: VS Code Remote SSH to localhost

**Container Features:**

- **Base OS**: Ubuntu 22.04 LTS (development environment)
- Rust stable toolchain (via rustup)
- **Native glibc Compilation**: Builds for Ubuntu-based deployments
  - Compile in Ubuntu dev environment
  - Deploy to Ubuntu-based staging/production containers
  - **Environment variables properly persisted** (v0.6.5+): Available in all shell sessions
- **Docker CLI**: Full Docker functionality from inside container (v0.6.5+)
  - Run Docker commands without leaving dev environment
  - Automatic Ubuntu container testing via `docker cp`
  - Proper group permissions for Docker socket access
- **`restart: unless-stopped`** (v0.8.1+): the dev container survives a
  Docker/host backend restart automatically, same as MongoDB/Mongo Express
- **Welcome banner** (v0.8.1+): every new interactive terminal shows real
  tool versions and the new-project checklist (`~/init_qmd.sh`,
  `~/init_graphify.sh`) — see `install_banner.sh`, self-healing on every
  deploy for the same reason as the QMD/Graphify bashrc helpers
- **QMD** — AI-optimized semantic code search, see §3.5 below and [QMD.md](../QMD.md)
- **Graphify** — AI code knowledge graph, next to QMD, see §3.6 below and [GRAPHIFY.md](../GRAPHIFY.md)
- **gstack** — Claude Code skills framework (28+ slash commands)
- Build tools (gcc, cmake, pkg-config, libssl-dev)
- MongoDB Shell (mongosh)
- GitHub CLI (gh)
- SSH server on port 2222
- VS Code extensions auto-install
- Shell aliases and git shortcuts
- User: rustdev (UID 1026, GID 110, groups: sudo, docker, systemd-journal)

---

## Prerequisites

### 1. Windows Development Machine

**Required Software:**

- Docker Desktop for Windows
- VS Code with Remote-SSH extension
- OpenSSH client (included in Windows 10/11)
- Git (for cloning repository within container)

**Verify OpenSSH:**

```powershell
ssh -V
# Should show: OpenSSH_for_Windows_x.x
```

If not installed:

```powershell
# PowerShell as Administrator
Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

### 2. Directory Structure

The deployment script will create these directories:

```bash
C:\rustdev\
├── projects\              # Project workspace (bind mount)
├── docker\
│   ├── mongodb\
│   │   ├── data\         # MongoDB persistent storage
│   │   └── init\         # Initialization scripts
│   ├── cargo_cache\      # Cargo registry cache
│   └── target_cache\     # Rust build cache
```

**Important**: Projects should be cloned **inside** the container, not on Windows.

### 3. VS Code Extensions

Install before connecting:

- **Remote - SSH** (ms-vscode-remote.remote-ssh)

---

## Quick Start

### Automated Deployment

```powershell
cd C:\path\to\set_backend\src\env_dev
.\deploy-dev.ps1
```

**What it does:**

1. Checks for existing SSH keys (ed25519 or RSA)
2. Generates new SSH key if none exists
3. Creates required directories
4. Configures SSH for VS Code
5. Creates MongoDB init script
6. Builds Docker images
7. Starts all services (dev, MongoDB, Mongo Express)

**First run prompts:**

- Project directory handling (keep/delete/cancel)
- SSH key generation (automatic if needed)

### Verification

After deployment:

```powershell
# Check containers
docker ps

# Should show:
# - dev-container (port 2222)
# - dev-mongodb (port 27017)
# - dev-mongo-express (port 8080)
```

---

## SSH Configuration

### Automatic Configuration (v0.6.7+)

The deployment script automatically:

1. Detects existing SSH keys (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)
2. Generates new ed25519 key if none exists
3. Copies public key to container's `authorized_keys`
4. Adds `rust-dev` host to `~/.ssh/config`

**Generated SSH Config:**

```ssh-config
# Rust Development Environment v0.6.7 - Auto-generated
Host rust-dev
    HostName localhost
    Port 2222
    User rustdev
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
```

### Manual SSH Key Generation

If needed:

```powershell
# Generate ed25519 key (recommended)
ssh-keygen -t ed25519 -C "your_email@example.com"

# Or RSA (alternative)
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### Test SSH Connection

```powershell
ssh rust-dev
# Should connect without password
# You are now inside the container as user 'rustdev'
```

---

## VS Code Remote Development

### Connect to Container

**Method 1: Command Palette**

1. Press `Ctrl+Shift+P`
2. Type: `Remote-SSH: Connect to Host`
3. Select: `rust-dev`
4. Wait for connection and VS Code server installation

**Method 2: VS Code UI**

1. Click Remote indicator (bottom-left corner)
2. Select "Connect to Host"
3. Choose `rust-dev`

**Method 3: Command Line**

```powershell
code --remote ssh-remote+rust-dev /workspace
```

### First Connection

1. VS Code installs its server in the container (automatic)
2. Extensions auto-install (rust-analyzer, CodeLLDB, etc.)
3. Open `/workspace` folder
4. Terminal opens as user `rustdev`

### Clone Repository

**Inside container** (via VS Code terminal):

```bash
cd /workspace
git clone https://github.com/tsouche/set_backend.git
cd set_backend

# Configure git (first time)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Build project
cargo build
```

**⚠️ Important**: Clone inside the container, NOT on Windows!

- ❌ Cloning on Windows causes WSL mount issues
- ✅ Clone within container for proper permissions

---

## Deployment Scripts

### deploy-dev.ps1 (v0.8.1)

**Purpose**: Complete environment deployment

**Usage:**

```powershell
.\deploy-dev.ps1
```

**Features:**

- Automatic cleanup of existing environment (with confirmation)
- Automatic SSH key generation
- Project directory handling (keep/delete/cancel)
- Directory structure creation
- MongoDB initialization
- Docker Compose service startup (3 containers, dev-container now
  `restart: unless-stopped`)
- Claude Code MCP configuration
- QMD initialization (`init_qmd.sh`)
- Graphify initialization (`init_graphify.sh`)
- Welcome banner installation (`install_banner.sh`)
- gstack Skills Framework initialization (`init_gstack.sh`)
- Runs the full deployment test suite (`test-deployment.sh`)

**Interactive Prompts:**

```doc
Existing project directory found: C:\rustdev\projects\set_backend
Options:
  1. Keep existing directory
  2. Delete and start fresh (default)
  3. Cancel deployment
Enter choice (1/2/3) [2]:
```

---

## Services & Access

### Service Ports

| Service | Port | Access | Description |
| ------- | ---- | ------ | ----------- |
| **SSH** | 2222 | `ssh rust-dev` | VS Code Remote, terminal access |
| **Backend** | 5645 | `http://localhost:5645` | Application (after build/run) |
| **MongoDB** | 27017 | `mongodb://localhost:27017` | Database |
| **Mongo Express** | 8080 | `http://localhost:8080` | Database admin UI |

### Network Configuration

The Docker Compose configuration creates a custom bridge network with static IP assignments:

**Network Details:**

- **Network Name**: `dev-network`
- **Subnet**: `172.20.0.0/24`
- **Gateway**: `172.20.0.1`

**Container IP Addresses** (hard-coded in [docker-compose-dev.yml](docker-compose-dev.yml)):

- **MongoDB (mongo-db)**: `172.20.0.10`
- **Mongo Express**: `172.20.0.12`
- **Dev Container**: Dynamic IP assignment from the subnet

**⚠️ Important Notes:**

- The MongoDB IP `172.20.0.10` is **hard-coded** to ensure consistent connectivity
- The Mongo Express IP `172.20.0.12` is **hard-coded** for reliable admin access
- If you need to change these IPs, modify the `networks` section in `docker-compose-dev.yml`
- Applications should use the hostname `mongo-db` instead of the IP address for better portability
- The static IPs ensure predictable network configuration across container restarts

### cleanup.ps1 (v0.6.7)

**Purpose**: Complete environment cleanup

**Usage:**

```powershell
.\cleanup.ps1
```

**Options:**

```powershell
.\cleanup.ps1 -SkipConfirmation  # For automated calls (no prompt)
```

**Warning**: Requires confirmation (type `YES`) unless `-SkipConfirmation` is used

**Removes:**

- All containers (dev-container, dev-mongodb, dev-mongo-express)
- All Docker images
- Project directory (`C:\rustdev\projects`)
- MongoDB data (`C:\rustdev\docker\mongodb`)
- Target cache (`C:\rustdev\docker\target_cache`)

**Preserves:**

- SSH keys (`~/.ssh/`)
- SSH config (`~/.ssh/config`)
- VS Code settings

---

## Services & Access

### Service Ports

| Service | Port | Access | Description |
| ------- | ---- | ------ | ----------- |
| **SSH** | 2222 | `ssh rust-dev` | VS Code Remote, terminal access |
| **Backend** | 5645 | `http://localhost:5645` | Application (after build/run) |
| **MongoDB** | 27017 | `mongodb://localhost:27017` | Database |
| **Mongo Express** | 8080 | `http://localhost:8080` | Database admin UI |

### Network Configuration

The Docker Compose configuration creates a custom bridge network with static IP assignments:

**Network Details:**

- **Network Name**: `dev-network`
- **Subnet**: `172.20.0.0/24`
- **Gateway**: `172.20.0.1`

**Container IP Addresses** (hard-coded in [docker-compose-dev.yml](docker-compose-dev.yml)):

- **MongoDB (mongo-db)**: `172.20.0.10`
- **Mongo Express**: `172.20.0.12`
- **Dev Container**: Dynamic IP assignment from the subnet

**⚠️ Important Notes:**

- The MongoDB IP `172.20.0.10` is **hard-coded** to ensure consistent connectivity
- The Mongo Express IP `172.20.0.12` is **hard-coded** for reliable admin access
- If you need to change these IPs, modify the `networks` section in `docker-compose-dev.yml`
- Applications should use the hostname `mongo-db` instead of the IP address for better portability
- The static IPs ensure predictable network configuration across container restarts

### Environment Variables

Defined in `.env` (v0.6.7):

```properties
# Ports
SSH_PORT=2222
APP_PORT=5645
MONGO_PORT=27017
MONGO_EXPRESS_PORT=8080

# Database
DB_NAME=rust_app_db
DB_USER=app_user
DB_PASSWORD=DevPassword123
DB_ADMIN_USER=admin
DB_ADMIN_PASSWORD=DevAdmin123

# MongoDB Collections
COLLECTION_1=setplayers
COLLECTION_2=setgames
COLLECTION_3=setstats

# Mongo Express
MONGO_EXPRESS_USER=dev
MONGO_EXPRESS_PASSWORD=dev123

# User/Group
USER_UID=1026
USER_GID=110
USERNAME=rustdev
GROUPNAME=rustdevteam
```

### Mongo Express Access

**URL**: `http://localhost:8080`

**Login**:

- Username: `dev`
- Password: `dev123`

**Features**:

- View/edit collections
- Execute queries
- Import/export data
- View indexes and stats

### MongoDB Connection

**From within container (recommended):**

```sh
mongodb://app_user:DevPassword123@mongo-db:27017/rust_app_db
```

**Using static IP (from within container):**

```sh
mongodb://app_user:DevPassword123@172.20.0.10:27017/rust_app_db
```

**From host (Windows):**

```sh
mongodb://admin:DevAdmin123@localhost:27017/rust_app_db
```

**⚠️ Connection Best Practices:**

- ✅ **Use hostname `mongo-db`** for service-to-service communication (recommended)
- ⚠️ **Static IP `172.20.0.10`** works but reduces portability
- The hostname is resolved by Docker's internal DNS to the static IP
- Environment variable `MONGODB_HOST=mongo-db` is set in the dev container

---

## Development Workflow

### 1. Deploy Environment

```powershell
cd C:\path\to\set_backend\src\env_dev
.\deploy-dev.ps1
```

### 2. Connect with VS Code

```powershell
# Method 1: Direct command
code --remote ssh-remote+rust-dev /workspace

# Method 2: From VS Code UI
# Ctrl+Shift+P → Remote-SSH: Connect to Host → rust-dev
```

### 3. Clone & Build

**Inside container:**

```bash
cd /workspace
git clone https://github.com/tsouche/set_backend.git
cd set_backend

# First build (downloads dependencies)
cargo build

# Run
cargo run
```

### 3.5. QMD - AI-Optimized Code Indexing

**QMD (Query Markup Documents)** indexes your codebase for efficient AI-assisted development with Claude Code.

#### Benefits

- Reduces Claude Code token usage by 60-80%
- Fast semantic and keyword search
- Persistent context across sessions

#### 🚀 Performance Recommendation

**For best performance, clone projects to `~/` (container-local) instead of `/workspace` (bind mount):**

```bash
ssh rust-dev

# ✅ RECOMMENDED: Container-local storage (5-10x faster compilation)
cd ~
git clone https://github.com/your-username/your-project.git

# ❌ SLOWER: Bind mount to Windows (NTFS → WSL2 → Docker overhead)
cd /workspace
git clone https://github.com/your-username/your-project.git
```

**Why container-local is faster:**

- ⚡ **Native Linux ext4 filesystem** vs cross-platform translation
- 🚀 **5-10x faster `cargo build`** times
- ✨ **Instant rust-analyzer** responses (no lag)
- 📂 **Reliable file watchers** (cargo watch, nodemon work perfectly)
- 💾 **Persistent via named volume** (`rustdev_${PROJECT_NAME}`) - survives rebuilds

**Data safety:** Your home directory is backed by a per-project Docker named volume, so projects persist across container rebuilds. Just **push to git frequently** for ultimate safety.

#### Per-repo index model (current, since v0.7.x)

**Every git repository gets its own isolated QMD index** — there is no single
global collection. `init_qmd.sh` scans `~/` and `/workspace` for git repos and,
for each one, creates:

| Artifact | Location |
| --- | --- |
| Index DB | `{repo}/.qmd/index.sqlite` (in-repo, auto-added to `.gitignore`) |
| Discovery symlink | `~/.cache/qmd/{name}.sqlite` |
| Named config | `~/.config/qmd/{name}.yml` |
| Claude Code MCP override | `{repo}/.mcp.json` → `qmd --index {name} mcp` |
| Shell alias | `qmd-{name}` = `qmd --index {name}` |
| Shared GGUF models | `~/.cache/qmd/models/` (~2GB, downloaded once, reused by all projects) |

**Initialization happens automatically** through 2 mechanisms:

1. **✅ During Deployment** — `deploy-dev.ps1` copies the latest `init_qmd.sh`
   into the container and runs it after deployment (completes in seconds if
   no repo is cloned yet)
2. **✅ On First Shell Login** — `.bashrc`'s `qmd-auto-init` function detects
   when no per-repo index exists and runs `init_qmd.sh`

After cloning a new repo, re-run initialization manually:

```bash
~/init_qmd.sh
# or, from the alias:
qmd-reindex
```

The script is fully idempotent — safe to run any number of times. If a
project's index already exists it's updated; otherwise it's created. New
repos are picked up automatically the next time it runs.

#### Automatic Claude Code Integration

Each repo carries its own `{repo}/.mcp.json`, so opening a project in Claude
Code automatically scopes all QMD searches to that project's index — no
manual MCP config editing. A fallback global MCP entry (`qmd mcp`, no
`--index`) also lives in the eternal `~/.claude.json` for use outside an
indexed repo.

**Persistence:**

- ✅ **GGUF models**: Cached in `C:/rustdev/docker/qmd_models` (Windows bind
  mount) — downloaded once, shared across ALL projects, never re-downloaded
- ✅ **Index database**: Lives inside each repo at `.qmd/index.sqlite`, so it
  persists with the repo itself (in the per-project home volume or
  `/workspace` bind mount)
- ✅ **Claude history**: Cached in `C:/rustdev/claude_config` (Windows bind
  mount) — eternal persistence across all projects

#### Daily Usage

```bash
qmd-status                 # health of every per-repo index found on this machine
qmd-{name} status          # health of one project's index
qmd-{name} update          # re-index after code changes
qmd-{name} embed           # regenerate semantic embeddings
qmd-{name} query "..."     # hybrid search (BM25 + rerank) — best quality
qmd-{name} search "..."    # fast BM25 keyword search
qmd-{name} vsearch "..."   # semantic vector search
qmd-reindex                 # alias for ~/init_qmd.sh — rescans for new repos
```

(`{name}` is the repo's directory name — the alias is written to `~/.bashrc`
by `init_qmd.sh` for every indexed project.)

#### How It Works

1. QMD indexes your code with BM25 + vector embeddings
2. Claude Code queries QMD via MCP (Model Context Protocol), scoped to the
   current repo's index via `.mcp.json`
3. QMD returns relevant code snippets instead of scanning all files
4. Result: Faster responses, lower costs, better accuracy

#### Troubleshooting

**"qmd: command not found"**

- Rebuild the base image (QMD is installed there, not per-deployment)

**Models downloading slowly**

- First embed run downloads ~2GB of GGUF models (one-time)
- Cached in `C:/rustdev/docker/qmd_models` (persists forever, shared across all projects)
- Subsequent deployments and projects reuse the cached models

**"No git repositories found" during initialization**

- Clone a git repository first:

  ```bash
  cd ~  # Recommended for performance
  git clone https://github.com/your-username/your-project.git
  ~/init_qmd.sh  # Re-run to detect and index the new repo
  ```

**Outdated search results**

- Run `qmd-{name} update` to re-index that project
- Or `~/init_qmd.sh` (`qmd-reindex`) to re-scan and update all projects

**QMD not being used by Claude Code**

- Check `{repo}/.mcp.json` exists and points at `qmd --index {name} mcp`
- Check `~/.claude/CLAUDE.md` exists and contains the QMD-first rule
- Verify the fallback MCP entry: `cat ~/.claude.json | grep qmd`

### 3.6. Graphify - AI Code Knowledge Graph

**Graphify** builds a structural code graph (tree-sitter AST + call-graph
traversal + community detection) for each project, next to QMD — see
[GRAPHIFY.md](../GRAPHIFY.md) for the full reference. This section covers
the deployment-specific mechanics; QMD's section above covers the analogous
setup for content/semantic search.

#### Benefits

- Answers structural questions QMD's content search cannot: "what calls X",
  path tracing between two symbols, "what implements this interface"
- Zero LLM cost for code-only extraction — pure tree-sitter AST + graph
  traversal, no API key or GGUF models needed
- No dedicated volume required (unlike QMD's ~2GB model volume)

#### Per-repo model (path-based, not flag-based)

Unlike QMD's `--index {name}` flag, Graphify scopes to `./graphify-out/`
relative to the current directory — no per-project alias needed, just `cd`
into a repo. `init_graphify.sh` scans `~/` and `/workspace` for git repos
and, for each one, creates:

| Artifact | Location | Committed to git? |
| --- | --- | --- |
| Graph | `{repo}/graphify-out/graph.json` | Yes |
| Architecture report | `{repo}/graphify-out/GRAPH_REPORT.md` | Yes |
| Interactive viewer | `{repo}/graphify-out/graph.html` | Yes |
| Run metadata | `{repo}/graphify-out/cost.json` | No (git-ignored) |
| Claude Code skill | `{repo}/.claude/skills/graphify/SKILL.md` | Yes |
| Claude Code hook | `{repo}/.claude/settings.json` (PreToolUse) | Yes |
| Git hooks | `{repo}/.git/hooks/post-commit`, `post-checkout` | N/A |

Committing `graph.json`/`GRAPH_REPORT.md`/`graph.html` is Graphify's own
recommended team workflow — the deliberate opposite of QMD's fully
git-ignored SQLite index.

**Initialization happens automatically**, the same two ways as QMD:

1. **During Deployment** — `deploy-dev.ps1` copies the latest
   `init_graphify.sh` into the container and runs it right after QMD's
   initialization (completes in seconds if no repo is cloned yet)
2. **On demand** after cloning a new repo:

   ```bash
   ~/init_graphify.sh
   # or, from the alias:
   graphify-reindex
   ```

The script is fully idempotent, and self-heals its `graphify-status`/
`graphify-reindex` bashrc helpers on every run (protects against the
home-volume-shadowing issue described in the Troubleshooting section below).

#### Automatic Claude Code Integration

Each repo gets its own project-scoped skill and `PreToolUse` hook via
`graphify claude install --project` — no manual configuration. The global
rule telling Claude Code when to reach for Graphify vs QMD lives in
`CLAUDE.md.template`: QMD for content/semantic questions, Graphify for
structural questions, `GRAPH_REPORT.md` for architecture orientation.

#### Daily Usage

```bash
graphify-status                  # graph status for every repo with a graphify-out/
graphify-reindex                 # alias for ~/init_graphify.sh — rescans for new repos

# From inside a project directory (no --index flag needed):
graphify query "what connects auth to the database?"
graphify path "UserService" "DatabasePool"
graphify explain "RateLimiter"
```

#### How It Works

1. `graphify extract . --code-only [--cargo]` builds the AST + call graph
2. `graphify cluster-only .` runs community detection and writes
   `GRAPH_REPORT.md`/`graph.html` — fully offline (generic "Community N"
   labels without an LLM backend configured, but still complete)
3. Claude Code consults the graph via its project-scoped skill/hook instead
   of grepping through files for structural questions
4. The git `post-commit` hook re-extracts automatically after each commit

#### Troubleshooting

**"graphify: command not found" after redeploying an existing environment**

- This is the home-volume-shadowing issue: `/home/rustdev` is a persistent
  named volume, and Docker only seeds a volume's content from the image the
  *first* time it's created. `uv`/`graphify` are installed into
  `/usr/local` specifically to avoid this, but if you see it anyway, rebuild
  the base image and recreate the container
  (`docker compose up -d --force-recreate dev-container`)

**"No git repositories found" during initialization**

- Clone a git repository first, then re-run: `~/init_graphify.sh`

**`--cargo` fails with a `tomli` error**

- Rebuild the base image — `tomli` is a required dependency for `--cargo`
  on Python 3.10, added at the base-image level

### 4. Build for Ubuntu Staging/Production Deployment

**Development Workflow:**

The dev environment is **Ubuntu 22.04** with native glibc compilation. You develop and test in Ubuntu, then build binaries for deployment to Ubuntu-based staging/production containers (also Ubuntu 22.04).

```bash
# Develop and test in Ubuntu dev environment (native target)
cargo build
cargo test
cargo run

# When ready to deploy: build release binary
cargo build --release

# The resulting binary is dynamically linked with glibc
./target/release/your_app

# Deploy to Ubuntu-based staging/production container (hot-swap)
# This mirrors the exact deployment process used on the NAS
docker cp ./target/release/your_app staging-container:/app/
docker restart staging-container
# or via SSH to NAS
scp ./target/release/your_app admin@nas:/volume1/docker/staging/
ssh admin@nas "docker restart staging-backend"
```

**Why This Works:**

- **Dev environment**: Ubuntu 22.04 with full development tools
- **Native glibc**: Same libc as staging/prod, ensures compatibility
- **System OpenSSL**: Uses Ubuntu's libssl-dev, no custom compilation needed
- **Staging/Prod**: Ubuntu 22.04 containers run the glibc binaries natively
- **Hot-swap deployment**: Copy binary to running container, test, restart

**Note**: Dev, staging, and prod all use Ubuntu 22.04 with glibc for maximum compatibility.

### 5. Development Service Aliases

**Convenient aliases and functions** are available for quick API testing:

```bash
# Health check
dev-h

# Version info
dev-v

# Shutdown service
dev-s
```

### 6. Development Loop

**Inside container:**

```bash
# Edit code in VS Code
# Save changes (Ctrl+S)

# Build and run (use shortcuts from v0.6.0+)
cb          # cargo build
cr          # cargo run
ct          # cargo test
ccl         # cargo clippy

# Test hot-swap deployment workflow
test-ubuntu  # Quick deployment test

# Or use cargo-watch (if installed)
cargo watch -x run

# Debug with VS Code
# F5 to start debugging (CodeLLDB extension)
```

### 8. Git Workflow

**Git Aliases** (v0.6.0+):

```bash
git st          # git status
git co <branch> # git checkout
git br          # git branch
git lg          # pretty graph logt)
dev-c

# Launch service (function with optional port, default 5645)
dev-l
dev-l 8080  # Use different port
```

**Alias Details:**

- `dev-h`: `curl http://localhost:8080/health && echo ""`
- `dev-v`: `curl http://localhost:8080/version && echo ""`
- `dev-s`: `curl -X POST http://localhost:8080/shutdown && echo ""`
- `dev-c`: `curl -X POST http://localhost:8080/clear?db && echo ""`
- `dev-l(port)`: Smart launch function (shutdown + restart with health check)

### 5. Development Loop

### 8. Stop Development

**From Windows:**

```powershell
cd C:\rustdev\dev_env_builder\deploy_dev_env

# Build and run
cargo run

# Or use cargo-watch (if installed)
cargo watch -x run

# Debug with VS Code
# F5 to start debugging (CodeLLDB extension)
```

### 5. Database Operations

**Check data with Mongo Express:**

```http
http://localhost:8080
Login: dev / dev123
```

**Or use mongosh in container:**

```bash
# Inside dev-container
mongosh mongodb://admin:DevAdmin123@mongo-db:27017/rust_app_db

# List collections
show collections

# Query data
db.setplayers.find()
```

### 6. Stop Development

**From Windows:**

```powershell
cd C:\path\to\set_backend\src\env_dev
docker compose -f docker-compose-dev.yml down
```

**Restart:**

```powershell
docker compose -f docker-compose-dev.yml up -d
```

---

## Troubleshooting

### Cannot SSH to Container

**Problem**: `ssh rust-dev` fails or times out

**Solution**:

```powershell
# Check container is running
docker ps | findstr dev-container

# Check SSH config
cat ~\.ssh\config | findstr -A 6 "Host rust-dev"

# Test manual SSH
ssh -p 2222 rustdev@localhost

# Check SSH key permissions
icacls ~\.ssh\id_ed25519
# Should show: <username>:(F) SYSTEM:(F)
```

**Fix key permissions:**

```powershell
# Remove inheritance
icacls ~\.ssh\id_ed25519 /inheritance:r

# Grant full control to current user only
icacls ~\.ssh\id_ed25519 /grant:r "$env:USERNAME:(F)"
```

### VS Code Cannot Connect

**Problem**: "Could not establish connection to rust-dev"

**Solutions**:

1. **Container not running:**

```powershell
docker ps | findstr dev-container
# If not running:
docker compose -f docker-compose-dev.yml up -d
```

1. **SSH key issues:**

```powershell
# Regenerate SSH key
rm ~\.ssh\id_ed25519*
ssh-keygen -t ed25519 -C "your_email@example.com"

# Redeploy
.\deploy-dev.ps1
```

1. **VS Code Server issues:**

```powershell
# Remove VS Code server cache
ssh rust-dev
rm -rf ~/.vscode-server
exit

# Reconnect (VS Code will reinstall server)
```

### MongoDB Connection Failed

**Problem**: Application cannot connect to MongoDB

**Solutions**:

1. **Check MongoDB is running:**

```powershell
docker ps | findstr mongodb
```

1. **Check network connectivity:**

```bash
# From inside container
ping mongo-db
# Should resolve to 172.20.0.10

# Test with static IP
ping 172.20.0.10
```

1. **Check connection string:**

```bash
# From inside container
mongosh mongodb://admin:DevAdmin123@mongo-db:27017/rust_app_db

# Or using static IP
mongosh mongodb://admin:DevAdmin123@172.20.0.10:27017/rust_app_db

# Should connect successfully
```

1. **Check environment variables:**

```bash
# Inside container
echo $MONGODB_URI
# Should show: mongodb://mongo-db:27017/rust_app_db

echo $MONGODB_HOST
# Should show: mongo-db
```

1. **Verify network configuration:**

```bash
# Inside container
docker network inspect dev-network
# Check that mongo-db has IP 172.20.0.10
```

### Cargo Build Fails

**Problem**: Build errors or dependency issues

**Solutions**:

1. **Clean build:**

```bash
# Inside container
cargo clean
cargo build
```

1. **Update dependencies:**

```bash
cargo update
```

1. **Check disk space:**

```bash
df -h /workspace
# Ensure sufficient space
```

1. **Clear caches:**

```powershell
# From Windows (stop containers first)
docker compose -f docker-compose-dev.yml down

# Remove cache directories
rm -r C:\rustdev\docker\cargo_cache\*
rm -r C:\rustdev\docker\target_cache\*

# Restart
docker compose -f docker-compose-dev.yml up -d
```

### Port Already in Use

**Problem**: "port 2222 already allocated"

**Solutions**:

1. **Find process using port:**

```powershell
netstat -ano | findstr :2222
# Note the PID (last column)

# Kill process
taskkill /PID <pid> /F
```

1. **Change port in .env:**

```properties
SSH_PORT=2223  # Use different port
```

1. **Stop conflicting containers:**

```powershell
docker ps -a
docker stop <container_id>
docker rm <container_id>
```

### Extensions Not Installing

**Problem**: rust-analyzer or other extensions missing

**Solutions**:

1. **Manual install:**

- Open Extensions view (Ctrl+Shift+X)
- Search and install:
  - rust-analyzer
  - CodeLLDB
  - Even Better TOML
  - crates

1. **Reinstall VS Code Server:**

```bash
# Inside container
rm -rf ~/.vscode-server
# Reconnect with VS Code (reinstalls server)
```

1. **Check extension settings:**

- Settings → Remote [SSH: rust-dev] → Extensions
- Enable auto-install

---

## File Structure

### Local Project Structure

```sh
deploy_dev_env/
├── .env                       # Environment configuration (v0.8.1)
├── Dockerfile.rust-dev         # Dev container definition
├── docker-compose-dev.yml     # Services orchestration (v0.8.1)
├── deploy-dev.ps1             # Deployment script (v0.8.1)
├── cleanup.ps1                # Cleanup script
├── init_qmd.sh                # QMD per-repo initialization (v0.8.1: indexing fix)
├── init_graphify.sh           # Graphify per-repo initialization
├── init_gstack.sh             # gstack skills framework initialization
├── install_banner.sh          # Welcome banner installer (v0.8.1+)
├── test-deployment.sh         # Deployment test suite (v0.8.1: functional checks)
├── CLAUDE.md.template         # Global Claude Code config (QMD/Graphify routing)
├── 01-init-db.js              # MongoDB initialization (auto-generated)
├── authorized_keys            # SSH public key (auto-generated)
└── README.md                  # This guide
```

### Windows Host Directories

```sh
C:\rustdev\
├── projects\                  # Project workspace
│   └── set_backend\           # Cloned repository (inside container)
│
└── docker\
    ├── mongodb\
    │   ├── data\              # MongoDB data (persistent)
    │   └── init\              # Init scripts
    ├── cargo_cache\           # Cargo registry cache
    └── target_cache\          # Rust build artifacts cache
```

### Container Structure

```sh
/workspace/                    # Mounted from C:\rustdev\projects
├── set_backend/               # Your project (clone here)
│   ├── src/
│   ├── Cargo.toml
│   └── ...

/home/rustdev/
├── .cargo/
│   └── registry/              # Mounted from C:\rustdev\docker\cargo_cache
├── .vscode-server/            # VS Code server
├── .ssh/
│   └── authorized_keys        # Your public key
└── .bashrc
```

---

## Quick Reference

### Common Commands

```powershell
# === DEPLOYMENT ===

# Deploy environment
.\deploy-dev.ps1

# Stop services
docker compose -f docker-compose-dev.yml down

# Restart services
docker compose -f docker-compose-dev.yml restart

# View logs
docker compose -f docker-compose-dev.yml logs -f

# Complete cleanup
.\cleanup.ps1

# === VS CODE ===

# Connect to container
code --remote ssh-remote+rust-dev /workspace

# Or from command palette:
# Ctrl+Shift+P → Remote-SSH: Connect to Host → rust-dev

# === SSH ===

# SSH to container
ssh rust-dev

# Or explicit:
ssh -p 2222 rustdev@localhost

# === INSIDE CONTAINER ===

# Clone repository
cd /workspace
git clone https://github.com/tsouche/set_backend.git

# Build and run
cd set_backend
cargo build
cargo run

# Test
cargo test

# Check MongoDB
mongosh mongodb://admin:DevAdmin123@mongo-db:27017/rust_app_db

# === DOCKER ===

# Check containers
docker ps

# Exec into container
docker exec -it dev-container bash

# View backend logs
docker compose -f docker-compose-dev.yml logs -f dev-container
```

### Service URLs

```sh
VS Code Remote:    ssh rust-dev
SSH Manual:        ssh -p 2222 rustdev@localhost
Backend:           http://localhost:5645
MongoDB:           mongodb://localhost:27017
Mongo Express:     http://localhost:8080 (dev/dev123)
```

---

## Notes

- 📂 **Clone projects inside container** - NOT on Windows!
- 💾 **Cargo/target caches persist** between container restarts
- 🔄 **MongoDB data persists** across deployments
- 🐛 **Debug builds** enabled by default for development
- 🚀 **VS Code extensions** auto-install on first connection
- ⚙️ **User rustdev** (UID 1026, GID 110) for consistency across environments
- 🏷️ **Development aliases available**: `dev-h`, `dev-v`, `dev-s`, `dev-c`, `dev-l`
- 🦀 **Cargo shortcuts**: `cb`, `cr`, `ct`, `ccl`, `cf`, `cu`
- 🔀 **Git aliases**: `git st`, `git co`, `git br`, `git lg`
- 🐋 **Native glibc compilation** - Ubuntu dev environment builds for Ubuntu staging/prod
- 🔐 **System OpenSSL** - Uses Ubuntu's libssl-dev for native builds

*For version history and feature introduction dates, see [CHANGELOG.md](CHANGELOG.md)*

---

## Next Steps

After deployment:

1. ✅ Connect with VS Code: `code --remote ssh-remote+rust-dev /workspace`
2. ✅ Clone repository: `git clone https://github.com/tsouche/set_backend.git`
3. ✅ Build project: `cargo build`
4. ✅ Run application: `cargo run`
5. ✅ Test with Mongo Express: `http://localhost:8080`

Happy coding! 🦀
