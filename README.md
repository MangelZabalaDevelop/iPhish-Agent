# Iphish Agent

Clean NVIDIA AI Workbench project for running Hermes Agent against a local
OpenAI-compatible vLLM endpoint.

## Get Started
1. Open this project in NVIDIA AI Workbench.
2. Set the Workbench Environment Variables if your vLLM endpoint differs:

```text
HERMES_MODEL=Qwen3.6-35B-A3B-NVFP4
HERMES_BASE_URL=http://192.168.0.8:9494
HERMES_API_KEY=local-external-vllm-placeholder
HERMES_API_SERVER_KEY=local-hermes-agent
GOPHISH_API_KEY=local-gophish-api-key-change-me
```

3. Start the `Iphish Agent` Application.
4. Click **Open**. Workbench opens a browser terminal running the Hermes TUI.

The Workbench Application starts two local containers on the Project Container
network:

```text
xpectra-iphish-agent
xpectra-iphish-agent-gophish
```

Hermes listens on:

```text
TUI web terminal: http://127.0.0.1:9119
API:              http://127.0.0.1:8642/v1
GoPhish admin:    http://127.0.0.1:3333
GoPhish public:   http://127.0.0.1:8080
```

Hermes receives these GoPhish variables:

```text
GOPHISH_ADMIN_URL=http://127.0.0.1:3333
GOPHISH_API_URL=http://127.0.0.1:3333/api
GOPHISH_PUBLIC_URL=http://127.0.0.1:8080
GOPHISH_API_KEY=<Workbench GOPHISH_API_KEY>
```

No NemoClaw, OpenShell, or legacy IPhish files are included in this project.
