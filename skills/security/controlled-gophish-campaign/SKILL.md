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
MAILPIT_USER_URL="${MAILPIT_USER_URL:-http://localhost:10000/projects/iphish-agent/applications/Mailpit}"
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
iphishctl gophish-list campaigns 10
iphishctl gophish-list groups
iphishctl gophish-list pages
iphishctl gophish-list templates
iphishctl gophish-list smtp
iphishctl mailpit info
iphishctl mailpit messages
iphishctl comfy status
iphishctl asset-url /opt/data/generated-images/example.png
iphishctl review CAMPAIGN_ID
```

Use `iphishctl gophish-list ...` for discovery. It returns compact summaries
without full HTML, images, or campaign timelines. Do not list full campaigns,
pages, or templates unless you need one specific object by ID.

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

## Known-Good Workbench Routing

Do not debug GoPhish middleware or create alternate landing servers for normal
review campaigns. This project already has the required Workbench routing:

- GoPhish admin UI: open the Workbench GoPhish app button.
- GoPhish landing review URLs: use `GOPHISH_PUBLIC_URL + "?rid=<result id>"`.
- Mailpit review URLs: use `MAILPIT_USER_URL` and `/view/<message id>`.
- Workbench exposes `/applications/GoPhish` only after the GoPhish app has
  been started from Workbench at least once. If a user-facing GoPhish URL
  returns 404, tell the user to start the GoPhish app button and reopen the
  exact same URL.

If a review link is unclear or appears broken, run:

```bash
iphishctl review CAMPAIGN_ID
```

Then report the raw `MAILPIT_*` and `LANDING_*` lines exactly as printed. Do
not report `/GoPhish?rid=...`, `/GoPhish/landing` without `?rid=...`, or
internal `127.0.0.1` URLs to the user. Do not propose a separate Python server
on another port.

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
6. Run `iphishctl review CAMPAIGN_ID` and report the exact raw URL lines it returns.
7. If a local service is down, say which Workbench app must be started and stop there.

For visuals, use ComfyUI only when the user explicitly asks to generate images,
visuals, graphics, hero images, illustrations, or image assets for the campaign.
If the user only asks to use a site's design, logos, colors, brand, visual
style, or content as reference, use those cues in HTML/CSS and copy; do not
generate images unless the prompt specifically requests them.

When the user explicitly requests images, use the `comfyui-z-image` skill to
generate PNG files, then run `iphishctl asset-url IMAGE_PATH` for each accepted
image. Use the returned Workbench URL in GoPhish HTML, for example:

```html
<img src="http://localhost:10000/projects/iphish-agent/applications/GoPhish/assets/iphish-z-image_00001_.png" alt="Campaign visual">
```

Do not replace requested generated images with procedural SVGs, emoji art,
base64 placeholder drawings, or decorative CSS-only illustrations. If image
generation fails, report that limitation instead of faking generated images.

## GoPhish API Shape

When using `iphishctl gophish`, pass paths relative to `GOPHISH_API_URL`.
Because `GOPHISH_API_URL` already ends in `/api`, do not include `/api` in the
path. For example, use `/campaigns/`, not `/api/campaigns/`.

Use JSON with these helper paths:

```text
GET/POST /groups/
GET/POST /pages/
GET/POST /templates/
GET/POST /smtp/
GET/POST /campaigns/
```

Minimal group:

```json
{"name":"Training Review Group","targets":[{"email":"person@example.com","first_name":"Training","last_name":"User","position":"Awareness"}]}
```

Minimal landing page:

```json
{"name":"Training Landing Page","html":"<html>...</html>","capture_credentials":false,"capture_passwords":false}
```

For approved low-risk training fields, use normal form fields with `name`
attributes, such as `name="full_name"` and `name="country"`. If those fields
must be recorded in GoPhish, set `capture_credentials` to `true` and
`capture_passwords` to `false`. Never include password, token, MFA, payment, or
secret fields.

Minimal template:

```json
{"name":"Training Email Template","subject":"...","html":"<html>Use {{.URL}} for the training link.</html>"}
```

Clickable links and buttons must use exactly `{{.URL}}`, including both pairs
of braces. `{{.Tracker}}` is only for GoPhish's invisible tracking pixel. Never
put `{{.Tracker}}`, `/track`, `{.URL}`, or a hardcoded `/track?rid=...` in a
button or visible link.

All GoPhish template variables must use double braces, for example
`{{.FirstName}}`, `{{.URL}}`, and `{{.Tracker}}`. Single-brace variables such
as `{.FirstName}` are invalid and can break HTML rendering or API updates.

Minimal review SMTP profile:

```json
{"name":"Mailpit Review SMTP","interface_type":"SMTP","host":"127.0.0.1:1025","from_address":"Iphish Training <training@example.local>","ignore_cert_errors":true,"headers":[]}
```

Minimal campaign:

```json
{"name":"Training Campaign","template":{"name":"Training Email Template"},"page":{"name":"Training Landing Page"},"smtp":{"name":"Mailpit Review SMTP"},"url":"http://localhost:10000/projects/iphish-agent/applications/GoPhish/landing","groups":[{"name":"Training Review Group"}]}
```

The campaign `url` is required. If it is missing, GoPhish may send unusable or
misleading links. Use `GOPHISH_PUBLIC_URL` as the campaign URL.

## Quality Bar

- The email and landing page should look like a controlled internal training artifact, not credential theft.
- Use exactly `{{.URL}}` for every clickable GoPhish landing link in the email.
- The landing page must include a visible training-safe purpose and only approved fields.
- Keep copy concise and believable without urgency, threats, account lockout claims, or coercion.
- If the user explicitly asks for generated visuals, use the `comfyui-z-image`
  skill and its visual review gate.
- Do not use ComfyUI merely because the user mentioned a site's design, logos,
  colors, brand, or visual style.
- For accepted generated images, embed the `iphishctl asset-url` URL as normal
  PNG `<img>` sources. Do not embed large base64 data URIs in GoPhish unless
  explicitly asked.
- Image prompts must say: "No text, no letters, no words, no numbers, no logo text, no signage, no captions in the image."
- Never embed generated visuals until they pass visual review for objective match, no visible text, and no AI slop.
- After launching the review campaign, use `iphishctl review CAMPAIGN_ID`; report only the user-facing Workbench URLs from that output. Do not report internal `127.0.0.1:8025` Mailpit URLs or a landing URL without `?rid=...`.
- Put review URLs in a plain fenced text block. Do not format them as Markdown links like `[Mailpit](...)`, because the TUI may hide the actual URL.

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

For review links, use:

```text
MAILPIT_INBOX_URL=...
MAILPIT_MESSAGE_URL=...
LANDING_URL_1=...
```
