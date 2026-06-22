#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-status}"
if [[ -z "${PROJECT_DIR:-}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CANDIDATE_PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
  if [[ -f "$CANDIDATE_PROJECT_DIR/.project/spec.yaml" ]]; then
    PROJECT_DIR="$CANDIDATE_PROJECT_DIR"
  else
    PROJECT_DIR="/project"
  fi
fi
if [[ -f "$PROJECT_DIR/variables.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "$PROJECT_DIR/variables.env"
  set +a
fi
LOG_FILE="${LOG_FILE:-$PROJECT_DIR/logs/iphish-agent.log}"
TTYD_LOG_FILE="${TTYD_LOG_FILE:-$PROJECT_DIR/logs/iphish-agent-tui.log}"
TTYD_PID_FILE="${TTYD_PID_FILE:-/tmp/iphish-agent-ttyd.pid}"
HERMES_DASHBOARD_PORT="${HERMES_DASHBOARD_PORT:-9120}"
GOPHISH_PROXY_LOG_FILE="${GOPHISH_PROXY_LOG_FILE:-$PROJECT_DIR/logs/gophish-workbench-proxy.log}"
GOPHISH_PROXY_PID_FILE="${GOPHISH_PROXY_PID_FILE:-/tmp/iphish-agent-gophish-proxy.pid}"
STATE_DIR="${STATE_DIR:-$PROJECT_DIR/data/hermes}"
GOPHISH_STATE_DIR="${GOPHISH_STATE_DIR:-$PROJECT_DIR/data/gophish}"
CONTAINER_NAME="${HERMES_CONTAINER_NAME:-xpectra-iphish-agent}"
IMAGE="${HERMES_IMAGE:-nousresearch/hermes-agent:latest}"
GOPHISH_CONTAINER_NAME="${GOPHISH_CONTAINER_NAME:-xpectra-iphish-agent-gophish}"
GOPHISH_IMAGE="${GOPHISH_IMAGE:-xpectra/gophish-arm64:v0.12.1}"
GOPHISH_PROXY_CONTAINER_NAME="${GOPHISH_PROXY_CONTAINER_NAME:-xpectra-iphish-agent-gophish-proxy}"
MAILPIT_CONTAINER_NAME="${MAILPIT_CONTAINER_NAME:-xpectra-iphish-agent-mailpit}"
MAILPIT_IMAGE="${MAILPIT_IMAGE:-axllent/mailpit:latest}"
COMFYUI_CONTAINER_NAME="${COMFYUI_CONTAINER_NAME:-xpectra-iphish-agent-comfyui}"
COMFYUI_IMAGE="${COMFYUI_IMAGE:-xpectra/comfyui-workbench:latest}"
MODEL="${HERMES_MODEL:-Qwen3.6-35B-A3B-NVFP4}"
BASE_URL="${HERMES_BASE_URL:-http://192.168.0.8:9494}"
API_KEY="${HERMES_API_KEY:-local-external-vllm-placeholder}"
CUSTOM_PROVIDER_NAME="${HERMES_CUSTOM_PROVIDER_NAME:-local-vllm}"
MAX_TOKENS="${HERMES_MAX_TOKENS:-32768}"
API_SERVER_KEY="${HERMES_API_SERVER_KEY:-local-hermes-agent}"
TTYD_PORT="${HERMES_TUI_PORT:-9119}"
GOPHISH_API_KEY="${GOPHISH_API_KEY:-local-gophish-api-key-change-me}"
GOPHISH_ADMIN_PASSWORD_HASH="${GOPHISH_ADMIN_PASSWORD_HASH:-\$2a\$10\$I/Wbkx1K48wsS8TUg.BMV.iTrQEiAYcSkHXmrWfUk4OrMeKabsU26}"
GOPHISH_ADMIN_URL="${GOPHISH_ADMIN_URL:-http://127.0.0.1:3333}"
GOPHISH_API_URL="${GOPHISH_API_URL:-http://127.0.0.1:3333/api}"
WORKBENCH_APP_BASE_URL="${WORKBENCH_APP_BASE_URL:-http://localhost:10000/projects/iphish-agent/applications}"
GOPHISH_PUBLIC_URL="${GOPHISH_PUBLIC_URL:-${WORKBENCH_APP_BASE_URL}/GoPhish/landing}"
GOPHISH_ASSET_PUBLIC_URL="${GOPHISH_ASSET_PUBLIC_URL:-${WORKBENCH_APP_BASE_URL}/GoPhish/assets}"
GOPHISH_ASSET_ROOT="${GOPHISH_ASSET_ROOT:-$STATE_DIR/generated-images}"
GOPHISH_PROXY_PORT="${GOPHISH_PROXY_PORT:-3334}"
MAILPIT_WEBROOT="${MAILPIT_WEBROOT:-/projects/iphish-agent/applications/Mailpit}"
MAILPIT_WEB_URL="${MAILPIT_WEB_URL:-http://127.0.0.1:8025${MAILPIT_WEBROOT}}"
MAILPIT_API_URL="${MAILPIT_API_URL:-${MAILPIT_WEB_URL}/api/v1}"
MAILPIT_USER_URL="${MAILPIT_USER_URL:-${WORKBENCH_APP_BASE_URL}/Mailpit}"
MAILPIT_SMTP_HOST="${MAILPIT_SMTP_HOST:-127.0.0.1}"
MAILPIT_SMTP_PORT="${MAILPIT_SMTP_PORT:-1025}"
GOPHISH_REVIEW_SMTP_NAME="${GOPHISH_REVIEW_SMTP_NAME:-Mailpit Review SMTP}"
COMFYUI_WEBROOT="${COMFYUI_WEBROOT:-/projects/iphish-agent/applications/ComfyUI}"
COMFYUI_WEB_URL="${COMFYUI_WEB_URL:-http://127.0.0.1:8188${COMFYUI_WEBROOT}}"
COMFYUI_API_URL="${COMFYUI_API_URL:-$COMFYUI_WEB_URL}"
COMFYUI_DIRECT_URL="${COMFYUI_DIRECT_URL:-http://127.0.0.1:8188}"
PROJECT_CONTAINER_NAME="${PROJECT_CONTAINER_NAME:-project-iphish-agent}"
if [[ -z "${DOCKER_HOST:-}" ]]; then
  if [[ -S /host-run/docker.sock ]]; then
    DOCKER_HOST="unix:///host-run/docker.sock"
  else
    DOCKER_HOST="unix:///var/run/docker.sock"
  fi
fi
export DOCKER_HOST

normalize_base_url() {
  local value="$1"
  value="${value%/}"
  if [[ "$value" != */v1 ]]; then
    value="$value/v1"
  fi
  printf '%s\n' "$value"
}

base_url_is_reachable() {
  local value="$1"
  curl -fsS --max-time 3 "${value%/}/models" >/dev/null 2>&1
}

resolve_llm_base_url() {
  local configured
  configured="$(normalize_base_url "$1")"
  if base_url_is_reachable "$configured"; then
    printf '%s\n' "$configured"
    return
  fi

  local candidate
  for candidate in ${HERMES_BASE_URL_CANDIDATES:-} \
    http://10.100.88.2:9494 \
    http://10.100.89.2:9494 \
    http://127.0.0.1:9494 \
    http://192.168.0.8:9494; do
    candidate="$(normalize_base_url "$candidate")"
    if base_url_is_reachable "$candidate"; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  printf '%s\n' "$configured"
}

project_host_dir() {
  if [[ -n "${PROJECT_HOST_DIR:-}" ]]; then
    printf '%s\n' "$PROJECT_HOST_DIR"
    return
  fi
  if [[ "$PROJECT_DIR" != "/project" && -f "$PROJECT_DIR/.project/spec.yaml" ]]; then
    printf '%s\n' "$PROJECT_DIR"
    return
  fi
  local target="$HOSTNAME"
  if docker container inspect "$PROJECT_CONTAINER_NAME" >/dev/null 2>&1; then
    target="$PROJECT_CONTAINER_NAME"
  fi
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/project"}}{{.Source}}{{end}}{{end}}' "$target"
}

network_container() {
  if docker container inspect -f '{{.State.Status}}' "$PROJECT_CONTAINER_NAME" 2>/dev/null | grep -qx running; then
    printf '%s\n' "$PROJECT_CONTAINER_NAME"
  elif docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -qx running; then
    printf '%s\n' "$CONTAINER_NAME"
  elif docker inspect "$HOSTNAME" >/dev/null 2>&1; then
    printf '%s\n' "$HOSTNAME"
  elif docker inspect -f '{{.State.Status}}' workbench-proxy 2>/dev/null | grep -qx running; then
    printf '%s\n' workbench-proxy
  else
    printf '%s\n' "$HOSTNAME"
  fi
}

service_curl() {
  local url="$1"
  shift || true
  if curl -fsS --max-time 5 "$@" "$url" >/dev/null 2>&1; then
    return 0
  fi

  local container
  for container in "$CONTAINER_NAME" "$COMFYUI_CONTAINER_NAME" "$MAILPIT_CONTAINER_NAME" "$GOPHISH_PROXY_CONTAINER_NAME"; do
    if ! docker inspect -f '{{.State.Status}}' "$container" 2>/dev/null | grep -qx running; then
      continue
    fi
    if docker exec "$container" sh -lc 'command -v curl >/dev/null 2>&1' >/dev/null 2>&1; then
      docker exec "$container" curl -fsS --max-time 5 "$@" "$url" >/dev/null
      return $?
    fi
    if [[ "$#" -eq 0 ]] && docker exec "$container" sh -lc 'command -v wget >/dev/null 2>&1' >/dev/null 2>&1; then
      docker exec "$container" wget -q -T 5 -O /dev/null "$url"
      return $?
    fi
  done
  return 1
}

repair_state_permissions() {
  local host_project="$1"
  if mkdir -p "$STATE_DIR" && touch "$STATE_DIR/.write-test" 2>/dev/null; then
    rm -f "$STATE_DIR/.write-test"
    return
  fi
  docker run --rm \
    --entrypoint sh \
    -v "$host_project/data/hermes:/target" \
    "$IMAGE" \
    -lc "chown -R $(id -u):$(id -g) /target && chmod -R u+rwX /target" >/dev/null
}

prepare_state() {
  local host_project="$1"
  local base_url
  base_url="${2:-}"
  if [[ -z "$base_url" ]]; then
    base_url="$(resolve_llm_base_url "$BASE_URL")"
  fi
  mkdir -p "$STATE_DIR" "$(dirname "$LOG_FILE")"
  repair_state_permissions "$host_project"
  chmod 700 "$STATE_DIR" 2>/dev/null || true
  if [ -d "$PROJECT_DIR/skills" ]; then
    rm -rf "$STATE_DIR/skills"
    mkdir -p "$STATE_DIR"
    cp -R "$PROJECT_DIR/skills" "$STATE_DIR/"
    chmod -R u+rwX,go+rX "$STATE_DIR/skills" 2>/dev/null || true
  fi

  cat >"$STATE_DIR/.env" <<EOF
OPENAI_BASE_URL=$base_url
OPENAI_API_KEY=$API_KEY
HERMES_BASE_URL=$base_url
HERMES_API_KEY=$API_KEY
HERMES_TUI_PROVIDER=$CUSTOM_PROVIDER_NAME
HERMES_INFERENCE_PROVIDER=$CUSTOM_PROVIDER_NAME
GOPHISH_ADMIN_URL=$GOPHISH_ADMIN_URL
GOPHISH_API_URL=$GOPHISH_API_URL
GOPHISH_PUBLIC_URL=$GOPHISH_PUBLIC_URL
WORKBENCH_APP_BASE_URL=$WORKBENCH_APP_BASE_URL
GOPHISH_API_KEY=$GOPHISH_API_KEY
MAILPIT_WEB_URL=$MAILPIT_WEB_URL
MAILPIT_API_URL=$MAILPIT_API_URL
MAILPIT_USER_URL=$MAILPIT_USER_URL
MAILPIT_WEBROOT=$MAILPIT_WEBROOT
MAILPIT_SMTP_HOST=$MAILPIT_SMTP_HOST
MAILPIT_SMTP_PORT=$MAILPIT_SMTP_PORT
GOPHISH_REVIEW_SMTP_NAME=$GOPHISH_REVIEW_SMTP_NAME
COMFYUI_WEB_URL=$COMFYUI_WEB_URL
COMFYUI_API_URL=$COMFYUI_API_URL
COMFYUI_DIRECT_URL=$COMFYUI_DIRECT_URL
GOPHISH_ASSET_PUBLIC_URL=$GOPHISH_ASSET_PUBLIC_URL
EOF
  chmod 600 "$STATE_DIR/.env" 2>/dev/null || true
  mkdir -p "$STATE_DIR/.local/bin"
  cat >"$STATE_DIR/.local/bin/iphishctl" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
import urllib.parse
import urllib.error
import urllib.request


def usage():
    print(
        "Usage:\n"
        "  iphishctl gophish METHOD /path [json-file|-]\n"
        "  iphishctl gophish-list campaigns|groups|pages|templates|smtp [limit]\n"
        "  iphishctl mailpit info|messages|message ID\n"
        "  iphishctl comfy status|queue|prompt json-file|-\n",
        "  iphishctl asset-url IMAGE_PATH_OR_FILENAME\n",
        "  iphishctl review CAMPAIGN_ID [--json]\n",
        file=sys.stderr,
    )
    return 2


def read_payload(arg):
    if not arg:
        return None
    raw = sys.stdin.read() if arg == "-" else open(arg, "r", encoding="utf-8").read()
    return json.loads(raw)


def request(method, url, payload=None, headers=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(url, data=data, method=method.upper())
    req.add_header("Accept", "application/json")
    if payload is not None:
        req.add_header("Content-Type", "application/json")
    for key, value in (headers or {}).items():
        req.add_header(key, value)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read()
            if not body:
                return None
            ctype = resp.headers.get("Content-Type", "")
            if "json" in ctype:
                return json.loads(body.decode())
            return body.decode()
    except urllib.error.HTTPError as exc:
        body = exc.read().decode(errors="replace")
        print(json.dumps({"error": exc.code, "body": body}, indent=2), file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as exc:
        print(json.dumps({"error": "connection_failed", "reason": str(exc.reason)}, indent=2), file=sys.stderr)
        sys.exit(1)


def print_json(value):
    try:
        print(json.dumps(value, indent=2, ensure_ascii=False))
    except BrokenPipeError:
        sys.exit(0)


def summarize_campaign(item):
    return {
        "id": item.get("id"),
        "name": item.get("name"),
        "status": item.get("status"),
        "url": item.get("url"),
        "created_date": item.get("created_date"),
        "template": (item.get("template") or {}).get("name"),
        "page": (item.get("page") or {}).get("name"),
        "smtp": (item.get("smtp") or {}).get("name"),
        "groups": [g.get("name") for g in item.get("groups", []) if isinstance(g, dict)],
    }


def summarize_named(item):
    return {
        "id": item.get("id"),
        "name": item.get("name"),
        "modified_date": item.get("modified_date"),
    }


def gophish_list(args):
    if not args or args[0] not in {"campaigns", "groups", "pages", "templates", "smtp"}:
        return usage()
    resource = args[0]
    limit = 10
    if len(args) > 1:
        try:
            limit = max(1, min(50, int(args[1])))
        except ValueError:
            return usage()
    base = os.environ.get("GOPHISH_API_URL", "http://127.0.0.1:3333/api").rstrip("/")
    key = os.environ.get("GOPHISH_API_KEY", "local-gophish-api-key-change-me")
    endpoint = "campaigns" if resource == "campaigns" else resource
    items = request("GET", f"{base}/{endpoint}/", headers={"Authorization": f"Bearer {key}"})
    if not isinstance(items, list):
        print_json(items)
        return 0
    items = items[:limit]
    if resource == "campaigns":
        print_json([summarize_campaign(item) for item in items])
    else:
        print_json([summarize_named(item) for item in items])
    return 0


def gophish(args):
    if len(args) < 2:
        return usage()
    method, path = args[0].upper(), args[1]
    payload = read_payload(args[2]) if len(args) > 2 else None
    base = os.environ.get("GOPHISH_API_URL", "http://127.0.0.1:3333/api").rstrip("/")
    key = os.environ.get("GOPHISH_API_KEY", "local-gophish-api-key-change-me")
    if not path.startswith("/"):
        path = "/" + path
    if payload is not None and method in {"POST", "PUT"} and path.startswith("/campaigns"):
        if not payload.get("url"):
            payload["url"] = os.environ.get(
                "GOPHISH_PUBLIC_URL",
                "http://localhost:10000/projects/iphish-agent/applications/GoPhish/landing",
            )
    print_json(request(method, base + path, payload, {"Authorization": f"Bearer {key}"}))
    return 0


def mailpit(args):
    if not args:
        return usage()
    base = os.environ.get("MAILPIT_API_URL", "http://127.0.0.1:8025/projects/iphish-agent/applications/Mailpit/api/v1").rstrip("/")
    action = args[0]
    if action == "info":
        print_json(request("GET", base + "/info"))
    elif action == "messages":
        print_json(request("GET", base + "/messages"))
    elif action == "message" and len(args) == 2:
        print_json(request("GET", base + "/message/" + args[1]))
    else:
        return usage()
    return 0


def comfy(args):
    if not args:
        return usage()
    base = os.environ.get("COMFYUI_DIRECT_URL", "http://127.0.0.1:8188").rstrip("/")
    action = args[0]
    if action == "status":
        print_json(request("GET", base + "/system_stats"))
    elif action == "queue":
        print_json(request("GET", base + "/queue"))
    elif action == "prompt" and len(args) == 2:
        print_json(request("POST", base + "/prompt", read_payload(args[1])))
    else:
        return usage()
    return 0


def asset_url(args):
    if len(args) != 1:
        return usage()
    value = args[0]
    name = os.path.basename(value)
    if not name:
        return usage()
    public_base = os.environ.get(
        "GOPHISH_ASSET_PUBLIC_URL",
        "http://localhost:10000/projects/iphish-agent/applications/GoPhish/assets",
    ).rstrip("/")
    print(public_base + "/" + urllib.parse.quote(name))
    return 0


def review(args):
    if len(args) not in {1, 2}:
        return usage()
    campaign_id = args[0]
    as_json = len(args) == 2 and args[1] == "--json"
    if len(args) == 2 and not as_json:
        return usage()
    gophish_base = os.environ.get("GOPHISH_API_URL", "http://127.0.0.1:3333/api").rstrip("/")
    gophish_key = os.environ.get("GOPHISH_API_KEY", "local-gophish-api-key-change-me")
    mailpit_api = os.environ.get("MAILPIT_API_URL", "http://127.0.0.1:8025/projects/iphish-agent/applications/Mailpit/api/v1").rstrip("/")
    mailpit_user = os.environ.get("MAILPIT_USER_URL", "http://localhost:10000/projects/iphish-agent/applications/Mailpit").rstrip("/")
    public_url = os.environ.get("GOPHISH_PUBLIC_URL", "http://localhost:10000/projects/iphish-agent/applications/GoPhish/landing").rstrip("/")

    campaign = request("GET", f"{gophish_base}/campaigns/{campaign_id}/results", headers={"Authorization": f"Bearer {gophish_key}"})
    messages = request("GET", f"{mailpit_api}/messages")
    message_items = messages.get("messages", []) if isinstance(messages, dict) else messages or []
    latest_message = message_items[0] if message_items else {}

    landing_links = []
    for result in campaign.get("results", []):
        rid = result.get("id")
        if rid:
            landing_links.append(
                {
                    "recipient": result.get("email"),
                    "status": result.get("status"),
                    "rid": rid,
                    "landing_url": f"{public_url}?rid={rid}",
                }
            )

    payload = {
        "campaign_id": campaign.get("id"),
        "campaign_name": campaign.get("name"),
        "campaign_status": campaign.get("status"),
        "mailpit_inbox_url": mailpit_user + "/",
        "latest_mailpit_message_url": (mailpit_user + "/view/" + latest_message.get("ID")) if latest_message.get("ID") else None,
        "latest_mailpit_subject": latest_message.get("Subject"),
        "landing_links": landing_links,
        "approval_note": "Review the Mailpit message and landing URL. Use real SMTP only after explicit user approval.",
        "routing_note": "Open LANDING_URL_N exactly as printed. If the Workbench URL returns 404, start the GoPhish Workbench app button once, then reopen the same URL. Do not use /GoPhish?rid=..., /GoPhish/landing without rid, or internal 127.0.0.1 URLs for user review.",
    }
    if as_json:
        print_json(payload)
        return 0

    print(f"CAMPAIGN_ID={payload['campaign_id']}")
    print(f"CAMPAIGN_NAME={payload['campaign_name']}")
    print(f"CAMPAIGN_STATUS={payload['campaign_status']}")
    print(f"MAILPIT_INBOX_URL={payload['mailpit_inbox_url']}")
    if payload["latest_mailpit_message_url"]:
        print(f"MAILPIT_MESSAGE_URL={payload['latest_mailpit_message_url']}")
    if payload["latest_mailpit_subject"]:
        print(f"MAILPIT_MESSAGE_SUBJECT={payload['latest_mailpit_subject']}")
    for index, item in enumerate(landing_links, start=1):
        print(f"LANDING_URL_{index}={item['landing_url']}")
        print(f"LANDING_RECIPIENT_{index}={item['recipient']}")
        print(f"LANDING_STATUS_{index}={item['status']}")
    print("APPROVAL_NOTE=Review these raw URLs. Use real SMTP only after explicit user approval.")
    print(f"ROUTING_NOTE={payload['routing_note']}")
    return 0


def main():
    if len(sys.argv) < 2:
        return usage()
    service, args = sys.argv[1], sys.argv[2:]
    if service == "gophish":
        return gophish(args)
    if service == "gophish-list":
        return gophish_list(args)
    if service == "mailpit":
        return mailpit(args)
    if service == "comfy":
        return comfy(args)
    if service == "asset-url":
        return asset_url(args)
    if service == "review":
        return review(args)
    return usage()


if __name__ == "__main__":
    raise SystemExit(main())
PY
  chmod 700 "$STATE_DIR/.local/bin/iphishctl"

  cat >"$STATE_DIR/config.yaml" <<EOF
model:
  provider: $CUSTOM_PROVIDER_NAME
  default: "$MODEL"
  model: "$MODEL"
  base_url: "$base_url"
  api_key: "$API_KEY"
  api_mode: chat_completions
  max_tokens: $MAX_TOKENS
providers:
  $CUSTOM_PROVIDER_NAME:
    api: "$base_url"
    name: "$CUSTOM_PROVIDER_NAME"
    api_key: "$API_KEY"
    default_model: "$MODEL"
    transport: chat_completions
approvals:
  mode: "off"
  timeout: 60
  cron_mode: deny
  mcp_reload_confirm: true
  destructive_slash_confirm: true
_config_version: 29
EOF

  cat >"$STATE_DIR/SOUL.md" <<EOF
# Iphish Agent

You are a clean Hermes Agent instance running inside NVIDIA AI Workbench.
Use the configured local OpenAI-compatible vLLM endpoint.

GoPhish is available locally for authorized security-awareness lab work:

- Admin/API base: $GOPHISH_ADMIN_URL
- API URL: $GOPHISH_API_URL
- Public landing base: $GOPHISH_PUBLIC_URL
- Generated image asset base: $GOPHISH_ASSET_PUBLIC_URL
- API key: read GOPHISH_API_KEY from the environment; do not print it unless explicitly asked.

Mailpit is available locally for review-only email previews:

- Internal Web/API base: $MAILPIT_WEB_URL
- User-facing Web UI: $MAILPIT_USER_URL/
- API: $MAILPIT_API_URL
- SMTP: $MAILPIT_SMTP_HOST:$MAILPIT_SMTP_PORT
- GoPhish review SMTP profile: $GOPHISH_REVIEW_SMTP_NAME

ComfyUI is available locally for safe review images:

- Web UI: $COMFYUI_WEB_URL
- API: $COMFYUI_API_URL
- Model workflow: Z-Image-Turbo

Use ComfyUI only when the user explicitly asks to generate images, visuals,
graphics, hero images, illustrations, or image assets for the campaign. If the
user only asks for design, logos, colors, brand, visual style, or content as
reference, use those cues in HTML/CSS and copy; do not generate images unless
the prompt specifically requests them.

When you generate images with comfyui-z-image, use iphishctl asset-url
IMAGE_PATH to turn each generated PNG path into a Workbench URL. Embed those PNG
URLs in GoPhish HTML with <img src="...">. Do not replace generated images with
procedural SVGs, emoji art, or base64 placeholder drawings.

Use iphishctl for routine GoPhish, Mailpit, and ComfyUI service access.
Do not generate one-off API client scripts for normal campaign work.
After creating a review campaign, run iphishctl review <campaign_id> and report
those exact user-facing URLs. Do not report internal 127.0.0.1 service URLs to
the user unless explicitly debugging internals.

Known-good Workbench routing:
- GoPhish admin is served by the GoPhish app button.
- GoPhish campaign landing pages are served through $GOPHISH_PUBLIC_URL?rid=...
- Workbench exposes /applications/GoPhish only after the GoPhish app has been
  started at least once from Workbench.
- Never create a separate Python landing server for review links.
- Never diagnose GoPhish auth middleware from a user-facing review link issue.
- If a link is unclear, run iphishctl review <campaign_id> and show the raw
  MAILPIT_* and LANDING_* lines exactly as printed.

Only use GoPhish for authorized internal awareness simulations. This Workbench
lab disables technical command approval popups. Keep the flow practical: build
the Mailpit review campaign first, then wait for explicit user approval before
real SMTP delivery.
EOF
}

wait_for_mailpit() {
  local i
  for i in $(seq 1 60); do
    if service_curl "$MAILPIT_WEB_URL/api/v1/info"; then
      return 0
    fi
    sleep 1
  done
  return 1
}

start_mailpit() {
  local network_target
  network_target="$(network_container)"
  {
    printf '=== starting Mailpit at %s ===\n' "$(date -Is)"
    printf 'image=%s container=%s web=%s smtp=%s:%s\n' "$MAILPIT_IMAGE" "$MAILPIT_CONTAINER_NAME" "$MAILPIT_WEB_URL" "$MAILPIT_SMTP_HOST" "$MAILPIT_SMTP_PORT"
  } >>"$LOG_FILE"
  if docker inspect "$MAILPIT_CONTAINER_NAME" >/dev/null 2>&1; then
    docker rm -f "$MAILPIT_CONTAINER_NAME" >>"$LOG_FILE" 2>&1 || true
  fi
  docker run -d \
    --name "$MAILPIT_CONTAINER_NAME" \
    --restart unless-stopped \
    --no-healthcheck \
    --network "container:$network_target" \
    "$MAILPIT_IMAGE" \
    --webroot "$MAILPIT_WEBROOT" >>"$LOG_FILE" 2>&1
  wait_for_mailpit
}

wait_for_comfyui() {
  local i
  for i in $(seq 1 180); do
    if service_curl "$COMFYUI_DIRECT_URL/system_stats"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

patch_comfyui_autoload() {
  local i
  for i in $(seq 1 60); do
    if docker exec "$COMFYUI_CONTAINER_NAME" test -f /usr/local/lib/python3.12/dist-packages/comfyui_frontend_package/static/index.html >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
  docker exec -i "$COMFYUI_CONTAINER_NAME" python3 - <<'PY'
import json
from pathlib import Path

index = Path("/usr/local/lib/python3.12/dist-packages/comfyui_frontend_package/static/index.html")
marker = "iphish-z-image-turbo-autoload"
html = index.read_text()
if marker not in html:
    script = f"""<script id="{marker}">
;(function () {{
  try {{
    var request = new XMLHttpRequest();
    request.open("GET", "userdata/workflows%2Fimage_z_image_turbo.json", false);
    request.send(null);
    if (request.status >= 200 && request.status < 300 && request.responseText) {{
      var workflow = JSON.parse(request.responseText);
      var current = localStorage.getItem("workflow") || "";
      if (!current || current.indexOf("z_image_turbo_bf16.safetensors") === -1) {{
        localStorage.setItem("workflow", JSON.stringify(workflow));
        localStorage.setItem("iphish.defaultWorkflow", "z-image-turbo");
      }}
    }}
  }} catch (error) {{
    console.warn("Iphish could not preload the Z-Image-Turbo workflow", error);
  }}
}})();
</script>"""
    html = html.replace('<script type="module"', script + '<script type="module"', 1)
    index.write_text(html)

settings = Path("/opt/ComfyUI/user/default/comfy.settings.json")
settings.parent.mkdir(parents=True, exist_ok=True)
try:
    data = json.loads(settings.read_text()) if settings.exists() else {}
except json.JSONDecodeError:
    data = {}
data["Comfy.Workflow.Persist"] = False
data["Comfy.EnableWorkflowViewRestore"] = True
data["Comfy.TutorialCompleted"] = True
settings.write_text(json.dumps(data, indent=2, sort_keys=True))

assets = Path("/usr/local/lib/python3.12/dist-packages/comfyui_frontend_package/static/assets")
load_z_image = (
    "try{let e=await fetch(z.apiURL(`/userdata/${encodeURIComponent(`workflows/image_z_image_turbo.json`)}`));"
    "if(e.ok){let t=await e.json();await Q.loadGraphData(t,!0,!0,`Z-Image-Turbo`);return}}"
    "catch(e){console.warn(`Iphish could not load Z-Image-Turbo workflow`,e)}"
)
replacements = {
    "loadDefaultWorkflow=async()=>{await Q.loadGraphData(Qc)}":
        "loadDefaultWorkflow=async()=>{" + load_z_image + "await Q.loadGraphData(Qc)}",
    "loadBlankWorkflow=async()=>{await Q.loadGraphData(el)}":
        "loadBlankWorkflow=async()=>{" + load_z_image + "await Q.loadGraphData(el)}",
    "async function tryLoadGraph(e,t,n){if(!e)return!1;try{let n=JSON.parse(e);return await $.loadGraphData(n,!0,!0,t),!0}catch(e){return console.error(`Failed to load persisted workflow`,e),n?.(),!1}}":
        "async function tryLoadGraph(e,t,n){if(!e)return!1;try{let r=JSON.parse(e);if(!Array.isArray(r?.nodes)||r.nodes.length===0){n?.();return!1}return await $.loadGraphData(r,!0,!0,t),!0}catch(e){return console.error(`Failed to load persisted workflow`,e),n?.(),!1}}",
    "loadDefaultWorkflow=async()=>{n.get(`Comfy.TutorialCompleted`)?await $.loadGraphData():(await n.set(`Comfy.TutorialCompleted`,!0),await Xi().loadBlankWorkflow(),hasSharedWorkflowIntent()||await Ji().execute(`Comfy.BrowseTemplates`))}":
        "loadDefaultWorkflow=async()=>{try{let e=await fetch(Xn.apiURL(`/userdata/${encodeURIComponent(`workflows/image_z_image_turbo.json`)}`));if(e.ok){let t=await e.json();await $.loadGraphData(t,!0,!0,`Z-Image-Turbo`);return}}catch(e){console.warn(`Iphish could not load Z-Image-Turbo workflow on startup`,e)}n.get(`Comfy.TutorialCompleted`)?await $.loadGraphData():(await n.set(`Comfy.TutorialCompleted`,!0),await Xi().loadBlankWorkflow(),hasSharedWorkflowIntent()||await Ji().execute(`Comfy.BrowseTemplates`))}",
}
for bundle in assets.glob("*.js"):
    text = bundle.read_text(errors="ignore")
    updated = text
    for needle, replacement in replacements.items():
        updated = updated.replace(needle, replacement)
    if updated != text:
        bundle.write_text(updated)
PY
}

start_comfyui() {
  local host_project
  local network_target
  host_project="$(project_host_dir)"
  network_target="$(network_container)"
  mkdir -p "$PROJECT_DIR/data/comfyui/models" \
    "$PROJECT_DIR/data/comfyui/input" \
    "$PROJECT_DIR/data/comfyui/output" \
    "$PROJECT_DIR/data/comfyui/user" \
    "$PROJECT_DIR/data/comfyui/workflows"
  ensure_z_image_models
  {
    printf '=== starting ComfyUI at %s ===\n' "$(date -Is)"
    printf 'image=%s container=%s web=%s api=%s\n' "$COMFYUI_IMAGE" "$COMFYUI_CONTAINER_NAME" "$COMFYUI_WEB_URL" "$COMFYUI_API_URL"
  } >>"$LOG_FILE"
  if docker inspect "$COMFYUI_CONTAINER_NAME" >/dev/null 2>&1; then
    docker rm -f "$COMFYUI_CONTAINER_NAME" >>"$LOG_FILE" 2>&1 || true
  fi
  docker run -d \
    --name "$COMFYUI_CONTAINER_NAME" \
    --restart unless-stopped \
    --gpus all \
    --ipc=host \
    --network "container:$network_target" \
    -v "$host_project/data/comfyui/models:/opt/ComfyUI/models" \
    -v "$host_project/data/comfyui/input:/opt/ComfyUI/input" \
    -v "$host_project/data/comfyui/output:/opt/ComfyUI/output" \
    -v "$host_project/data/comfyui/user:/opt/ComfyUI/user" \
    -v "$host_project/data/comfyui/workflows:/opt/ComfyUI/user/default/workflows" \
    "$COMFYUI_IMAGE" >>"$LOG_FILE" 2>&1
  patch_comfyui_autoload >>"$LOG_FILE" 2>&1 || true
  wait_for_comfyui
}

download_model() {
  local url="$1"
  local output="$2"
  if [ -s "$output" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$output")"
  {
    printf 'downloading %s\n' "$output"
    printf 'source=%s\n' "$url"
  } >>"$LOG_FILE"
  curl -L --fail --retry 5 --retry-delay 5 -C - -o "$output.part" "$url" >>"$LOG_FILE" 2>&1
  mv "$output.part" "$output"
}

ensure_z_image_models() {
  download_model \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors" \
    "$PROJECT_DIR/data/comfyui/models/text_encoders/qwen_3_4b.safetensors"
  download_model \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors" \
    "$PROJECT_DIR/data/comfyui/models/diffusion_models/z_image_turbo_bf16.safetensors"
  download_model \
    "https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors" \
    "$PROJECT_DIR/data/comfyui/models/vae/ae.safetensors"
}

ensure_gophish_review_smtp() {
  python3 - "$GOPHISH_API_URL" "$GOPHISH_API_KEY" "$GOPHISH_REVIEW_SMTP_NAME" "$MAILPIT_SMTP_HOST:$MAILPIT_SMTP_PORT" <<'PY'
import json
import sys
import urllib.request

api_url, api_key, profile_name, smtp_host = sys.argv[1:5]

def request(method, path, payload=None):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        api_url.rstrip("/") + path,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=10) as resp:
        raw = resp.read()
        return json.loads(raw.decode() or "null")

payload = {
    "name": profile_name,
    "interface_type": "SMTP",
    "host": smtp_host,
    "from_address": "Iphish Training <training@example.local>",
    "ignore_cert_errors": True,
    "headers": [],
}

profiles = request("GET", "/smtp/")
for profile in profiles:
    if profile.get("name") == profile_name or profile.get("name") == "Mailpit SMTP (Test)":
        profile.update(payload)
        request("PUT", f"/smtp/{profile['id']}", profile)
        break
else:
    request("POST", "/smtp/", payload)
PY
}

prepare_gophish_state() {
  mkdir -p "$GOPHISH_STATE_DIR"
  if ! touch "$GOPHISH_STATE_DIR/.write-test" 2>/dev/null; then
    local host_project
    host_project="$(project_host_dir)"
    docker run --rm \
      --entrypoint sh \
      -v "$host_project/data/gophish:/target" \
      "$GOPHISH_IMAGE" \
      -lc "chown -R $(id -u):$(id -g) /target && chmod -R u+rwX /target" >/dev/null
  fi
  rm -f "$GOPHISH_STATE_DIR/.write-test" 2>/dev/null || true
  cat >"$GOPHISH_STATE_DIR/config.json" <<'EOF'
{
  "admin_server": {
    "listen_url": "0.0.0.0:3333",
    "use_tls": false,
    "cert_path": "gophish_admin.crt",
    "key_path": "gophish_admin.key",
    "trusted_origins": []
  },
  "phish_server": {
    "listen_url": "0.0.0.0:8080",
    "use_tls": false,
    "cert_path": "example.crt",
    "key_path": "example.key"
  },
  "db_name": "sqlite3",
  "db_path": "/opt/gophish/data/gophish.db",
  "migrations_prefix": "db/db_",
  "contact_address": "",
  "logging": {
    "filename": "",
    "level": "info"
  }
}
EOF
}

wait_for_gophish() {
  local i
  for i in $(seq 1 60); do
    if service_curl "$GOPHISH_ADMIN_URL/login"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

configure_gophish_admin() {
  python3 - "$GOPHISH_STATE_DIR/gophish.db" "$GOPHISH_API_KEY" "$GOPHISH_ADMIN_PASSWORD_HASH" <<'PY'
import sqlite3
import sys
from pathlib import Path

db = Path(sys.argv[1])
api_key = sys.argv[2]
password_hash = sys.argv[3]
if not db.exists():
    raise SystemExit(f"missing GoPhish database: {db}")
con = sqlite3.connect(db)
try:
    con.execute(
        "update users set api_key = ?, hash = ?, password_change_required = 0 where username = 'admin'",
        (api_key, password_hash),
    )
    con.commit()
finally:
    con.close()
PY
}

start_gophish() {
  local host_project
  local network_target
  host_project="$(project_host_dir)"
  network_target="$(network_container)"
  start_mailpit
  prepare_gophish_state
  {
    printf '=== starting GoPhish at %s ===\n' "$(date -Is)"
    printf 'image=%s container=%s admin=%s public=%s\n' "$GOPHISH_IMAGE" "$GOPHISH_CONTAINER_NAME" "$GOPHISH_ADMIN_URL" "$GOPHISH_PUBLIC_URL"
  } >>"$LOG_FILE"
  if docker inspect "$GOPHISH_CONTAINER_NAME" >/dev/null 2>&1; then
    docker rm -f "$GOPHISH_CONTAINER_NAME" >>"$LOG_FILE" 2>&1 || true
  fi
  docker run -d \
    --name "$GOPHISH_CONTAINER_NAME" \
    --restart unless-stopped \
    --network "container:$network_target" \
    -v "$host_project/data/gophish:/opt/gophish/data" \
    -v "$host_project/data/gophish/config.json:/opt/gophish/config.json:ro" \
    "$GOPHISH_IMAGE" \
    ./gophish --config /opt/gophish/config.json >>"$LOG_FILE" 2>&1
  wait_for_gophish
  configure_gophish_admin
  ensure_gophish_review_smtp
  curl -fsS --max-time 5 -H "Authorization: Bearer $GOPHISH_API_KEY" "$GOPHISH_API_URL/campaigns/" >/dev/null
}

stop_gophish_proxy() {
  docker rm -f "$GOPHISH_PROXY_CONTAINER_NAME" >/dev/null 2>&1 || true
  if [ -f "$GOPHISH_PROXY_PID_FILE" ]; then
    local pid
    pid="$(cat "$GOPHISH_PROXY_PID_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$GOPHISH_PROXY_PID_FILE"
  fi
}

start_gophish_proxy() {
  local host_project
  local host_asset_root
  local gophish_proxy_prefix="/projects/iphish-agent/applications/GoPhish"
  local network_target
  host_project="$(project_host_dir)"
  host_asset_root="$host_project/data/hermes/generated-images"
  network_target="$(network_container)"
  mkdir -p "$host_asset_root"
  mkdir -p "$(dirname "$GOPHISH_PROXY_LOG_FILE")"
  stop_gophish_proxy
  {
    printf '=== starting GoPhish Workbench proxy at %s ===\n' "$(date -Is)"
    printf 'port=%s prefix=%s\n' "$GOPHISH_PROXY_PORT" "$gophish_proxy_prefix"
  } >"$GOPHISH_PROXY_LOG_FILE"
  docker run -d \
    --name "$GOPHISH_PROXY_CONTAINER_NAME" \
    --restart unless-stopped \
    --network "container:$network_target" \
    --entrypoint python3 \
    -v "$PROJECT_DIR/scripts/gophish_workbench_proxy.py:/app/gophish_workbench_proxy.py:ro" \
    -v "$host_asset_root:/assets:ro" \
    -e GOPHISH_ASSET_ROOT=/assets \
    -e GOPHISH_API_KEY="$GOPHISH_API_KEY" \
    -e PROXY_PREFIX="$gophish_proxy_prefix" \
    -e GOPHISH_PROXY_PORT="$GOPHISH_PROXY_PORT" \
    "$IMAGE" \
    /app/gophish_workbench_proxy.py >>"$GOPHISH_PROXY_LOG_FILE" 2>&1
  local i
  for i in $(seq 1 30); do
    if service_curl "http://127.0.0.1:${GOPHISH_PROXY_PORT}/healthz"; then
      return 0
    fi
    sleep 1
  done
  printf 'GoPhish Workbench proxy did not become healthy. See %s\n' "$GOPHISH_PROXY_LOG_FILE" >>"$LOG_FILE"
  return 1
}

wait_for_hermes_api() {
  local i
  for i in $(seq 1 90); do
    if service_curl http://127.0.0.1:8642/health; then
      return 0
    fi
    sleep 2
  done
  return 1
}

wait_for_hermes_dashboard() {
  local i
  for i in $(seq 1 90); do
    if service_curl "http://127.0.0.1:${HERMES_DASHBOARD_PORT}/"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

start_container() {
  local host_project
  local network_target
  local llm_base_url
  host_project="$(project_host_dir)"
  network_target="$(network_container)"
  llm_base_url="$(resolve_llm_base_url "$BASE_URL")"
  prepare_state "$host_project" "$llm_base_url"
  {
    printf '=== starting Hermes Iphish Agent at %s ===\n' "$(date -Is)"
    printf 'image=%s container=%s model=%s base_url=%s\n' "$IMAGE" "$CONTAINER_NAME" "$MODEL" "$llm_base_url"
  } >"$LOG_FILE"

  start_gophish
  start_gophish_proxy

  if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    docker rm -f "$CONTAINER_NAME" >>"$LOG_FILE" 2>&1 || true
  fi

  docker run -d \
    --name "$CONTAINER_NAME" \
    --restart unless-stopped \
    --network "container:$network_target" \
    -e HERMES_DASHBOARD=1 \
    -e HERMES_UID="$(id -u)" \
    -e HERMES_GID="$(id -g)" \
    -e PUID="$(id -u)" \
    -e PGID="$(id -g)" \
    -e HERMES_DASHBOARD_HOST=0.0.0.0 \
    -e HERMES_DASHBOARD_PORT="$HERMES_DASHBOARD_PORT" \
    -e HERMES_DASHBOARD_INSECURE=1 \
    -e PATH=/opt/hermes/bin:/opt/hermes/.venv/bin:/opt/data/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    -e API_SERVER_ENABLED=true \
    -e API_SERVER_HOST=0.0.0.0 \
    -e API_SERVER_KEY="$API_SERVER_KEY" \
    -e OPENAI_BASE_URL="$llm_base_url" \
    -e OPENAI_API_KEY="$API_KEY" \
    -e HERMES_BASE_URL="$llm_base_url" \
    -e HERMES_API_KEY="$API_KEY" \
    -e HERMES_TUI_PROVIDER="$CUSTOM_PROVIDER_NAME" \
    -e HERMES_INFERENCE_PROVIDER="$CUSTOM_PROVIDER_NAME" \
    -e WORKBENCH_APP_BASE_URL="$WORKBENCH_APP_BASE_URL" \
    -e GOPHISH_ADMIN_URL="$GOPHISH_ADMIN_URL" \
    -e GOPHISH_API_URL="$GOPHISH_API_URL" \
    -e GOPHISH_PUBLIC_URL="$GOPHISH_PUBLIC_URL" \
    -e GOPHISH_API_KEY="$GOPHISH_API_KEY" \
    -e MAILPIT_WEB_URL="$MAILPIT_WEB_URL" \
    -e MAILPIT_API_URL="$MAILPIT_API_URL" \
    -e MAILPIT_USER_URL="$MAILPIT_USER_URL" \
    -e MAILPIT_SMTP_HOST="$MAILPIT_SMTP_HOST" \
    -e MAILPIT_SMTP_PORT="$MAILPIT_SMTP_PORT" \
    -e GOPHISH_REVIEW_SMTP_NAME="$GOPHISH_REVIEW_SMTP_NAME" \
    -e COMFYUI_WEB_URL="$COMFYUI_WEB_URL" \
    -e COMFYUI_API_URL="$COMFYUI_API_URL" \
    -e COMFYUI_DIRECT_URL="$COMFYUI_DIRECT_URL" \
    -v "$host_project/data/hermes:/opt/data" \
    -v "$host_project/data/hermes/.local/bin/iphishctl:/usr/local/bin/iphishctl:ro" \
    "$IMAGE" gateway run >>"$LOG_FILE" 2>&1

  nohup docker logs --timestamps --follow "$CONTAINER_NAME" >>"$LOG_FILE" 2>&1 </dev/null &
  wait_for_hermes_api
  wait_for_hermes_dashboard
}

stop_tui() {
  if [[ -f "$TTYD_PID_FILE" ]]; then
    local pid
    pid="$(cat "$TTYD_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$TTYD_PID_FILE"
  fi
}

start_tui() {
  mkdir -p "$(dirname "$TTYD_LOG_FILE")"
  stop_tui
  {
    printf '=== starting Hermes TUI web terminal at %s ===\n' "$(date -Is)"
    printf 'port=%s container=%s\n' "$TTYD_PORT" "$CONTAINER_NAME"
  } >"$TTYD_LOG_FILE"
  nohup ttyd \
    --interface 0.0.0.0 \
    --port "$TTYD_PORT" \
    docker exec -it \
      -e PATH=/opt/hermes/bin:/opt/hermes/.venv/bin:/opt/data/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
      -e HERMES_HOME=/opt/data \
      "$CONTAINER_NAME" \
      /opt/hermes/bin/hermes --tui --provider "$CUSTOM_PROVIDER_NAME" -m "$MODEL" >>"$TTYD_LOG_FILE" 2>&1 </dev/null &
  echo "$!" >"$TTYD_PID_FILE"
}

health() {
  local llm_base_url
  llm_base_url="$(resolve_llm_base_url "$BASE_URL")"
  docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null | grep -qx running
  docker inspect -f '{{.State.Status}}' "$GOPHISH_CONTAINER_NAME" 2>/dev/null | grep -qx running
  docker inspect -f '{{.State.Status}}' "$MAILPIT_CONTAINER_NAME" 2>/dev/null | grep -qx running
  curl -fsS --max-time 5 "${llm_base_url%/}/models" >/dev/null
  service_curl http://127.0.0.1:8642/health
  service_curl "http://127.0.0.1:${HERMES_DASHBOARD_PORT}/"
  service_curl "$GOPHISH_API_URL/campaigns/" -H "Authorization: Bearer $GOPHISH_API_KEY"
  service_curl "$MAILPIT_WEB_URL/api/v1/info"
}

case "$ACTION" in
  start)
    start_container
    ;;
  start-gophish)
    start_gophish
    start_gophish_proxy
    ;;
  start-gophish-proxy)
    start_gophish_proxy
    ;;
  start-mailpit)
    start_mailpit
    ;;
  start-comfyui)
    start_comfyui
    ;;
  stop)
    stop_tui
    stop_gophish_proxy
    docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm -f "$GOPHISH_CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm -f "$MAILPIT_CONTAINER_NAME" >/dev/null 2>&1 || true
    docker rm -f "$COMFYUI_CONTAINER_NAME" >/dev/null 2>&1 || true
    ;;
  stop-gophish)
    stop_gophish_proxy
    docker rm -f "$GOPHISH_CONTAINER_NAME" >/dev/null 2>&1 || true
    ;;
  stop-mailpit)
    docker rm -f "$MAILPIT_CONTAINER_NAME" >/dev/null 2>&1 || true
    ;;
  stop-comfyui)
    docker rm -f "$COMFYUI_CONTAINER_NAME" >/dev/null 2>&1 || true
    ;;
  restart)
    "$0" stop
    "$0" start
    ;;
  health)
    health
    ;;
  gophish-health)
    docker inspect -f '{{.State.Status}}' "$GOPHISH_CONTAINER_NAME" 2>/dev/null | grep -qx running
    docker inspect -f '{{.State.Status}}' "$MAILPIT_CONTAINER_NAME" 2>/dev/null | grep -qx running
    docker inspect -f '{{.State.Status}}' "$GOPHISH_PROXY_CONTAINER_NAME" 2>/dev/null | grep -qx running
    service_curl "$GOPHISH_ADMIN_URL/login"
    service_curl "$GOPHISH_API_URL/campaigns/" -H "Authorization: Bearer $GOPHISH_API_KEY"
    service_curl "http://127.0.0.1:${GOPHISH_PROXY_PORT}/healthz"
    ;;
  gophish-landing-health)
    docker inspect -f '{{.State.Status}}' "$GOPHISH_CONTAINER_NAME" 2>/dev/null | grep -qx running
    code="$(docker exec "$CONTAINER_NAME" curl -sS --max-time 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:8080/" || true)"
    [ "$code" = "404" ] || [ "$code" = "200" ]
    ;;
  mailpit-health)
    docker inspect -f '{{.State.Status}}' "$MAILPIT_CONTAINER_NAME" 2>/dev/null | grep -qx running
    service_curl "$MAILPIT_WEB_URL/api/v1/info"
    ;;
  comfyui-health)
    docker inspect -f '{{.State.Status}}' "$COMFYUI_CONTAINER_NAME" 2>/dev/null | grep -qx running
    service_curl "$COMFYUI_DIRECT_URL/system_stats"
    ;;
  status)
    docker ps -a --filter "name=$CONTAINER_NAME" --filter "name=$GOPHISH_CONTAINER_NAME" --filter "name=$MAILPIT_CONTAINER_NAME" --filter "name=$COMFYUI_CONTAINER_NAME" --filter "name=$GOPHISH_PROXY_CONTAINER_NAME" --format 'table {{.Names}}\t{{.Status}}'
    ;;
  logs)
    docker logs --tail "${2:-120}" "$CONTAINER_NAME"
    ;;
  gophish-logs)
    docker logs --tail "${2:-120}" "$GOPHISH_CONTAINER_NAME"
    ;;
  mailpit-logs)
    docker logs --tail "${2:-120}" "$MAILPIT_CONTAINER_NAME"
    ;;
  comfyui-logs)
    docker logs --tail "${2:-120}" "$COMFYUI_CONTAINER_NAME"
    ;;
  tui-logs)
    tail -n "${2:-120}" "$TTYD_LOG_FILE"
    ;;
  *)
    printf 'Usage: %s {start|start-gophish|start-gophish-proxy|start-mailpit|start-comfyui|stop|stop-gophish|stop-mailpit|stop-comfyui|restart|health|gophish-health|gophish-landing-health|mailpit-health|comfyui-health|status|logs|gophish-logs|mailpit-logs|comfyui-logs|tui-logs}\n' "$0" >&2
    exit 2
    ;;
esac
