#!/bin/bash
################################################################################
# gstack Initialization Script
# Install or update gstack skills framework for Claude Code
# This script is idempotent - safe to run multiple times
#
# gstack lives in ~/.claude/skills/gstack (persistent volume)
# See: https://github.com/garrytan/gstack
################################################################################

set -e

GSTACK_DIR="$HOME/.claude/skills/gstack"
GSTACK_REPO="https://github.com/garrytan/gstack.git"

# Bun's default global cache may be inaccessible when running via docker exec.
# Set an explicit cache directory to avoid "tempdir: AccessDenied" errors.
export BUN_INSTALL_CACHE_DIR="$HOME/.bun/install/cache"
mkdir -p "$BUN_INSTALL_CACHE_DIR"

echo "========================================="
echo "gstack Initialization"
echo "========================================="

# Check prerequisites
if ! command -v git &> /dev/null; then
    echo "❌ git not found. Please rebuild the container."
    exit 1
fi

if ! command -v bun &> /dev/null; then
    echo "❌ bun not found. Please rebuild the container."
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo "❌ node not found. Please rebuild the container."
    exit 1
fi

echo "✓ Prerequisites: git, bun, node"

# Ensure parent directory exists
mkdir -p "$HOME/.claude/skills"

if [ -d "$GSTACK_DIR/.git" ]; then
    # Update existing installation
    echo ""
    echo "gstack already installed. Updating to latest..."
    cd "$GSTACK_DIR"
    git pull --ff-only 2>&1 || {
        echo "⚠️  git pull failed (possibly modified files). Attempting reset..."
        git fetch origin
        git reset --hard origin/main
    }
    echo "✓ Updated to latest"
else
    # Fresh installation — remove anything at the target path
    # (could be a stale directory, symlink, or file from a previous attempt)
    if [ -e "$GSTACK_DIR" ] || [ -L "$GSTACK_DIR" ]; then
        echo ""
        echo "⚠️  Stale gstack path found (no .git). Removing..."
        rm -rf "$GSTACK_DIR"
    fi

    echo ""
    echo "Cloning gstack..."
    git clone "$GSTACK_REPO" "$GSTACK_DIR"
    echo "✓ Cloned successfully"
fi

# Run setup
echo ""
echo "Running gstack setup..."
cd "$GSTACK_DIR"
./setup
echo "✓ Setup complete"

# Configure telemetry off by default
GSTACK_CONFIG_DIR="$HOME/.gstack"
GSTACK_CONFIG_FILE="$GSTACK_CONFIG_DIR/config.yaml"
mkdir -p "$GSTACK_CONFIG_DIR"

if [ ! -f "$GSTACK_CONFIG_FILE" ]; then
    echo "telemetry: false" > "$GSTACK_CONFIG_FILE"
    echo "✓ Telemetry configured: off"
elif ! grep -q "telemetry" "$GSTACK_CONFIG_FILE"; then
    echo "telemetry: false" >> "$GSTACK_CONFIG_FILE"
    echo "✓ Telemetry configured: off"
else
    echo "✓ Telemetry already configured"
fi

# Install browse dependencies (Playwright)
echo ""
echo "Installing gstack browse dependencies..."
cd "$GSTACK_DIR"
if [ -f "package.json" ]; then
    bun install 2>&1 || echo "⚠️  bun install had issues (non-fatal)"
    bun run build 2>&1 || echo "⚠️  bun run build had issues (non-fatal)"
    echo "✓ Browse dependencies installed"
else
    echo "⚠️  No package.json found — skipping browse deps"
fi

echo ""
echo "========================================="
echo "gstack Installation Complete"
echo "========================================="
echo ""
echo "Available skills:"
echo "  /office-hours, /plan-ceo-review, /plan-eng-review,"
echo "  /plan-design-review, /design-consultation, /review,"
echo "  /ship, /land-and-deploy, /canary, /benchmark, /browse,"
echo "  /qa, /qa-only, /design-review, /setup-browser-cookies,"
echo "  /setup-deploy, /retro, /investigate, /document-release,"
echo "  /codex, /cso, /autoplan, /careful, /freeze, /guard,"
echo "  /unfreeze, /gstack-upgrade"
echo ""
echo "To update gstack later: /gstack-upgrade (from Claude Code)"
echo "Or re-run: ~/init_gstack.sh"
echo ""
