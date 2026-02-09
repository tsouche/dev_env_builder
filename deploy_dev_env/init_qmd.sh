#!/bin/bash
################################################################################
# QMD Initialization Script
# Run this after first container deployment to set up QMD indexing
# This script is idempotent - safe to run multiple times
################################################################################

set -e

echo "========================================="
echo "QMD Initialization"
echo "========================================="

# Check if QMD is installed
if ! command -v qmd &> /dev/null; then
    echo "❌ QMD not found. Please rebuild the container."
    exit 1
fi

echo "✓ QMD is installed"

# Auto-detect and index git repositories
echo ""
echo "Scanning for projects..."

PROJECTS_FOUND=0

# Function to index a directory
index_project() {
    local project_dir="$1"
    local project_name="$2"
    
    echo ""
    echo "Found: $project_name at $project_dir"
    
    # Check if collection already exists
    if qmd collection list 2>/dev/null | grep -q "^$project_name$"; then
        echo "  → Collection already exists, updating..."
        cd "$project_dir"
        qmd update
        echo "  ✓ Updated"
    else
        echo "  → Creating new collection..."
        cd "$project_dir"
        qmd collection add . --name "$project_name" --mask "**/*.{rs,md,toml,json,yaml,yml,sh,py,js,ts,jsx,tsx,go,c,cpp,h,hpp}"
        echo "  ✓ Created"
    fi
    
    # Add context
    qmd context add "qmd://$project_name" "Project: $project_name"
    [ -d "$project_dir/src" ] && qmd context add "qmd://$project_name/src" "Source code"
    [ -d "$project_dir/docs" ] && qmd context add "qmd://$project_name/docs" "Documentation"
    [ -d "$project_dir/tests" ] && qmd context add "qmd://$project_name/tests" "Tests"
    
    PROJECTS_FOUND=$((PROJECTS_FOUND + 1))
}

# Scan home directory for git repositories
for dir in ~/*/.git; do
    if [ -d "$dir" ]; then
        project_dir=$(dirname "$dir")
        project_name=$(basename "$project_dir")
        index_project "$project_dir" "$project_name"
    fi
done

# Scan /workspace for git repositories
if [ -d "/workspace" ]; then
    for dir in /workspace/*/.git; do
        if [ -d "$dir" ]; then
            project_dir=$(dirname "$dir")
            project_name=$(basename "$project_dir")
            index_project "$project_dir" "$project_name"
        fi
    done
    
    # Also check if /workspace itself is a git repo
    if [ -d "/workspace/.git" ]; then
        index_project "/workspace" "workspace"
    fi
fi

if [ $PROJECTS_FOUND -eq 0 ]; then
    echo "⚠️  No git repositories found in ~/ or /workspace"
    echo "    Clone a project and run this script again"
else
    echo ""
    echo "✓ Indexed $PROJECTS_FOUND project(s)"
fi

# Generate vector embeddings (this will download GGUF models on first run)
echo ""
if [ $PROJECTS_FOUND -gt 0 ]; then
    echo "Generating vector embeddings for all collections..."
    echo "(Downloading GGUF models ~2GB if not cached...)"
    qmd embed
    echo "✓ Embeddings generated"
else
    echo "⚠️  No projects to embed - skipping embedding generation"
    echo "    Run this script again after cloning your project"
fi

# Show index status
echo ""
echo "========================================="
echo "QMD Status:"
echo "========================================="
qmd status

echo ""
echo "========================================="
echo "✓ QMD initialization complete!"
echo "========================================="
echo ""
echo "Notes:"
echo "  - GGUF models (~2GB) are cached in: ~/.cache/qmd/models/"
echo "  - Index database persists across container rebuilds"
echo "  - This script is safe to run multiple times"
echo ""
echo "Next steps:"
echo "  1. QMD is already configured with Claude Code via MCP"
echo "  2. Review the global CLAUDE.md in ~/.claude/CLAUDE.md"
echo "  3. Optionally create a project-specific CLAUDE.md in /workspace"
echo "  4. Test: claude code (then ask a question about your code)"
echo ""
echo "Maintenance commands:"
echo "  qmd-update   - Re-index after code changes"
echo "  qmd-refresh  - Full re-index with embedding refresh"
echo "  qmd-status   - Check index health"
echo ""
