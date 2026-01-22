# Changelog - Development Environment

All notable changes to the development environment deployment are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

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
