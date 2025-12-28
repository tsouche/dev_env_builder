# Development Environment Guide - v0.5.6

Complete guide for deploying and using the local development container on Windows laptop.

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

- **Platform**: Windows laptop with Docker Desktop
- **Container**: Rust development environment with SSH access
- **Base Image**: `tsouche/rust_dev_container:v0.5.6`
- **Services**: Dev container + MongoDB + Mongo Express
- **Access**: VS Code Remote SSH to localhost

**Container Features:**

- Ubuntu 22.04 LTS
- Rust stable toolchain (via rustup)
- Build tools (gcc, cmake, pkg-config, libssl-dev)
- MongoDB Shell (mongosh)
- SSH server on port 2222
- VS Code extensions auto-install
- User: rustdev (UID 1026, GID 110)

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

```
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
- **Remote - SSH: Editing Configuration Files** (optional)

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
7. Starts all services

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

### Automatic Configuration (v0.5.6+)

The deployment script automatically:

1. Detects existing SSH keys (`~/.ssh/id_ed25519` or `~/.ssh/id_rsa`)
2. Generates new ed25519 key if none exists
3. Copies public key to container's `authorized_keys`
4. Adds `rust-dev` host to `~/.ssh/config`

**Generated SSH Config:**

```ssh-config
# Rust Development Environment v0.5.6 - Auto-generated
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

### deploy-dev.ps1 (v0.5.6)

**Purpose**: Complete environment deployment

**Usage:**

```powershell
.\deploy-dev.ps1
```

**Features:**

- Automatic SSH key generation (new in v0.5.6)
- Project directory handling (keep/delete/cancel)
- Directory structure creation
- MongoDB initialization
- Docker image build
- Service startup

**Interactive Prompts:**

```
Existing project directory found: C:\rustdev\projects\set_backend
Options:
  1. Keep existing directory
  2. Delete and start fresh (default)
  3. Cancel deployment
Enter choice (1/2/3) [2]:
```

### cleanup.ps1 (v0.5.6)

**Purpose**: Complete environment cleanup

**Usage:**

```powershell
.\cleanup.ps1
```

**Warning**: Requires confirmation (type `YES`)

**Removes:**

- All containers (dev-container, dev-mongodb, dev-mongo-express)
- All Docker images
- Project directory (`C:\rustdev\projects`)
- MongoDB data (`C:\rustdev\docker\mongodb`)
- Cargo cache (`C:\rustdev\docker\cargo_cache`)
- Target cache (`C:\rustdev\docker\target_cache`)

**Preserves:**

- SSH keys (`~/.ssh/`)
- SSH config (`~/.ssh/config`)
- VS Code settings

---

## Services & Access

### Service Ports

| Service | Port | Access | Description |
|---------|------|--------|-------------|
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

Defined in `.env` (v0.5.6):

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

```
mongodb://app_user:DevPassword123@mongo-db:27017/rust_app_db
```

**Using static IP (from within container):**

```
mongodb://app_user:DevPassword123@172.20.0.10:27017/rust_app_db
```

**From host (Windows):**

```
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

# Test
cargo test
```

### 4. Development Service Aliases

**Convenient aliases and functions** are available for quick API testing:

```bash
# Health check
dev-h

# Version info
dev-v

# Shutdown service
dev-s

# Clear data (takes 'db' argument)
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

**Inside container:**

```bash
# Edit code in VS Code
# Save changes (Ctrl+S)

# Build and run
cargo run

# Or use cargo-watch (if installed)
cargo watch -x run

# Debug with VS Code
# F5 to start debugging (CodeLLDB extension)
```

### 5. Database Operations

**Check data with Mongo Express:**

```
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

```
C:\path\to\set_backend\src\env_dev\
├── .env                       # Environment configuration (v0.5.6)
├── Dockerfile                 # Dev container definition
├── docker-compose-dev.yml     # Services orchestration (v0.5.6)
├── deploy-dev.ps1            # Deployment script (v0.5.6)
├── cleanup.ps1               # Cleanup script (v0.5.6)
├── 01-init-db.js             # MongoDB initialization (auto-generated)
├── authorized_keys            # SSH public key (auto-generated)
└── README.md                 # This guide
```

### Windows Host Directories

```
C:\rustdev\
├── projects\                  # Project workspace
│   └── set_backend\          # Cloned repository (inside container)
│
└── docker\
    ├── mongodb\
    │   ├── data\             # MongoDB data (persistent)
    │   └── init\             # Init scripts
    ├── cargo_cache\          # Cargo registry cache
    └── target_cache\         # Rust build artifacts cache
```

### Container Structure

```
/workspace/                    # Mounted from C:\rustdev\projects
├── set_backend/              # Your project (clone here)
│   ├── src/
│   ├── Cargo.toml
│   └── ...

/home/rustdev/
├── .cargo/
│   └── registry/             # Mounted from C:\rustdev\docker\cargo_cache
├── .vscode-server/           # VS Code server
├── .ssh/
│   └── authorized_keys       # Your public key
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

```
VS Code Remote:    ssh rust-dev
SSH Manual:        ssh -p 2222 rustdev@localhost
Backend:           http://localhost:5645
MongoDB:           mongodb://localhost:27017
Mongo Express:     http://localhost:8080 (dev/dev123)
```

### Version Summary

- **Environment**: v0.5.6
- **Base Image**: tsouche/rust_dev_container:v0.5.6
- **New in v0.5.6**: Documentation improvements for MongoDB network configuration with hard-coded IPs

---

## Notes

- 🔑 **SSH keys auto-generated** if none exist (new in v0.5.6)
- 📂 **Clone projects inside container** - NOT on Windows!
- 💾 **Cargo/target caches persist** between container restarts
- 🔄 **MongoDB data persists** across deployments
- 🐛 **Debug builds** enabled by default for development
- 🚀 **VS Code extensions** auto-install on first connection
- ⚙️ **User rustdev** (UID 1026, GID 110) for consistency across environments
- 🏷️ **Enhanced development aliases** available: `dev-h`, `dev-v`, `dev-s`, `dev-c` (with db arg), `dev-l` (smart function with port parameter)

---

## Next Steps

After deployment:

1. ✅ Connect with VS Code: `code --remote ssh-remote+rust-dev /workspace`
2. ✅ Clone repository: `git clone https://github.com/tsouche/set_backend.git`
3. ✅ Build project: `cargo build`
4. ✅ Run application: `cargo run`
5. ✅ Test with Mongo Express: `http://localhost:8080`

Happy coding! 🦀
