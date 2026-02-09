# How to set up QMD for Claude

Here’s the full setup, step by step.

## Step 1: Install qmd

First, install Bun if you don’t have it:

```sh
curl -fsSL https://bun.sh/install | bash
```

Then install qmd:

```sh
bun install -g github:tobi/qmd
```

## Step 2: Index your projects

For each project you work on:

```sh
qmd collection add ./my-project --name myproject
```

This indexes all markdown and JSON files by default. You can customize the file patterns with --mask:

```sh
qmd collection add ./my-project --name myproject --mask "**/*.{ts,tsx,md,json}"
```

Then generate vector embeddings for semantic search:

```sh
qmd embed
```

You can verify everything is indexed:

```sh
qmd status
```

I have 27 collections with 181 indexed documents across all my projects. The index is lightweight and fast.

To keep the index up to date as your code changes:

```sh
qmd update
```

## Step 3: Add qmd as an MCP server in Claude Code

Open your Claude Code MCP config at ~/.claude/settings.json and add qmd:

```json
{
  "mcpServers": {
    "qmd": {
      "command": "qmd",
      "args": [
        "mcp"
      ]
    }
  }
}
```

Restart Claude Code. It now has access to qmd’s search tools natively — search, vsearch, query, get, and multi_get.

## Step 4: The secret sauce — CLAUDE.md

This is the most important step, and the one most people skip.

Claude Code doesn’t know it should use qmd unless you tell it. By default, it will fall back to its usual Read/Glob/Grep behavior.

Add this to your project’s `CLAUDE.md` (or `~/.claude/CLAUDE.md` for a global rule that applies everywhere):

### Rule: always use qmd before reading files

Before reading files or exploring directories, always use qmd to search for information in local projects.

Available tools:

- `qmd search “query”` — fast keyword search (BM25)
- `qmd query “query”` — hybrid search with reranking (best quality)
- `qmd vsearch “query”` — semantic vector search
- `qmd get <file>` — retrieve a specific document

Use qmd search for quick lookups and qmd query for complex questions.
Use Read/Glob only if qmd doesn’t return enough results.

Once this is in place, Claude will always search the index first. It will only fall back to reading full files when it genuinely can’t find what it needs through the index.
