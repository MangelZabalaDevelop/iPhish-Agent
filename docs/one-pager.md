# iPhish Agent

*One-Pager | A local AI that helps companies train their people to spot phishing, on a Dell Pro Max with GB10.*

---

Phishing is when an attacker sends a fake email or message to trick someone into clicking a bad link or giving up a password. It is still the number one way criminals break into companies, and the attackers invent new tricks every day. The best defense is practice: companies send their own staff safe, fake phishing emails so people learn to spot the real ones. But setting that up by hand is slow and fiddly, so many companies barely do it.

iPhish Agent hands that whole job to a local AI helper. A specialist describes the exercise in plain English, and the agent builds the email, web page, recipient list, and review step. Nothing reaches a real person until a human checks and approves it.

![iPhish Agent Architecture](https://github.com/MangelZabalaDevelop/iPhish-Agent/raw/main/static/iphish-architecture2.png)

## How it works, step by step

1. The specialist types what they want, for example "a package-delivery reminder for the finance team."
2. The agent prepares the campaign inside GoPhish, the tool that runs these training exercises.
3. Every message goes first to Mailpit, a safe review inbox, so it can be checked before anything real is sent.
4. If images are needed, the agent generates them locally with ComfyUI. No stock assets, no external calls.
5. A human gives the final approval before any email actually goes out.

## Why it matters

Attackers move fast and operate freely, so defense has to keep pace. iPhish Agent lets a company run more of these exercises, more often, without the usual setup pain and without any data leaving the machine. Everything runs locally on the Dell Pro Max with GB10: no cloud, and the human always stays in control. OpenShell keeps the agent fenced to the tools it is meant to use, so it helps without ever running wild.

## Hardware, models, and main components

- **Hardware:** Dell Pro Max with GB10 (compact local AI workstation).
- **AI model:** local, OpenAI-compatible vLLM endpoint (demo model: Qwen3.6-35B-A3B-NVFP4). Images: ComfyUI with Z-Image-Turbo.
- **Packaging and control:** NVIDIA AI Workbench project, NVIDIA NemoClaw with OpenShell secure runtime, Hermes operator interface.
- **Security tooling:** GoPhish (campaigns and landing pages) and Mailpit (review-only inbox).
