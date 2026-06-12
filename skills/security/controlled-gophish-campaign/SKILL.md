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

## Hard Rules

- Communicate with the user in English only.
- Only create benign, authorized awareness simulations.
- Use only recipients explicitly provided by the user and described as trusted or owned.
- Never collect passwords, MFA codes, secrets, payment data, or sensitive data.
- Landing forms may collect low-risk training fields only, such as name, username, email, department, or country.
- Do not send a final campaign through real SMTP until the user explicitly approves the reviewed content.
- If SMTP/Mailpit is unavailable, stop and explain exactly what is missing. Do not pretend the test email was sent.

## Local Services

GoPhish and Mailpit are local to this Workbench project.

```bash
GOPHISH_ADMIN_URL="${GOPHISH_ADMIN_URL:-http://127.0.0.1:3333}"
GOPHISH_API_URL="${GOPHISH_API_URL:-http://127.0.0.1:3333/api}"
GOPHISH_PUBLIC_URL="${GOPHISH_PUBLIC_URL:-http://127.0.0.1:8080}"
GOPHISH_API_KEY="${GOPHISH_API_KEY:-local-gophish-api-key-change-me}"
MAILPIT_WEB_URL="${MAILPIT_WEB_URL:-http://127.0.0.1:8025/projects/iphish-agent/applications/Mailpit}"
MAILPIT_API_URL="${MAILPIT_API_URL:-http://127.0.0.1:8025/projects/iphish-agent/applications/Mailpit/api/v1}"
MAILPIT_SMTP_HOST="${MAILPIT_SMTP_HOST:-127.0.0.1}"
MAILPIT_SMTP_PORT="${MAILPIT_SMTP_PORT:-1025}"
GOPHISH_REVIEW_SMTP_NAME="${GOPHISH_REVIEW_SMTP_NAME:-Mailpit Review SMTP}"
```

Call the API with:

```bash
curl -fsS -H "Authorization: Bearer $GOPHISH_API_KEY" "$GOPHISH_API_URL/campaigns/"
curl -fsS "$MAILPIT_API_URL/info"
```

## Workflow

1. Restate the safe objective in one sentence.
2. Extract: target site URL, campaign topic, allowed recipient(s), fields to collect, and whether review-only or final SMTP is requested.
3. Verify the recipient list is explicit and trusted. If not, ask for clarification.
4. Inspect the reference site for public design cues: logo words, colors, layout, tone, and useful images. Do not hardcode one company; adapt to the provided URL.
5. Draft:
   - email subject
   - email HTML
   - landing page HTML
   - campaign name
   - safe training rationale
6. Create or reuse GoPhish objects in this order:
   - group
   - landing page
   - email template
   - sending profile
   - campaign
7. Use the `Mailpit Review SMTP` GoPhish sending profile for review sends. It delivers to Mailpit at `127.0.0.1:1025`; the user can inspect messages in the Workbench `Mailpit` app.
8. Report the created object names/IDs, recipient(s), review status, and the exact next approval step.

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

Minimal review SMTP profile:

```json
{"name":"Mailpit Review SMTP","interface_type":"SMTP","host":"127.0.0.1:1025","from_address":"Iphish Training <training@example.local>","ignore_cert_errors":true,"headers":[]}
```

Minimal campaign:

```json
{"name":"Training Campaign","template":{"name":"Training Email Template"},"page":{"name":"Training Landing Page"},"smtp":{"name":"Mailpit Review SMTP"},"url":"http://127.0.0.1:8080","groups":[{"name":"Training Review Group"}]}
```

## Quality Bar

- The email and landing page should look like a controlled internal training artifact, not credential theft.
- Use `{{.URL}}` for the GoPhish tracking link in the email.
- The landing page must include a visible training-safe purpose and only approved fields.
- Keep copy concise and believable without urgency, threats, account lockout claims, or coercion.
- If using generated visuals, prompts must say: "No text, no letters, no words in the image."
- After launching the review campaign, check Mailpit with `GET $MAILPIT_API_URL/messages` and report whether a message arrived.

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
