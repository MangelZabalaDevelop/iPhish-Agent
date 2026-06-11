#!/bin/bash
set -euo pipefail

DOCKER_GID="${DOCKER_GID:-988}"

if getent group docker >/dev/null; then
  current_gid="$(getent group docker | cut -d: -f3)"
  if [ "$current_gid" != "$DOCKER_GID" ]; then
    sudo groupmod -g "$DOCKER_GID" docker || true
  fi
else
  sudo groupadd -g "$DOCKER_GID" docker || true
fi

sudo usermod -aG docker workbench || true
sudo ln -sfn /host-run/docker.sock /var/run/docker.sock
