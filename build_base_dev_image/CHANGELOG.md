# Changelog for BuildDevImage scripts

## Version 0.7.0 (March 24, 2026)

### 🌐 Playwright/Chromium for gstack /browse

**Pre-installed headless browser for AI-driven web browsing skills**

#### Changes

- **Playwright + Chromium pre-installed in base image**
  - System-level browser dependencies (libgbm1, libnss3, libatk-bridge2.0-0, etc.)
  - Chromium installed via `bunx playwright install chromium`
  - Enables gstack's `/browse` skill to work out-of-the-box
  - No first-use download delay — browser ready immediately

#### Technical Details

- Playwright installed via Bun (bunx)
- Chromium binary cached at system level
- ~200MB added to base image size
- Required by: gstack `/browse`, `/qa`, `/qa-only`, `/benchmark`, `/canary` skills

---

## Version 0.6.13 (February 10, 2026)

### 🚀 Enhanced QMD Auto-Integration

**Automatic project configuration and periodic repository scanning**

#### Changes

- **Periodic Repository Scanning** ⚠️ CRITICAL
  - Enhanced `.bashrc` auto-init to check for new repositories every hour
  - Automatically runs `~/init_qmd.sh` when new git repos are detected
  - Eliminates need for manual QMD re-indexing after cloning repositories
  - Uses timestamp file `~/.cache/qmd/last_repo_check` to track last scan

- **Automatic Claude Code Project Configuration** ⚠️ CRITICAL
  - `init_qmd.sh` now automatically updates `.claude.json` project configurations
  - Adds QMD contexts (`qmd://project_name`, `qmd://project_name/src`) to `mcpContextUris`
  - Claude Code immediately uses QMD for code searches without manual setup
  - No manual `.claude.json` editing required after cloning

- **Enhanced Auto-Init Function**
  - Added repository change detection logic
  - Silent background re-indexing (`> /dev/null 2>&1`)
  - Maintains existing index freshness warnings (>24h old)

#### Technical Details

- Repository scan interval: 3600 seconds (1 hour)
- Project config update: Python script embedded in `init_qmd.sh`
- Context discovery: Parses `qmd context list` output
- MCP integration: Automatic `mcpContextUris` population

**Future deployments will have fully automated QMD integration!** 🎉

---

## Version 0.6.12 (February 10, 2026)

### 🐛 Critical Fixes

**Fixed .bashrc syntax errors, QMD path configuration, and MCP integration**

#### Changes

- **MCP configuration location** ⚠️ CRITICAL
  - Fixed: Claude Code uses `~/.claude.json`, not `~/.claude/settings.json`
  - Created symlink: `~/.claude.json` → `~/.claude/claude.json` (line 293)
  - Makes MCP configuration eternal (persists in Windows bind mount across all projects)
  - Removed creation of unused `~/.claude/settings.json`
  - **Deployment script now properly merges QMD MCP server into existing config**
  - Claude Code can now discover QMD MCP server properly

- **Bash syntax error in auto-init function** ⚠️ CRITICAL
  - Removed incorrect backslash escaping in variable substitutions
  - Fixed: `LAST_UPDATE=\$(...)` → `LAST_UPDATE=$(...)`
  - Fixed: `NOW=\$(...)` → `NOW=$(...)`
  - Fixed: `DIFF=\$((...))` → `DIFF=$((...))` 
  - Fixed: `[ \$DIFF -gt ...]` → `[ $DIFF -gt ...]`
  - Previous versions had bash syntax errors preventing .bashrc from loading

- **Auto-init path corrected**
  - Changed check from `~/.local/share/qmd/index.sqlite` to `~/.cache/qmd/index.sqlite`
  - Matches QMD's actual storage behavior
  - Prevents unnecessary re-initialization

#### Technical Details

- QMD stores index at: `~/.cache/qmd/index.sqlite` (not `.local/share`)
- Auto-init function: Lines 305-322 in Dockerfile.base_rust_dev
- Bash escaping: Use `$var` inside single-quoted echo strings (not `\$var`)
- Index freshness check: Uses correct path for stat command

**Note**: This fixes a critical bug in v0.6.11. Rebuild base image recommended.

---

## Version 0.6.11 (February 9, 2026)

### 🔧 QMD Pre-Installation & Directory Structure Fixes

**QMD moved to base image for performance and reliability**

#### Changes

