#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <input_lora.safetensors> [output_lora.safetensors]"
  exit 1
fi

INPUT_PATH="$1"
if [[ $# -ge 2 ]]; then
  OUTPUT_PATH="$2"
else
  OUTPUT_PATH="${INPUT_PATH%.safetensors}-comfy.safetensors"
fi

if [[ ! -f "${INPUT_PATH}" ]]; then
  echo "[convert] Missing input: ${INPUT_PATH}"
  exit 1
fi

cd /workspace/musubi-tuner

uv run python src/musubi_tuner/convert_lora.py \
  --input "${INPUT_PATH}" \
  --output "${OUTPUT_PATH}" \
  --target comfy

echo "[convert] Wrote ${OUTPUT_PATH}"
