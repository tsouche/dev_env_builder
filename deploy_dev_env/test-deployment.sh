#!/bin/bash
################################################################################
# Deployment Test Suite - v0.8.0
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

# uv (required for Graphify)
if command -v uv &>/dev/null; then
    UV_VER=$(uv --version 2>/dev/null | awk '{print $2}')
    pass "uv package manager" "v$UV_VER"
else
    fail "uv package manager" "not found in PATH"
fi

# Python3 >= 3.10 (used by deploy script for JSON manipulation; also Graphify's floor)
if command -v python3 &>/dev/null; then
    PY3_VER=$(python3 --version 2>/dev/null | awk '{print $2}')
    PY3_MAJOR=$(echo "$PY3_VER" | cut -d. -f1)
    PY3_MINOR=$(echo "$PY3_VER" | cut -d. -f2)
    if [ "$PY3_MAJOR" -gt 3 ] || { [ "$PY3_MAJOR" -eq 3 ] && [ "$PY3_MINOR" -ge 10 ]; }; then
        pass "Python3 >= 3.10" "$PY3_VER"
    else
        warn "Python3 >= 3.10" "got $PY3_VER — Graphify requires >=3.10, deploy script MCP merge may fail"
    fi
else
    warn "Python3" "not found (deploy script MCP merge may fail; Graphify requires >=3.10)"
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

