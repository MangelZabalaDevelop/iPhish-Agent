# Software And Models Inventory

## Dell System

- Dell Pro Max with GB10.
- NVIDIA GB10 Grace Blackwell platform.
- 128 GB LPDDR5X unified memory target.
- NVIDIA DGX OS 7 class local workstation environment.

## NVIDIA Software

- NVIDIA AI Workbench.
- Workbench project specification: `.project/spec.yaml`.
- Base environment: `nvcr.io/nvidia/ai-workbench/python-basic:1.0.9`.

## Agent And Guardrail Stack

- Hermes Agent container: `nousresearch/hermes-agent:latest`.
- OpenShell guardrail model: policy template in
  `policies/openshell-policy.example.yaml`.
- Controlled GoPhish Hermes skill:
  `skills/security/controlled-gophish-campaign/SKILL.md`.
- ComfyUI Hermes skill:
  `skills/creative/comfyui-z-image/SKILL.md`.

## Local Model

- Runtime interface: OpenAI-compatible vLLM endpoint.
- Demo model: `Qwen3.6-35B-A3B-NVFP4`.
- Default endpoint: `http://127.0.0.1:9494`.
- The public repository does not include model weights.

## Campaign Services

- GoPhish container: `opensecnetwork/gophish:multi-arch`.
- Mailpit container: `axllent/mailpit:latest`.
- GoPhish Workbench proxy: `scripts/gophish_workbench_proxy.py`.
- Helper CLI generated at runtime: `iphishctl`.

## Image Generation

- ComfyUI container: local image `iphish-comfyui:gb10`.
- ComfyUI image source: `containers/comfyui/Dockerfile`.
- Workflow: `data/comfyui/workflows/image_z_image_turbo.json`.
- Model files downloaded locally on first ComfyUI start:
  - `qwen_3_4b.safetensors`
  - `z_image_turbo_bf16.safetensors`
  - `ae.safetensors`
- Source: Comfy-Org Z-Image-Turbo files on Hugging Face.
- Model files are stored under `data/comfyui/models/` and ignored by Git.

## Python And System Packages

- Python from the Workbench base environment.
- `jupyterlab==4.3.6`.
- Apt packages:
  - `curl`
  - `docker.io`
  - `ttyd`

## Public Assets

- `static/iphish-cover.png`
- `static/iphish-architecture2.png`
- `static/iphish-demo.gif`
- Clean captures from the demo video under `static/`.

## Runtime Data Excluded From Git

- `data/hermes/`
- `data/gophish/`
- `data/comfyui/models/`
- `data/comfyui/input/`
- `data/comfyui/output/`
- `data/comfyui/user/`
- `logs/`
- `.env`