- **QMD pre-installed in base image**
  - Moved from deployment-specific image to base image
  - Reduces deployment time by 30-60 seconds (no re-download)
  - Installed via: `bun install -g github:tobi/qmd`
  - Version verified during build

- **Directory structure pre-created**
  - `/home/rustdev/.local/share` - for QMD SQLite database
  - `/home/rustdev/.cache/qmd` - for GGUF models (~2GB)
  - Proper ownership: `rustdev:rustdevteam` (1026:110)

- **PATH configuration**
  - Added QMD to PATH via `.bashrc`
  - Ensures `qmd` command available immediately

- **MCP configuration**
  - Claude Code MCP settings pre-configured in `~/.claude/settings.json`
  - Ready for integration with Claude Code out of the box

- **QMD aliases and auto-init**
  - Shell aliases: `qmd-update`, `qmd-refresh`, `qmd-status`, `qmd-search`, `qmd-reindex`
  - Auto-init function: Detects uninitialized QMD and runs init automatically
  - Index freshness check: Warns if index >24h old

#### Benefits

- **Faster deployments**: QMD only installed once during base image build
- **No initialization failures**: Directories exist with correct permissions from the start
- **Consistent environment**: All deployment environments have same QMD version
- **Ready-to-use**: MCP and aliases configured, no manual setup required

#### Technical Details

- Installation location: `/usr/local/install/global/node_modules/qmd`
- Database path: `~/.local/share/qmd/index.sqlite`
- Cache path: `~/.cache/qmd/models/`
- MCP config: `~/.claude/settings.json`
- Ownership: All directories owned by rustdev:rustdevteam

**Note**: This version is required for deployment environments v0.6.11+

---

## Version 0.6.10 (February 9, 2026)

### 🚀 QMD Support - Bun Runtime Addition

**Added Bun runtime for AI-optimized code indexing capabilities**

#### Changes

- **Added Bun runtime** (latest stable version)
  - System-wide installation in `/usr/local`
  - Required dependency for QMD (Query Markup Documents)
  - Enables AI-assisted development in deployment environments
- Bun installed after Node.js, before Rust toolchain
- Symlink `bunx` created for convenience
- Version verification included in build process

#### Benefits

- **Enables QMD integration** in deployment images
  - AI-optimized code indexing
  - 60-80% reduction in Claude Code token usage
  - Semantic search capabilities
- **Lightweight addition**: ~50MB total
- **System-wide availability**: All users can access Bun

#### Technical Details

- Installation: `curl -fsSL https://bun.sh/install | bash -s -- --prefix /usr/local`
- Environment: `BUN_INSTALL=/usr/local`, added to PATH
- Verification: `bun --version` runs during build

**Note**: This version is a prerequisite for QMD-enabled deployment environments (v0.7.0+)

---

## Version 0.6.9 (February 1, 2026)

### 📝 Version Update

**Version consistency update - no functional changes to the base image**

#### Changes

- Updated version references to 0.6.9 for consistency with deployment environment
- Deployment environment updated to use claude.ai subscription by default for Claude Code
- No changes to base image itself

---

## Version 0.6.8 (January 27, 2026)

### 🛡️ Security & SSL Improvements

**Added ca-certificates and updated certificate store for improved SSL support**

#### Changes

- Added `ca-certificates` package to the base image
- Ran `update-ca-certificates` to ensure up-to-date trusted roots
- Updated version references to 0.6.8 for consistency
- No other functional changes

**Note**: The base image `tsouche/rust_dev_container:v0.6.8` now includes ca-certificates and updated certs for improved SSL support.

---

## Version 0.6.7 (January 23, 2026)

### 📝 Documentation Update

**Version consistency update - no functional changes to the base image**

#### Changes

- Updated version references to 0.6.7 for consistency with deployment scripts
- No changes to base image functionality or dependencies
- Base image remains Ubuntu 22.04 with native glibc compilation (v0.6.6)
- This release focuses on deployment environment changes (removal of ubuntu-test container)

**Note**: The base image `tsouche/rust_dev_container:v0.6.6` remains unchanged and fully compatible. This version bump is for deployment script alignment only.

---

## Version 0.6.6 (January 22, 2026)

### 🔄 Major Change - Alpine/musl to Ubuntu/glibc Migration

**Removed musl toolchain support, switched to native glibc compilation**

#### Changes

##### Removed musl/Alpine Support

- **Removed musl-tools** from system dependencies
  - No longer installing musl-gcc, perl, linux-libc-dev, linux-headers-generic
  - Alpine Linux binary support discontinued due to Tokio runtime incompatibility
  
