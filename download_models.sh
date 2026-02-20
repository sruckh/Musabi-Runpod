#!/usr/bin/env bash
set -euo pipefail

export HF_HOME="${HF_HOME:-/workspace/.cache/huggingface}"
export HF_HUB_CACHE="${HF_HUB_CACHE:-/workspace/.cache/huggingface/hub}"
export HF_HUB_ENABLE_HF_TRANSFER="${HF_HUB_ENABLE_HF_TRANSFER:-1}"
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"
export HF_HUB_DOWNLOAD_TIMEOUT="${HF_HUB_DOWNLOAD_TIMEOUT:-30}"
export HF_HUB_ETAG_TIMEOUT="${HF_HUB_ETAG_TIMEOUT:-10}"
MAX_WORKERS="${HF_MAX_WORKERS:-16}"

mkdir -p \
  "${HF_HOME}" \
  "${HF_HUB_CACHE}" \
  /workspace/models/dit \
  /workspace/models/vae \
  /workspace/models/text_encoder

if [[ -n "${HF_TOKEN:-}" ]]; then
  echo "[download] Logging into Hugging Face with HF_TOKEN"
  hf auth login --token "${HF_TOKEN}" --no-add-to-git-credential || true
fi

if [[ \
  -f /workspace/models/dit/diffusion_pytorch_model-00001-of-00002.safetensors && \
  -f /workspace/models/dit/diffusion_pytorch_model-00002-of-00002.safetensors \
  ]]; then
  echo "[download] Z-Image Base DiT already present"
else
  echo "[download] Downloading Z-Image Base DiT"
  hf download Tongyi-MAI/Z-Image \
    transformer/diffusion_pytorch_model-00001-of-00002.safetensors \
    transformer/diffusion_pytorch_model-00002-of-00002.safetensors \
    --local-dir /workspace/models/dit \
    --max-workers "${MAX_WORKERS}"
  if compgen -G "/workspace/models/dit/transformer/*.safetensors" > /dev/null; then
    mv /workspace/models/dit/transformer/*.safetensors /workspace/models/dit/
  fi
fi

if [[ -f /workspace/models/vae/ae.safetensors ]]; then
  echo "[download] VAE already present"
else
  echo "[download] Downloading VAE"
  hf download Comfy-Org/z_image_turbo \
    split_files/vae/ae.safetensors \
    --local-dir /workspace/models/vae \
    --max-workers "${MAX_WORKERS}"
  if [[ -f /workspace/models/vae/split_files/vae/ae.safetensors ]]; then
    mv /workspace/models/vae/split_files/vae/ae.safetensors /workspace/models/vae/ae.safetensors
  fi
fi

if [[ \
  -f /workspace/models/text_encoder/model-00001-of-00003.safetensors && \
  -f /workspace/models/text_encoder/model-00002-of-00003.safetensors && \
  -f /workspace/models/text_encoder/model-00003-of-00003.safetensors \
  ]]; then
  echo "[download] Text encoder shards already present"
else
  echo "[download] Downloading text encoder shards"
  hf download Tongyi-MAI/Z-Image-Turbo \
    text_encoder/model-00001-of-00003.safetensors \
    text_encoder/model-00002-of-00003.safetensors \
    text_encoder/model-00003-of-00003.safetensors \
    --local-dir /workspace/models/text_encoder \
    --max-workers "${MAX_WORKERS}"
  if compgen -G "/workspace/models/text_encoder/text_encoder/*.safetensors" > /dev/null; then
    mv /workspace/models/text_encoder/text_encoder/*.safetensors /workspace/models/text_encoder/
  fi
fi

echo "[download] Model download step complete"
