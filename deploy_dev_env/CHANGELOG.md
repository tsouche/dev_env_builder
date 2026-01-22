# Changelog - Development Environment

All notable changes to the development environment deployment are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [0.6.6] - 2026-01-22

### Changed

- **Switched from Alpine/musl to Ubuntu/glibc test container**
  - Replaced `alpine-test` service with `ubuntu-test` service
  - Base image: ubuntu:22.04 (was alpine:3.19)
  - Build context: Uses new Dockerfile.ubuntu-test
  - Purpose: Test hot-swap deployment workflow locally before NAS deployment
  - Simulates staging/prod environment for binary compatibility testing
  - Runtime deps: libssl3, curl, ca-certificates
  - Same network configuration (172.20.0.14)

- **New test scripts for Ubuntu container**
  - Created `test-ubuntu.ps1` (PowerShell version)
  - Created `test-ubuntu.sh` (Bash version for use inside dev container)
  - Tests native glibc-compiled binaries
  - Replaced `test-alpine.*` scripts (deprecated)

- **Updated base image reference**
  - Base: tsouche/rust_dev_container:v0.6.6 (was v0.6.5)
  - Removed musl toolchain, uses native glibc compilation

### Removed

- **Alpine test container removed**
  - Alpine/musl support discontinued
  - Reason: Tokio runtime incompatibility with musl libc
  - Migration: Use Ubuntu test container for binary verification

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.6`
- Test container: Ubuntu 22.04 with glibc runtime
- Build target: x86_64-unknown-linux-gnu (native, default)
- Deployment: Ubuntu-based staging/production environments

---

## [0.6.5] - 2026-01-22

### Fixed

- **OpenSSL Environment Variables Properly Persisted**: Added exports to shell profiles for full persistence
  - OpenSSL environment variables now **properly persisted** and available in all shell sessions
  - Variables exported in both `~/.bashrc` and `~/.profile` for complete coverage
  - **Fixes musl build failures** from interactive shells (SSH, VS Code terminal)
  - Previously only worked via `docker exec` due to ENV directives alone
  - **Impact**: Cargo builds with musl dependencies (like `reqwest`, `tokio-tls`) now work from any shell
  - Variables persisted: `OPENSSL_DIR`, `OPENSSL_LIB_DIR`, `OPENSSL_INCLUDE_DIR`, `OPENSSL_STATIC`, `PKG_CONFIG_ALLOW_CROSS`

- **Docker Socket Permissions**: Resolved permission issues for Docker CLI access
  - rustdev user now member of both `docker` (999) and `systemd-journal` (101) groups
  - Docker commands work correctly via SSH, VS Code terminal, and docker exec
  - Fixes "permission denied" errors when accessing Docker socket

### Changed

- **Simplified Alpine Testing Architecture**: Removed shared volume complexity
  - **Previous**: Shared volume mount between dev and Alpine containers
  - **New**: Direct `docker cp` from dev container to Alpine container
  - Eliminates all volume permission issues
  - Simpler, more reliable workflow
  - No intermediate volumes needed
- **test-alpine.ps1**: Updated to use `docker cp` approach
  - Copies binary via Windows temp directory to Alpine container
  - More reliable than shared volume
- **test-alpine.sh**: Updated to use `docker cp` approach
  - Compiles in user's home directory (`~/.alpine-test`)
  - Copies binary directly to Alpine container using Docker CLI
  - Automatic execution and verification
- **docker-compose-dev.yml**: Removed `alpine-test-binaries` volume
  - Cleaner configuration
  - No volume management needed
- **deploy-dev.ps1**: Removed shared volume permission configuration
  - No longer needed with `docker cp` approach

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.5`
- User groups: rustdev → rustdevteam (110), sudo (27), systemd-journal (101), docker (999)
- Alpine testing: `docker cp` + `docker exec` (no shared volumes)
- Full Docker CLI functionality from inside container
- Works seamlessly on Windows Docker Desktop

### Upgrade Notes

- Existing v0.6.4 deployments should upgrade to v0.6.5
- Shared volume `alpine-test-binaries` no longer used (can be removed)
- No configuration changes needed - automatic on redeploy
- All existing workflows remain compatible

---

## [0.6.4] - 2026-01-22

### Enhanced

- **Docker CLI Integration**: Docker CLI now available inside dev container
  - Base image upgraded from v0.6.3 to v0.6.4
  - Docker socket mounted: `/var/run/docker.sock`
  - Enables Docker commands from within dev container
  - test-alpine script can now automatically execute tests on Alpine container
  - No more manual `docker exec` commands needed

### Changed