# Per-repo architecture: init_qmd.sh must have been run and created symlinks
QMD_SYMLINKS=0
for _f in "$HOME"/.cache/qmd/*.sqlite; do [ -L "$_f" ] && QMD_SYMLINKS=$((QMD_SYMLINKS+1)); done
if [ "$QMD_SYMLINKS" -gt 0 ]; then
    pass "Per-repo index symlinks" "$QMD_SYMLINKS found in ~/.cache/qmd/"
else
    warn "Per-repo index symlinks" "none found — run ~/init_qmd.sh"
fi

# Each symlink must be a real symlink (not a plain file) pointing into a repo .qmd/
SYMLINK_BROKEN=0
SYMLINK_OK=0
for symlink in "$HOME"/.cache/qmd/*.sqlite; do
    [ -e "$symlink" ] || continue
    if [ -L "$symlink" ]; then
        target=$(readlink -f "$symlink" 2>/dev/null || echo "")
        if echo "$target" | grep -q "\.qmd/index\.sqlite$"; then
            SYMLINK_OK=$((SYMLINK_OK+1))
        else
            SYMLINK_BROKEN=$((SYMLINK_BROKEN+1))
        fi
    else
        SYMLINK_BROKEN=$((SYMLINK_BROKEN+1))
    fi
done
if [ "$SYMLINK_OK" -gt 0 ] && [ "$SYMLINK_BROKEN" -eq 0 ]; then
    pass "Symlinks → {repo}/.qmd/index.sqlite" "$SYMLINK_OK valid"
elif [ "$SYMLINK_BROKEN" -gt 0 ]; then
    warn "Symlinks → {repo}/.qmd/index.sqlite" "$SYMLINK_BROKEN broken, $SYMLINK_OK ok — re-run ~/init_qmd.sh"
fi

# Each per-repo index must have a .mcp.json pointing at 'qmd --index {name} mcp'
MCP_OK=0
MCP_MISSING=0
for symlink in "$HOME"/.cache/qmd/*.sqlite; do
    [ -L "$symlink" ] || continue
    project_name=$(basename "$symlink" .sqlite)
    # Resolve the repo dir: target is {repo}/.qmd/index.sqlite
    target=$(readlink -f "$symlink" 2>/dev/null || echo "")
    repo_dir=$(dirname "$(dirname "$target")" 2>/dev/null || echo "")
    mcp_file="$repo_dir/.mcp.json"
    if [ -f "$mcp_file" ] && grep -q "\"--index\"" "$mcp_file" 2>/dev/null && \
       grep -q "\"$project_name\"" "$mcp_file" 2>/dev/null; then
        MCP_OK=$((MCP_OK+1))
    else
        MCP_MISSING=$((MCP_MISSING+1))
        warn "  .mcp.json for $project_name" "${mcp_file:-not found}"
    fi
done
if [ "$MCP_OK" -gt 0 ] && [ "$MCP_MISSING" -eq 0 ]; then
    pass "{repo}/.mcp.json (per-project MCP)" "$MCP_OK repos configured"
elif [ "$MCP_OK" -eq 0 ] && [ "$MCP_MISSING" -eq 0 ]; then
    warn "{repo}/.mcp.json" "no repos found to check"
else
    warn "{repo}/.mcp.json" "$MCP_OK ok, $MCP_MISSING missing — re-run ~/init_qmd.sh"
fi

# Each repo's .gitignore must ignore .qmd/*.sqlite*
GITIGNORE_OK=0
GITIGNORE_MISSING=0
for symlink in "$HOME"/.cache/qmd/*.sqlite; do
    [ -L "$symlink" ] || continue
    target=$(readlink -f "$symlink" 2>/dev/null || echo "")
    repo_dir=$(dirname "$(dirname "$target")" 2>/dev/null || echo "")
    if grep -qF ".qmd/*.sqlite" "$repo_dir/.gitignore" 2>/dev/null; then
        GITIGNORE_OK=$((GITIGNORE_OK+1))
    else
        GITIGNORE_MISSING=$((GITIGNORE_MISSING+1))
    fi
done
if [ "$GITIGNORE_OK" -gt 0 ] && [ "$GITIGNORE_MISSING" -eq 0 ]; then
    pass ".gitignore: .qmd/*.sqlite* ignored" "$GITIGNORE_OK repos"
elif [ "$GITIGNORE_MISSING" -gt 0 ]; then
    warn ".gitignore: .qmd/*.sqlite* ignored" "$GITIGNORE_MISSING repo(s) missing entry"
fi

# Global index must NOT exist (no stale ~/.cache/qmd/index.sqlite plain file)
if [ -f "$HOME/.cache/qmd/index.sqlite" ] && [ ! -L "$HOME/.cache/qmd/index.sqlite" ]; then
    warn "~/.cache/qmd/index.sqlite" "plain file (stale global index) — run: qmd cleanup"
else
    pass "No stale global index.sqlite" "only per-repo symlinks present"
fi

# Per-project aliases written by init_qmd.sh (look for the managed block marker)
if grep -qF "# QMD per-project aliases — managed by init_qmd.sh" "$HOME/.bashrc" 2>/dev/null; then
    ALIAS_COUNT=$(grep -c "^alias qmd-" "$HOME/.bashrc" 2>/dev/null || echo 0)
    pass "Per-project qmd-{name} aliases" "$ALIAS_COUNT in ~/.bashrc"
else
    warn "Per-project qmd-{name} aliases" "marker not found in ~/.bashrc — run ~/init_qmd.sh"
fi


################################################################################
section "Graphify (Code Knowledge Graph)"
################################################################################

# graphify binary in PATH
if command -v graphify &>/dev/null; then
    GRAPHIFY_PATH=$(which graphify)
    pass "graphify binary in PATH" "$GRAPHIFY_PATH"
else
    fail "graphify binary" "not found in PATH"
fi

# graphify --version runs without error
GRAPHIFY_VER=$(graphify --version 2>&1)
GRAPHIFY_EXIT=$?
if [ $GRAPHIFY_EXIT -eq 0 ] && [ -n "$GRAPHIFY_VER" ]; then
    pass "graphify --version" "$GRAPHIFY_VER"
else
    fail "graphify --version" "exit $GRAPHIFY_EXIT — ${GRAPHIFY_VER:0:80}"
fi

# graphify-mcp entrypoint present (mcp extra installed)
if command -v graphify-mcp &>/dev/null; then
    pass "graphify-mcp entrypoint" "present ([mcp] extra installed)"
else
    warn "graphify-mcp entrypoint" "not found — [mcp] extra may be missing"
fi

# Discover repos the same way init_graphify.sh does: any dir under ~/ or /workspace with a .git/
GRAPHIFY_REPOS=()
for dir in "$HOME"/*/; do
    [ -d "${dir}.git" ] && GRAPHIFY_REPOS+=("${dir%/}")
done
if [ -d "/workspace/.git" ]; then
    GRAPHIFY_REPOS+=("/workspace")
