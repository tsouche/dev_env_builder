#!/bin/bash
################################################################################
# Deployment Test Suite - v0.7.1
# Validates all components of the dev environment after deployment.
# Called automatically by deploy-dev.ps1 after initialization.
#
# Exit code: 0 = all critical tests passed
#            1 = one or more critical tests failed
#
# Test categories:
#   CRITICAL - failure means the environment is broken
#   WARN     - failure may need manual attention but environment can still be used
################################################################################

# ── Color codes ───────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
GRAY='\033[0;90m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
CRITICAL_FAILURES=""

# ── Test helpers ──────────────────────────────────────────────────────────────
section() {
    echo ""
    echo -e "${BLUE}  [$1]${NC}"
}

pass() {
    local label="$1"
    local detail="${2:-}"
    printf "  ${GREEN}✓${NC}  %-38s ${GRAY}%s${NC}\n" "$label" "$detail"
    PASS=$((PASS+1))
}

fail() {
    local label="$1"
    local detail="${2:-}"
    printf "  ${RED}✗${NC}  %-38s ${RED}%s${NC}\n" "$label" "$detail"
    FAIL=$((FAIL+1))
    CRITICAL_FAILURES="${CRITICAL_FAILURES}\n    ${RED}✗${NC} $label${detail:+ — $detail}"
}

warn() {
    local label="$1"
    local detail="${2:-}"
    printf "  ${YELLOW}⚠${NC}  %-38s ${GRAY}%s${NC}\n" "$label" "$detail"
    WARN=$((WARN+1))
}

# ── Header ────────────────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Deployment Test Suite"
echo "========================================"


################################################################################
section "Runtime & Toolchain"
################################################################################

# Node.js — must be >= 22 (QMD engine requirement)
if command -v node &>/dev/null; then
    NODE_VER=$(node --version 2>/dev/null)
    NODE_MAJOR=$(echo "$NODE_VER" | sed 's/v\([0-9]*\).*/\1/')
    if [ "$NODE_MAJOR" -ge 22 ]; then
        pass "Node.js >= 22" "$NODE_VER"
    else
        fail "Node.js >= 22" "got $NODE_VER — upgrade required"
    fi
else
    fail "Node.js" "not found in PATH"
fi

# Bun runtime
if command -v bun &>/dev/null; then
    BUN_VER=$(bun --version 2>/dev/null)
    pass "Bun runtime" "v$BUN_VER"
else
    fail "Bun runtime" "not found in PATH"
fi

# Rust — rustc
if command -v rustc &>/dev/null; then
    RUST_VER=$(rustc --version 2>/dev/null | awk '{print $2}')
    pass "Rust (rustc)" "$RUST_VER"
else
    fail "Rust (rustc)" "not found in PATH"
fi

# Rust — cargo
if command -v cargo &>/dev/null; then
    CARGO_VER=$(cargo --version 2>/dev/null | awk '{print $2}')
    pass "Cargo" "$CARGO_VER"
else
    fail "Cargo" "not found in PATH"
fi

# git
if command -v git &>/dev/null; then
    GIT_VER=$(git --version 2>/dev/null | awk '{print $3}')
    pass "git" "v$GIT_VER"
else
    fail "git" "not found in PATH"
fi

# python3 (used by deploy script for JSON manipulation)
if command -v python3 &>/dev/null; then
    PY_VER=$(python3 --version 2>/dev/null | awk '{print $2}')
    pass "Python3" "$PY_VER"
else
    warn "Python3" "not found (deploy script MCP merge may fail)"
fi


################################################################################
section "QMD (Query Markup Documents)"
################################################################################

# qmd binary in PATH
if command -v qmd &>/dev/null; then
    QMD_PATH=$(which qmd)
    pass "qmd binary in PATH" "$QMD_PATH"
else
    fail "qmd binary" "not found in PATH"
fi

# qmd --version runs without error (was broken in v0.7.0)
QMD_VER=$(qmd --version 2>&1)
QMD_EXIT=$?
if [ $QMD_EXIT -eq 0 ] && [ -n "$QMD_VER" ]; then
    pass "qmd --version" "$QMD_VER"
