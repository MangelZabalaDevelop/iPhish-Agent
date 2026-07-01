# iPhish Agent Technical Installation Guide

## Target Environment

- Hardware: Dell Pro Max with GB10.
- Operating environment: NVIDIA AI Workbench local location.
- GPU: GB10 Blackwell through the Workbench project runtime.
- Local model server: OpenAI-compatible vLLM endpoint reachable from the
  Workbench project.
- Container runtime: Docker access from inside the Workbench project container.

The project is public source, but runtime data is local and ignored by Git.

## Clone With NVIDIA AI Workbench

1. Open NVIDIA AI Workbench.
2. Select the local Dell Pro Max with GB10 location.
3. Select **Clone Project**.
4. Enter:

```text
https://github.com/MangelZabalaDevelop/iPhish-Agent.git
```

5. Let Workbench clone the repository and load the project specification.
6. Build the **Project Container**.
7. Configure the host mount required for Docker socket access:

```bash
nvwb configure mounts /var/run/:/host-run/ -c local -p /absolute/path/to/iPhish-Agent
```

In the Workbench UI, configure mount target `/host-run/` with host source
`/var/run/`.

8. Open **Environment > Project Container > Environment Variables**.
9. Set:

```text
HERMES_MODEL=Qwen3.6
HERMES_BASE_URL=http://127.0.0.1:9494
```

Use the local or LAN URL for your vLLM server if it is not on `127.0.0.1`.

## Validate From CLI

```bash
cd iPhish-Agent
nvwb validate project-spec
bash -n scripts/hermes_workbench.sh preBuild.bash postBuild.bash
python3 -m py_compile scripts/gophish_workbench_proxy.py
python3 -m py_compile skills/creative/comfyui-z-image/scripts/generate_z_image.py
```

## Start Apps

Start these Workbench apps from the project dashboard:

1. **Iphish** - starts Hermes, GoPhish, Mailpit, and the GoPhish proxy.
2. **GoPhish** - opens the campaign admin UI.
3. **Mailpit** - opens the review inbox.
4. **ComfyUI** - starts local image generation when needed.

The first ComfyUI start downloads Z-Image-Turbo files into
`data/comfyui/models/`. That path is ignored by Git.

## GoPhish Local Login

```text
Username: admin
Password: Iphish123!
```

This is a local demo password only. In a shared environment, set
`GOPHISH_ADMIN_PASSWORD_HASH` to a new bcrypt hash before starting GoPhish.

## Runtime Services

The launcher starts local containers for:

- `iphish-agent`
- `iphish-agent-gophish`
- `iphish-agent-gophish-proxy`
- `iphish-agent-mailpit`
- `iphish-agent-comfyui`

The project also writes ignored runtime state under:

- `data/hermes/`
- `data/gophish/`
- `data/comfyui/models/`
- `data/comfyui/input/`
- `data/comfyui/output/`
- `data/comfyui/user/`
- `logs/`

## Model Endpoint

The model server must expose an OpenAI-compatible API. The launcher normalizes
the configured base URL to `/v1` and checks `/models`.

Example:

```text
HERMES_MODEL=Qwen3.6
HERMES_BASE_URL=http://127.0.0.1:9494
```

If a model endpoint is not reachable, the Iphish app health check will fail.

## OpenShell Guardrails

Use `policies/openshell-policy.example.yaml` as the starting point for the
OpenShell guardrail runtime. Adapt endpoint hosts to your workstation.
The intended policy permits only the local model endpoint and expected local
services: GoPhish, Mailpit, ComfyUI, and Workbench control routes.

## Operational Flow

1. Operator opens Iphish.
2. Operator asks for an authorized awareness campaign.
3. Hermes loads `controlled-gophish-campaign`.
4. The skill verifies authorized recipients and safe fields.
5. The agent creates or updates GoPhish objects.
6. Review email goes to Mailpit.
7. `iphishctl review <campaign_id>` prints raw review links.
8. Human approval is required before real SMTP.

## Public Release Notes

This repository intentionally avoids publishing:

- GoPhish databases.
- Hermes history and auth state.
- Local model weights.
- Generated campaign assets.
- Logs.
- `.env`.
- Runtime-generated secrets.
