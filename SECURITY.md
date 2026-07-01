# Security Policy

## Intended Use

iPhish Agent is intended for authorized phishing-awareness simulations,
security training, and defensive workflow automation in a controlled local lab
or enterprise environment.

Do not use this project for unauthorized phishing, credential theft, social
engineering against unapproved targets, malware delivery, payment-data
collection, or collection of secrets.

## Safety Controls

- Campaign recipients must be explicitly provided and authorized.
- Mailpit is the default review SMTP target.
- Final SMTP delivery requires human approval.
- Landing pages must not request passwords, MFA codes, tokens, payment data, or
  secrets.
- Generated images must be reviewed before campaign use.
- Runtime state is ignored by Git: local databases, logs, models, generated
  campaign media, `.env`, and generated secrets are not published.
- `GOPHISH_API_KEY` and `HERMES_API_SERVER_KEY` are generated per local runtime
  under `data/scratch/secrets/` unless explicitly supplied by the operator.

## Workbench And Docker Socket Boundary

This project uses NVIDIA AI Workbench as the public packaging layer. The
Workbench project container uses access to the host Docker socket to launch
Hermes, GoPhish, Mailpit, ComfyUI, and the GoPhish Workbench proxy as local
containers.

Docker socket access is effectively host-level control. Run this project only on
a trusted workstation or lab system you control, such as the Dell Pro Max with
GB10 used for the contest demo. Do not expose the Workbench apps to untrusted
networks.

## OpenShell Guardrail Model

The repository includes `policies/openshell-policy.example.yaml` as the
guardrail template for bounding network access to the local model endpoint and
the expected local services. Adapt endpoint hosts and ports for your lab before
using it with an OpenShell runtime.

## Reporting Vulnerabilities

Open a GitHub issue with a clear description and reproduction steps. Do not
include live credentials, private campaign data, customer names, or real target
lists in public issues.
