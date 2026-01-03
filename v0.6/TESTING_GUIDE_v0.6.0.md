# Testing Guide for v0.6.0

## Quick Verification

All new features have been successfully deployed. Follow these tests to verify functionality.

---

## Test 1: SSH Connection & Environment

### Steps

1. **Connect via VS Code Remote-SSH:**
   - Press `Ctrl+Shift+P`
   - Type "Remote-SSH: Connect to Host"
   - Select `rust-dev`
   - Open folder: `/workspace`

2. **Open Terminal** (`Ctrl+``)

3. **Verify new shell aliases:**

```bash
# Test file listing aliases
ll                    # Should show: ls -alF
la                    # Should show: ls -A

# Test navigation
pwd
..                    # Go up one directory
pwd
cd /workspace        # Return to workspace

# Test colored grep
echo "test string" | grep --color=auto "test"
```

**Expected Result:** All aliases work without errors ✓

---

## Test 2: Cargo Shortcuts

### Steps

```bash
# Navigate to a Rust project or create test
cd /workspace

# Test cargo aliases
cb --help           # Should run: cargo build --help
cr --help           # Should run: cargo run --help
ct --help           # Should run: cargo test --help
cc --help           # Should run: cargo check --help
ccl --help          # Should run: cargo clippy --help
cf --help           # Should run: cargo fmt --help
cu --help           # Should run: cargo update --help
```

**Expected Result:** All cargo shortcuts execute correctly ✓

---

## Test 3: Git Aliases

### Steps

```bash
# Test git aliases
git st              # Should run: git status
git br              # Should run: git branch

# Test pretty log
git config --get alias.lg
# Should show: log --graph --pretty=format:...

# Test other aliases
git config --get alias.co      # checkout
git config --get alias.ci      # commit
git config --get alias.unstage # reset HEAD --
git config --get alias.last    # log -1 HEAD
```

**Expected Result:** All git aliases configured ✓

---

## Test 4: GitHub CLI

### Steps

```bash
# Verify gh is installed
gh --version
# Expected: gh version 2.83.2 or newer

# Test GitHub CLI (requires authentication)
gh auth login
# Follow prompts to authenticate

# After authentication, test
gh auth status
gh repo list --limit 5
```

**Expected Result:**

- GitHub CLI installed ✓
- Can authenticate and list repos ✓

---

## Test 5: Development Service Functions

### Prerequisites

Clone your Rust backend project:

```bash
cd /workspace
git clone https://github.com/tsouche/set_backend.git
cd set_backend
```

### Steps

#### A. Test dev-l (Launch Server)

```bash
# Launch server on default port (5645)
dev-l

# Wait for "Server is ready on port 5645"
```

**Expected Result:** Server starts and reports ready ✓

#### B. Test dev-h (Health Check)

```bash
dev-h
```

**Expected Output:** Health status from server ✓

#### C. Test dev-v (Version)

```bash
dev-v
```

**Expected Output:** Version information ✓

#### D. Test dev-s (Shutdown)

```bash
dev-s
```

**Expected Output:** Server shutdown confirmation ✓

#### E. Test dev-c (Clear Database)

First, restart server:

```bash
dev-l
```

Then:

```bash
dev-c
```

**Expected Output:** Database cleared confirmation ✓

#### F. Test Custom Port

```bash
# Launch on custom port
dev-l 8080 set_backend

# Then check
curl http://localhost:8080/health
```

**Expected Result:** Server runs on specified port ✓

---

## Test 6: VS Code Extensions Auto-Install

### Steps

1. **First Terminal Session:**
   - Open new terminal in VS Code (`Ctrl+``)
   - You should see extension installation message
   - Extensions will install automatically

2. **Verify Extensions:**
   - Press `Ctrl+Shift+X` (Extensions view)
   - Check for:
     - `rust-lang.rust-analyzer`
     - `panicbit.cargo`
     - `fill-labs.dependi`
     - `tamasfe.even-better-toml`
     - `github.copilot`
     - `github.copilot-chat`
     - `davidanson.vscode-markdownlint`

3. **Reload Window:**
   - `Ctrl+Shift+P` → "Reload Window"

**Expected Result:** All extensions installed and active ✓

---

## Test 7: MongoDB & Mongo Express

### Steps

#### A. Test MongoDB Connection

```bash
# From container terminal
mongosh mongodb://localhost:27017/rust_app_db

# Inside mongosh:
show dbs
use rust_app_db
show collections
exit
```

**Expected Result:** MongoDB accessible, database initialized ✓

#### B. Test Mongo Express

1. Open browser: <http://localhost:8080>
2. Login: `dev` / `dev123`
3. Navigate to `rust_app_db` database
4. Check collections: `items`, `users`, `data`

**Expected Result:** Mongo Express accessible, shows database ✓

---

## Test 8: Rust Toolchain

### Steps

```bash
# Check Rust version
rustc --version
cargo --version
rustup --version

# Check toolchain
rustup show

# Check installed components
rustup component list --installed
```

**Expected Result:**

