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
    
    # Update Claude Code project configuration to use QMD contexts
    echo ""
    echo "Configuring Claude Code to use QMD for code searches..."
    
    python3 -c "
import json
import os

# Read current configuration
config_file = os.path.expanduser('~/.claude.json')
if os.path.exists(config_file):
    with open(config_file, 'r') as f:
        try:
            data = json.load(f)
        except json.JSONDecodeError:
            print('Warning: Could not parse .claude.json, skipping project config update')
            exit(0)
else:
    print('Warning: .claude.json not found, skipping project config update')
    exit(0)

# Get list of QMD contexts
import subprocess
try:
    result = subprocess.run(['qmd', 'context', 'list'], capture_output=True, text=True, timeout=10)
    if result.returncode == 0:
        contexts_output = result.stdout
        # Parse contexts - look for lines like 'set_backend' and '  src'
        contexts = []
        current_project = None
        for line in contexts_output.split('\n'):
            line = line.strip()
            if line and not line.startswith(' ') and line != 'Configured Contexts':
                current_project = line
                contexts.append(f'qmd://{current_project}')
            elif line.startswith(' ') and current_project and line.strip():
                context_name = line.strip().split()[0]
                if context_name != '/':
                    contexts.append(f'qmd://{current_project}/{context_name}')
        
        # Update project configurations
        projects_updated = 0
        for project_path in ['/workspace', '/home/rustdev/set_backend']:
            if os.path.exists(project_path):
                if 'projects' not in data:
                    data['projects'] = {}
                if project_path not in data['projects']:
                    data['projects'][project_path] = {}
                
                # Add QMD contexts to this project
                project_contexts = [ctx for ctx in contexts if project_path.split('/')[-1] in ctx]
                if project_contexts:
                    data['projects'][project_path]['mcpContextUris'] = project_contexts
                    projects_updated += 1
        
        # Save updated configuration
        if projects_updated > 0:
            with open(config_file, 'w') as f:
                json.dump(data, f, indent=2)
            print(f'✓ Updated Claude Code configuration for {projects_updated} project(s)')
        else:
            print('ℹ️  No projects needed QMD context configuration')
    else:
        print('Warning: Could not get QMD contexts, skipping project config update')
except Exception as e:
    print(f'Warning: Error updating project config: {e}')
"
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
echo "  - GGUF models (~2GB) are stored in: ~/.cache/qmd/models/"
echo "    (Mounted from Windows: C:/rustdev/docker/qmd_models - shared across projects)"
echo "  - Index database persisted in: ~/.cache/qmd/index.sqlite"
echo "    (In per-project home volume for clean separation)"
echo "  - Claude history in: ~/.claude/"
echo "    (Mounted from Windows: C:/rustdev/claude_config - eternal persistence)"
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
