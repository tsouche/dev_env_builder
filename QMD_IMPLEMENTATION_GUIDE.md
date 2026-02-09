# QMD Implementation Guide for Dev Environment

**Date:** February 9, 2026  
**Purpose:** Enable QMD (Query Markup Documents) for AI-optimized code indexing and efficient Claude Code integration

---

## Table of Contents

1. [Overview](#overview)
2. [Critical Fixes to QMD.md](#critical-fixes-to-qmdmd)
3. [Implementation Phases](#implementation-phases)
4. [File Checklist](#file-checklist)
5. [Post-Deployment Usage](#post-deployment-usage)
6. [Troubleshooting](#troubleshooting)

---

## Overview

### What is QMD?

QMD (Query Markup Documents) is an on-device search engine that indexes your codebase using:

- **BM25 full-text search** (keyword matching)
- **Vector semantic search** (conceptual similarity)
- **LLM re-ranking** (query expansion and relevance scoring)

### Why Add QMD?

**Benefits:**

- **Reduces Claude Code token usage** by 60-80% (searches index instead of reading all files)
- **Faster context gathering** (cached embeddings vs. file scanning)
- **Better search results** (semantic understanding vs. grep)
- **Persistent knowledge base** (survives container restarts)

**Cost:**

- ~2GB disk space (GGUF models)
- Initial setup: 10-15 minutes
- Index updates: 1-2 minutes per project

---

## Critical Fixes to QMD.md

### Issue 1: Wrong Command Syntax

**Current (BROKEN):**

```bash
qmd collection add ./my-project — name myproject — mask "**/*.{ts,tsx,md,json}"
```

**Should be:**

```bash
qmd collection add ./my-project --name myproject --mask "**/*.{ts,tsx,md,json}"
```

**Fix:** Replace all em-dashes `—` with double hyphens `--`

### Issue 2: MCP Configuration Location

**Current (INCOMPLETE):**

```json
~/.claude/mcp.json
```

**Should be:**

- For Claude Code: `~/.claude/settings.json`
- For Claude Desktop: `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS)

### Issue 3: Installation Command

**Current:**

```bash
bun install -g https://github.com/tobi/qmd
```

**Recommended:**

```bash
bun install -g github:tobi/qmd
```

---

## Implementation Phases

### Phase 1: Base Image - Add Bun Runtime

**File:** `build_base_dev_image/Dockerfile.base_rust_dev`  
**Location:** After Node.js installation (around line 45), before Rust toolchain

```dockerfile
################################################################################
# Install Bun Runtime (Required for QMD)
################################################################################
USER root
RUN curl -fsSL https://bun.sh/install | bash -s -- --prefix /usr/local && \
    ln -s /usr/local/bin/bun /usr/local/bin/bunx

# Verify Bun installation
RUN bun --version

ENV BUN_INSTALL="/usr/local"
ENV PATH="${BUN_INSTALL}/bin:${PATH}"
```

**Rationale:**

- Bun is required for QMD (QMD is distributed as a Bun package)
- Install system-wide so all users benefit
- Installed before user creation for proper permissions

---

### Phase 2: Deployment Image - Install QMD

**File:** `deploy_dev_env/Dockerfile.rust-dev`  
**Location:** After Claude Code installation (after line 46)

```dockerfile
################################################################################
# QMD - Query Markup Documents (AI-optimized code indexing)
################################################################################
USER rustdev

# Install QMD globally
RUN bun install -g github:tobi/qmd

# Verify QMD installation
RUN qmd --version || echo "QMD installed, waiting for first use to download models"

# Create QMD cache directory with proper permissions
RUN mkdir -p /home/rustdev/.cache/qmd && \
    chown -R 1026:110 /home/rustdev/.cache

# Add QMD to PATH (should already be there via Bun, but ensure it)
RUN echo 'export PATH="$HOME/.bun/bin:$PATH"' >> /home/rustdev/.bashrc

# Configure Claude Code MCP integration automatically
RUN mkdir -p /home/rustdev/.claude && \
    echo '{"mcpServers":{"qmd":{"command":"qmd","args":["mcp"]}}}' > /home/rustdev/.claude/settings.json && \
    chown -R 1026:110 /home/rustdev/.claude

# Note: GGUF models (~2GB) will auto-download on first qmd embed
# Models stored in: ~/.cache/qmd/models/
# - embeddinggemma-300M-Q8_0 (~300MB)
# - qwen3-reranker-0.6b-q8_0 (~640MB)  
# - qmd-query-expansion-1.7B-q4_k_m (~1.1GB)
```

---

### Phase 3: Docker Compose - Add QMD Cache Volume

**File:** `deploy_dev_env/docker-compose-dev.yml`  
**Location:** In `dev-container` service, `volumes` section

```yaml
volumes:
  - ${VOLUME_CLAUDE_CONFIG}:/home/rustdev/.claude
  - ${PROJECT_PATH}:/workspace
  - ${VOLUME_TARGET_CACHE}:/workspace/target
  - /var/run/docker.sock:/var/run/docker.sock
  # QMD cache volume (for GGUF models and index)
  - ${VOLUME_QMD_CACHE:-./volumes/qmd_cache}:/home/rustdev/.cache/qmd
```

**File:** `deploy_dev_env/.env` (or create if not exists)  
**Add:**

```bash
# QMD Configuration
VOLUME_QMD_CACHE=./volumes/qmd_cache
```

**Rationale:**

- Persist GGUF models between container rebuilds (avoid 2GB re-download)
- Persist index database (SQLite) between container restarts
- Much faster container startup

---

### Phase 4: Create QMD Initialization Script

**File:** `deploy_dev_env/init_qmd.sh` (NEW)

```bash
#!/bin/bash
################################################################################
# QMD Initialization Script
# Run this after first container deployment to set up QMD indexing
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

# Index the workspace
echo ""
echo "Creating QMD collection for /workspace..."
cd /workspace

qmd collection add . --name workspace --mask "**/*.{rs,md,toml,json,yaml,yml,sh}"

echo "✓ Collection 'workspace' created"

# Add context to help search understand the codebase
echo ""
echo "Adding context descriptions..."
qmd context add qmd://workspace "Rust development workspace with backend services"

# Add more specific contexts if standard directories exist
[ -d "/workspace/src" ] && qmd context add qmd://workspace/src "Rust source code"
[ -d "/workspace/docs" ] && qmd context add qmd://workspace/docs "Project documentation"
[ -d "/workspace/tests" ] && qmd context add qmd://workspace/tests "Test files"

echo "✓ Context descriptions added"

# Generate vector embeddings (this will download GGUF models on first run)
echo ""
echo "Generating vector embeddings (this may take a few minutes on first run)..."
echo "Downloading GGUF models (~2GB) if not cached..."
qmd embed

echo ""
echo "✓ Embeddings generated"

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
echo "Next steps:"
echo "1. QMD is already configured with Claude Code via MCP"
echo "2. Review the global CLAUDE.md in ~/.claude/CLAUDE.md"
echo "3. Optionally create a project-specific CLAUDE.md in /workspace"
echo "4. Test: claude code (then ask a question about your code)"
echo ""
echo "Maintenance commands:"
echo "  qmd-update   - Re-index after code changes"
echo "  qmd-refresh  - Full re-index with embedding refresh"
echo "  qmd-status   - Check index health"
echo ""
```

**Add to Dockerfile.rust-dev (after QMD installation):**

```dockerfile
# Copy QMD initialization script
COPY init_qmd.sh /home/rustdev/init_qmd.sh
RUN chmod +x /home/rustdev/init_qmd.sh && \
    chown 1026:110 /home/rustdev/init_qmd.sh
```

---

### Phase 5: Claude Code MCP Integration (Plugin Method)

**Location:** Automatically configured in Phase 2 Dockerfile

The MCP configuration is created automatically during container build in Phase 2:

```dockerfile
# Configure Claude Code MCP integration automatically
RUN mkdir -p /home/rustdev/.claude && \
    echo '{"mcpServers":{"qmd":{"command":"qmd","args":["mcp"]}}}' > /home/rustdev/.claude/settings.json && \
    chown -R 1026:110 /home/rustdev/.claude
```

**Note:** The `~/.claude/` directory is volume-mounted via `${VOLUME_CLAUDE_CONFIG}`, so this configuration persists across container rebuilds.

**Alternative (Manual Plugin Method):**

If users want to use the Claude plugin marketplace instead:

```bash
# Run inside container after SSH login:
claude marketplace add tobi/qmd
claude plugin add qmd@qmd

# Verify
claude plugin list
```

**However, the automatic MCP config in Dockerfile is preferred** because:

- Works immediately on first container start
- No manual steps required
- Consistent across all deployments
- Volume-mounted, so persists across rebuilds

---

### Phase 6: CLAUDE.md Configuration

**Location:** `${VOLUME_CLAUDE_CONFIG}/CLAUDE.md` → `/home/rustdev/.claude/CLAUDE.md`

This file is **global** (applies to all projects) and **persistent** (volume-mounted).

**File:** `deploy_dev_env/CLAUDE.md.template` (NEW)

```markdown
# Global Claude Code Configuration

## Rule: Always use QMD before reading files

Before reading files or exploring directories, **always use QMD** to search for information in local projects.

### Available QMD Tools (via MCP):

- `qmd_search "query"` — Fast BM25 keyword search (best for exact matches, function names, error messages)
- `qmd_query "query"` — Hybrid search with query expansion and LLM reranking (best for complex questions)
- `qmd_vsearch "query"` — Semantic vector search (best for conceptual similarity)
- `qmd_get <file>` — Retrieve a specific document by path or docid (supports fuzzy matching)
- `qmd_multi_get <pattern>` — Get multiple files matching a glob pattern
- `qmd_status` — Check index health and available collections

### Search Strategy:

1. **For specific code/symbols/functions:** Use `qmd_search` with exact terms
2. **For concepts/explanations/architecture:** Use `qmd_query` for best results
3. **For similar functionality/patterns:** Use `qmd_vsearch` for semantic similarity
4. **For specific files:** Use `qmd_get` with path (supports fuzzy matching with suggestions)
5. **Only use Read/Grep/Glob tools** if QMD doesn't return sufficient results

### When to Skip QMD:

- File modifications (use Read before Edit)
- Line-specific debugging (QMD returns chunks, not line numbers)
- Binary files or generated code
- Very small codebases (<10 files)

### Collections:

- **workspace** — Current project in /workspace
- File types indexed: `*.rs`, `*.md`, `*.toml`, `*.json`, `*.yaml`, `*.yml`, `*.sh`

### Index Maintenance:

Remind users to run `qmd-update` after significant code changes:
- After merging branches
- After pulling updates
- After adding new files
- After major refactoring

## Output Preferences:

When using QMD results:
- Cite the source file and context
- Mention the QMD score if relevant
- If results seem outdated, suggest running `qmd-update`
```

**Add to Dockerfile.rust-dev (after QMD installation):**

```dockerfile
# Copy global CLAUDE.md template to .claude directory
COPY CLAUDE.md.template /home/rustdev/.claude/CLAUDE.md
RUN chown 1026:110 /home/rustdev/.claude/CLAUDE.md
```

**Directory Structure:**

```
/home/rustdev/.claude/            # Volume-mounted: ${VOLUME_CLAUDE_CONFIG}
├── settings.json                 # MCP server config (generated in Dockerfile)
└── CLAUDE.md                     # Global rules (from template)

/workspace/                       # Volume-mounted: ${PROJECT_PATH}
├── CLAUDE.md                     # Optional: Project-specific overrides
└── (your project files)
```

**Behavior:**

- Claude Code reads both global (`~/.claude/CLAUDE.md`) and project-specific (`/workspace/CLAUDE.md`)
- Project-specific rules override global rules
- Global rules apply to all projects

---

### Phase 7: Shell Aliases for Convenience

**File:** `deploy_dev_env/Dockerfile.rust-dev`  
**Location:** After QMD installation, in the shell aliases section

```dockerfile
# Add QMD shortcuts to bashrc
RUN echo '' >> /home/rustdev/.bashrc && \
    echo '# QMD Shortcuts' >> /home/rustdev/.bashrc && \
    echo 'alias qmd-update="cd /workspace && qmd update"' >> /home/rustdev/.bashrc && \
    echo 'alias qmd-refresh="cd /workspace && qmd update && qmd embed"' >> /home/rustdev/.bashrc && \
    echo 'alias qmd-status="qmd status"' >> /home/rustdev/.bashrc && \
    echo 'alias qmd-search="qmd query"' >> /home/rustdev/.bashrc && \
    echo '' >> /home/rustdev/.bashrc && \
    echo '# QMD index freshness check' >> /home/rustdev/.bashrc && \
    echo 'function qmd-check-update() {' >> /home/rustdev/.bashrc && \
    echo '    if [ ! -f ~/.cache/qmd/index.sqlite ]; then' >> /home/rustdev/.bashrc && \
    echo '        echo "⚠️  QMD not initialized. Run: ~/init_qmd.sh"' >> /home/rustdev/.bashrc && \
    echo '        return' >> /home/rustdev/.bashrc && \
    echo '    fi' >> /home/rustdev/.bashrc && \
    echo '    LAST_UPDATE=$(stat -c %Y ~/.cache/qmd/index.sqlite 2>/dev/null || echo 0)' >> /home/rustdev/.bashrc && \
    echo '    NOW=$(date +%s)' >> /home/rustdev/.bashrc && \
    echo '    DIFF=$((NOW - LAST_UPDATE))' >> /home/rustdev/.bashrc && \
    echo '    if [ $DIFF -gt 86400 ]; then' >> /home/rustdev/.bashrc && \
    echo '        echo "⚠️  QMD index is >24h old. Consider running: qmd-update"' >> /home/rustdev/.bashrc && \
    echo '    fi' >> /home/rustdev/.bashrc && \
    echo '}' >> /home/rustdev/.bashrc && \
    echo 'qmd-check-update' >> /home/rustdev/.bashrc
```

**Available Commands:**

| Command | Description |
|---------|-------------|
| `qmd-update` | Re-index all files (after code changes) |
| `qmd-refresh` | Full re-index with embedding regeneration |
| `qmd-status` | Show index health and collection info |
| `qmd-search "query"` | Quick search (uses `qmd query` for best results) |
| `qmd-check-update` | Check if index needs updating (auto-runs on login) |

---

### Phase 8: Documentation Updates

#### Update `deploy_dev_env/README.md`

Add section:

```markdown
## QMD - AI-Optimized Code Indexing

### What is QMD?

QMD (Query Markup Documents) indexes your codebase for efficient AI-assisted development:
- Reduces Claude Code token usage by 60-80%
- Fast semantic and keyword search
- Persistent context across sessions

### First-Time Setup

After deploying the container:

```bash
# SSH into the container
ssh -p 2222 rustdev@localhost

# Initialize QMD (one-time, ~5-10 minutes)
~/init_qmd.sh
```

This will:

1. Index the `/workspace` directory
2. Download GGUF models (~2GB, cached for future use)
3. Generate vector embeddings
4. Configure Claude Code integration

### Daily Usage

**Update index after code changes:**

```bash
qmd-update
```

**Check index status:**

```bash
qmd-status
```

**Full refresh (after major changes):**

```bash
qmd-refresh
```

### How It Works

1. QMD indexes your code with BM25 + vector embeddings
2. Claude Code queries QMD via MCP (Model Context Protocol)
3. QMD returns relevant code snippets instead of scanning all files
4. Result: Faster responses, lower costs, better accuracy

### Troubleshooting

**"qmd: command not found"**

- Rebuild container (Bun and QMD not installed)

**Models downloading slowly**

- First run downloads ~2GB of GGUF models
- Cached in `./volumes/qmd_cache` (persists across rebuilds)

**Outdated search results**

- Run `qmd-update` to re-index

**QMD bypassing Claude Code**

- Check `~/.claude/CLAUDE.md` exists
- Verify MCP config: `cat ~/.claude/settings.json`

```

#### Update Root `README.md`

Add to features section:

```markdown
### AI-Assisted Development

- **Claude Code CLI** - Latest version installed globally
- **QMD (Query Markup Documents)** - AI-optimized code indexing
  - 60-80% reduction in Claude token usage
  - Semantic search with BM25 + vector embeddings
  - Persistent knowledge base across sessions
- **MCP Integration** - Automatic configuration for Claude Code
```

---

## File Checklist

### Files to Create

- [ ] `deploy_dev_env/init_qmd.sh` - First-time initialization script
- [ ] `deploy_dev_env/CLAUDE.md.template` - Global Claude Code rules
- [ ] `QMD_IMPLEMENTATION_GUIDE.md` - This document

### Files to Modify

- [ ] `build_base_dev_image/Dockerfile.base_rust_dev` - Add Bun installation
- [ ] `deploy_dev_env/Dockerfile.rust-dev` - Add QMD, MCP config, scripts, aliases
- [ ] `deploy_dev_env/docker-compose-dev.yml` - Add QMD cache volume
- [ ] `deploy_dev_env/.env` - Add `VOLUME_QMD_CACHE` variable
- [ ] `deploy_dev_env/README.md` - Document QMD usage
- [ ] Root `README.md` - Mention QMD feature
- [ ] `QMD.md` - Fix command syntax errors (em-dashes → double hyphens)

### Update Root CHANGELOG

When complete, add entry:

```markdown
## [v0.7.0] - 2026-02-09

### Added
- **QMD Integration** - AI-optimized code indexing
  - Bun runtime for QMD support (base image)
  - QMD global installation with MCP configuration
  - Automatic CLAUDE.md configuration for global rules
  - Initialization script for first-time setup
  - Shell aliases for maintenance (qmd-update, qmd-status, etc.)
  - Persistent cache volume for GGUF models (~2GB)
  - Index freshness checker on shell login

### Benefits
- 60-80% reduction in Claude Code token usage
- Faster context gathering and search
- Persistent knowledge base across container restarts
```

---

## Post-Deployment Usage

### First-Time Setup (Per Project)

```bash
# 1. SSH into container
ssh -p 2222 rustdev@localhost

# 2. Navigate to workspace with your project
cd /workspace

# 3. Run initialization script
~/init_qmd.sh
```

**What happens:**

- Creates `workspace` collection
- Indexes all `.rs`, `.md`, `.toml`, `.json`, `.yaml`, `.yml`, `.sh` files
- Downloads GGUF models (~2GB, first time only)
- Generates vector embeddings
- Displays index status

**Expected time:**

- Model download: 5-10 minutes (first time only)
- Indexing: 1-2 minutes (depends on project size)
- Embedding: 2-5 minutes (depends on number of files)

### Daily Workflow

**After making code changes:**

```bash
qmd-update
```

**After major refactoring or branch merge:**

```bash
qmd-refresh
```

**Check if index needs updating:**

```bash
qmd-status
```

**Search from command line:**

```bash
qmd search "error handling"
qmd query "how does authentication work"
qmd vsearch "similar to login function"
```

### Using with Claude Code

Once initialized, Claude Code will automatically use QMD when searching your codebase:

```bash
# Start Claude Code
claude code

# Example prompts that will use QMD:
"Where is the database connection configured?"
"Show me all error handling patterns"
"Find the authentication middleware"
"What files deal with user management?"
```

**You'll see QMD in action when:**

- Claude mentions "searching the index"
- Claude cites specific files with high relevance scores
- Responses are faster than usual
- Claude finds relevant code without reading everything

---

## Troubleshooting

### Issue: `qmd: command not found`

**Cause:** Bun or QMD not installed

**Solution:**

```bash
# Check if Bun is installed
bun --version

# If not, rebuild the container with updated Dockerfiles
```

### Issue: Models downloading very slowly

**Cause:** First-time download of ~2GB GGUF models from HuggingFace

**Solution:**

- Wait for download to complete (5-10 minutes)
- Models are cached in `./volumes/qmd_cache`
- Subsequent containers will use cached models

**Check progress:**

```bash
ls -lh ~/.cache/qmd/models/
```

### Issue: Search results are outdated

**Cause:** Index not updated after code changes

**Solution:**

```bash
qmd-update
```

### Issue: QMD not being used by Claude Code

**Symptoms:** Claude still reads entire files instead of searching index

**Debug steps:**

1. **Check MCP configuration:**

```bash
cat ~/.claude/settings.json
# Should contain: {"mcpServers":{"qmd":{"command":"qmd","args":["mcp"]}}}
```

1. **Check CLAUDE.md exists:**

```bash
cat ~/.claude/CLAUDE.md
# Should contain "Rule: Always use QMD before reading files"
```

1. **Verify QMD is working:**

```bash
qmd status
qmd search "test"
```

1. **Test MCP connection:**

```bash
claude code
# Ask: "Use qmd_status to show me the index"
```

### Issue: Index database locked

**Cause:** Multiple QMD processes running

**Solution:**

```bash
# Kill any running QMD processes
pkill -f qmd

# Re-run update
qmd-update
```

### Issue: Out of disk space

**Cause:** QMD models + index consuming too much space

**Check usage:**

```bash
du -sh ~/.cache/qmd/
```

**Solution:**

- Models: ~2GB (required, cannot reduce)
- Index: Usually <100MB per project
- If index is huge, check for duplicate collections:

```bash
qmd collection list
qmd collection remove <duplicate-name>
```

### Issue: Embeddings fail with out-of-memory

**Cause:** Large files or insufficient container memory

**Solution:**

- Increase Docker Desktop memory allocation (Settings → Resources)
- Or exclude large files from indexing:

```bash
qmd collection remove workspace
qmd collection add /workspace --name workspace --mask "**/*.{rs,md,toml,json}" --exclude "**/target/**"
```

---

## Performance Considerations

### Disk Space

- **GGUF models:** ~2GB (one-time download, cached)
- **Index database:** ~10-100MB (depends on project size)
- **Total:** ~2.1GB minimum

### Memory Usage

- **Indexing:** ~500MB-1GB
- **Searching:** ~300MB-500MB
- **Embedding generation:** ~1-2GB (transient)

### Initial Setup Time

- **Model download:** 5-10 minutes (first time only)
- **Indexing 1000 files:** ~1-2 minutes
- **Embedding 1000 files:** ~3-5 minutes

### Daily Maintenance

- **Re-index (qmd-update):** 30 seconds - 2 minutes
- **Full refresh (qmd-refresh):** 2-5 minutes

---

## Advanced Configuration

### Custom File Patterns

Exclude test files and generated code:

```bash
qmd collection remove workspace
qmd collection add /workspace --name workspace \
  --mask "**/*.{rs,md,toml,json}" \
  --exclude "**/target/**,**/tests/**,**/*_generated.rs"
```

### Multiple Collections

Index multiple projects separately:

```bash
qmd collection add /workspace/backend --name backend --mask "**/*.rs"
qmd collection add /workspace/docs --name docs --mask "**/*.md"
qmd embed
```

Search specific collection:

```bash
qmd search "auth" -c backend
```

### Custom Context

Add semantic context to improve search:

```bash
qmd context add qmd://workspace/src/auth "User authentication and authorization modules"
qmd context add qmd://workspace/src/db "Database layer with MongoDB integration"
```

---

## Integration with CI/CD

### Pre-commit Hook

Update QMD index before committing:

```bash
# .git/hooks/pre-commit
#!/bin/bash
if command -v qmd &> /dev/null; then
    echo "Updating QMD index..."
    qmd update
fi
```

### Automated Updates

Add to crontab for periodic updates:

```bash
# Run every 4 hours
0 */4 * * * cd /workspace && /home/rustdev/.bun/bin/qmd update
```

---

## Estimated Implementation Time

- **Phase 1 (Base Image):** 15 minutes (Bun installation)
- **Phase 2 (Deployment Image):** 30 minutes (QMD + MCP config)
- **Phase 3 (Docker Compose):** 10 minutes (volume configuration)
- **Phase 4 (Init Script):** 20 minutes (script creation and testing)
- **Phase 5 (MCP):** Included in Phase 2
- **Phase 6 (CLAUDE.md):** 15 minutes (template creation)
- **Phase 7 (Shell Aliases):** 10 minutes
- **Phase 8 (Documentation):** 30 minutes

**Total:** ~2 hours development + 10 minutes first-time deployment setup

---

## Success Criteria

After implementation, you should be able to:

1. ✅ Run `qmd --version` in container
2. ✅ Run `~/init_qmd.sh` successfully
3. ✅ Run `qmd status` and see indexed files
4. ✅ Run `qmd search "query"` and get results
5. ✅ Start `claude code` and have it use QMD automatically
6. ✅ See "searching the index" in Claude responses
7. ✅ Notice faster Claude responses and lower token usage
8. ✅ Index persists across container restarts
9. ✅ Models don't need to re-download on container rebuild

---

## Next Steps

1. Fix QMD.md syntax errors (em-dashes → double hyphens)
2. Implement Phases 1-8 in order
3. Rebuild base image
4. Deploy dev environment
5. Run `~/init_qmd.sh` on first login
6. Test with Claude Code
7. Monitor token usage reduction
8. Update documentation as needed

---

## References

- **QMD GitHub:** <https://github.com/tobi/qmd>
- **MCP Specification:** <https://modelcontextprotocol.io/>
- **Bun Documentation:** <https://bun.sh/docs>
- **Claude Code MCP Guide:** <https://docs.anthropic.com/claude/docs/model-context-protocol>

---

**End of Implementation Guide**
