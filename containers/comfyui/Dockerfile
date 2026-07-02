FROM nvcr.io/nvidia/pytorch:25.09-py3

ARG COMFYUI_REF=v0.27.0

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends git curl ca-certificates libx11-6 libxext6 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

RUN git clone --depth 1 --branch "$COMFYUI_REF" https://github.com/comfyanonymous/ComfyUI.git /workspace/ComfyUI

WORKDIR /workspace/ComfyUI

RUN python3 - <<'PY'
from pathlib import Path

path = Path("/workspace/ComfyUI/comfy/ldm/lightricks/vae/audio_vae.py")
text = path.read_text()
text = text.replace(
    "import torchaudio\n",
    "try:\n"
    "    import torchaudio\n"
    "except Exception:\n"
    "    torchaudio = None\n",
)
text = text.replace(
    "        if source_rate == self.target_sample_rate:\n"
    "            return waveform\n"
    "        return torchaudio.functional.resample(waveform, source_rate, self.target_sample_rate)\n",
    "        if source_rate == self.target_sample_rate:\n"
    "            return waveform\n"
    "        if torchaudio is None:\n"
    "            raise RuntimeError('torchaudio is required for audio VAE resampling')\n"
    "        return torchaudio.functional.resample(waveform, source_rate, self.target_sample_rate)\n",
)
text = text.replace(
    "        mel_transform = torchaudio.transforms.MelSpectrogram(\n",
    "        if torchaudio is None:\n"
    "            raise RuntimeError('torchaudio is required for audio VAE preprocessing')\n"
    "        mel_transform = torchaudio.transforms.MelSpectrogram(\n",
)
path.write_text(text)
PY

RUN grep -v -E '^(torch|torchvision|torchaudio)([<=> ].*)?$' requirements.txt > /tmp/comfyui-requirements.txt \
    && python3 -m pip install --no-cache-dir -r /tmp/comfyui-requirements.txt

EXPOSE 8188

CMD ["bash", "-lc", "cd /workspace/ComfyUI && python3 main.py --listen 0.0.0.0 --port 8188"]
