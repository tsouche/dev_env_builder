#!/bin/bash
################################################################################
# Graphify Initialization Script
# Run this after first container deployment (or after cloning a new repo).
# Builds a code knowledge graph for every git repository found in ~/ or
# /workspace, and wires up Claude Code + git integration for each.
#
# Complements QMD (see init_qmd.sh): QMD answers content/semantic questions
# via chunk retrieval; Graphify answers structural questions (call graphs,
# path tracing) via AST + graph traversal. Both run side by side.
#
# Per-repo layout (created for each project):
#   {repo}/graphify-out/graph.json        — the graph itself (meant to be committed)
#   {repo}/graphify-out/GRAPH_REPORT.md   — architecture overview (meant to be committed)
#   {repo}/graphify-out/graph.html        — interactive graph viewer (meant to be committed)
#   {repo}/graphify-out/cost.json         — local-only run metadata (git-ignored)
#   {repo}/.claude/skills/graphify/SKILL.md — Claude Code project skill
#   {repo}/.claude/CLAUDE.md, {repo}/CLAUDE.md — project guidance (graphify section)
#   {repo}/.claude/settings.json          — PreToolUse hook nudging toward graphify
#   {repo}/.git/hooks/post-commit, post-checkout — auto-rebuild the graph
#
# GRAPH_REPORT.md/graph.html generation (via `graphify cluster-only`) runs
# fully offline: with no LLM backend/API key configured (the default here),
# community names fall back to generic "Community N" placeholders instead of
# descriptive labels, but the report is still complete and free to produce.
#
# Scoping is path-based (cwd), not flag-based like QMD's --index: from inside
# a repo, just run `graphify query "..."` — no per-project alias needed.
#
# This script is fully idempotent — safe to re-run after pulling new code.
################################################################################

set -euo pipefail

echo "========================================="
echo "Graphify Initialization"
echo "========================================="

# Check if Graphify is installed
if ! command -v graphify &> /dev/null; then
    echo "ERROR: graphify not found. Please rebuild the container."
    exit 1
fi
echo "  Graphify is installed: $(graphify --version 2>/dev/null || echo 'ok')"

################################################################################
# Ensure generic bashrc helpers are present (self-healing)
#
# /home/${USER} is a persistent named volume on deployment. Docker only
# seeds a volume's content from the image the FIRST time that volume is
# created, so .bashrc additions baked into a LATER base image build are
# invisible on any redeploy against an already-existing volume. Rewriting
# this managed block here on every run (idempotent, marker-delimited, same
# pattern as the per-project alias block below) makes it self-healing
# regardless of when the volume was first created.
################################################################################

GRAPHIFY_BASHRC_MARKER="# Graphify Shortcuts — managed by init_graphify.sh"
if grep -qF "$GRAPHIFY_BASHRC_MARKER" ~/.bashrc 2>/dev/null; then
    sed -i "/$GRAPHIFY_BASHRC_MARKER/,/^$/d" ~/.bashrc
fi
cat >> ~/.bashrc << 'BASHRCEOF'
# Graphify Shortcuts — managed by init_graphify.sh
alias graphify-reindex="~/init_graphify.sh"

# graphify-status: show graph status for every repo with a graphify-out/
function graphify-status() {
    local found=0
    for graph in "$HOME"/*/graphify-out/graph.json /workspace/*/graphify-out/graph.json /workspace/graphify-out/graph.json; do
        [ -f "$graph" ] || continue
        found=1
        repo_dir=$(dirname "$(dirname "$graph")")
        echo "=== $(basename "$repo_dir") ==="
        echo "  $graph ($(wc -c < "$graph") bytes)"
    done
    if [ "$found" -eq 0 ]; then echo "No Graphify graphs found. Run: ~/init_graphify.sh"; fi
}

BASHRCEOF
echo "  bashrc helpers ensured: graphify-status, graphify-reindex"

################################################################################
# Per-repo setup function
################################################################################

PROJECTS_FOUND=0
PROJECT_NAMES=()

