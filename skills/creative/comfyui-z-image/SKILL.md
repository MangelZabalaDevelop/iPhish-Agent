---
name: comfyui-z-image
description: Generate campaign-safe review images with local ComfyUI and Z-Image-Turbo.
version: 1.0.0
platforms: [linux]
metadata:
  hermes:
    tags: [comfyui, z-image-turbo, image-generation, creative-review]
    category: creative
    requires_toolsets: [terminal]
---

# ComfyUI Z-Image-Turbo

## When to Use

Use this skill when the user asks for campaign visuals, hero images, email
graphics, landing page imagery, concept art, or visual assets for an authorized
training campaign.

## Local Service

ComfyUI runs locally in the Workbench project.

```bash
COMFYUI_WEB_URL="${COMFYUI_WEB_URL:-http://127.0.0.1:8188/projects/iphish-agent/applications/ComfyUI}"
COMFYUI_API_URL="${COMFYUI_API_URL:-http://127.0.0.1:8188}"
COMFYUI_DIRECT_URL="${COMFYUI_DIRECT_URL:-http://127.0.0.1:8188}"
```

If ComfyUI is not reachable, tell the user to start the **ComfyUI** application
from NVIDIA AI Workbench. Do not pretend an image was created.

## Hard Rules

- Communicate with the user in English only.
- Never generate images for credential theft, coercion, impersonation harm, or unauthorized abuse.
- Generated images must contain no visible text, no letters, no numbers, no captions, no fake UI copy, and no readable logos.
- Prefer abstract branded visuals, atmosphere, realistic devices, workplace scenes, security concepts, and clean backgrounds.
- Do not place call-to-action text inside images. Put all text in HTML/CSS instead.
- After generating an image, validate it visually. Reject and regenerate if it contains text, looks generic, distorted, uncanny, low-quality, or like AI slop.

## Prompt Pattern

Always append this exact constraint to image prompts:

```text
No text, no letters, no words, no numbers, no logo text, no signage, no captions in the image.
```

Good prompt shape:

```text
Professional cybersecurity awareness hero image, modern office workstation,
subtle brand-inspired color palette, realistic lighting, clean composition,
human-safe training context, no readable screens, no text, no letters, no words,
no numbers, no logo text, no signage, no captions in the image.
```

## Generate

Use the helper script:

```bash
python3 /opt/data/skills/creative/comfyui-z-image/scripts/generate_z_image.py \
  --prompt "DESCRIBE THE IMAGE OBJECTIVE HERE" \
  --width 1024 \
  --height 1024 \
  --steps 8
```

The helper:

1. Queues the official Z-Image-Turbo workflow through ComfyUI.
2. Saves the generated PNG under `/opt/data/generated-images`.
3. Runs a vision review through the configured OpenAI-compatible model when available.
4. Prints JSON with `image_path`, `seed`, and `vision_review`.

## Visual Review Gate

Use the image only if the review says it passes and:

- `has_text` is false.
- `looks_ai_slop` is false.
- It matches the campaign objective.
- It is suitable for a controlled training campaign.

If it fails, generate a new image with a clearer prompt and report that the
previous attempt was rejected during visual review.

## Final Response

Report:

```text
Image status:
Image path:
Visual review:
Used in campaign:
Next step:
```