- **test-alpine.sh**: Enhanced with automatic Alpine container execution
  - Compiles Rust program with musl target
  - Copies binary to shared volume
  - **NEW**: Automatically executes on Alpine container using Docker CLI
  - Shows complete test results in one command
  - Developer workflow: just run `test-alpine` inside container

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.4`
- Docker CLI version: Latest from official Docker repository
- Docker socket permissions handled automatically by Docker Desktop
- Backward compatible with v0.6.3 workflows

---

## [0.6.3] - 2026-01-22

### Added

- **Alpine Test Container**: Permanent Alpine Linux container for musl binary testing
  - Runs Alpine 3.19 alongside dev environment
  - Shared volume `/alpine-test` mounted in both dev and Alpine containers
  - Enables local runtime verification before staging/production deployment
  - IP address: 172.20.0.14
  - Container name: `dev-alpine-test`
- **test-alpine.ps1 Script**: Automated musl binary testing workflow
  - Creates simple Rust test program
  - Compiles with `x86_64-unknown-linux-musl` target in dev container
  - Copies binary to shared volume
  - Executes on Alpine Linux 3.19 container
  - Verifies output and reports success/failure
  - Runs automatically during deployment
  - Can be executed independently anytime
- **test-alpine Command**: Available inside dev container for developers
  - Bash script installed at `/usr/local/bin/test-alpine`
  - Same functionality as PowerShell version
  - Developers can test musl compilation from within container
  - Provides clear instructions for Alpine execution

### Changed

- **Enhanced Build Verification**: Added two-stage musl toolchain verification
  - Stage 1: File existence checks (musl-gcc, OpenSSL libraries, target)
  - Stage 2: Compilation test (compile and execute simple Rust program)
  - Ensures both toolchain presence AND functionality
- **deploy-dev.ps1**: Now runs Alpine container test automatically after deployment
  - v0.6.2 → v0.6.3
  - Continues deployment even if test fails (non-blocking)
  - User can re-run test manually with `.\test-alpine.ps1`

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.3`
- ENV variables unchanged from v0.6.2 (already correct)
- Improved build-time verification catches configuration issues
- Alpine container uses Docker volume for binary sharing
- Test workflow: Dev container → Shared volume → Alpine container
- No breaking changes, backward compatible

---

## [0.6.2] - 2026-01-21

### Added

- **Alpine Linux Cross-Compilation Support**: Pre-configured musl toolchain for building statically-linked binaries
  - Development environment runs Ubuntu 22.04
  - Cross-compile binaries for Alpine-based staging and production containers
  - `x86_64-unknown-linux-musl` target pre-installed
  - Pre-compiled OpenSSL 3.0.13 for musl in `/usr/local/musl`
  - Automatic Cargo configuration for musl builds
  - Build static binaries in Ubuntu dev → Deploy to Alpine staging/production
- Documentation for cross-compilation workflows

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.2` (Ubuntu 22.04)
- OpenSSL compiled with musl-gcc including comprehensive kernel headers
- Fixed musl-gcc compilation issues with Linux kernel header paths
- Dev container remains Ubuntu-based with cross-compilation toolchain

### Documentation

- Updated README.md with cross-compilation build instructions
- Added troubleshooting section for musl-specific issues
- Clarified Ubuntu dev / Alpine production architecture
- Updated CHANGELOG.md in build_dev_image directory

---

## [0.6.0] - 2026-01-03

### Added

- **GitHub CLI (gh)**: Repository management from terminal
  - Version 2.83.2
  - Commands: `gh auth login`, `gh repo clone`, `gh pr create`, etc.
- **Shell Aliases**: Convenient shortcuts for common operations
  - Navigation: `ll`, `la`, `l`, `..`, `...`
  - Colored output: `grep`, `fgrep`, `egrep`
- **Cargo Shortcuts**: Quick Rust development commands
  - `cb` → `cargo build`
  - `cr` → `cargo run`
  - `ct` → `cargo test`
  - `cc` → `cargo check`
  - `ccl` → `cargo clippy`
  - `cf` → `cargo fmt`
  - `cu` → `cargo update`
- **Git Aliases**: Enhanced git workflow
  - `git st` → status
  - `git co` → checkout
  - `git br` → branch
  - `git ci` → commit
  - `git unstage` → reset HEAD --
  - `git last` → log -1 HEAD
  - `git lg` → pretty graph log
- **Development Service Functions**: API testing helpers
  - `dev-h` → Health check
  - `dev-v` → Version info
  - `dev-s` → Shutdown server
  - `dev-c` → Clear database
  - `dev-l [port] [project]` → Launch server with auto-restart

### Documentation

- Created DEPLOYMENT_SUMMARY_v0.6.0.md with comprehensive deployment details
- Created QUICK_REFERENCE_v0.6.0.md for quick command lookup
- Created TESTING_GUIDE_v0.6.0.md for feature verification
- Created UPGRADE_TO_V0.6.0.md for migration instructions
- Updated README.md with v0.6.0 features section

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.0`
- All aliases configured in `.bashrc`
- Git aliases stored in global git config
- Functions require interactive shell (VS Code Remote-SSH)