- **Removed custom OpenSSL compilation** for musl target
  - Removed entire OpenSSL 3.0.13 musl compilation section
  - No longer needed with native glibc builds
  - Uses system libssl-dev (already installed)

- **Removed musl environment variables**
  - Removed OPENSSL_DIR, OPENSSL_LIB_DIR, OPENSSL_INCLUDE_DIR
  - Removed OPENSSL_STATIC, PKG_CONFIG_ALLOW_CROSS
  - Removed exports from .bashrc and .profile

- **Removed musl target configuration**
  - No longer adding x86_64-unknown-linux-musl target
  - Removed .cargo/config.toml musl configuration
  - Removed musl verification tests (Stage 1 & 2)

##### Native glibc Only

- **Default build target**: x86_64-unknown-linux-gnu (native)
  - No custom target flags needed
  - Uses system OpenSSL via pkg-config
  - Faster builds, no cross-compilation overhead
  - Full Tokio runtime support

**Reason for change**: Tokio async runtime has fundamental incompatibility with musl libc, causing segfaults. Ubuntu/glibc is the proven production-ready solution for Rust async applications.

**Migration impact**:

- Existing projects: Change build target from musl to native (default)
- Deployment: Switch from Alpine to Ubuntu-based containers
- Build command: `cargo build --release` (no --target flag needed)
- Binary size: ~30MB dynamically linked (vs 28MB static musl)
- Container size: ~60MB Ubuntu (vs ~30MB Alpine)

---

## Version 0.6.5 (January 22, 2026)

### 🔧 Fix - Docker Socket Permissions, OpenSSL Environment Variables & Architecture Simplification

**Proper Docker group membership, environment variable persistence, and simplified Alpine testing workflow**

#### Fixes

##### OpenSSL Environment Variables for Interactive Shells

- **Added OpenSSL environment variable exports** to `.bashrc` and `.profile`
  - Variables were set via `ENV` directives but not available in SSH/terminal sessions
  - Caused musl builds to fail from interactive shells (SSH, VS Code terminal)
  - Now properly persisted and exported in both shell profile files for login/interactive shells

**Why both ENV and shell exports are needed:**

- `ENV` directives: Available to non-interactive processes (`docker exec`, VS Code tasks)
- Shell exports: Available in interactive sessions (SSH, terminal, `bash -l`)

**Variables now persisted:**

```bash
export OPENSSL_DIR=/usr/local/musl
export OPENSSL_LIB_DIR=/usr/local/musl/lib64
export OPENSSL_INCLUDE_DIR=/usr/local/musl/include
export OPENSSL_STATIC=1
export PKG_CONFIG_ALLOW_CROSS=1
```

**Impact:**

- ✅ Musl builds now work from SSH sessions
- ✅ Musl builds now work from VS Code terminal
- ✅ Environment variables properly inherited by all shell sessions
- ✅ Consistent behavior across all access methods

##### Docker Group Membership

- **Docker group** created in base image (GID 999)
  - rustdev user added to docker group during image build
  - Ensures Docker socket access when mounted from host
  - Fixes permission denied errors when running Docker commands

##### Simplified Alpine Testing Architecture

- **Removed shared volume mount** between dev and Alpine containers
  - Previous: Shared `/alpine-test` volume with complex permissions
  - New: Direct `docker cp` from dev container to Alpine container
  - Eliminates all volume permission issues
  - Simpler, more reliable workflow

##### Why This Matters

- **SSH access**: Docker commands now work when connecting via SSH
  - Previously: Only worked via `docker exec` (runs as root)
  - Now: Works for rustdev user in all connection modes
- **No permission issues**: Binary copying uses `docker cp` (always works)
- **test-alpine script**: Fully functional via SSH or terminal
- **Cleaner architecture**: No intermediate shared volumes needed

#### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.5`
- Docker group GID: 999 (common default across Docker installations)
- User membership: rustdev → docker, sudo, rustdevteam groups
- Socket mount: `/var/run/docker.sock` (configured in deployment)
- Alpine testing: `docker cp` + `docker exec` (no shared volumes)

#### Upgrade Notes

- Existing v0.6.4 deployments should upgrade to v0.6.5
- Shared volume `alpine-test-binaries` no longer needed
- Redeploy dev environment to apply simplified architecture

---

## Version 0.6.4 (January 22, 2026)

