# Iphish Agent

Simple NVIDIA AI Workbench project for running:

- Iphish Agent, powered by Hermes.
- GoPhish, for authorized security-awareness campaign testing.
- Mailpit, for local email review before any final send.
- ComfyUI, for local review images with Z-Image-Turbo.

## First Setup

1. Open this project in NVIDIA AI Workbench.
2. Go to **Environment > Project Container > Environment Variables**.
3. Confirm these two values:

```text
HERMES_MODEL=Qwen3.6-35B-A3B-NVFP4
HERMES_BASE_URL=http://192.168.0.8:9494
```

Use the IP and port of your running vLLM server. If your vLLM is already using
`192.168.0.8:9494`, you do not need to change anything.

## Start

1. Start **Iphish Agent**.
2. Click **Open Iphish Agent** to open the agent terminal.
3. Start **GoPhish**.
4. Click **Open GoPhish** to open the GoPhish admin panel.
5. Start **Mailpit**.
6. Click **Open Mailpit** to review test emails.
7. Start **ComfyUI** when the agent needs images.
8. Click **Open ComfyUI** to inspect generated images and workflows.

The first ComfyUI start can take a while because it downloads the official
Z-Image-Turbo files. After that, the files stay local in the project data
folder.

## GoPhish Login

Default local credentials:

```text
Username: admin
Password: Iphish123!
```

These credentials are for the local Workbench lab only.

Campaign landing links are opened through the Workbench GoPhish proxy:

```text
http://localhost:10000/projects/iphish-agent/applications/GoPhish/landing
```

The agent uses this URL when it creates campaigns, so links in Mailpit should
open the landing page directly. The GoPhish admin button still opens the admin
panel.

## What Runs

Workbench starts these local containers:

```text
xpectra-iphish-agent
xpectra-iphish-agent-gophish
xpectra-iphish-agent-mailpit
xpectra-iphish-agent-comfyui
```

The agent includes a small local Hermes skill named
`controlled-gophish-campaign`. It teaches Hermes how to create safe,
authorized GoPhish awareness campaigns and requires review before final SMTP.

The agent also includes `comfyui-z-image`, a small Hermes skill for creating
campaign-safe images through ComfyUI. It uses the Z-Image-Turbo workflow and
requires generated images to avoid visible text and pass visual review before
use.

ComfyUI model files are stored under:

```text
data/comfyui/models/
```

The configured Z-Image-Turbo files are:

```text
data/comfyui/models/text_encoders/qwen_3_4b.safetensors
data/comfyui/models/diffusion_models/z_image_turbo_bf16.safetensors
data/comfyui/models/vae/ae.safetensors
```

No NemoClaw, OpenShell, or legacy IPhish files are included in this project.
