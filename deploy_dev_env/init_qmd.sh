#!/bin/bash
################################################################################
# QMD Initialization Script
# Run this after first container deployment (or after cloning a new repo).
# Sets up a per-repo QMD index for every git repository found in ~/ or /workspace.
#
# Per-repo layout (created for each project):
#   {repo}/.qmd/index.sqlite          — DB lives IN the repo (git-ignored)
#   ~/.cache/qmd/{name}.sqlite        — symlink → repo DB (for qmd --index discovery)
#   ~/.config/qmd/{name}.yml          — named-index config (db path)
#   {repo}/.mcp.json                  — Claude Code project-level MCP override
#   ~/.bashrc alias: qmd-{name}       — shorthand for 'qmd --index {name}'
#
# This script is fully idempotent — safe to re-run after pulling new docs.
################################################################################

set -euo pipefail

echo "========================================="
echo "QMD Initialization (per-repo mode)"
echo "========================================="

# Check if QMD is installed
if ! command -v qmd &> /dev/null; then
    echo "ERROR: QMD not found. Please rebuild the container."
    exit 1
fi
echo "  QMD is installed: $(qmd --version 2>/dev/null || echo 'ok')"

################################################################################
# Per-repo setup function
################################################################################

PROJECTS_FOUND=0
ALIASES_ADDED=()

setup_project_qmd() {
    local project_dir="$1"
    local project_name="$2"

    echo ""
    echo "--- $project_name ($project_dir) ---"

    # 1. Create .qmd directory inside the repo
    mkdir -p "$project_dir/.qmd"

    # 2. Add .qmd/*.sqlite* to repo .gitignore (idempotent)
    local gitignore="$project_dir/.gitignore"
    if ! grep -qF ".qmd/*.sqlite" "$gitignore" 2>/dev/null; then
        {
            echo ""
            echo "# QMD per-repo index (local only, not pushed to git)"
            echo ".qmd/*.sqlite*"
        } >> "$gitignore"
        echo "  .gitignore updated: .qmd/*.sqlite* ignored"
    fi

    # 3. Create symlink ~/.cache/qmd/{name}.sqlite → {repo}/.qmd/index.sqlite
    #    This allows 'qmd --index {name}' to locate the DB automatically.
    mkdir -p "$HOME/.cache/qmd"
    local db_path="$project_dir/.qmd/index.sqlite"
    local symlink_path="$HOME/.cache/qmd/${project_name}.sqlite"
    # Recreate symlink if missing or pointing elsewhere
    if [ ! -L "$symlink_path" ] || [ "$(readlink "$symlink_path")" != "$db_path" ]; then
        ln -sf "$db_path" "$symlink_path"
        echo "  Symlink: ~/.cache/qmd/${project_name}.sqlite -> $db_path"
    fi

    # 4. Create ~/.config/qmd/{name}.yml (named-index config)
    mkdir -p "$HOME/.config/qmd"
    local config_path="$HOME/.config/qmd/${project_name}.yml"
    cat > "$config_path" << YMLEOF
db: ${db_path}
YMLEOF
    echo "  Config:  ~/.config/qmd/${project_name}.yml"

    # 5. Index the project with per-repo --index flag
    cd "$project_dir"
    if qmd --index "$project_name" status 2>/dev/null | grep -qiE "collection|document|chunk"; then
        echo "  Updating existing index..."
        qmd --index "$project_name" update
    else
        echo "  Creating new index..."
        qmd --index "$project_name" collection add . \
            --name "$project_name" \
            --mask "**/*.{rs,md,toml,json,yaml,yml,sh,py,js,ts,jsx,tsx,go,c,cpp,h,hpp}"
    fi
    echo "  Indexed."

    # 6. Create/update {repo}/.mcp.json for Claude Code project-level MCP override
    #    When Claude Code opens this project, it will use qmd --index {name} mcp
    #    automatically, scoping all QMD searches to THIS project's index.
    cat > "$project_dir/.mcp.json" << MCPEOF
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": ["--index", "${project_name}", "mcp"]
    }
  }
}
MCPEOF
    echo "  .mcp.json: qmd --index ${project_name} mcp"

    ALIASES_ADDED+=("alias qmd-${project_name}='qmd --index ${project_name}'")
    PROJECTS_FOUND=$((PROJECTS_FOUND + 1))
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
        setup_project_qmd "$dir" "$project_name"
    fi
