#!/bin/bash
################################################################################
# Container Entrypoint
#
# Different Docker backends expose the bind-mounted /var/run/docker.sock
# under different host GIDs — e.g. Rancher Desktop's VM matches this image's
# "docker" group (999), but Docker Desktop's Linux VM owns the socket as
# root:root instead. Force it into the "docker" group at every container
# start so rustdev (already a member, see Dockerfile) can use it regardless
# of which backend is running on the host.
################################################################################
set -e

if [ -S /var/run/docker.sock ]; then
    chgrp docker /var/run/docker.sock 2>/dev/null || true
    chmod g+rw /var/run/docker.sock 2>/dev/null || true
fi

exec "$@"
