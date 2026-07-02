# iPhish Agent Technical Installation Guide

This guide describes the expected clean install path for NVIDIA AI Workbench on
a GB10-class workstation. It is written for a new user cloning the public repo
for the first time.

## Target Environment

- Hardware: Dell Pro Max with GB10, NVIDIA DGX Spark, or similar GB10 hardware.
- Operating environment: NVIDIA AI Workbench local location.
- GPU: exposed through the Workbench project runtime.
- Container runtime: Docker on the Workbench host.
- Model server: an OpenAI-compatible endpoint reachable from the Workbench
  project container.

The project source is public. Runtime data, downloaded models, logs, and local
secrets stay in ignored folders under the cloned project.

## Clean Workbench Setup

1. Open NVIDIA AI Workbench.
2. Select the local GB10 Workbench location.
3. Select **Clone Project**.
4. Enter:

```text
https://github.com/MangelZabalaDevelop/iPhish-Agent.git
```

5. Let Workbench clone the repository and load the project specification.
6. Open the project settings and configure the required Docker socket mount:

```text
Host source: /var/run/
Container target: /host-run/
```

This is the only manual Workbench mount required. It lets the project container
reach the host Docker socket as `/host-run/docker.sock`, which is how the app
starts GoPhish, Mailpit, ComfyUI, and the Workbench route helpers.

CLI equivalent for advanced users:

```bash
nvwb configure mounts /var/run/:/host-run/ -c local -p /absolute/path/to/iPhish-Agent
```

In NVIDIA AI Workbench, use the cloned project folder shown in the project
details; if you open a Workbench terminal from that project, replace
`/absolute/path/to/iPhish-Agent` with `$(pwd)`.

Example:

```bash
nvwb configure mounts /var/run/:/host-run/ -c local -p "$(pwd)"
```

7. Build the **Project Container**.
8. Open **Environment > Project Container > Environment Variables**.
9. Set the model endpoint values.

Default local endpoint:

```text
HERMES_MODEL=Qwen3.6-35B-A3B-NVFP4
HERMES_BASE_URL=http://127.0.0.1:9494
```

LAN endpoint example:

```text
HERMES_MODEL=Xpectra
HERMES_BASE_URL=http://192.168.0.3:9494
```

The launcher normalizes the configured URL to `/v1` automatically.

## Optional Environment Variables

These defaults are already safe for a clean GB10 Workbench install:

| Variable | Default | Purpose |
| --- | --- | --- |
| `HERMES_BASE_URL_CANDIDATES` | unset | Space-separated fallback model endpoints. |
| `HERMES_API_KEY` | `local-external-vllm-placeholder` | API key for the local OpenAI-compatible endpoint, if required. |
| `GOPHISH_IMAGE` | `opensecnetwork/gophish:multi-arch` | Public multi-architecture GoPhish image. |
| `GOPHISH_ADMIN_PASSWORD_HASH` | demo hash | Optional replacement bcrypt hash for the GoPhish admin password. |
| `COMFYUI_IMAGE` | `iphish-comfyui:gb10` | Local ComfyUI image built for GB10. |
| `COMFYUI_IMAGE_AUTO_BUILD` | `1` | Builds the local ComfyUI image on first start when missing. |

Runtime secrets such as `GOPHISH_API_KEY` and `HERMES_API_SERVER_KEY` are
generated locally under `data/hermes/` and should not be committed.

## Validate From CLI

Open a Workbench terminal in the project and run:

```bash
nvwb validate project-spec
bash -n scripts/hermes_workbench.sh preBuild.bash postBuild.bash
python3 -m py_compile scripts/gophish_workbench_proxy.py scripts/hermes_dashboard_proxy.py
python3 -m py_compile skills/creative/comfyui-z-image/scripts/generate_z_image.py
```

If the Docker socket mount is correct, this should also work:

```bash
docker -H unix:///host-run/docker.sock ps
```

## Start Apps

Start these apps from the Workbench project dashboard:

1. **Iphish** - starts Hermes, the no-auth dashboard proxy, GoPhish, Mailpit,
   and Workbench routes for the demo.
2. **GoPhish** - opens the campaign admin UI.
3. **Mailpit** - opens the review inbox.
4. **ComfyUI** - starts local image generation for Z-Image-Turbo assets.

The first ComfyUI start can take several minutes because it may build the local
`iphish-comfyui:gb10` image and download model files into
`data/comfyui/models/`.

Hermes/Iphish opens directly through Workbench. There is no Hermes dashboard
username or password in this setup.

## GoPhish Local Login

```text
Username: admin
Password: Iphish123!
```

This is a local demo password only. In a shared environment, set
`GOPHISH_ADMIN_PASSWORD_HASH` to a new bcrypt hash before starting GoPhish.

## Workbench Routes

