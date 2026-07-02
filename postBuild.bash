#!/bin/bash
set -euo pipefail

DOCKER_GIDS="${DOCKER_GIDS:-988 998 999 1001}"

as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

ensure_group_for_gid() {
  local gid="$1"
  local group_name

  if getent group "$gid" >/dev/null; then
    group_name="$(getent group "$gid" | cut -d: -f1)"
  elif [ "$gid" = "988" ] && ! getent group docker >/dev/null; then
    group_name="docker"
    as_root groupadd -g "$gid" "$group_name" || true
  else
    group_name="docker-$gid"
    as_root groupadd -g "$gid" "$group_name" || true
  fi

  if getent group "$gid" >/dev/null; then
    group_name="$(getent group "$gid" | cut -d: -f1)"
    as_root usermod -aG "$group_name" workbench || true
  fi
}

for gid in $DOCKER_GIDS; do
  ensure_group_for_gid "$gid"
done

as_root mkdir -p /host-run
as_root ln -sfn /host-run/docker.sock /var/run/docker.sock
