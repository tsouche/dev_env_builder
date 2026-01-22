# Rust Development Environment Builder

**Containerized Rust development environment with MongoDB**

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

**Current Version:** v0.6.5  
**Last Updated:** January 22, 2026

**Key Features (v0.6.5):**

- ✅ OpenSSL environment variables properly persisted for musl builds
- ✅ Docker CLI with proper socket permissions
- ✅ Simplified Alpine testing via `docker cp`