### 🐳 Enhancement - Docker CLI Integration

**Added Docker CLI to base image for developer testing capabilities**

#### New Features

##### Docker CLI Installed Natively

- **Docker CLI** included in base image
  - Enables developers to run Docker commands from inside dev container
  - Required for `test-alpine` script to execute tests automatically
  - Works seamlessly with Docker socket mount from host

##### Why This Matters

- **test-alpine command**: Now automatically executes Alpine tests
  - Previously: Script only prepared binary, user had to test manually
  - Now: Script compiles AND tests on Alpine in one command
- **Developer workflow**: Run `test-alpine` and get immediate results
- **CI/CD ready**: Automated testing without manual intervention

#### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.4`
- Docker CLI: Latest from official Docker repository (Ubuntu Jammy)
- Requires: Docker socket mount (`/var/run/docker.sock`)
- No breaking changes: Fully compatible with v0.6.3

#### Usage

```bash
# From inside dev container
test-alpine

# Automatically:
# 1. Creates test Rust program
# 2. Compiles with musl target
# 3. Copies to shared volume
# 4. Executes on Alpine container
# 5. Verifies output
```

---

## Version 0.6.3 (January 22, 2026)

### 🔧 Enhancement - Improved Build Verification

**Enhanced musl toolchain verification with comprehensive testing**

#### Improvements

##### 1. Two-Stage Verification Process

- **Stage 1: File Existence Checks**
  - Verifies musl target is installed
  - Confirms musl-gcc compiler availability
  - Validates pre-compiled OpenSSL static libraries
  - Fast validation of toolchain components

- **Stage 2: Compilation Test**
  - Compiles a simple Rust program with musl target
  - Executes the compiled binary to verify runtime
  - Confirms end-to-end musl compilation workflow
  - Catches environment variable or linker issues

##### 2. Why Both Stages Matter

- **Existence checks**: Fast, catches missing files/packages
- **Compile test**: Thorough, verifies ENV variables work correctly
- **Together**: Ensures both toolchain presence AND functionality

#### Technical Details

- Base image: `tsouche/rust_dev_container:v0.6.3`
- ENV variables already present from v0.6.2
- Verification catches configuration issues during build
- Prevents deployment of non-functional musl environments

#### Migration from v0.6.2

- ENV variables unchanged (already correct in v0.6.2)
- Only verification logic enhanced
- No breaking changes
- Rebuild recommended for verification benefits

---

## Version 0.6.2 (January 21, 2026)

### 🚀 Feature Enhancement - Alpine Linux Build Support

**Major Update**: Added complete toolchain support for building statically-linked binaries for Alpine Linux deployment.

#### New Features

##### 1. musl Toolchain Support

- **musl-tools** package installed for musl libc compilation
- **x86_64-unknown-linux-musl** Rust target added
- Enables building statically-linked binaries for Alpine Linux
- Configured Cargo to use `musl-gcc` linker automatically

##### 2. Pre-compiled OpenSSL for musl

- **OpenSSL 3.0.13** pre-compiled with musl during image build
- Static libraries available at `/usr/local/musl`
- **Dramatically faster builds**: ~30 seconds vs 5-10 minutes per build
- Environment variables configured for seamless OpenSSL linking:
  - `OPENSSL_DIR=/usr/local/musl`
  - `OPENSSL_LIB_DIR=/usr/local/musl/lib64`
  - `OPENSSL_INCLUDE_DIR=/usr/local/musl/include`
  - `OPENSSL_STATIC=1`

##### 3. Automatic Build Configuration

- Cargo config at `/home/rustdev/.cargo/config.toml` configures musl builds
- Static linking enabled with `target-feature=+crt-static`
- Cross-compilation setup with `PKG_CONFIG_ALLOW_CROSS=1`

##### 4. Build Environment Verification

- Automated verification checks during image build
- Validates musl-gcc availability
- Confirms OpenSSL static libraries are present
- Ensures x86_64-unknown-linux-musl target is installed

#### Benefits

- **Fast Iterative Development**: First build ~2-3 minutes, subsequent builds ~30 seconds
- **Zero Runtime Dependencies**: Binaries run on Alpine without external libs
- **Seamless Experience**: Simple `cargo build --target x86_64-unknown-linux-musl --release`
- **Production Ready**: Generates deployment-ready Alpine binaries from dev container

#### Technical Details

