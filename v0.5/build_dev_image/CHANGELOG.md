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
