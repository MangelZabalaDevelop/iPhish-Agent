# iPhish Agent One-Pager

## Overview

iPhish Agent is a local AI assistant that helps a security consultant create
authorized phishing-awareness simulations without manually wiring together every
tool. It runs as an NVIDIA AI Workbench project on Dell Pro Max with GB10 and
uses Hermes as the operator-facing agent.

The goal is defensive: make corporate awareness campaigns easier, safer, and
more repeatable so organizations can train employees against real phishing
techniques before attackers do.

## What It Does

An operator describes a safe awareness scenario in natural language. iPhish
Agent then prepares the GoPhish campaign objects, routes the first email through
Mailpit for review, and can generate local campaign visuals with ComfyUI when
requested. The agent is guided by a controlled GoPhish skill and an OpenShell
guardrail model so it only works inside the expected security-awareness lane.

## Why It Matters

Security teams need to run realistic exercises, but phishing simulation
platforms can be complex and risky when used manually. iPhish Agent reduces that
friction by giving the consultant a local AI operator that understands the
workflow, keeps review gates in place, and avoids collecting sensitive data.

This saves time while improving safety:

- Local model execution keeps campaign context on the workstation.
- Mailpit review prevents accidental real delivery.
- OpenShell policy boundaries limit expected tool and network access.
- The campaign skill blocks password, MFA, token, payment, and secret capture.
- Workbench packaging makes the demo reproducible for other users.

## Hardware And Model

- Dell system: Dell Pro Max with GB10.
- Model endpoint: local OpenAI-compatible vLLM endpoint.
- Demo model alias: Qwen3.6.
- Image model workflow: local ComfyUI with Z-Image-Turbo.

## Main Components

- NVIDIA AI Workbench: clone, build, run, and publish the project.
- Hermes Agent: natural-language interface and tool orchestration.
- OpenShell: guardrail model for bounded tool/network access.
- GoPhish: authorized campaign objects and landing pages.
- Mailpit: local SMTP sink and review inbox.
- ComfyUI: optional local image generation.

## Result

iPhish Agent packages a realistic offensive-security workflow into a defensive,
review-first local AI demo. It shows why a compact Dell Pro Max with GB10 is a
strong fit for enterprise security consultants: it can run and orchestrate local
agents, models, and training tools without sending sensitive workflow data to a
cloud service.