The launcher writes Workbench proxy routes for both `localhost` and
`127.0.0.1` hosts:

| App | Route |
| --- | --- |
| Iphish | `/projects/iphish-agent/applications/Iphish` |
| GoPhish | `/projects/iphish-agent/applications/GoPhish` |
| Mailpit | `/projects/iphish-agent/applications/Mailpit` |
| ComfyUI | `/projects/iphish-agent/applications/ComfyUI` |

ComfyUI strips the Workbench prefix before forwarding to the internal service,
so API routes such as `/system_stats` keep working through the Workbench URL.

## Runtime Services

The launcher starts these local containers:

- `iphish-agent`
- `iphish-agent-dashboard-proxy`
- `iphish-agent-gophish`
- `iphish-agent-gophish-proxy`
- `iphish-agent-mailpit`
- `iphish-agent-comfyui`

The project writes ignored runtime state under:

- `data/hermes/`
- `data/gophish/`
- `data/comfyui/models/`
- `data/comfyui/input/`
- `data/comfyui/output/`
- `data/comfyui/user/`
- `data/comfyui/workflows/`
- `logs/`

## ComfyUI GB10 Image

The stable ComfyUI image is built from `containers/comfyui/Dockerfile` and
tagged as:

```text
iphish-comfyui:gb10
```

The Dockerfile uses `nvcr.io/nvidia/pytorch:25.09-py3`, pins ComfyUI to
`v0.27.0`, and filters `torch`, `torchvision`, and `torchaudio` from ComfyUI's
Python requirements so the NVIDIA PyTorch stack is kept intact.

The image also makes the ComfyUI audio VAE import tolerant when `torchaudio` is
unavailable. The iPhish image workflow does not require audio generation, and
this avoids installing a generic PyPI `torchaudio` wheel that can be
incompatible with the NVIDIA base image.

Do not use an older `flux-comfyui:latest` image for this project. That image
can start, but it may fail to load the Z-Image-Turbo workflow or the
`qwen_3_4b.safetensors` text encoder correctly.

## Smoke Tests

After starting **ComfyUI**, verify the direct API from a Workbench terminal:

```bash
curl -fsS http://127.0.0.1:8188/system_stats
```

Verify the Workbench route:

```bash
curl -fsS -H 'Host: localhost' \
  http://127.0.0.1:10000/projects/iphish-agent/applications/ComfyUI/system_stats
```

Generate a small test image:

```bash
COMFYUI_API_URL=http://127.0.0.1:8188 \
python3 skills/creative/comfyui-z-image/scripts/generate_z_image.py \
  --prompt "clean cybersecurity awareness image, no text" \
  --width 512 \
  --height 512 \
  --steps 1 \
  --timeout 420 \
  --no-vision
```

A successful run writes an image under `data/comfyui/output/`.

## Model Endpoint

The model server must expose an OpenAI-compatible API. The launcher normalizes
the configured base URL to `/v1` and checks `/models`.

Example:

```text
HERMES_MODEL=Qwen3.6-35B-A3B-NVFP4
HERMES_BASE_URL=http://127.0.0.1:9494
```

If the model endpoint is not reachable from the Workbench project container,
the Iphish app health check will fail.

## Troubleshooting

### Docker Socket Mount Missing

Symptom:

```text
Cannot connect to the Docker daemon
```

Fix the Workbench mount:

```text
Host source: /var/run/
Container target: /host-run/
```

Then rebuild or restart the project container.

### Dashboard Asks For Hermes Auth

Iphish should open without a Hermes username or password. If Workbench shows a
message similar to `public bind - auth required`, update to the current launcher
and restart the **Iphish** app. The launcher binds Hermes internally and exposes
it through `iphish-agent-dashboard-proxy`.

### ComfyUI Starts But Generation Fails

If generation fails with model shape or text encoder errors, make sure the
environment is using:

```text
COMFYUI_IMAGE=iphish-comfyui:gb10
COMFYUI_IMAGE_AUTO_BUILD=1
```

Then restart the **ComfyUI** app so the local GB10 image is built or reused.

### Workbench Route Returns 404 Or 502

Start the related app from the Workbench dashboard, or run the app launcher from
a Workbench terminal:

```bash
/project/scripts/hermes_workbench.sh start-comfyui
```

The launcher republishes the Workbench routes each time it starts an app.

### First ComfyUI Start Is Slow

This is expected on a clean machine. The first start may build the Docker image
and download Z-Image-Turbo files. Later starts reuse `iphish-comfyui:gb10` and
the downloaded files under `data/comfyui/models/`.

## OpenShell Guardrails

Use `policies/openshell-policy.example.yaml` as the starting point for the
OpenShell guardrail runtime. Adapt endpoint hosts to your workstation.
The intended policy permits only the local model endpoint and expected local
services: GoPhish, Mailpit, ComfyUI, and Workbench control routes.
