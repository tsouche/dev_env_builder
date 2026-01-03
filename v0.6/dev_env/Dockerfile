################################################################################
# SET Backend Development Environment
# Base: tsouche/rust_dev_container:latest (v0.6.0+)
# 
# The base image already provides:
# - Ubuntu 22.04 LTS
# - Rust stable toolchain (via rustup)
# - Build tools (gcc, cmake, pkg-config, libssl-dev)
# - MongoDB Shell (mongosh)
# - GitHub CLI (gh)
# - SSH server configured with host keys
# - VS Code extensions auto-install
# - User rustdev (UID 1026, GID 110)
# - /workspace directory
# - Shell aliases (ll, la, grep colors, cargo shortcuts)
# - Git aliases (st, co, br, ci, lg)
# - Development service functions (dev-h, dev-v, dev-s, dev-c, dev-l)
################################################################################
FROM tsouche/rust_dev_container:latest

# Git configuration arguments from .env
ARG GIT_USER_NAME
ARG GIT_USER_EMAIL

# Override with local user's SSH public key
# This allows each machine/user to have their own SSH access
USER root
COPY authorized_keys /home/rustdev/.ssh/authorized_keys
RUN chown 1026:110 /home/rustdev/.ssh/authorized_keys && \
    chmod 600 /home/rustdev/.ssh/authorized_keys

# Configure git with user credentials (override base image if needed)
USER rustdev
RUN if [ -n "${GIT_USER_NAME}" ] && [ -n "${GIT_USER_EMAIL}" ]; then \
        git config --global user.name "${GIT_USER_NAME}" && \
        git config --global user.email "${GIT_USER_EMAIL}"; \
    fi

# Note: Development aliases, shell shortcuts, and git aliases are now
# included in the base image (tsouche/rust_dev_container:latest)
# No need to redefine them here.

USER root
WORKDIR /workspace

CMD ["/usr/sbin/sshd", "-D"]