else
    fail "qmd --version" "exit $QMD_EXIT — ${QMD_VER:0:80}"
fi

# dist/cli/qmd.js physically present (root cause of v0.7.0 breakage)
QMD_DIST="$(npm root -g 2>/dev/null)/@tobilu/qmd/dist/cli/qmd.js"
if [ -f "$QMD_DIST" ]; then
    pass "qmd dist/cli/qmd.js present" "npm package correct"
else
    fail "qmd dist/cli/qmd.js" "missing — broken npm install"
fi

# QMD MCP server configured in ~/.claude.json
if [ -f ~/.claude.json ] || [ -L ~/.claude.json ]; then
    if grep -q '"qmd"' ~/.claude.json 2>/dev/null; then
        pass "QMD MCP in ~/.claude.json" "configured"
    else
        warn "QMD MCP in ~/.claude.json" "entry missing — add manually"
    fi
else
    warn "~/.claude.json" "file not found (not authenticated yet)"
fi


################################################################################
section "gstack Skills Framework"
################################################################################

GSTACK_DIR="$HOME/.claude/skills/gstack"

# gstack cloned
if [ -d "$GSTACK_DIR/.git" ]; then
    GSTACK_COMMIT=$(git -C "$GSTACK_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
    GSTACK_BRANCH=$(git -C "$GSTACK_DIR" branch --show-current 2>/dev/null || echo "unknown")
    pass "gstack cloned" "commit $GSTACK_COMMIT ($GSTACK_BRANCH)"
else
    fail "gstack cloned" "$GSTACK_DIR/.git not found — run ~/init_gstack.sh"
fi

# Skills symlinked into ~/.claude/skills/
SKILL_COUNT=$(find "$HOME/.claude/skills/" -maxdepth 1 -mindepth 1 -not -name 'gstack' 2>/dev/null | wc -l | tr -d ' ')
if [ "$SKILL_COUNT" -gt 0 ]; then
    pass "gstack skills linked" "$SKILL_COUNT skills"
else
    warn "gstack skills linked" "0 found — run ~/init_gstack.sh"
fi

# gstack node_modules (bun install ran during setup)
if [ -d "$GSTACK_DIR/node_modules" ]; then
    pass "gstack node_modules" "present"
else
    warn "gstack node_modules" "missing — bun install may have failed"
fi

# Playwright Chromium browser (required for /browse skill)
CHROMIUM=$(find /root/.cache/ms-playwright /home/rustdev/.cache/ms-playwright \
    -name 'chrome' -type f 2>/dev/null | head -1)
if [ -n "$CHROMIUM" ]; then
    pass "Playwright Chromium" "$(dirname "$CHROMIUM")"
else
    warn "Playwright Chromium" "browser binary not found — /browse skill may fail"
fi


################################################################################
section "MongoDB"
################################################################################

# mongosh CLI installed
if command -v mongosh &>/dev/null; then
    MONGOSH_VER=$(mongosh --version 2>/dev/null | head -1 | tr -d '\r')
    pass "mongosh CLI" "$MONGOSH_VER"
else
    fail "mongosh CLI" "not found in PATH"
fi

# mongo-db host reachable (internal docker network)
if mongosh --host mongo-db --port 27017 --eval "quit(0)" --quiet 2>/dev/null; then
    pass "mongo-db reachable" "mongo-db:27017 (no auth)"
elif mongosh "mongodb://${DB_ADMIN_USER:-admin}:${DB_ADMIN_PASSWORD:-admin123}@mongo-db:27017" \
        --eval "quit(0)" --quiet 2>/dev/null; then
    pass "mongo-db reachable" "mongo-db:27017 (admin auth)"
else
    fail "mongo-db reachable" "cannot connect to mongo-db:27017"
fi

# App database / user accessible with app credentials
DB_NAME="${MONGODB_DATABASE:-rust_app_db}"
DB_USER="${MONGODB_USER:-app_user}"
DB_PASS="${MONGODB_PASSWORD:-app_password}"
if mongosh "mongodb://$DB_USER:$DB_PASS@mongo-db:27017/$DB_NAME" \
        --eval "db.getName()" --quiet 2>/dev/null | grep -q "$DB_NAME"; then
    pass "App DB + user accessible" "$DB_NAME (as $DB_USER)"
else
    warn "App DB + user accessible" "$DB_USER@$DB_NAME auth failed — init script may be pending"
fi


################################################################################
section "Claude Code"
################################################################################

# claude CLI
if command -v claude &>/dev/null; then
    CLAUDE_VER=$(claude --version 2>/dev/null | head -1 | tr -d '\r')
    pass "claude CLI" "${CLAUDE_VER:-installed}"
else
    warn "claude CLI" "not installed — run: npm install -g @anthropic-ai/claude-code"
fi

# ~/.claude.json must be a symlink to ~/.claude/claude.json for persistence
if [ -L ~/.claude.json ]; then
    LINK_TARGET=$(readlink ~/.claude.json)
    if [ "$LINK_TARGET" = "/home/rustdev/.claude/claude.json" ] || \
       [ "$LINK_TARGET" = "$HOME/.claude/claude.json" ]; then
        pass "~/.claude.json symlink" "→ $LINK_TARGET"
    else
        warn "~/.claude.json symlink" "points to $LINK_TARGET (expected ~/.claude/claude.json)"
    fi
elif [ -f ~/.claude.json ]; then
    warn "~/.claude.json" "regular file — not persistent across deploys (should be symlink)"
else
    warn "~/.claude.json" "does not exist (not authenticated yet — run: claude login)"
fi

# CLAUDE.md present on persistent volume
if [ -f ~/.claude/CLAUDE.md ]; then
    LINES=$(wc -l < ~/.claude/CLAUDE.md | tr -d ' ')
    HAS_GSTACK=$(grep -c -i 'gstack' ~/.claude/CLAUDE.md 2>/dev/null || echo 0)
    pass "CLAUDE.md present" "$LINES lines, $HAS_GSTACK gstack references"
else
    warn "CLAUDE.md" "not found in ~/.claude/ — check CLAUDE.md.template copy"
fi


################################################################################
section "Developer Tools"
################################################################################

# GitHub CLI
if command -v gh &>/dev/null; then
    GH_VER=$(gh --version 2>/dev/null | head -1 | awk '{print $3}')
    pass "GitHub CLI (gh)" "v$GH_VER"
else
    warn "GitHub CLI (gh)" "not found"
fi

# Docker CLI (via bind-mounted socket)
if command -v docker &>/dev/null; then
    DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
    pass "Docker CLI" "v$DOCKER_VER"
else
    warn "Docker CLI" "not in PATH"
fi

# SSH server running
if pgrep -x sshd &>/dev/null; then
    pass "SSH server (sshd)" "running"
else
    warn "SSH server (sshd)" "no sshd process detected"
fi


################################################################################
# Summary
################################################################################

echo ""
echo "========================================"
TOTAL=$((PASS + FAIL + WARN))

if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
    echo -e "${GREEN}  Results: $PASS passed, 0 warnings, 0 failed${NC}"
    echo -e "${GREEN}  ALL TESTS PASSED${NC}"
elif [ $FAIL -eq 0 ]; then
    echo -e "${YELLOW}  Results: $PASS passed, $WARN warnings, 0 failed${NC}"
    echo -e "${GREEN}  ALL CRITICAL TESTS PASSED${NC}"
    echo -e "${YELLOW}  $WARN non-critical issue(s) — see warnings above${NC}"
else
    echo -e "${RED}  Results: $PASS passed, $WARN warnings, $FAIL failed${NC}"
    echo ""
    echo -e "${RED}  CRITICAL FAILURES:${NC}"
    echo -e "$CRITICAL_FAILURES"
fi

echo "========================================"
echo ""

[ $FAIL -eq 0 ]
