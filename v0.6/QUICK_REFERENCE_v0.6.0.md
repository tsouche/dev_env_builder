# v0.6.0 Quick Reference Card

## 🚀 Connect to Environment

```
VS Code → Ctrl+Shift+P → "Remote-SSH: Connect to Host" → "rust-dev"
```

---

## 📦 New Features at a Glance

### GitHub CLI

```bash
gh --version          # Check version
gh auth login         # Authenticate
gh repo list          # List repositories
gh pr create          # Create pull request
gh issue list         # List issues
```

### Shell Aliases

```bash
ll                    # ls -alF (detailed list)
la                    # ls -A (all files)
l                     # ls -CF (compact)
..                    # cd .. (up one directory)
...                   # cd ../.. (up two directories)
```

### Cargo Shortcuts

```bash
cb                    # cargo build
cr                    # cargo run
ct                    # cargo test
cc                    # cargo check
ccl                   # cargo clippy
cf                    # cargo fmt
cu                    # cargo update
```

### Git Aliases

```bash
git st                # git status
git co <branch>       # git checkout
git br                # git branch
git ci -m "msg"       # git commit
git unstage <file>    # git reset HEAD --
git last              # git log -1 HEAD
git lg                # Pretty graph log
```

### Development Functions

```bash
dev-l                 # Launch server (default port 5645)
dev-l 8080            # Launch on custom port
dev-l 8080 myproject  # Launch custom port & project

dev-h                 # Health check
dev-v                 # Version info
dev-s                 # Shutdown server
dev-c                 # Clear database
```

---

## 🔧 Common Workflows

### Start New Project

```bash
cd /workspace
gh repo clone owner/repo
# or: git clone https://github.com/owner/repo.git
cd repo
cb                    # Build
ct                    # Test
```

### Development Cycle

```bash
# Edit code in VS Code
ccl                   # Check with clippy
cf                    # Format code
cb                    # Build
dev-l                 # Launch server

# In another terminal
dev-h                 # Test health
dev-v                 # Check version

# When done
dev-s                 # Stop server
git st                # Check changes
git add .
git ci -m "message"
git push
```

### Code Quality Check

```bash
ccl                   # Lint with clippy
cf                    # Format code
ct                    # Run tests
cb --release          # Release build
```

---

## 🌐 Service URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| SSH | localhost:2222 | rustdev (key auth) |
| Application | <http://localhost:5645> | - |
| MongoDB | localhost:27017 | admin/DevAdmin123 |
| Mongo Express | <http://localhost:8080> | dev/dev123 |

---

## 🔍 Quick Diagnostics

```bash
# Check all tools
gh --version
git --version
cargo --version
rustc --version
mongosh --version

# Check services
dev-h                 # App health
curl localhost:27017  # MongoDB

# View logs
docker logs dev-container
```

---

## 💡 Pro Tips

1. **Use `dev-l` for smart server management** - it automatically stops old server before starting new one

2. **Git log with `git lg`** - beautiful graph visualization of commits

3. **Quick navigation with `..` and `...`** - faster than typing `cd ..`

4. **Cargo shortcuts save typing** - `cb` instead of `cargo build`

5. **GitHub CLI for quick PR creation** - `gh pr create` from terminal

6. **Check multiple services with aliases** - chain commands: `dev-h && dev-v`

---

## 📁 Important Paths

```
/workspace                # Your project workspace
/workspace/set_backend    # Example project
~/.bashrc                 # Alias definitions
~/.cargo                  # Rust cache
~/.gitconfig              # Git configuration
```

---

## 🛠️ Troubleshooting

### Aliases not working?

```bash
source ~/.bashrc      # Reload configuration
```

### Server won't start?

```bash
dev-s                 # Stop any running server
sleep 2
dev-l                 # Restart
```

### Build errors?

```bash
cargo clean           # Clean build artifacts
cb                    # Rebuild
```

### Git authentication?

```bash
gh auth login         # GitHub CLI auth
# or configure git:
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
```

---

## 📚 Documentation

- [DEPLOYMENT_SUMMARY_v0.6.0.md](DEPLOYMENT_SUMMARY_v0.6.0.md) - Full deployment details
- [TESTING_GUIDE_v0.6.0.md](TESTING_GUIDE_v0.6.0.md) - Comprehensive testing
- [UPGRADE_TO_V0.6.0.md](UPGRADE_TO_V0.6.0.md) - Upgrade instructions
- [CHANGELOG.md](build_dev_image/CHANGELOG.md) - Version history

---

**Version:** 0.6.0  
**Last Updated:** January 3, 2026  
**Image:** tsouche/rust_dev_container:v0.6.0  

🎉 **Happy Coding!**
