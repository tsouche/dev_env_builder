################################################################################
# SET Backend Development Environment
# Base: tsouche/rust_dev_container:latest
# 
# The base image already provides:
# - Ubuntu 22.04 LTS
# - Rust stable toolchain (via rustup)
# - Build tools (gcc, cmake, pkg-config, libssl-dev)
# - MongoDB Shell (mongosh)
# - SSH server configured with host keys
# - VS Code extensions auto-install
# - User rustdev (UID 1026, GID 110)
# - /workspace/projects directory
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

# Configure git with user credentials
USER rustdev
RUN if [ -n "${GIT_USER_NAME}" ] && [ -n "${GIT_USER_EMAIL}" ]; then \
        git config --global user.name "${GIT_USER_NAME}" && \
        git config --global user.email "${GIT_USER_EMAIL}"; \
    fi

# Add development service aliases and functions
RUN echo '' >> /home/rustdev/.bashrc && \
    echo '# Custom test aliases for set_backend project' >> /home/rustdev/.bashrc && \
    echo "alias test_unit='cd /workspace/set_backend && cargo test -- --skip set_server_from_ext --test-threads=1'" >> /home/rustdev/.bashrc && \
    echo "alias test_all='cd /workspace/set_backend && cargo test -- --test-threads=1'" >> /home/rustdev/.bashrc && \
    echo "alias test_int='cd /workspace/set_backend && cargo test set_server_from_ext -- --test-threads=1'" >> /home/rustdev/.bashrc
    echo '# Development Service Aliases and Functions' >> /home/rustdev/.bashrc && \
    echo 'alias dev-h="curl http://localhost:5645/health && echo \"\""' >> /home/rustdev/.bashrc && \
    echo 'alias dev-v="curl http://localhost:5645/version && echo \"\""' >> /home/rustdev/.bashrc && \
    echo 'alias dev-s="curl -X POST http://localhost:5645/shutdown && echo \"\""' >> /home/rustdev/.bashrc && \
    echo 'alias dev-c="curl -X POST http://localhost:5645/clear?db && echo \"\""' >> /home/rustdev/.bashrc && \
    echo '' >> /home/rustdev/.bashrc && \
    echo 'dev-l() {' >> /home/rustdev/.bashrc && \
    echo '    local port=${1:-5645}  # Default port 5645, or pass as argument' >> /home/rustdev/.bashrc && \
    echo '    cd /workspace/set_backend' >> /home/rustdev/.bashrc && \
    echo '    ' >> /home/rustdev/.bashrc && \
    echo '    if curl -s http://localhost:$port/health > /dev/null 2>&1; then' >> /home/rustdev/.bashrc && \
    echo '        echo "Shutting down server on port $port..."' >> /home/rustdev/.bashrc && \
    echo '        curl -X POST http://localhost:$port/shutdown 2>/dev/null' >> /home/rustdev/.bashrc && \
    echo '        sleep 2' >> /home/rustdev/.bashrc && \
    echo '    else' >> /home/rustdev/.bashrc && \
    echo '        echo "Server not running on port $port"' >> /home/rustdev/.bashrc && \
    echo '    fi' >> /home/rustdev/.bashrc && \
    echo '    ' >> /home/rustdev/.bashrc && \
    echo '    echo "Starting server..."' >> /home/rustdev/.bashrc && \
    echo '    nohup cargo run > /dev/null 2>&1 &' >> /home/rustdev/.bashrc && \
    echo '    echo "Server started (PID: $!)"' >> /home/rustdev/.bashrc && \
    echo '    ' >> /home/rustdev/.bashrc && \
    echo '    # Wait for server to be ready' >> /home/rustdev/.bashrc && \
    echo '    for i in {1..10}; do' >> /home/rustdev/.bashrc && \
    echo '        if curl -s http://localhost:$port/health > /dev/null 2>&1; then' >> /home/rustdev/.bashrc && \
    echo '            echo "Server is ready on port $port"' >> /home/rustdev/.bashrc && \
    echo '            return 0' >> /home/rustdev/.bashrc && \
    echo '        fi' >> /home/rustdev/.bashrc && \
    echo '        sleep 1' >> /home/rustdev/.bashrc && \
    echo '    done' >> /home/rustdev/.bashrc && \
    echo '    echo "Server failed to start within 10 seconds"' >> /home/rustdev/.bashrc && \
    echo '}' >> /home/rustdev/.bashrc

USER root
WORKDIR /workspace

CMD ["/usr/sbin/sshd", "-D"]