- Rust 1.92.0 or newer ✓
- Stable toolchain active ✓
- Components: rustc, cargo, clippy, rustfmt ✓

---

## Test 9: Project Build

### Steps

```bash
cd /workspace/set_backend

# Clean build
cargo clean

# Build project
cb
# or: cargo build

# Run tests
ct
# or: cargo test

# Check code
ccl
# or: cargo clippy

# Format code
cf
# or: cargo fmt
```

**Expected Result:**

- Build completes successfully ✓
- Tests pass ✓
- No clippy warnings ✓
- Code formatted ✓

---

## Test 10: GitHub Integration Workflow

### Steps

```bash
cd /workspace/set_backend

# Check repository status with alias
git st

# Create a test branch
git co -b test-v0.6.0-features

# Make a change
echo "# v0.6.0 Test" >> TEST.md
git add TEST.md
git ci -m "Test v0.6.0 features"

# View pretty log
git lg

# Use GitHub CLI to create PR (if authenticated)
gh pr create --title "Test v0.6.0" --body "Testing new features"

# Clean up
git co main
git br -D test-v0.6.0-features
rm TEST.md
```

**Expected Result:**

- Git aliases work ✓
- GitHub CLI can create PR ✓
- Pretty log displays correctly ✓

---

## Performance Tests

### Test 11: Build Cache Performance

```bash
cd /workspace/set_backend

# First build (cold cache)
time cargo clean && cargo build

# Second build (warm cache)
time cargo build

# Incremental build (change one file)
touch src/main.rs
time cargo build
```

**Expected Result:**

- Warm cache much faster than cold ✓
- Incremental builds very fast ✓

---

## Integration Test: Full Workflow

### Complete Development Cycle Test

```bash
# 1. Clone repository
cd /workspace
git clone https://github.com/tsouche/set_backend.git
cd set_backend

# 2. Check status
git st

# 3. Build project
cb

# 4. Run tests
ct

# 5. Start development server
dev-l

# 6. In another terminal: Test endpoints
dev-h
dev-v

# 7. Work on code (simulate)
# Edit files in VS Code

# 8. Check code quality
ccl
cf

# 9. Rebuild
cb

# 10. Restart server
dev-s
sleep 2
dev-l

# 11. Verify server
dev-h

# 12. Commit changes
git add .
git ci -m "Test commit"

# 13. View log
git lg

# 14. Push (if authenticated)
git push origin main
```

**Expected Result:** Seamless development workflow ✓

---

## Troubleshooting Tests

### If Aliases Don't Work

```bash
# Check .bashrc
cat ~/.bashrc | grep -A 5 "Common Shell Aliases"
cat ~/.bashrc | grep -A 5 "Cargo Shortcuts"
cat ~/.bashrc | grep -A 5 "Development Service"

# Reload bashrc
source ~/.bashrc
```

### If GitHub CLI Not Found

```bash
# Verify installation
which gh
dpkg -l | grep gh

# Reinstall if needed
sudo apt update
sudo apt install gh
```

### If Dev Functions Fail

```bash
# Check if functions are loaded
type dev-l
type dev-h

# Manually source
source ~/.bashrc
```

---

## Success Criteria

All tests should pass with these results:

- ✓ SSH connection successful
- ✓ All shell aliases functional (ll, la, .., etc.)
- ✓ All Cargo shortcuts work (cb, cr, ct, cc, ccl, cf, cu)
- ✓ All Git aliases configured (st, co, br, ci, lg, etc.)
- ✓ GitHub CLI installed and functional
- ✓ Development service functions work (dev-h, dev-v, dev-s, dev-c, dev-l)
- ✓ VS Code extensions auto-install
- ✓ MongoDB accessible
- ✓ Mongo Express accessible
- ✓ Rust toolchain complete and up-to-date
- ✓ Projects build successfully
- ✓ Build caching works efficiently

---

## Reporting Issues

If any test fails:

1. **Check Docker logs:**

   ```powershell
   docker logs dev-container
   docker logs dev-mongodb
   ```

2. **Check container status:**

   ```powershell
   docker ps -a
   ```

3. **Verify image version:**

   ```bash
   # From container
   cat /etc/os-release
   rustc --version
   gh --version
   ```

4. **Review bashrc:**

   ```bash
   cat ~/.bashrc
   ```

5. **Test SSH directly:**

   ```powershell
   ssh -i C:\Users\<your-user>\.ssh\id_ed25519 -p 2222 rustdev@localhost
   ```

---

## Additional Verification Commands

```bash
# Verify all tools installed
which gh mongosh rustc cargo git

# Check PATH
echo $PATH

# Verify user and permissions
whoami
id
sudo -l

# Check mounted volumes
df -h | grep workspace
ls -la /workspace

# Network connectivity
curl -I https://github.com
curl -I https://crates.io
```

---

**Testing Date:** January 3, 2026  
**Version Tested:** v0.6.0  
**Base Image:** tsouche/rust_dev_container:v0.6.0  

All tests completed successfully! ✓
