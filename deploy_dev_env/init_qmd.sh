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

# Check if workspace collection already exists
echo ""
echo "Checking existing collections..."
if qmd collection list 2>/dev/null | grep -q "workspace"; then
    echo "⚠️  Collection 'workspace' already exists"
    echo "    Updating existing index instead..."
    cd /workspace
    qmd update
    echo "✓ Index updated"
else
    # Create new collection
    echo ""
    echo "Creating QMD collection for /workspace..."
    cd /workspace
    qmd collection add . --name workspace --mask "**/*.{rs,md,toml,json,yaml,yml,sh}"
    echo "✓ Collection 'workspace' created"
fi

# Add context to help search understand the codebase
# Context commands are idempotent - they update if exists
echo ""
echo "Adding/updating context descriptions..."
qmd context add qmd://workspace "Rust development workspace with backend services"

# Add more specific contexts if standard directories exist
[ -d "/workspace/src" ] && qmd context add qmd://workspace/src "Rust source code"
[ -d "/workspace/docs" ] && qmd context add qmd://workspace/docs "Project documentation"
[ -d "/workspace/tests" ] && qmd context add qmd://workspace/tests "Test files"

echo "✓ Context descriptions configured"

# Generate vector embeddings (this will download GGUF models on first run)
echo ""
echo "Generating vector embeddings..."
if [ -d "/workspace" ] && [ "$(ls -A /workspace 2>/dev/null)" ]; then
    echo "Workspace has content, generating embeddings..."
    echo "(Downloading GGUF models ~2GB if not cached...)"
    qmd embed
    echo "✓ Embeddings generated"
else
    echo "⚠️  Workspace is empty - skipping embedding generation"
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
