# Changelog - Rust Development Environment Builder

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

## Version History Notes

- **v0.5.5**: Current version with development aliases and port updates
- **v0.5.4**: Performance optimization through comprehensive caching
- **v0.5.1**: SSH automation and project management improvements
- **v0.5.0**: Initial v0.5 release with complete development environment

---

**Maintained by:** Thierry Souche
**Last Updated:** November 19, 2025</content>
<parameter name="filePath">c:\rustdev\dev_env_builder\CHANGELOG.md
