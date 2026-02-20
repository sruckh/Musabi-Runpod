#!/usr/bin/env bash
set -euo pipefail

MARKER_FILE="/workspace/.musubi_bootstrap_done"

if [[ -f "${MARKER_FILE}" ]]; then
  echo "[bootstrap] Already initialized. Skipping."
  exit 0
fi

echo "[bootstrap] Initializing workspace and software"

mkdir -p \
  /workspace/models/dit \
  /workspace/models/vae \
  /workspace/models/text_encoder \
  /workspace/dataset/images \
  /workspace/dataset/cache/latents \
  /workspace/dataset/cache/text_encoder \
  /workspace/output \
  /workspace/logs \
  /workspace/scripts \
  /workspace/notebooks \
  /workspace/.cache/huggingface

if [[ ! -d /workspace/musubi-tuner ]]; then
  echo "[bootstrap] Cloning musubi-tuner"
  git clone --recursive https://github.com/kohya-ss/musubi-tuner.git /workspace/musubi-tuner
else
  echo "[bootstrap] musubi-tuner exists, syncing submodules"
  git -C /workspace/musubi-tuner submodule update --init --recursive
fi

echo "[bootstrap] Installing musubi-tuner dependencies with uv"
cd /workspace/musubi-tuner

# Avoid leaking global venv into uv project env resolution.
unset VIRTUAL_ENV || true

MUSUBI_PYTHON="${MUSUBI_PYTHON:-3.10}"
MUSUBI_CUDA_EXTRA="${MUSUBI_CUDA_EXTRA:-cu130}"

echo "[bootstrap] uv sync with Python ${MUSUBI_PYTHON} and extra ${MUSUBI_CUDA_EXTRA}"
if ! uv sync --python "${MUSUBI_PYTHON}" --extra "${MUSUBI_CUDA_EXTRA}"; then
  echo "[bootstrap] uv sync failed with extra ${MUSUBI_CUDA_EXTRA}, retrying without CUDA extra"
  uv sync --python "${MUSUBI_PYTHON}"
fi

echo "[bootstrap] musubi environment Python version:"
uv run python -V
echo "[bootstrap] musubi torch/CUDA:"
uv run python -c "import torch; print('torch', torch.__version__, 'cuda', torch.version.cuda)"

echo "[bootstrap] Installing requested flash_attn wheel in musubi-tuner environment"
if uv run python -c "import sys; exit(0 if sys.version_info[:2] == (3, 12) else 1)"; then
  uv run python -m pip install --no-cache-dir \
    "https://github.com/Dao-AILab/flash-attention/releases/download/v2.8.3/flash_attn-2.8.3+cu12torch2.9cxx11abiTRUE-cp312-cp312-linux_x86_64.whl" || \
    echo "[bootstrap] flash_attn wheel install failed in musubi env; continuing."
else
  echo "[bootstrap] Skipping requested cp312 flash_attn wheel because musubi env is not Python 3.12."
fi

echo "[bootstrap] Installing bitsandbytes in musubi-tuner environment (best-effort)"
uv run python -m pip install --no-cache-dir bitsandbytes || \
  echo "[bootstrap] bitsandbytes install failed in musubi env; AdamW8bit may be unavailable."

echo "[bootstrap] Installing hf_transfer in musubi-tuner environment (best-effort)"
uv run python -m pip install --no-cache-dir hf_transfer || \
  echo "[bootstrap] hf_transfer install failed in musubi env; runtime scripts disable it by default."

echo "[bootstrap] Writing non-interactive accelerate config"
mkdir -p /root/.cache/huggingface/accelerate
cat > /root/.cache/huggingface/accelerate/default_config.yaml << 'EOF'
compute_environment: LOCAL_MACHINE
debug: false
distributed_type: 'NO'
downcast_bf16: 'no'
enable_cpu_affinity: false
gpu_ids: all
machine_rank: 0
main_training_function: main
mixed_precision: bf16
num_machines: 1
num_processes: 1
rdzv_backend: static
same_network: true
tpu_env: []
tpu_use_cluster: false
tpu_use_sudo: false
use_cpu: false
EOF

echo "[bootstrap] Staging helper scripts and templates into /workspace/scripts"
cp -f /opt/runpod/download_models.sh /workspace/scripts/download_models.sh
cp -f /opt/runpod/prepare_dataset.sh /workspace/scripts/prepare_dataset.sh
cp -f /opt/runpod/train_lora_prodigy.sh /workspace/scripts/train_lora_prodigy.sh
cp -f /opt/runpod/train_lora_adamw8bit.sh /workspace/scripts/train_lora_adamw8bit.sh
cp -f /opt/runpod/convert_lora.sh /workspace/scripts/convert_lora.sh
chmod +x /workspace/scripts/*.sh

if [[ ! -f /workspace/dataset/dataset.toml ]]; then
  cp /opt/runpod/dataset.toml.example /workspace/dataset/dataset.toml
fi
if [[ ! -f /workspace/dataset/sample_prompts.txt ]]; then
  cp /opt/runpod/sample_prompts.txt /workspace/dataset/sample_prompts.txt
fi

cp --update=none /opt/runpod/notebooks/00_musubi_tuner_runpod.ipynb /workspace/notebooks/00_musubi_tuner_runpod.ipynb || true

if [[ "${SKIP_MODEL_DOWNLOAD:-0}" != "1" ]]; then
  /workspace/scripts/download_models.sh
else
  echo "[bootstrap] SKIP_MODEL_DOWNLOAD=1 -> skipping model download"
fi

touch "${MARKER_FILE}"
echo "[bootstrap] Completed successfully"
