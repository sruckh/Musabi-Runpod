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

JUPYTER_DEFAULT_URL="${JUPYTER_DEFAULT_URL:-/tree}"

cat > /tmp/jupyter_server_config.py <<'PYCFG'
import os
c = get_config()
c.ServerApp.ip = "0.0.0.0"
c.ServerApp.port = int(os.environ.get("JUPYTER_PORT", "8888"))
c.ServerApp.allow_root = True
c.ServerApp.open_browser = False
c.ServerApp.root_dir = "/workspace"
c.ServerApp.password = ""
c.IdentityProvider.token = os.environ.get("JUPYTER_TOKEN", "runpod")
c.ServerApp.default_url = os.environ.get("JUPYTER_DEFAULT_URL", "/tree")
c.ServerApp.jpserver_extensions = {
    "jupyterlab": True,
    "notebook": True,
    "nbclassic": True,
    "jupyter_archive": False,
}
PYCFG

echo "[entrypoint] Launching Jupyter Server on 0.0.0.0:${JUPYTER_PORT:-8888} with default URL ${JUPYTER_DEFAULT_URL}"
exec jupyter server --config=/tmp/jupyter_server_config.py
