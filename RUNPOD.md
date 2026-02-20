# Runpod Container: Musubi-Tuner + Z-Image Base

This repo now includes a Runpod-ready container that:
- starts from `runpod/base:1.0.3-cuda1290-ubuntu2404`
- installs your requested flash-attn wheel:
  `flash_attn-2.8.3+cu12torch2.9cxx11abiTRUE-cp312-cp312-linux_x86_64.whl`
- uses `hf` (not deprecated `huggingface-cli`)
- optimizes downloads with Hugging Face transfer settings
- boots into JupyterLab and exposes training helper scripts

## Files Added

- `Dockerfile`
- `entrypoint.sh`
- `bootstrap.sh`
- `download_models.sh`
- `prepare_dataset.sh`
- `train_lora_prodigy.sh`
- `train_lora_adamw8bit.sh`
- `convert_lora.sh`
- `dataset.toml.example`
- `sample_prompts.txt`
- `notebooks/00_musubi_tuner_runpod.ipynb`

## Runpod-Only Deployment (No Local Installs)

Do not build or run this container on your local host.
Use a registry image built remotely (for example, Docker Hub automated build or GitHub Actions to GHCR), then use that image in Runpod.

## Runpod Template Settings

- Container image: your remote registry image tag
- Expose port: `8888`
- Recommended env vars:
  - `HF_TOKEN` (optional; needed for gated/private repos)
  - `JUPYTER_TOKEN` (set a strong value)
  - `HF_MAX_WORKERS=16` (or tune per network speed)
  - `SKIP_MODEL_DOWNLOAD=0` (set `1` if models are already present)

## GitHub Actions (Remote Build/Push Only)

Workflow file:
- `.github/workflows/docker-publish.yml`

This workflow builds remotely on GitHub Actions and pushes to Docker Hub:
- Image: `gemneye/musabi-runpod`
- Triggers: push to `main`, tags `v*`, and manual run (`workflow_dispatch`)

Repository target:
- GitHub repo: `sruckh/Musabi-Runpod`

Required GitHub repository secrets:
- `DOCKER_USERNAME` = `gemneye`
- `DOCKER_PASSWORD` = Docker Hub Personal Access Token

After first successful workflow run, use one of these image tags in Runpod:
- `gemneye/musabi-runpod:latest` (default branch build)
- `gemneye/musabi-runpod:main`
- `gemneye/musabi-runpod:sha-<commit>`
- `gemneye/musabi-runpod:vX.Y.Z` (when pushing a matching git tag)

## Startup Behavior

On first container boot:
1. Clones `musubi-tuner` into `/workspace/musubi-tuner`
2. Installs musubi dependencies via `uv sync --extra cu128`
3. Configures `accelerate`
4. Downloads Z-Image model files into `/workspace/models/*`
5. Copies scripts into `/workspace/scripts`
6. Launches JupyterLab

Subsequent boots skip setup using:
- `/workspace/.musubi_bootstrap_done`

## User Workflow in Jupyter

1. Upload images + matching captions (`.txt`) to:
   - `/workspace/dataset/images`
2. Verify/edit dataset config:
   - `/workspace/dataset/dataset.toml`
3. Prepare caches:
   - `/workspace/scripts/prepare_dataset.sh`
4. Train:
   - `/workspace/scripts/train_lora_prodigy.sh`
5. Convert for ComfyUI:
   - `/workspace/scripts/convert_lora.sh <checkpoint.safetensors>`

## `hf` Download Optimization Included

This setup uses `hf` CLI and enables:
- `HF_HUB_ENABLE_HF_TRANSFER=1`
- `HF_XET_HIGH_PERFORMANCE=1`
- `HF_HUB_DOWNLOAD_TIMEOUT=30`
- `HF_HUB_ETAG_TIMEOUT=10`
- `hf download ... --max-workers ${HF_MAX_WORKERS}`

From current Hub docs, `hf download` supports:
- `--include`, `--exclude`
- `--local-dir`
- `--repo-type`
- `--revision`
- `--cache-dir`
- `--max-workers`
