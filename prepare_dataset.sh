#!/usr/bin/env bash
set -euo pipefail

DATASET_CONFIG="${DATASET_CONFIG:-/workspace/dataset/dataset.toml}"
VAE_PATH="${VAE_PATH:-/workspace/models/vae/ae.safetensors}"
TEXT_ENCODER_PATH="${TEXT_ENCODER_PATH:-/workspace/models/text_encoder/model-00001-of-00003.safetensors}"
TEXT_ENCODER_BATCH_SIZE="${TEXT_ENCODER_BATCH_SIZE:-4}"

if [[ ! -f "${DATASET_CONFIG}" ]]; then
  echo "[prepare] Missing dataset config: ${DATASET_CONFIG}"
  echo "[prepare] Copy /opt/runpod/dataset.toml.example to ${DATASET_CONFIG} and edit it."
  exit 1
fi

SANITIZED_DATASET_CONFIG="${DATASET_CONFIG}"
if grep -Eq "^[[:space:]]*shuffle_caption[[:space:]]*=" "${DATASET_CONFIG}"; then
  echo "[prepare] Found unsupported key 'shuffle_caption' in ${DATASET_CONFIG}; removing for compatibility"
  SANITIZED_DATASET_CONFIG="/tmp/dataset_config.sanitized.toml"
  grep -Ev "^[[:space:]]*shuffle_caption[[:space:]]*=" "${DATASET_CONFIG}" > "${SANITIZED_DATASET_CONFIG}"
fi

cd /workspace/musubi-tuner

echo "[prepare] Caching latents"
uv run python src/musubi_tuner/zimage_cache_latents.py \
  --dataset_config "${SANITIZED_DATASET_CONFIG}" \
  --vae "${VAE_PATH}"

echo "[prepare] Caching text encoder outputs"
TEXT_ENCODER_ARGS=(
  --dataset_config "${SANITIZED_DATASET_CONFIG}"
  --text_encoder "${TEXT_ENCODER_PATH}"
  --batch_size "${TEXT_ENCODER_BATCH_SIZE}"
)

if [[ "${ENABLE_FP8_LLM:-1}" == "1" ]]; then
  TEXT_ENCODER_ARGS+=(--fp8_llm)
fi

uv run python src/musubi_tuner/zimage_cache_text_encoder_outputs.py "${TEXT_ENCODER_ARGS[@]}"

echo "[prepare] Dataset cache complete"
