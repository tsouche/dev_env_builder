# Rust DevContainer Image Builder

## Quick Start

Build and push with a specific version:

```powershell
.\build_and_push.ps1 [VERSION]
```

Example:

```powershell
.\build_and_push.ps1 0.5.6
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
- **Features**:
  - SSH server configured and running with host keys
  - VS Code extensions auto-install on first login
  - MongoDB tools (mongosh)
  - **GitHub CLI (gh)** - New in v0.6.0
  - Common dev tools (curl, wget, git, build-essential, etc.)
  - **Shell aliases**: ll, la, grep colors, cargo shortcuts (cb, cr, ct, cc, ccl, cf, cu)
  - **Git aliases**: st, co, br, ci, lg, unstage, last
  - **Dev service functions**: dev-h, dev-v, dev-s, dev-c, dev-l()
  - Empty `/workspace` directory ready for projects

## Troubleshooting

**Missing files error**: Ensure all required support files exist in this directory.
**Docker not running**: Start Docker Desktop
**Build fails**: Check Docker Desktop has enough resources allocated
**DockerHub login fails**: Verify your DockerHub credentials are correct

---
**Last Updated**: 2025-11-19
