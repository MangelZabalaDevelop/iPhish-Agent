#!/usr/bin/env python3
import argparse
import base64
import json
import os
import random
import time
import urllib.parse
import urllib.request
from pathlib import Path


NO_TEXT_RULE = "No text, no letters, no words, no numbers, no logo text, no signage, no captions in the image."


def request_json(method, url, payload=None, timeout=30):
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        raw = resp.read()
        return json.loads(raw.decode() or "null")


def build_prompt(text, width, height, steps, seed, prefix):
    safe_text = f"{text.strip()}. {NO_TEXT_RULE}"
    return {
        "3": {
            "class_type": "KSampler",
            "inputs": {
                "seed": seed,
                "steps": steps,
                "cfg": 1,
                "sampler_name": "res_multistep",
                "scheduler": "simple",
                "denoise": 1,
                "model": ["11", 0],
                "positive": ["27", 0],
                "negative": ["33", 0],
                "latent_image": ["13", 0],
            },
        },
        "8": {
            "class_type": "VAEDecode",
            "inputs": {"samples": ["3", 0], "vae": ["29", 0]},
        },
        "9": {
            "class_type": "SaveImage",
            "inputs": {"filename_prefix": prefix, "images": ["8", 0]},
        },
        "11": {
            "class_type": "ModelSamplingAuraFlow",
            "inputs": {"model": ["28", 0], "shift": 3},
        },
        "13": {
            "class_type": "EmptySD3LatentImage",
            "inputs": {"width": width, "height": height, "batch_size": 1},
        },
        "27": {
            "class_type": "CLIPTextEncode",
            "inputs": {"clip": ["30", 0], "text": safe_text},
        },
        "28": {
            "class_type": "UNETLoader",
            "inputs": {
                "unet_name": "z_image_turbo_bf16.safetensors",
                "weight_dtype": "default",
            },
        },
        "29": {
            "class_type": "VAELoader",
            "inputs": {"vae_name": "ae.safetensors"},
        },
        "30": {
            "class_type": "CLIPLoader",
            "inputs": {
                "clip_name": "qwen_3_4b.safetensors",
                "type": "lumina2",
                "device": "default",
            },
        },
        "33": {
            "class_type": "ConditioningZeroOut",
            "inputs": {"conditioning": ["27", 0]},
        },
    }


def wait_for_output(api_url, prompt_id, timeout):
    deadline = time.time() + timeout
    history_url = f"{api_url.rstrip('/')}/history/{urllib.parse.quote(prompt_id)}"
    while time.time() < deadline:
        history = request_json("GET", history_url, timeout=15)
        item = history.get(prompt_id)
        if item:
            outputs = item.get("outputs", {})
            for output in outputs.values():
                images = output.get("images") or []
                if images:
                    return images[0], item
        time.sleep(2)
    raise TimeoutError(f"Timed out waiting for ComfyUI output: {prompt_id}")


def download_image(api_url, image_info, out_dir):
    query = urllib.parse.urlencode(
        {
            "filename": image_info["filename"],
            "subfolder": image_info.get("subfolder", ""),
            "type": image_info.get("type", "output"),
        }
    )
    url = f"{api_url.rstrip('/')}/view?{query}"
    out_dir.mkdir(parents=True, exist_ok=True)
    target = out_dir / image_info["filename"]
    with urllib.request.urlopen(url, timeout=60) as resp:
        target.write_bytes(resp.read())
    return target


def validate_with_vision(image_path, prompt):
    base_url = os.environ.get("OPENAI_BASE_URL") or os.environ.get("HERMES_BASE_URL")
    model = os.environ.get("HERMES_MODEL", "")
    key = os.environ.get("OPENAI_API_KEY") or os.environ.get("HERMES_API_KEY") or "local"
    if not base_url or not model:
        return {"status": "skipped", "reason": "Missing OpenAI-compatible vision endpoint configuration."}

    data_url = "data:image/png;base64," + base64.b64encode(image_path.read_bytes()).decode()
    review_prompt = (
        "Review this generated campaign-safe image. Answer in JSON only with keys: "
        "passes, has_text, looks_ai_slop, issues, recommendation. "
        "Pass only if it matches the objective, contains no visible text/letters/numbers, "
        "and does not look generic, distorted, uncanny, low-quality, or AI slop. "
        f"Original objective: {prompt}"
    )
    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": review_prompt},
                    {"type": "image_url", "image_url": {"url": data_url}},
                ],
            }
        ],
        "temperature": 0,
        "max_tokens": 1536,
        "chat_template_kwargs": {"enable_thinking": False},
    }
    req = urllib.request.Request(
        base_url.rstrip("/") + "/chat/completions",
        data=json.dumps(payload).encode(),
        method="POST",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            response = json.loads(resp.read().decode())
        message = response["choices"][0]["message"]
        content = message.get("content")
        reasoning = message.get("reasoning")
        if content is None and reasoning:
            return {
                "status": "reasoning_only",
                "passes": None,
                "has_text": None,
                "looks_ai_slop": None,
                "issues": ["Vision endpoint returned reasoning without final JSON content."],
                "recommendation": "Operator should inspect the image manually or retry review with a non-thinking vision model.",
                "reasoning_excerpt": reasoning[:1200],
            }
        if content is None:
            return {
                "status": "empty",
                "passes": None,
                "has_text": None,
                "looks_ai_slop": None,
                "issues": ["Vision endpoint returned no content."],
                "recommendation": "Inspect the image manually.",
            }
        try:
            return json.loads(content)
        except json.JSONDecodeError:
            return {"status": "raw", "content": content}
    except Exception as exc:
        return {"status": "skipped", "reason": str(exc)}


def main():
    parser = argparse.ArgumentParser(description="Generate a Z-Image-Turbo image through local ComfyUI.")
    parser.add_argument("--prompt", required=True)
    parser.add_argument("--width", type=int, default=1024)
    parser.add_argument("--height", type=int, default=1024)
    parser.add_argument("--steps", type=int, default=8)
    parser.add_argument("--seed", type=int, default=None)
    parser.add_argument("--prefix", default="iphish-z-image")
    parser.add_argument("--timeout", type=int, default=900)
    parser.add_argument("--out-dir", default="/opt/data/generated-images")
    parser.add_argument("--no-vision", action="store_true")
    args = parser.parse_args()

    api_url = os.environ.get("COMFYUI_DIRECT_URL") or os.environ.get("COMFYUI_API_URL") or "http://127.0.0.1:8188"
    seed = args.seed if args.seed is not None else random.randint(1, 2**63 - 1)
    prompt = build_prompt(args.prompt, args.width, args.height, args.steps, seed, args.prefix)

    system_stats = request_json("GET", f"{api_url.rstrip('/')}/system_stats", timeout=10)
    queue = request_json("POST", f"{api_url.rstrip('/')}/prompt", {"prompt": prompt}, timeout=30)
    prompt_id = queue["prompt_id"]
    image_info, history = wait_for_output(api_url, prompt_id, args.timeout)
    image_path = download_image(api_url, image_info, Path(args.out_dir))

    result = {
        "status": "generated",
        "prompt_id": prompt_id,
        "seed": seed,
        "image_path": str(image_path),
        "image": image_info,
        "comfyui": {"url": api_url, "device": system_stats.get("devices", [{}])[0].get("name")},
        "vision_review": None,
    }
    if not args.no_vision:
        result["vision_review"] = validate_with_vision(image_path, args.prompt)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