- OpenSSL version: 3.0.13 (compiled with no-shared, no-async flags)
- Rust target: x86_64-unknown-linux-musl
- Linker: musl-gcc
- Static linking: Enabled for all dependencies
- Additional packages: perl (for OpenSSL compilation)

#### Usage

```bash
# Build statically-linked binary for Alpine Linux
cargo build --target x86_64-unknown-linux-musl --release

# Verify static linking
file target/x86_64-unknown-linux-musl/release/your_binary
# Output: "statically linked"

# Test on Alpine (no dependencies needed)
docker run --rm -v $(pwd):/app alpine:3.19 /app/target/x86_64-unknown-linux-musl/release/your_binary
```

#### Breaking Changes

None. Existing Ubuntu-based builds continue to work normally. Alpine support is an additional target.

---

## Version 0.6.1 (January 21, 2026)

### 🧹 Cleanup - Removed Service-Specific Aliases

**Changes**: Removed set-backend specific aliases to keep the base image more generic and focused on general Rust development.

#### Removed Features

- Removed `dev-h` alias (Health check endpoint)
- Removed `dev-v` alias (Version endpoint)

These service-specific aliases should be defined in project-specific configurations rather than the base development image.

---

## Version 0.6.0 (January 3, 2026)

### ✨ Feature Enhancement - Shell Productivity & GitHub Integration

**Major Updates**: Added GitHub CLI, comprehensive shell aliases, and moved development functions to base image.

#### New Features

##### 1. GitHub CLI Integration

- **GitHub CLI (gh)** installed in base image
- Enables repository management from terminal
- PR and issue handling without leaving VS Code
- Supports GitHub authentication and token management
- Usage: `gh auth login`, `gh repo clone`, `gh pr create`, etc.

##### 2. Shell Aliases & Productivity

**Common Shell Aliases:**

- File listing: `ll`, `la`, `l`
- Navigation: `..` (up one dir), `...` (up two dirs)
- Colored output: `grep`, `fgrep`, `egrep`

**Cargo Shortcuts:**

- `cb` → `cargo build`
- `cr` → `cargo run`
- `ct` → `cargo test`
- `cc` → `cargo check`
- `ccl` → `cargo clippy`
- `cf` → `cargo fmt`
- `cu` → `cargo update`

**Git Aliases:**

- `git st` → status
- `git co` → checkout
- `git br` → branch
- `git ci` → commit
- `git unstage` → reset HEAD
- `git last` → show last commit
- `git lg` → pretty formatted log with graph

##### 3. Development Service Functions (Now in Base Image)

Moved from environment-specific Dockerfile to base image for consistency:

