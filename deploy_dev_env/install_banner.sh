#!/bin/bash
################################################################################
# Welcome Banner Installer
# Writes an idempotent managed block into ~/.bashrc that displays a welcome
# banner (tool versions + getting-started commands) on every new interactive
# terminal (e.g. a VS Code Remote-SSH terminal spawned into this container).
#
# Run automatically by deploy-dev.ps1 on every deploy, the same way the QMD
# and Graphify bashrc helpers are self-healed: /home/${USER} is a persistent
# named volume, so anything baked purely into the base image's .bashrc at
# build time is invisible on a redeploy against an already-existing volume.
# Writing the block here, at deploy time, avoids that.
#
# This script is fully idempotent — safe to re-run on every deploy.
################################################################################

set -euo pipefail

MARKER="# Welcome Banner — managed by install_banner.sh"
END_MARKER="# END Welcome Banner"

if grep -qF "$MARKER" ~/.bashrc 2>/dev/null; then
    sed -i "/$MARKER/,/$END_MARKER/d" ~/.bashrc
fi

cat >> ~/.bashrc << 'BASHRCEOF'
# Welcome Banner — managed by install_banner.sh
function dev-welcome() {
    # Only for real interactive shells (not docker exec/scripted sessions)
    [ -n "$PS1" ] || return

    local rust_ver node_ver bun_ver qmd_ver graphify_ver claude_ver
    rust_ver=$(rustc --version 2>/dev/null | awk '{print $2}')
    node_ver=$(node --version 2>/dev/null)
    bun_ver=$(bun --version 2>/dev/null)
    qmd_ver=$(qmd --version 2>/dev/null)
    graphify_ver=$(graphify --version 2>/dev/null | awk '{print $2}')
    claude_ver=$(claude --version 2>/dev/null | head -1)

    echo ""
    echo "=================================================================="
    echo "  Rust Development Environment"
    echo "=================================================================="
    echo ""
    echo "  Rust:      ${rust_ver:-not found}"
    echo "  Node.js:   ${node_ver:-not found}"
    echo "  Bun:       ${bun_ver:-not found}"
    echo "  QMD:       ${qmd_ver:-not found}          — semantic code search"
    echo "  Graphify:  ${graphify_ver:-not found}  — code knowledge graph"
    echo "  Claude:    ${claude_ver:-not found}"
    echo ""
    echo "  New project checklist:"
    echo "    1. git clone <url>          (inside ~ for best performance)"
    echo "    2. ~/init_qmd.sh            — initialize semantic search"
    echo "    3. ~/init_graphify.sh       — initialize code knowledge graph"
    echo ""
    echo "  Commands: qmd-status | qmd-reindex | graphify-status | graphify-reindex"
    echo ""
}
dev-welcome
# END Welcome Banner
BASHRCEOF

echo "Welcome banner installed in ~/.bashrc"