elif [ -d "/workspace" ]; then
    for dir in /workspace/*/; do
        [ -d "${dir}.git" ] && GRAPHIFY_REPOS+=("${dir%/}")
    done
fi

if [ "${#GRAPHIFY_REPOS[@]}" -eq 0 ]; then
    warn "Per-repo graphs" "no git repositories found — clone a repo, then run ~/init_graphify.sh"
else
    GRAPH_OK=0
    GRAPH_MISSING=0
    SKILL_OK=0
    SKILL_MISSING=0
    HOOK_OK=0
    HOOK_MISSING=0
    POSTCOMMIT_OK=0
    POSTCOMMIT_MISSING=0
    GITIGNORE_OK=0
    GITIGNORE_MISSING=0

    for repo in "${GRAPHIFY_REPOS[@]}"; do
        repo_name=$(basename "$repo")

        # graph.json built and non-trivial
        graph_file="$repo/graphify-out/graph.json"
        if [ -s "$graph_file" ]; then
            GRAPH_OK=$((GRAPH_OK+1))
        else
            GRAPH_MISSING=$((GRAPH_MISSING+1))
            warn "  graphify-out/graph.json ($repo_name)" "missing or empty — run: cd $repo && graphify extract . --code-only --cargo"
        fi

        # Claude Code project skill installed
        if [ -f "$repo/.claude/skills/graphify/SKILL.md" ]; then
            SKILL_OK=$((SKILL_OK+1))
        else
            SKILL_MISSING=$((SKILL_MISSING+1))
        fi

        # PreToolUse hook registered in the repo's .claude/settings.json
        if grep -q "graphify" "$repo/.claude/settings.json" 2>/dev/null; then
            HOOK_OK=$((HOOK_OK+1))
        else
            HOOK_MISSING=$((HOOK_MISSING+1))
        fi

        # git post-commit hook installed (auto-rebuild on commit)
        if grep -q "graphify" "$repo/.git/hooks/post-commit" 2>/dev/null; then
            POSTCOMMIT_OK=$((POSTCOMMIT_OK+1))
        else
            POSTCOMMIT_MISSING=$((POSTCOMMIT_MISSING+1))
        fi

        # .gitignore excludes the local-only cost.json
        if grep -qF "graphify-out/cost.json" "$repo/.gitignore" 2>/dev/null; then
            GITIGNORE_OK=$((GITIGNORE_OK+1))
        else
            GITIGNORE_MISSING=$((GITIGNORE_MISSING+1))
        fi
    done

    if [ "$GRAPH_OK" -gt 0 ] && [ "$GRAPH_MISSING" -eq 0 ]; then
        pass "Per-repo graphify-out/graph.json" "$GRAPH_OK repo(s)"
    elif [ "$GRAPH_OK" -gt 0 ]; then
        warn "Per-repo graphify-out/graph.json" "$GRAPH_OK ok, $GRAPH_MISSING missing"
    fi

    if [ "$SKILL_OK" -gt 0 ] && [ "$SKILL_MISSING" -eq 0 ]; then
        pass ".claude/skills/graphify/SKILL.md" "$SKILL_OK repo(s)"
    elif [ "$SKILL_OK" -gt 0 ] || [ "$SKILL_MISSING" -gt 0 ]; then
        warn ".claude/skills/graphify/SKILL.md" "$SKILL_OK ok, $SKILL_MISSING missing — run: graphify claude install --project"
    fi

    if [ "$HOOK_OK" -gt 0 ] && [ "$HOOK_MISSING" -eq 0 ]; then
        pass ".claude/settings.json PreToolUse hook" "$HOOK_OK repo(s)"
    elif [ "$HOOK_OK" -gt 0 ] || [ "$HOOK_MISSING" -gt 0 ]; then
        warn ".claude/settings.json PreToolUse hook" "$HOOK_OK ok, $HOOK_MISSING missing"
    fi

    if [ "$POSTCOMMIT_OK" -gt 0 ] && [ "$POSTCOMMIT_MISSING" -eq 0 ]; then
        pass "git post-commit auto-rebuild hook" "$POSTCOMMIT_OK repo(s)"
    elif [ "$POSTCOMMIT_OK" -gt 0 ] || [ "$POSTCOMMIT_MISSING" -gt 0 ]; then
        warn "git post-commit auto-rebuild hook" "$POSTCOMMIT_OK ok, $POSTCOMMIT_MISSING missing — run: graphify hook install"
    fi

    if [ "$GITIGNORE_OK" -gt 0 ] && [ "$GITIGNORE_MISSING" -eq 0 ]; then
        pass ".gitignore: graphify-out/cost.json ignored" "$GITIGNORE_OK repo(s)"
    elif [ "$GITIGNORE_MISSING" -gt 0 ]; then
        warn ".gitignore: graphify-out/cost.json ignored" "$GITIGNORE_MISSING repo(s) missing entry"
    fi
fi

# graphify-status bashrc helper present
if grep -qF "function graphify-status" "$HOME/.bashrc" 2>/dev/null; then
    pass "graphify-status bashrc helper" "present"
else
    warn "graphify-status bashrc helper" "not found in ~/.bashrc"
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
