#!/usr/bin/env bash
set -euo pipefail

TENSORBOARD_HOST="${TENSORBOARD_HOST:-0.0.0.0}"
TENSORBOARD_PORT="${TENSORBOARD_PORT:-6006}"
TENSORBOARD_LOGDIR="${TENSORBOARD_LOGDIR:-/workspace/logs}"

mkdir -p "${TENSORBOARD_LOGDIR}"

echo "[tensorboard] Starting TensorBoard"
echo "[tensorboard] host=${TENSORBOARD_HOST} port=${TENSORBOARD_PORT} logdir=${TENSORBOARD_LOGDIR}"

exec tensorboard \
  --logdir "${TENSORBOARD_LOGDIR}" \
  --host "${TENSORBOARD_HOST}" \
  --port "${TENSORBOARD_PORT}"
