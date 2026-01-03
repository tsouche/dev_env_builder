# Upgrade Guide: v0.5.6 → v0.6.0

## What's New in v0.6.0

### ✨ New Features

1. **GitHub CLI (`gh`)**
   - Full GitHub integration from terminal
   - Manage repos, PRs, issues without leaving VS Code
   - Authentication support: `gh auth login`

2. **Shell Aliases**
   - `ll`, `la`, `l` - Enhanced file listing
   - `..`, `...` - Quick navigation
   - Colored `grep`, `fgrep`, `egrep`

3. **Cargo Shortcuts**
   - `cb` → `cargo build`
   - `cr` → `cargo run`
   - `ct` → `cargo test`
   - `cc` → `cargo check`
   - `ccl` → `cargo clippy`
   - `cf` → `cargo fmt`
   - `cu` → `cargo update`

4. **Git Aliases**
   - `git st` → status
   - `git co` → checkout
   - `git br` → branch
   - `git ci` → commit
   - `git unstage` → reset HEAD
   - `git last` → show last commit
   - `git lg` → pretty log with graph

5. **Development Service Functions** (Moved from dev_env to base image)
   - `dev-h` - Health check
   - `dev-v` - Version info
   - `dev-s` - Shutdown server
   - `dev-c` - Clear database
   - `dev-l [port] [project]` - Launch server with auto-restart

## Deployment Steps

### Step 1: Build New Base Image

```powershell
cd v0.5/build_dev_image
.\build_and_push.ps1 0.6.0
```

This will:

- Build the new image with all features
- Tag as `v0.6.0`, `v0.6`, and `latest`
- Push to DockerHub (requires login)

### Step 2: Rebuild Development Environment

```powershell
cd v0.5/dev_env
.\deploy-dev.ps1
```

This will:

- Pull the new base image
- Build the dev environment layer
- Start all services
- Configure SSH access

## What Changed

### Modified Files

#### Base Image (`build_dev_image/`)

- [Dockerfile.rustdev](build_dev_image/Dockerfile.rustdev) - Added GitHub CLI, aliases, functions
- [CHANGELOG.md](build_dev_image/CHANGELOG.md) - Documented v0.6.0 changes
- [README.md](build_dev_image/README.md) - Updated feature list

#### Development Environment (`dev_env/`)

- [Dockerfile](dev_env/Dockerfile) - Simplified (removed aliases now in base)
- [.env](dev_env/.env) - Updated version to 0.6.0
- [deploy-dev.ps1](dev_env/deploy-dev.ps1) - Updated version references
- [docker-compose-dev.yml](dev_env/docker-compose-dev.yml) - Updated version
- [README.md](dev_env/README.md) - Added v0.6.0 section

## Benefits

### For Developers

- **Faster workflow** with keyboard shortcuts
- **GitHub integration** without browser
- **Consistent environment** across all deployments
- **Better productivity** with smart defaults

### For Maintainers

- **Cleaner Dockerfiles** in environment-specific builds
- **Single source of truth** for development tools
- **Easier updates** - change once in base image

## Testing the New Features

After deployment, connect via VS Code Remote-SSH and test:

```bash
# Test shell aliases
ll
cb --help

# Test git aliases
git st
git lg

# Test GitHub CLI
gh --version
gh auth login

# Test dev functions (after cloning your project)
cd /workspace/set_backend
dev-l          # Launch on default port 5645
dev-h          # Health check
dev-v          # Version info
```

## Rollback Plan

If needed, you can rollback to v0.5.6:

1. Pull previous image:

   ```powershell
   docker pull tsouche/rust_dev_container:v0.5.6
   ```

2. Update [dev_env/Dockerfile](dev_env/Dockerfile) FROM line:

   ```dockerfile
   FROM tsouche/rust_dev_container:v0.5.6
   ```

3. Rebuild:

   ```powershell
   cd v0.5/dev_env
   .\deploy-dev.ps1
   ```

## Notes

- All changes are **backwards compatible**
- Environment variables and ports remain unchanged
- No changes to MongoDB or network configuration
- SSH access configuration unchanged

## Support

For issues or questions:

- Check [CHANGELOG.md](build_dev_image/CHANGELOG.md) for detailed changes
- Review [README.md](build_dev_image/README.md) for feature documentation
- Test builds locally before pushing to DockerHub