setup_project_graphify() {
    local project_dir="$1"
    local project_name="$2"

    echo ""
    echo "--- $project_name ($project_dir) ---"

    cd "$project_dir"

    # 1. Extract the code graph (code-only: no API key/GGUF models needed)
    local cargo_flag=""
    if [ -f "$project_dir/Cargo.toml" ]; then
        cargo_flag="--cargo"
    fi
    echo "  Extracting graph (code-only${cargo_flag:+, cargo})..."
    graphify extract . --code-only ${cargo_flag}

    # 1b. Generate GRAPH_REPORT.md + graph.html (community detection + report).
    #     Runs fully offline: with no LLM backend/API key configured (the
    #     default in this environment), it falls back to generic "Community
    #     N" placeholder names instead of descriptive labels, but still
    #     produces a complete, useful report at zero cost.
    echo "  Generating GRAPH_REPORT.md (offline, no API key needed)..."
    graphify cluster-only . || echo "  (cluster-only skipped/failed, graph.json is still usable)"

    # 2. Add graphify-out/cost.json to .gitignore (idempotent). graph.json and
    #    GRAPH_REPORT.md are meant to be committed (upstream's own recommended
    #    team workflow — JSON diffs reasonably, and `graphify hook install`
    #    below sets up a merge driver so parallel commits don't conflict).
    local gitignore="$project_dir/.gitignore"
    if ! grep -qF "graphify-out/cost.json" "$gitignore" 2>/dev/null; then
        {
            echo ""
            echo "# Graphify local-only run metadata (graph.json/GRAPH_REPORT.md are committed)"
            echo "graphify-out/cost.json"
        } >> "$gitignore"
        echo "  .gitignore updated: graphify-out/cost.json ignored"
    fi

    # 3. Install Claude Code project integration (CLAUDE.md + skill + hook).
    #    Not --strict: the default soft nudge coexists with QMD's existing
    #    soft CLAUDE.md rule instead of blocking the first Read.
    echo "  Installing Claude Code project integration..."
    graphify claude install --project || echo "  (claude install skipped/already present)"

    # 4. Install the git post-commit auto-rebuild hook + graph.json merge driver
    echo "  Installing git commit hook..."
    graphify hook install || echo "  (hook install skipped/already present)"

    PROJECT_NAMES+=("$project_name")
    PROJECTS_FOUND=$((PROJECTS_FOUND + 1))
    echo "  Done."
}

################################################################################
# Scan for git repositories
################################################################################

echo ""
echo "Scanning for git repositories..."

# Home directory repos
for dir in "$HOME"/*/; do
    if [ -d "${dir}.git" ]; then
        project_name=$(basename "$dir")
        setup_project_graphify "$dir" "$project_name"
    fi
done

# /workspace (single repo or parent of repos)
if [ -d "/workspace/.git" ]; then
    setup_project_graphify "/workspace" "workspace"
elif [ -d "/workspace" ]; then
    for dir in /workspace/*/; do
        if [ -d "${dir}.git" ]; then
            project_name=$(basename "$dir")
            setup_project_graphify "$dir" "$project_name"
        fi
    done
fi

if [ "$PROJECTS_FOUND" -eq 0 ]; then
    echo ""
    echo "WARNING: No git repositories found in ~/ or /workspace."
    echo "  Clone a project, then re-run: ~/init_graphify.sh"
    exit 0
fi

echo ""
echo "Found $PROJECTS_FOUND project(s)."

################################################################################
# Summary
################################################################################

echo ""
echo "========================================="
echo "Graphify Per-Project Status"
echo "========================================="
for graph in "$HOME"/*/graphify-out/graph.json /workspace/*/graphify-out/graph.json /workspace/graphify-out/graph.json; do
    [ -f "$graph" ] || continue
    repo_dir=$(dirname "$(dirname "$graph")")
    echo ""
    echo "  [$(basename "$repo_dir")]"
    echo "  $graph ($(wc -c < "$graph") bytes)"
done

echo ""
echo "========================================="
echo "  Graphify initialization complete!"
echo "========================================="
echo ""
echo "Per-project layout:"
echo "  Graph:       {repo}/graphify-out/graph.json        (committed to git)"
echo "  Report:      {repo}/graphify-out/GRAPH_REPORT.md   (committed to git)"
echo "  Viewer:      {repo}/graphify-out/graph.html        (committed to git)"
echo "  Local-only:  {repo}/graphify-out/cost.json          (git-ignored)"
echo "  Skill:       {repo}/.claude/skills/graphify/SKILL.md"
echo "  Hook:        {repo}/.claude/settings.json (PreToolUse) + git post-commit/post-checkout"
echo ""
echo "Usage (from inside a project directory — no --index flag needed):"
echo "  graphify query \"what connects auth to the database?\""
echo "  graphify path \"UserService\" \"DatabasePool\""
echo "  graphify explain \"RateLimiter\""
echo "  (the git post-commit hook re-extracts automatically; to force a"
echo "   manual re-extract, re-run: ~/init_graphify.sh)"
echo ""
echo "On a new machine: clone the repo, then run:  ~/init_graphify.sh"
echo "Claude Code project context is set automatically via {repo}/.claude/"
echo ""
