#!/usr/bin/env bash
set -euo pipefail

# musubi-tuner's uv environment may not include hf_transfer.
# Disable transfer backend for reliability when tokenizers/models are fetched by transformers.
export HF_HUB_ENABLE_HF_TRANSFER=0
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"

DATASET_CONFIG="${DATASET_CONFIG:-/workspace/dataset/dataset.toml}"
VAE_PATH="${VAE_PATH:-/workspace/models/vae/ae.safetensors}"
TEXT_ENCODER_PATH="${TEXT_ENCODER_PATH:-/workspace/models/text_encoder/model-00001-of-00003.safetensors}"
TEXT_ENCODER_BATCH_SIZE="${TEXT_ENCODER_BATCH_SIZE:-4}"
TEXT_ENCODER_DEVICE="${TEXT_ENCODER_DEVICE:-cuda}"
TEXT_ENCODER_NUM_WORKERS="${TEXT_ENCODER_NUM_WORKERS:-1}"
TEXT_ENCODER_SKIP_EXISTING="${TEXT_ENCODER_SKIP_EXISTING:-1}"
LATENT_DEVICE="${LATENT_DEVICE:-cuda}"
LATENT_NUM_WORKERS="${LATENT_NUM_WORKERS:-1}"
LATENT_BATCH_SIZE="${LATENT_BATCH_SIZE:-1}"
LATENT_SKIP_EXISTING="${LATENT_SKIP_EXISTING:-1}"
DISABLE_CUDNN_BACKEND="${DISABLE_CUDNN_BACKEND:-1}"
RUN_LATENT_CACHE="${RUN_LATENT_CACHE:-1}"
RUN_TEXT_ENCODER_CACHE="${RUN_TEXT_ENCODER_CACHE:-1}"

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

echo "[prepare] Settings: RUN_LATENT_CACHE=${RUN_LATENT_CACHE}, LATENT_DEVICE=${LATENT_DEVICE}, RUN_TEXT_ENCODER_CACHE=${RUN_TEXT_ENCODER_CACHE}, TEXT_ENCODER_DEVICE=${TEXT_ENCODER_DEVICE}"

if [[ "${RUN_LATENT_CACHE}" == "1" ]]; then
  echo "[prepare] Caching latents"
  LATENT_ARGS=(
    --dataset_config "${SANITIZED_DATASET_CONFIG}"
    --vae "${VAE_PATH}"
    --device "${LATENT_DEVICE}"
    --num_workers "${LATENT_NUM_WORKERS}"
    --batch_size "${LATENT_BATCH_SIZE}"
  )

  if [[ "${DISABLE_CUDNN_BACKEND}" == "1" ]]; then
    LATENT_ARGS+=(--disable_cudnn_backend)
  fi

  if [[ "${LATENT_SKIP_EXISTING}" == "1" ]]; then
    LATENT_ARGS+=(--skip_existing)
  fi

  uv run python src/musubi_tuner/zimage_cache_latents.py "${LATENT_ARGS[@]}"
else
  echo "[prepare] RUN_LATENT_CACHE=0 -> skipping latent caching"
fi

if [[ "${RUN_TEXT_ENCODER_CACHE}" == "1" ]]; then
  echo "[prepare] Caching text encoder outputs"
  TEXT_ENCODER_ARGS=(
    --dataset_config "${SANITIZED_DATASET_CONFIG}"
    --text_encoder "${TEXT_ENCODER_PATH}"
    --batch_size "${TEXT_ENCODER_BATCH_SIZE}"
    --device "${TEXT_ENCODER_DEVICE}"
    --num_workers "${TEXT_ENCODER_NUM_WORKERS}"
  )

  if [[ "${ENABLE_FP8_LLM:-1}" == "1" ]]; then
    TEXT_ENCODER_ARGS+=(--fp8_llm)
  fi

  if [[ "${TEXT_ENCODER_SKIP_EXISTING}" == "1" ]]; then
    TEXT_ENCODER_ARGS+=(--skip_existing)
  fi

  uv run python src/musubi_tuner/zimage_cache_text_encoder_outputs.py "${TEXT_ENCODER_ARGS[@]}"
else
  echo "[prepare] RUN_TEXT_ENCODER_CACHE=0 -> skipping text encoder caching"
fi

echo "[prepare] Dataset cache complete"
