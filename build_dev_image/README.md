# Rust DevContainer Image Builder

## Quick Start

Build and push with a specific version:

```powershell
.\build_and_push.ps1 [VERSION]
```

Example:

```powershell
.\build_and_push.ps1 0.6.7
```

Or build with 'latest' tag only (default):

```powershell
.\build_and_push.ps1
```

Default: `latest` tag only (if no version specified)

## Prerequisites

1. **Docker Desktop**: Ensure Docker is running on Windows
2. **DockerHub Credentials**: The script will automatically check and prompt for login if needed
3. **Required Files**: The following files must exist in this directory:
   - `Dockerfile.rustdev` (main Dockerfile)
   - `authorized_keys.template` (placeholder SSH keys file)
   - `install_vscode_extensions.sh` (VS Code extension installer)
   - `devcontainer.json` (Dev container configuration)

## What It Does

1. Validates all required files exist locally
2. **Checks Docker is running**
3. Builds image locally: `tsouche/rust_dev_container:vX.Y.Z`
4. Tags with: `vX.Y.Z`, `vX.Y`, `latest`
5. **Checks DockerHub login status (prompts for login if needed)**
6. Pushes all tags to DockerHub

## Image Details

- **Base**: Ubuntu 22.04
- **User**: rustdev (UID 1026, GID 110)
- **Rust**: Installed via rustup (stable toolchain)
- **Native glibc Compilation**: Builds for Ubuntu-based deployments
- **Features**:
  - SSH server configured and running with host keys
  - VS Code extensions auto-install on first login
  - MongoDB tools (mongosh)
  - **GitHub CLI (gh)** - v0.6.0+
  - **Docker CLI** - v0.6.5+ for container management
  - Common dev tools (curl, wget, git, build-essential, libssl-dev, pkg-config, etc.)
  - **Native glibc builds** - v0.6.6+:
    - Default `x86_64-unknown-linux-gnu` target (native)
    - Uses system OpenSSL via libssl-dev
    - Builds for Ubuntu-based staging/production environments
  - **Shell aliases**: ll, la, grep colors, cargo shortcuts (cb, cr, ct, cc, ccl, cf, cu)
  - **Git aliases**: st, co, br, ci, lg, unstage, last
  - **Dev service functions**: dev-h, dev-v, dev-s, dev-c, dev-l
  - Empty `/workspace` directory ready for projects

## Building for Ubuntu Deployment

The image is configured for native Ubuntu glibc compilation:

```bash
# Build for Ubuntu deployment (native glibc)
cargo build --release

# The resulting binary is dynamically linked with glibc
./target/release/your_app
```

System OpenSSL (libssl-dev) is available via pkg-config, so dependencies like `reqwest` work seamlessly.

## Troubleshooting

**Missing files error**: Ensure all required support files exist in this directory.
**Docker not running**: Start Docker Desktop
**Build fails**: Check Docker Desktop has enough resources allocated (recommend 8GB+ RAM for building)
**DockerHub login fails**: Verify your DockerHub credentials are correct
**OpenSSL link errors**: The image includes system libssl-dev via pkg-config

---
**Last Updated**: 2026-01-22