- `dev-h`: Health check endpoint (curl <http://localhost:5645/health>)
- `dev-v`: Version endpoint (curl <http://localhost:5645/version>)
- `dev-s`: Shutdown endpoint (POST to /shutdown)
- `dev-c`: Clear database endpoint (POST to /clear?db)
- `dev-l()`: Launch server function with auto-restart
  - Enhanced to accept port and project directory as parameters
  - Usage: `dev-l [port] [project_dir]`
  - Default: `dev-l 5645 set_backend`

#### Benefits

- **Improved Productivity**: Common tasks now require fewer keystrokes
- **Consistent Experience**: All aliases available in every deployment
- **GitHub Integration**: Seamless git workflow with gh CLI
- **Simplified Deployments**: Environment-specific Dockerfiles are now cleaner
- **Better Maintainability**: Single source of truth for development tools

#### Breaking Changes

None. All changes are additive and backwards compatible.

---

## Version 0.5.6 (December 28, 2025)

### 📚 Documentation Enhancement - MongoDB Network Configuration

**Improved Documentation**: Added comprehensive documentation for hard-coded IP addresses in MongoDB network configuration.

#### Updates

##### 1. Network Configuration Documentation

Added detailed network configuration section to README:

- Documented custom bridge network `dev-network` (172.20.0.0/24)
- Documented hard-coded IP addresses:
  - MongoDB (mongo-db): 172.20.0.10
  - Mongo Express: 172.20.0.12
- Added important notes about when to use hostnames vs. IPs
- Explained Docker's internal DNS resolution

##### 2. MongoDB Connection Best Practices

Enhanced MongoDB connection documentation:

- Added examples of both hostname and IP-based connections
- Clarified that hostname `mongo-db` is recommended for portability
- Documented environment variables (MONGODB_HOST, MONGODB_URI)
- Added network troubleshooting steps

##### 3. Troubleshooting Enhancements

Expanded MongoDB troubleshooting section:

- Added network connectivity tests (ping mongo-db, ping IP)
- Added mongosh connection examples with both hostname and static IP
- Added docker network inspect commands

#### Technical Details

- No changes to container functionality
- Documentation-only release
- Network configuration remains unchanged from v0.5.5

---

## Version 0.5.5 (November 19, 2025)

### 🚀 Development Service Aliases & Port Updates

**Enhanced Developer Experience**: Added convenient bash aliases for quick API access from container terminal.

#### New Features

##### 1. Development Service Aliases

Added bash aliases and functions to `.bashrc` for easy access to development service endpoints:

- `dev-h` - Health check: `curl http://localhost:8080/health && echo ""`
- `dev-v` - Version info: `curl http://localhost:8080/version && echo ""`  
- `dev-s` - Shutdown service: `curl -X POST http://localhost:8080/shutdown && echo ""`
- `dev-c` - Clear data: `curl -X POST http://localhost:8080/clear?db && echo ""` (takes 'db' argument)
- `dev-l(port)` - Smart launch function: Graceful shutdown + restart with health checking (optional port parameter, default 5645)

##### 2. Port Configuration Update

- Updated default application port from 5665 to 5645 for development environment
- Maintains compatibility with existing volume mounts and cache configuration

#### Performance Benefits

- **Faster API testing** - Quick aliases for common development operations
- **Improved workflow** - No need to remember full curl commands
- **Consistent port usage** - Standardized port 5645 for development

#### Technical Details

- Aliases target `localhost:8080` (internal container port)
- External access available on port 5645
- Aliases persist across container restarts
- Compatible with existing Rust cache optimization

---

### 🚀 Enhanced Rust Compiler Cache Configuration

**Major Improvement**: Added comprehensive by-default configuration of Rust compiler cache for optimal development performance.

#### New Features

##### 1. Complete Cargo Cache Structure

- Creates `/home/rustdev/.cargo/git/db` - Git dependencies cache
- Creates `/home/rustdev/.cargo/registry/index` - Crate registry index
- Creates `/home/rustdev/.cargo/registry/cache` - Downloaded dependencies cache
- Creates `/home/rustdev/.cargo/registry/src` - Source code cache

##### 2. Rustup Cache Directory

- Creates `/home/rustdev/.rustup` - Rustup toolchain and update cache

##### 3. Optimized Build Environment Variables

- `CARGO_INCREMENTAL=1` - Enables incremental compilation for faster rebuilds
- `CARGO_BUILD_JOBS=4` - Parallel compilation jobs for multi-core systems
- `RUST_BACKTRACE=1` - Full backtraces for better error debugging
- `CARGO_HOME=/home/rustdev/.cargo` - Explicit Cargo home directory
- `RUSTUP_HOME=/home/rustdev/.rustup` - Explicit Rustup home directory

#### Performance Benefits

- **Faster dependency downloads** - Registry cache persists across container rebuilds
- **Faster git clones** - Git dependencies cached locally
- **Faster compilation** - Incremental builds and parallel jobs
- **Reduced network usage** - Cached dependencies don't re-download
- **Better debugging** - Full backtraces for development

#### Volume Mount Compatibility

The cache directories are designed to work with the environment-specific volume mounts:

- `VOLUME_CARGO_CACHE` → `/home/rustdev/.cargo/registry`
- `VOLUME_CARGO_GIT_CACHE` → `/home/rustdev/.cargo/git`
- `VOLUME_RUSTUP_CACHE` → `/home/rustdev/.rustup`
- `VOLUME_TARGET_CACHE` → `/workspace/target`

---

## Version 0.5.0 (November 11, 2025)

### 🎯 Initial v0.5 Release

**Base Features:**

- Ubuntu 22.04 LTS
- Rust stable toolchain via rustup
- SSH server with host keys
- VS Code extensions auto-install
- MongoDB shell (mongosh)
- Development user (rustdev:1026:110)
- Git configuration support
- Basic workspace setup

---

## Version History Notes

- **v0.5.6**: Documentation improvements for MongoDB network configuration
- **v0.5.5**: Development aliases and port updates
- **v0.5.4**: Performance optimization through comprehensive caching
- **v0.5.1**: Focus on Rust performance optimization through comprehensive caching
- **Future versions**: May include additional language support, security hardening, or specialized toolchains

---

**Maintained by:** Thierry Souche
**Last Updated:** December 28, 2025