done

# /workspace (single repo or parent of repos)
if [ -d "/workspace/.git" ]; then
    setup_project_qmd "/workspace" "workspace"
elif [ -d "/workspace" ]; then
    for dir in /workspace/*/; do
        if [ -d "${dir}.git" ]; then
            project_name=$(basename "$dir")
            setup_project_qmd "$dir" "$project_name"
        fi
    done
fi

if [ "$PROJECTS_FOUND" -eq 0 ]; then
    echo ""
    echo "WARNING: No git repositories found in ~/ or /workspace."
    echo "  Clone a project, then re-run: ~/init_qmd.sh"
    exit 0
fi

echo ""
echo "Found $PROJECTS_FOUND project(s)."

################################################################################
# Write per-project aliases to ~/.bashrc (idempotent)
################################################################################

echo ""
echo "Writing per-project aliases to ~/.bashrc..."

MARKER="# QMD per-project aliases — managed by init_qmd.sh"

# Remove any previously generated aliases block
if grep -qF "$MARKER" ~/.bashrc 2>/dev/null; then
    # Delete from marker line to the next blank line (inclusive)
    sed -i "/$MARKER/,/^$/d" ~/.bashrc
fi

{
    echo ""
    echo "$MARKER"
    for alias_line in "${ALIASES_ADDED[@]}"; do
        echo "$alias_line"
    done
    echo ""
} >> ~/.bashrc

echo "  Aliases written (activate with: source ~/.bashrc)"

################################################################################
# Generate vector embeddings per project
################################################################################

echo ""
echo "Generating vector embeddings..."
echo "(First run downloads GGUF models ~2GB to ~/.cache/qmd/models/)"

for symlink in "$HOME"/.cache/qmd/*.sqlite; do
    [ -L "$symlink" ] || continue
    project_name=$(basename "$symlink" .sqlite)
    echo ""
    echo "  Embedding: $project_name..."
    qmd --index "$project_name" embed && echo "  Done: $project_name"
done

################################################################################
# Summary
################################################################################

echo ""
echo "========================================="
echo "QMD Per-Project Status"
echo "========================================="
for symlink in "$HOME"/.cache/qmd/*.sqlite; do
    [ -L "$symlink" ] || continue
    project_name=$(basename "$symlink" .sqlite)
    echo ""
    echo "  [$project_name]"
    qmd --index "$project_name" status 2>/dev/null || echo "  (not yet initialized)"
done

echo ""
echo "========================================="
echo "  QMD initialization complete!"
echo "========================================="
echo ""
echo "Per-project layout:"
echo "  DB:          {repo}/.qmd/index.sqlite   (in-repo, git-ignored)"
echo "  Symlink:     ~/.cache/qmd/{name}.sqlite → repo DB"
echo "  Config:      ~/.config/qmd/{name}.yml"
echo "  MCP:         {repo}/.mcp.json           (Claude Code auto-picks up on open)"
echo "  Models:      ~/.cache/qmd/models/       (shared across projects, ~2GB)"
echo ""
echo "Available aliases (after: source ~/.bashrc):"
for alias_line in "${ALIASES_ADDED[@]}"; do
    echo "  $alias_line"
done
echo ""
echo "Usage per project:"
echo "  qmd-{name} status    — check index health"
echo "  qmd-{name} update    — re-index after code changes"
echo "  qmd-{name} embed     — regenerate semantic embeddings"
echo "  qmd-{name} query ... — search that project's index"
echo ""
echo "On a new machine: clone the repo, then run:  ~/init_qmd.sh"
echo "Claude Code project context is set automatically via {repo}/.mcp.json"
echo ""
