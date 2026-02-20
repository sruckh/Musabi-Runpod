#!/usr/bin/env bash
set -euo pipefail

echo "[entrypoint] Starting musubi-tuner Runpod container"
echo "[entrypoint] Workspace: /workspace"

if [[ "${RUN_BOOTSTRAP_ON_START:-1}" == "1" ]]; then
  /opt/runpod/bootstrap.sh
else
  echo "[entrypoint] RUN_BOOTSTRAP_ON_START=0 -> skipping bootstrap"
fi

mkdir -p /workspace/notebooks
cp --update=none /opt/runpod/notebooks/00_musubi_tuner_runpod.ipynb /workspace/notebooks/00_musubi_tuner_runpod.ipynb || true

echo "[entrypoint] Launching JupyterLab on 0.0.0.0:${JUPYTER_PORT:-8888}"
exec jupyter lab \
  --ip=0.0.0.0 \
  --port="${JUPYTER_PORT:-8888}" \
  --allow-root \
  --no-browser \
  --IdentityProvider.token="${JUPYTER_TOKEN:-runpod}" \
  --ServerApp.password='' \
  --ServerApp.jpserver_extensions="{'jupyter_archive': False, 'notebook': False}" \
  --ServerApp.root_dir=/workspace
