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
```

3. Start the `Iphish Agent` Application.
4. Open the Hermes dashboard from Workbench.

The Workbench Application starts one Docker container:

```text
xpectra-iphish-agent
```

Hermes listens on:

```text
Dashboard: http://127.0.0.1:9119
API:       http://127.0.0.1:8642/v1
```

No GoPhish, NemoClaw, OpenShell, or legacy IPhish files are included in this
project.
