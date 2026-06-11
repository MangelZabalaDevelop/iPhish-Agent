#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"
PROJECT_DIR="${PROJECT_DIR:-/project}"
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/logs/iphish-agent.log}"
STATE_DIR="${STATE_DIR:-$PROJECT_DIR/data/hermes}"
CONTAINER_NAME="${HERMES_CONTAINER_NAME:-xpectra-iphish-agent}"
IMAGE="${HERMES_IMAGE:-nousresearch/hermes-agent:latest}"
MODEL="${HERMES_MODEL:-Qwen3.6-35B-A3B-NVFP4}"
BASE_URL="${HERMES_BASE_URL:-http://192.168.0.8:9494}"
API_KEY="${HERMES_API_KEY:-local-external-vllm-placeholder}"
API_SERVER_KEY="${HERMES_API_SERVER_KEY:-local-hermes-agent}"
DOCKER_HOST="${DOCKER_HOST:-unix:///host-run/docker.sock}"
export DOCKER_HOST

normalize_base_url() {
  local value="$1"
  value="${value%/}"
  if [[ "$value" != */v1 ]]; then
    value="$value/v1"
  fi
  printf '%s\n' "$value"
}

project_host_dir() {
  if [[ -n "${PROJECT_HOST_DIR:-}" ]]; then
    printf '%s\n' "$PROJECT_HOST_DIR"
    return
  fi
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/project"}}{{.Source}}{{end}}{{end}}' "$HOSTNAME"
}

prepare_state() {
  local base_url
  base_url="$(normalize_base_url "$BASE_URL")"
  mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"
  chmod 700 "$STATE_DIR" 2>/dev/null || true

  cat >"$STATE_DIR/.env" <<EOF
OPENAI_BASE_URL=$base_url
OPENAI_API_KEY=$API_KEY
HERMES_MODEL=$MODEL
HERMES_BASE_URL=$base_url
HERMES_API_KEY=$API_KEY
EOF
  chmod 600 "$STATE_DIR/.env" 2>/dev/null || true

  cat >"$STATE_DIR/config.yaml" <<EOF
model:
  provider: custom
  default: "$MODEL"
  model: "$MODEL"
  base_url: "$base_url"
  api_key: "$API_KEY"
  api_mode: chat_completions
EOF
}

start_container() {
  prepare_state
  local host_project
  host_project="$(project_host_dir)"
  {
    printf '=== starting Hermes Iphish Agent at %s ===\n' "$(date -Is)"
    printf 'image=%s container=%s model=%s base_url=%s\n' "$IMAGE" "$CONTAINER_NAME" "$MODEL" "$(normalize_base_url "$BASE_URL")"
  } >"$LOG_FILE"

  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker rm -f "$CONTAINER_NAME" >>"$LOG_FILE" 2>&1 || true
  fi

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network "container:$HOSTNAME" \
    -e HERMES_DASHBOARD=1 \
    -e HERMES_DASHBOARD_HOST=0.0.0.0 \
    -e HERMES_DASHBOARD_PORT=9119 \
    -e HERMES_DASHBOARD_INSECURE=1 \
    -e API_SERVER_ENABLED=true \
    -e API_SERVER_HOST=0.0.0.0 \
    -e API_SERVER_KEY="$API_SERVER_KEY" \
    -e OPENAI_BASE_URL="$(normalize_base_url "$BASE_URL")" \
    -e OPENAI_API_KEY="$API_KEY" \
    -e HERMES_MODEL="$MODEL" \
    -e HERMES_BASE_URL="$(normalize_base_url "$BASE_URL")" \
    -e HERMES_API_KEY="$API_KEY" \
    -v "$host_project/data/hermes:/opt/data" \
    "$IMAGE" gateway run >>"$LOG_FILE" 2>&1

  nohup docker logs --timestamps --follow "$CONTAINER_NAME" >>"$LOG_FILE" 2>&1 </dev/null &
}

health() {
  docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -qx running
  curl -fsS --max-time 5 http://127.0.0.1:8642/health >/dev/null
}

case "$ACTION" in
  start)
    start_container
    ;;
  stop)
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    ;;
  restart)
    "$0" stop
    "$0" start
    ;;
  health)
    health
    ;;
  status)
    docker ps -a --filter "name=$CONTAINER_NAME" --format 'table {{.Names}}\t{{.Status}}'
    ;;
  logs)
    docker logs --tail "${2:-120}" "$CONTAINER_NAME"
    ;;
  *)
    printf 'Usage: %s {start|stop|restart|health|status|logs}\n' "$0" >&2
    exit 2
    ;;
esac
