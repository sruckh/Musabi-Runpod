#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] Starting musubi-tuner Runpod container"
echo "[entrypoint] Workspace: /workspace"

if [[ -z "${JUPYTER_TOKEN:-}" ]]; then
  echo "[entrypoint] ERROR: JUPYTER_TOKEN is required. Set it in Runpod template env vars."
  exit 1
fi

if [[ "${RUN_BOOTSTRAP_ON_START:-1}" == "1" ]]; then
  /opt/runpod/bootstrap.sh
else
  echo "[entrypoint] RUN_BOOTSTRAP_ON_START=0 -> skipping bootstrap"
fi

mkdir -p /workspace/notebooks
cp --update=none /opt/runpod/notebooks/00_musubi_tuner_runpod.ipynb /workspace/notebooks/00_musubi_tuner_runpod.ipynb || true

JUPYTER_DEFAULT_URL="${JUPYTER_DEFAULT_URL:-/lab}"

if [[ "${AUTO_START_TENSORBOARD:-0}" == "1" ]]; then
  echo "[entrypoint] AUTO_START_TENSORBOARD=1 -> starting TensorBoard in background"
  mkdir -p /workspace/logs
  nohup /opt/runpod/start_tensorboard.sh >/workspace/logs/tensorboard.log 2>&1 &
fi

echo "[entrypoint] Launching JupyterLab on 0.0.0.0:${JUPYTER_PORT:-8888} with default URL ${JUPYTER_DEFAULT_URL}"
exec jupyter lab \
  --ip=0.0.0.0 \
  --port="${JUPYTER_PORT:-8888}" \
  --no-browser \
  --allow-root \
  --ServerApp.default_url="${JUPYTER_DEFAULT_URL}" \
  --NotebookApp.password='' \
  --FileContentsManager.delete_to_trash=False \
  --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
  --ServerApp.allow_origin='*' \
  --ServerApp.preferred_dir="/workspace" \
  --ServerApp.allow_remote_access=True \
  --ServerApp.trust_xheaders=True \
  --NotebookApp.token="${JUPYTER_TOKEN}" \
  --ServerApp.token="${JUPYTER_TOKEN}" \
  --IdentityProvider.token="${JUPYTER_TOKEN}" \
  --ServerApp.root_dir="/workspace" \
  --ServerApp.jpserver_extensions="{'jupyter_archive': False}"
