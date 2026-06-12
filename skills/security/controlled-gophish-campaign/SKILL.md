---
name: controlled-gophish-campaign
description: Build authorized security-awareness campaigns in local GoPhish with review-first safety gates.
version: 1.0.0
platforms: [linux]
metadata:
  hermes:
    tags: [security-awareness, gophish, phishing-simulation, training]
    category: security
    requires_toolsets: [terminal]
---

# Controlled GoPhish Campaign

## When to Use

Use this skill when the user asks to create an authorized phishing simulation,
security-awareness campaign, GoPhish campaign, training email, landing page, or
blue-team awareness exercise.

## Non-Negotiables

- Communicate with the user in English only.
- Only create benign, authorized awareness simulations.
- Use only recipients explicitly provided by the user and described as trusted or owned.
- Never collect passwords, MFA codes, secrets, payment data, or sensitive data.
- Landing forms may collect low-risk training fields only, such as name, username, email, department, or country.
- Do not send a final campaign through real SMTP until the user explicitly approves the reviewed content.
- If SMTP/Mailpit is unavailable, stop and explain exactly what is missing. Do not pretend the test email was sent.

Everything else is flexible. Prefer progress over ceremony: use reasonable
defaults, keep the user informed, and ask only for information that is truly
required to continue safely.

## Local Services

GoPhish, Mailpit, and ComfyUI are local to this Workbench project.

```bash
GOPHISH_ADMIN_URL="${GOPHISH_ADMIN_URL:-http://127.0.0.1:3333}"
GOPHISH_API_URL="${GOPHISH_API_URL:-http://127.0.0.1:3333/api}"
GOPHISH_PUBLIC_URL="${GOPHISH_PUBLIC_URL:-http://localhost:10000/projects/iphish-agent/applications/GoPhish/landing}"
GOPHISH_API_KEY="${GOPHISH_API_KEY:-local-gophish-api-key-change-me}"
MAILPIT_WEB_URL="${MAILPIT_WEB_URL:-http://127.0.0.1:8025/projects/iphish-agent/applications/Mailpit}"
MAILPIT_API_URL="${MAILPIT_API_URL:-http://127.0.0.1:8025/projects/iphish-agent/applications/Mailpit/api/v1}"
MAILPIT_SMTP_HOST="${MAILPIT_SMTP_HOST:-127.0.0.1}"
MAILPIT_SMTP_PORT="${MAILPIT_SMTP_PORT:-1025}"
GOPHISH_REVIEW_SMTP_NAME="${GOPHISH_REVIEW_SMTP_NAME:-Mailpit Review SMTP}"
COMFYUI_WEB_URL="${COMFYUI_WEB_URL:-http://127.0.0.1:8188/projects/iphish-agent/applications/ComfyUI}"
COMFYUI_API_URL="${COMFYUI_API_URL:-http://127.0.0.1:8188}"
COMFYUI_DIRECT_URL="${COMFYUI_DIRECT_URL:-http://127.0.0.1:8188}"
```

Use the bundled `iphishctl` helper for service access. Prefer this helper over
ad hoc Python files or raw curl commands.

```bash
iphishctl gophish GET /campaigns/
iphishctl mailpit info
iphishctl mailpit messages
iphishctl comfy status
```

For create/update operations, write the JSON body to a temporary `.json` file
and pass it to `iphishctl`, for example:

```bash
iphishctl gophish POST /groups/ /tmp/group.json
iphishctl gophish POST /pages/ /tmp/page.json
iphishctl gophish POST /templates/ /tmp/template.json
iphishctl gophish POST /smtp/ /tmp/smtp.json
iphishctl gophish POST /campaigns/ /tmp/campaign.json
```

Do not create one-off Python API clients for routine GoPhish, Mailpit, or
ComfyUI access. Do not pipe downloaded or curl output directly into `python3`,
`bash`, or another interpreter.

## Operating Style

Work naturally. The user usually wants a working review campaign, not a long
plan. Build the smallest complete campaign that satisfies the request, then
report what was created and what needs approval.

Use this loose flow:

1. Identify the reference site, topic, allowed recipient(s), and safe form fields.
2. If a trusted recipient is missing, ask for it. Otherwise continue.
3. Use public design cues from the provided site URL. Do not hardcode any company.
4. Create or reuse the GoPhish group, landing page, template, Mailpit SMTP profile, and campaign.
5. Send review traffic to Mailpit first. Only use real SMTP after explicit approval.
6. If a local service is down, say which Workbench app must be started and stop there.

For visuals, use ComfyUI when it will improve the campaign, but do not block the
whole campaign if image generation is unavailable. In that case, create clean
HTML/CSS without generated imagery and explain the limitation.

## GoPhish API Shape

Use JSON with these endpoints:

```text
GET/POST /api/groups/
GET/POST /api/pages/
GET/POST /api/templates/
GET/POST /api/smtp/
GET/POST /api/campaigns/
```

Minimal group:

```json
{"name":"Training Review Group","targets":[{"email":"person@example.com","first_name":"Training","last_name":"User","position":"Awareness"}]}
```

Minimal landing page:

```json
{"name":"Training Landing Page","html":"<html>...</html>","capture_credentials":false,"capture_passwords":false}
```

Minimal template:

```json
{"name":"Training Email Template","subject":"...","html":"<html>Use {{.URL}} for the training link.</html>"}
```

Clickable links and buttons must use exactly `{{.URL}}`, including both pairs
of braces. `{{.Tracker}}` is only for GoPhish's invisible tracking pixel. Never
put `{{.Tracker}}`, `/track`, `{.URL}`, or a hardcoded `/track?rid=...` in a
button or visible link.

Minimal review SMTP profile:

```json
{"name":"Mailpit Review SMTP","interface_type":"SMTP","host":"127.0.0.1:1025","from_address":"Iphish Training <training@example.local>","ignore_cert_errors":true,"headers":[]}
```

Minimal campaign:

```json
{"name":"Training Campaign","template":{"name":"Training Email Template"},"page":{"name":"Training Landing Page"},"smtp":{"name":"Mailpit Review SMTP"},"url":"http://localhost:10000/projects/iphish-agent/applications/GoPhish/landing","groups":[{"name":"Training Review Group"}]}
```

## Quality Bar

- The email and landing page should look like a controlled internal training artifact, not credential theft.
- Use exactly `{{.URL}}` for every clickable GoPhish landing link in the email.
- The landing page must include a visible training-safe purpose and only approved fields.
- Keep copy concise and believable without urgency, threats, account lockout claims, or coercion.
- If using generated visuals, use the `comfyui-z-image` skill and its visual review gate.
- Image prompts must say: "No text, no letters, no words, no numbers, no logo text, no signage, no captions in the image."
- Never embed generated visuals until they pass visual review for objective match, no visible text, and no AI slop.
- After launching the review campaign, check Mailpit with `iphishctl mailpit messages` and report whether a message arrived.

## Final Response Format

Return:

```text
Status:
Campaign:
Recipient(s):
Created GoPhish objects:
Review link or limitation:
Needs approval before final SMTP:
```
