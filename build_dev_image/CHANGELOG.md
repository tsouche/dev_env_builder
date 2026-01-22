# Changelog for BuildDevImage scripts

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
