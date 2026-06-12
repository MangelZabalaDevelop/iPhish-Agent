# Iphish Agent

Simple NVIDIA AI Workbench project for running:

- Iphish Agent, powered by Hermes.
- GoPhish, for authorized security-awareness campaign testing.

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

## GoPhish Login

Default local credentials:

```text
Username: admin
Password: Iphish123!
```

These credentials are for the local Workbench lab only.

## What Runs

Workbench starts these local containers:

```text
xpectra-iphish-agent
xpectra-iphish-agent-gophish
```

No NemoClaw, OpenShell, or legacy IPhish files are included in this project.
