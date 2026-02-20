#!/usr/bin/env bash
set -euo pipefail

# Keep Hub downloads robust inside musubi uv environment.
export HF_HUB_ENABLE_HF_TRANSFER=0
export HF_XET_HIGH_PERFORMANCE="${HF_XET_HIGH_PERFORMANCE:-1}"

DIT_PATH="${DIT_PATH:-/workspace/models/dit/diffusion_pytorch_model-00001-of-00002.safetensors}"
VAE_PATH="${VAE_PATH:-/workspace/models/vae/ae.safetensors}"
TEXT_ENCODER_PATH="${TEXT_ENCODER_PATH:-/workspace/models/text_encoder/model-00001-of-00003.safetensors}"
DATASET_CONFIG="${DATASET_CONFIG:-/workspace/dataset/dataset.toml}"
SAMPLE_PROMPTS="${SAMPLE_PROMPTS:-/workspace/dataset/sample_prompts.txt}"

NETWORK_DIM="${NETWORK_DIM:-32}"
NETWORK_ALPHA="${NETWORK_ALPHA:-16}"
LEARNING_RATE="${LEARNING_RATE:-1e-4}"
MAX_TRAIN_EPOCHS="${MAX_TRAIN_EPOCHS:-16}"
SAVE_EVERY_N_EPOCHS="${SAVE_EVERY_N_EPOCHS:-2}"
OUTPUT_DIR="${OUTPUT_DIR:-/workspace/output}"
OUTPUT_NAME="${OUTPUT_NAME:-character_lora_v1}"
LOGGING_DIR="${LOGGING_DIR:-/workspace/logs}"
SEED="${SEED:-42}"

if [[ ! -f "${DATASET_CONFIG}" ]]; then
  echo "[train] Missing dataset config: ${DATASET_CONFIG}"
  exit 1
fi

if [[ ! -f "${SAMPLE_PROMPTS}" ]]; then
  echo "[train] Missing sample prompts: ${SAMPLE_PROMPTS}"
  exit 1
fi

cd /workspace/musubi-tuner

TRAIN_ARGS=(
  --num_cpu_threads_per_process 2
  --mixed_precision bf16
  src/musubi_tuner/zimage_train_network.py
  --dit "${DIT_PATH}"
  --vae "${VAE_PATH}"
  --text_encoder "${TEXT_ENCODER_PATH}"
  --dataset_config "${DATASET_CONFIG}"
  --mixed_precision bf16
  --sdpa
  --timestep_sampling shift
  --weighting_scheme none
  --discrete_flow_shift 2.0
  --optimizer_type adamw8bit
  --learning_rate "${LEARNING_RATE}"
  --lr_scheduler cosine_with_restarts
  --lr_warmup_steps 100
  --network_module networks.lora_zimage
  --network_dim "${NETWORK_DIM}"
  --network_alpha "${NETWORK_ALPHA}"
  --fp8_base
  --fp8_scaled
  --fp8_llm
  --gradient_checkpointing
  --max_data_loader_n_workers 2
  --persistent_data_loader_workers
  --max_train_epochs "${MAX_TRAIN_EPOCHS}"
  --save_every_n_epochs "${SAVE_EVERY_N_EPOCHS}"
  --save_state
  --seed "${SEED}"
  --sample_every_n_steps 200
  --sample_prompts "${SAMPLE_PROMPTS}"
  --output_dir "${OUTPUT_DIR}"
  --output_name "${OUTPUT_NAME}"
  --log_with tensorboard
  --logging_dir "${LOGGING_DIR}"
)

if [[ -n "${BLOCKS_TO_SWAP:-}" ]]; then
  TRAIN_ARGS+=(--blocks_to_swap "${BLOCKS_TO_SWAP}")
fi

uv run accelerate launch "${TRAIN_ARGS[@]}"