### Known Behaviors

- Shell aliases and functions don't appear in non-interactive SSH (expected)
- All features fully functional in VS Code Remote-SSH terminals
- Git aliases work in all contexts (stored in git config, not bash)

---

## [0.5.6] - 2025-11-19

### Added

- **Automatic SSH Key Generation**: Script detects and generates SSH keys if none exist
  - Supports ed25519 (preferred) or RSA keys
  - Automatically configures `~/.ssh/config`
  - Copies public key to container's `authorized_keys`
- **Interactive Project Directory Handling**: Prompts for existing project directories
  - Options: Keep, Delete, or Cancel deployment
  - Prevents accidental data loss

### Changed

- Enhanced `deploy-dev.ps1` script with improved error handling
- Updated `cleanup.ps1` with confirmation prompt (requires typing "YES")
- Improved MongoDB network documentation with static IP details

### Documentation

- Comprehensive README.md update (926 lines)
- Documented hard-coded MongoDB IPs (172.20.0.10, 172.20.0.12)
- Added troubleshooting section for SSH key permissions
- Enhanced network configuration documentation

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.5.6`
- MongoDB static IP: 172.20.0.10
- Mongo Express static IP: 172.20.0.12
- Network: dev-network (172.20.0.0/24)

### Fixed

- SSH key permission handling on Windows
- Project directory conflict handling
- MongoDB connection string documentation

---

## [0.5.5] - 2025-11

### Changed

- Refined deployment scripts for Windows PowerShell
- Improved Docker Compose configuration
- Enhanced environment variable management

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.5.5`
- Services: dev-container, dev-mongodb, dev-mongo-express
- Ports: SSH (2222), App (5645), MongoDB (27017), Mongo Express (8080)

---

## [0.5.0] - 2025-11

### Added

- Initial development environment deployment structure
- Docker Compose configuration for multi-service setup
- MongoDB integration with initialization scripts
- Mongo Express web UI for database administration
- VS Code Remote-SSH configuration
- Automated deployment scripts for Windows

### Features

- **Dev Container**: Rust development environment with SSH access
- **MongoDB**: Database service with persistent storage
- **Mongo Express**: Web-based MongoDB admin interface
- **Bind Mounts**: Project workspace and cache persistence
- **Custom Network**: Isolated Docker network for services

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.5.x`
- Ubuntu 22.04 LTS base
- Rust stable toolchain
- User: rustdev (UID 1026, GID 110)

### Scripts

- `deploy-dev.ps1`: Complete deployment automation
- `cleanup.ps1`: Environment cleanup and removal
- `docker-compose-dev.yml`: Service orchestration
- `01-init-db.js`: MongoDB initialization

---

## Quick Reference

### Version Compatibility

| Version | Base Image | Key Features |
|---------|------------|--------------|
| 0.6.2 | v0.6.2 | Alpine/musl support, OpenSSL for musl |
| 0.6.0 | v0.6.0 | GitHub CLI, shell aliases, git shortcuts |
| 0.5.6 | v0.5.6 | Auto SSH key gen, interactive prompts |
| 0.5.5 | v0.5.5 | Refined deployment scripts |
| 0.5.0 | v0.5.x | Initial release |

### Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| SSH | 2222 | VS Code Remote-SSH access |
| Application | 5645 | Backend application |
| MongoDB | 27017 | Database service |
| Mongo Express | 8080 | Database admin UI |

### Directory Structure

```sh
C:\rustdev\
├── projects\              # Project workspace
├── docker\
│   ├── mongodb\
│   │   ├── data\         # MongoDB persistent storage
│   │   └── init\         # Initialization scripts
│   ├── cargo_cache\      # Cargo registry cache
│   └── target_cache\     # Rust build cache
```

### Migration Notes

**Upgrading from v0.5.x to v0.6.0+**:

1. Rebuild base image with new version
2. Update Dockerfile `FROM` line
3. Run `.\deploy-dev.ps1`
4. Reconnect VS Code to load new features

**Upgrading to v0.6.2**:

1. Build base image: `.\build_and_push.ps1 0.6.2`
2. Update deployment configuration
3. Redeploy environment
4. musl toolchain available immediately

---

## Resources

- **Base Image Repository**: [build_dev_image/](../build_dev_image/)
- **Base Image Changelog**: [build_dev_image/CHANGELOG.md](../build_dev_image/CHANGELOG.md)
- **Deployment Guide**: [README.md](README.md)
- **Project Root**: [../README.md](../README.md)

---

**Maintained By**: Development Team  
**Last Updated**: 2026-01-21
