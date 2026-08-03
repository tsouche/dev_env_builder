# Changelog - Rust Development Environment Builder

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.8.3] - 2026-08-04

### Fixed

- Docker socket inside `dev-container` was unusable for the `rustdev` user
  after migrating from Rancher Desktop to Docker Desktop — different
  backends expose `/var/run/docker.sock` under different host GIDs. Fixed
  with a new `docker-entrypoint.sh` that re-groups the socket at every
  container start, regardless of backend. Applied identically to
  [`dev_env_builder_postgresql`](https://github.com/tsouche/dev_env_builder_postgresql).
- `build_and_push.ps1`'s DockerHub login pre-check could falsely report
  "not logged in" under Docker Desktop (its `docker info` doesn't populate
  the legacy `Username:` field), forcing a non-interactive `docker login`
  that always fails. Replaced with a push-first approach.

See [build_base_dev_image/CHANGELOG.md](build_base_dev_image/CHANGELOG.md) for full detail.

---

## [0.8.2] - 2026-08-03

### Changed

- Removed `github.copilot`/`github.copilot-chat` from the base image's
  default VS Code extension list — both consistently failed to install and
  neither is part of this environment's AI stack. Applied the same change to
  [`dev_env_builder_postgresql`](https://github.com/tsouche/dev_env_builder_postgresql)
  to keep the two variants in sync. See
  [build_base_dev_image/CHANGELOG.md](build_base_dev_image/CHANGELOG.md).

---

## [0.8.1] - 2026-08-03

### Added

- **Exhaustive functional test suite**, reviewed across the whole
  environment (QMD, Rust, Docker CLI, Claude Code — not just Graphify):
  several existing checks only verified structural artifacts or binary
  presence, not that the tool actually worked. New functional checks catch
  the difference (see `deploy_dev_env/CHANGELOG.md` for the full list).
- **`restart: unless-stopped` on `dev-container`** — it needed a manual
  restart after every Docker/host backend hiccup, unlike the database
  containers which already had this.
- **Welcome banner** on every new interactive terminal: tool versions +
  new-project checklist (`~/init_qmd.sh`, `~/init_graphify.sh`).

### Fixed

Three bugs found by the new functional tests, all sharing the same root
cause — npm 12's install-scripts hardening silently blocking native-module
postinstall scripts unless explicitly allow-listed:

- **QMD indexing had never actually worked** — the native sqlite binding
  was never built (fixed with `--allow-scripts` on QMD's npm install), and
  independently, `init_qmd.sh`'s "already indexed" detection always
  false-positived on static text in `qmd status` output, so `collection
  add` never ran even once that was fixed. Both are fixed now; verified
  end-to-end with real indexing, real embeddings, real search results.
- **Claude Code CLI was completely non-functional** — every invocation
  failed with "claude native binary not installed," invisible in the old
  test suite because of a lenient fallback that reported a bare "installed"
  string on any failure. Fixed the same way as QMD.

See [build_base_dev_image/CHANGELOG.md](build_base_dev_image/CHANGELOG.md)
and [deploy_dev_env/CHANGELOG.md](deploy_dev_env/CHANGELOG.md) for full
technical detail.

---

## [0.8.0] - 2026-08-02

### Added

- **Graphify — AI code knowledge graph, next to QMD** ([GRAPHIFY.md](GRAPHIFY.md))
  - Structural code search (call graphs, path tracing) complementing QMD's
    content/semantic search — the two run side by side per project
  - `uv` + `graphifyy[mcp]` pre-installed in the base image, into `/usr/local`
    (zero LLM cost for code-only extraction: no API key, no GGUF models)
  - New `deploy_dev_env/init_graphify.sh`, wired into `deploy-dev.ps1` right
    after QMD's initialization
  - Per-repo: `graph.json`/`GRAPH_REPORT.md`/`graph.html` (committed to git),
    Claude Code project skill + `PreToolUse` hook, git commit hooks for
    auto-rebuild
  - Global `CLAUDE.md.template` routing rule: QMD for content/semantic
    questions, Graphify for structural questions
  - Extended `test-deployment.sh` with a full Graphify test section, written
    before the implementation so each build step had a red-to-green signal
  - See [build_base_dev_image/CHANGELOG.md](build_base_dev_image/CHANGELOG.md)
    and [deploy_dev_env/CHANGELOG.md](deploy_dev_env/CHANGELOG.md) for
    the two bugs found and fixed during verification (home-volume shadowing
    of per-user tool installs; missing `tomli` dependency for `--cargo` on
    Python 3.10)

---

## [0.7.0] - 2026-03-24

### Added

- **gstack Skills Framework** - Garry Tan's Claude Code virtual engineering team
  - 28 slash-command skills: /office-hours, /review, /qa, /browse, /ship, etc.
  - Global install in persistent `~/.claude/skills/gstack` volume
  - Idempotent init script (`init_gstack.sh`) — safe to re-run
  - Self-updating via `/gstack-upgrade` or redeployment
  - Telemetry off by default
  - CLAUDE.md template updated with gstack skill listing

- **Playwright + Chromium in base image**
  - Headless browser pre-installed for gstack `/browse`, `/qa`, `/benchmark` skills
  - System-level Chromium dependencies (libgbm1, libnss3, libatk-bridge2.0-0, etc.)
  - No first-use download delay

---

## [0.6.9] - 2026-02-01

### Changed - Deploy Environment

- **Claude Code Authentication Strategy**: Modified to prioritize claude.ai subscription usage
  - Commented out `ANTHROPIC_API_KEY` to prevent automatic API billing
  - Updated deployment script to guide users to authenticate with `claude login`
  - Enhanced documentation explaining both authentication methods
  - Reference: https://support.claude.com/en/articles/11145838

---

## [0.6.7] - 2026-01-23

### Removed

- **Ubuntu test container removed from deployment**
  - Removed `ubuntu-test` service from docker-compose-dev.yml
  - Deleted Dockerfile.ubuntu-test
  - Deleted test-ubuntu.ps1 and test-ubuntu.sh scripts
  - Removed automatic test execution from deploy-dev.ps1
  - Simplified deployment to 3 containers: dev-container, MongoDB, Mongo Express
  - Reason: Streamlined development environment, reduced resource usage

### Changed

- Updated documentation to reflect 3-container architecture
- Removed ubuntu-test references from README files and cleanup script

---

## [0.6.6] - 2026-01-22

### Changed

- **Migration from Alpine/musl to Ubuntu/glibc**: Complete removal of Alpine/musl support
  - Base image: Removed musl toolchain, OpenSSL musl compilation, and environment variables
  - Test container: Replaced `alpine-test` with `ubuntu-test` for hot-swap deployment testing
  - Build target: Native x86_64-unknown-linux-gnu (glibc) instead of musl cross-compilation
  - Purpose: Test hot-swap deployment workflow locally before NAS deployment

- **Ubuntu Test Container**: New permanent container for deployment workflow validation
  - Base: Ubuntu 22.04 with minimal runtime dependencies (libssl3, curl, ca-certificates)
  - User: testuser (UID 1026, GID 110) matching staging/prod environments
  - Simulates hot-swap deployment: copy binary to running container, test, restart
  
- **Test Scripts Renamed**: `test-alpine.*` → `test-ubuntu.*`
  - PowerShell: `test-ubuntu.ps1` for Windows host testing
  - Bash: `test-ubuntu.sh` for testing from inside dev container
  - Validates glibc compilation and hot-swap deployment workflow

- **Documentation Updates**: All references updated from Alpine/musl to Ubuntu/glibc
  - Deployment instructions reflect hot-swap workflow
  - Build commands simplified (no --target flag needed)
  - Dockerfile renamed: `Dockerfile` → `Dockerfile.ubuntu-dev`

### Removed

- **Alpine/musl Support**: Discontinued due to Tokio runtime incompatibility with musl libc
  - Removed musl-tools, custom OpenSSL compilation, musl environment variables
  - Removed x86_64-unknown-linux-musl target and cargo configuration
  - Removed Alpine test container and associated volumes

### Technical Details

- Version: 0.6.6
- Base image: tsouche/rust_dev_container:v0.6.6
- Test container: Ubuntu 22.04 (was Alpine 3.19)
- Build target: x86_64-unknown-linux-gnu (native glibc)
- Deployment: Ubuntu-based staging/production environments

---

## [0.6.3] - 2026-01-22

### Added

- **Alpine Test Container**: Permanent Alpine Linux 3.19 container for local musl binary testing
  - Runs alongside development environment (4 containers total)
  - Shared Docker volume for binary exchange between dev and Alpine containers
  - Static IP: 172.20.0.14 on dev-network
- **test-alpine.ps1 Script**: Automated cross-compilation verification
  - Creates simple Rust test program
  - Compiles with musl target inside Ubuntu dev container
  - Copies binary to shared volume
  - Executes on Alpine Linux to verify compatibility
  - Runs automatically during deployment
  - Can be executed independently anytime
- **Enhanced Build Verification**: Two-stage musl toolchain validation in Dockerfile
  - Stage 1: File existence checks (musl-gcc, OpenSSL, Rust target)
  - Stage 2: Functional compilation test
  - Catches configuration issues at build time

### Changed

- **deploy-dev.ps1**: Automatically runs Alpine container test after deployment (v0.6.2 → v0.6.3)
- **cleanup.ps1**: Now handles 4 containers including Alpine test container (v0.6.2 → v0.6.3)
- **docker-compose-dev.yml**: Added alpine-test service and shared volume configuration

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.3`
- Alpine container: `alpine:3.19`
- Shared volume: `alpine-test-binaries` (dev: `/alpine-test`, alpine: `/test`)
- ENV variables unchanged from v0.6.2
- Complete workflow: Compile in Ubuntu → Copy to volume → Test on Alpine
- Non-breaking change, fully backward compatible

---

## [0.6.2] - 2026-01-21

### Added

- **Alpine Linux Cross-Compilation Support**: Complete musl toolchain for static binaries
  - Development in Ubuntu 22.04 LTS
  - Deployment to Alpine-based staging/production
  - `x86_64-unknown-linux-musl` target pre-installed
  - Pre-compiled OpenSSL 3.0.13 for musl at `/usr/local/musl`
  - Automatic Cargo configuration for musl builds
- **Fixed OpenSSL/musl Compilation**: Added comprehensive Linux kernel headers
  - linux-libc-dev and linux-headers-generic packages
  - 8 include directory paths for musl-gcc
  - Resolves missing `linux/mman.h`, `asm/mman.h`, `asm/types.h` errors

### Documentation

- Updated README.md with cross-compilation workflows
- Added musl troubleshooting guide
- Clarified Ubuntu dev / Alpine production architecture
- Created comprehensive CHANGELOG.md

### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.2`
- OpenSSL 3.0.13 compiled with musl-gcc
- Static linking enabled via ENV variables
- Build-time verification of musl toolchain

---

## [0.5.5] - 2025-11-19

### Added

- **CHANGELOG.md**: Added comprehensive changelog file for version tracking
- **Enhanced Development Service Aliases**: added improved bash aliases and functions for quick API access from container terminal
  - `dev-c`: Now takes 'db' argument for database clearing
  - `dev-l`: Replaced with smart launch function with port parameter and health checking
- **Port Configuration**: Updated default application port to 5645 for development environment

### Changed

- **Version Update**: Updated all documentation and configuration files to reflect version 0.5.5
- **Base Image Reference**: Updated base image references from v0.5.4 to v0.5.5

### Fixed

- **Documentation Consistency**: Ensured all version references are consistent across all files

### Technical Details

- **Rust Cache Optimization**: Verified comprehensive Rust compilation cache setup with:
  - Incremental compilation (`CARGO_INCREMENTAL=1`)
  - Parallel build jobs (`CARGO_BUILD_JOBS=4`)
  - Persistent cache volumes for cargo registry, git dependencies, and target directory
  - Full backtrace support for debugging (`RUST_BACKTRACE=1`)

## [0.5.4] - 2025-11-15

### Added

- **Enhanced Rust Compiler Cache**: Comprehensive cache configuration for optimal development performance
- **Cache Directory Structure**: Complete setup of cargo registry, git, and rustup caches
- **Performance Optimizations**: Incremental compilation and parallel build jobs
- **Volume Mount Compatibility**: Cache directories designed to work with persistent volume mounts

### Changed

- **Build Environment**: Optimized Rust environment variables for better performance

## [0.5.1] - 2025-11-11

### Added

- **Automatic SSH Key Generation**: Deployment script now auto-generates SSH keys if none exist
- **SSH Configuration Automation**: Automatic addition of rust-dev host to SSH config
- **Project Directory Handling**: Interactive prompts for existing project directory management

### Changed

- **Documentation Updates**: Updated all references to reflect v0.5.1 features

## [0.5.0] - 2025-11-11

### Added

- **Complete Development Environment**: Full containerized Rust development setup
- **SSH Access**: Secure SSH server with key-based authentication
- **MongoDB Integration**: MongoDB database with Mongo Express admin interface
- **VS Code Remote Development**: Full VS Code integration with auto-installing extensions
- **Persistent Caching**: Volume mounts for cargo, git, and build caches
- **Automated Deployment**: PowerShell scripts for complete environment setup
- **Comprehensive Documentation**: Detailed setup and troubleshooting guides

### Technical Features

- Ubuntu 22.04 LTS base
- Rust stable toolchain via rustup
- MongoDB 7.0 with initialization scripts
- SSH server on configurable ports
- User isolation (rustdev:1026:110)
- Git configuration support
- Development workflow optimization

---

## Version History Summary

| Version | Date | Key Features |
|---------|------|--------------|
| 0.6.3 | 2026-01-22 | Alpine test container, automated musl verification |
| 0.6.2 | 2026-01-21 | Alpine/musl cross-compilation support, OpenSSL for musl |
| 0.5.5 | 2025-11-19 | Development aliases, port configuration |
| 0.5.4 | 2025-11-15 | Enhanced caching, performance optimizations |
| 0.5.1 | 2025-11-11 | SSH automation, project management |
| 0.5.0 | 2025-11-11 | Initial release with complete environment |

---

**Maintained by:** Thierry Souche  
**Last Updated:** January 22, 2026</content>
<parameter name="filePath">c:\rustdev\dev_env_builder\CHANGELOG.md
