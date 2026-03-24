# Rust Development Environment Builder

**Containerized Rust development environment with MongoDB**

**Note:** As of v0.6.8, the base image includes ca-certificates and updated certificate store for improved SSL support.

---

## 🚀 Quick Start

### Prerequisites

- Docker Desktop installed and running
- PowerShell (Windows)
- Git
- SSH key generated (`ssh-keygen -t ed25519`)

### Deploy Development Environment

```powershell
cd C:\rustdev\dev_env_builder\deploy_dev_env
.\deploy-dev.ps1
```

### Connect with VS Code

1. Press `Ctrl+Shift+P`
2. Type: **Remote-SSH: Connect to Host**
3. Select: **rust-dev**
4. Open folder: `/workspace`
5. Create projects directory and clone your repository:

   ```bash
   mkdir /workspace/projects
   cd /workspace/projects
   git clone https://github.com/your-username/your-project.git
   cd your-project
   cargo build
   ```

---

## � Full Documentation

- **Deployment Guide**: [deploy_dev_env/README.md](deploy_dev_env/README.md)
- **Changelog**: [deploy_dev_env/CHANGELOG.md](deploy_dev_env/CHANGELOG.md)
- **Base Image Build**: [build_dev_image/README.md](build_dev_image/README.md)

---

## 📄 License

See [LICENSE](LICENSE) file.

---

## 🙏 Acknowledgments

This project was made possible with the assistance of **Claude Sonnet 4.5** by Anthropic. The AI pair programming capabilities helped streamline development, troubleshoot complex Docker configurations, and create robust automation scripts.

---

**Current Version:** v0.7.0  
**Last Updated:** March 24, 2026

**Key Features (v0.7.0):**

- ✅ Native glibc compilation for Ubuntu-based deployments
- ✅ Docker CLI with proper socket permissions
- ✅ Streamlined 3-container architecture (dev, MongoDB, Mongo Express)
- ✅ **Bun runtime** integrated in base image for QMD support
- ✅ **Playwright + Chromium** pre-installed for headless browsing

**AI-Assisted Development:**

- ✅ **Claude Code CLI** - Latest version installed globally
- ✅ **gstack Skills Framework** - 28 slash-command skills for Claude Code
  - Virtual engineering team: CEO, Designer, Eng Manager, QA, Release Engineer
  - Key skills: /office-hours, /review, /qa, /browse, /ship, /investigate
  - Global install in persistent volume — works across all projects
- ✅ **QMD (Query Markup Documents)** - AI-optimized code indexing
  - 60-80% reduction in Claude token usage
  - Semantic search with BM25 + vector embeddings
  - Persistent knowledge base across sessions
  - Smart auto-detection of projects in `~/` and `/workspace`
  - Location-independent indexing (works anywhere you clone)
  - 5-10x faster compilation with container-local storage
- ✅ **MCP Integration** - Automatic configuration for Claude Code
- ✅ **Persistent home volume** - Named volume for optimal performance
